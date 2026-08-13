#!/usr/bin/env bash
#
# Manages published skills in blob storage.
#
#   publish <version> [dist-dir]     upload a version's artifacts and index — no pointer change
#   verify  <version>                re-download the version and check every digest
#   promote <environment> <version>  point an environment at a version, then confirm it serves it
#   prune                            delete old versions, keeping the newest $KEEP plus any in use
#
# Versions are immutable, so publish is safe to repeat and promote is just a pointer copy.
# Each version folder carries its own index.json, which is what the environment pointers are
# copies of — so a version is self-describing and nothing here needs a local dist/ except publish.
#
# Requires: ACCOUNT, CONTAINER.
# Optional: KEEP (default 5), DRY_RUN=1, SKIP_ENDPOINT_CHECK=1, CACHE_FLUSH_KEY,
#           STAGING_URL, PRODUCTION_URL, VERIFY_TIMEOUT_SECONDS.
set -euo pipefail

ACCOUNT="${ACCOUNT:?ACCOUNT is required}"
CONTAINER="${CONTAINER:?CONTAINER is required}"
KEEP="${KEEP:-5}"
DRY_RUN="${DRY_RUN:-0}"
VERIFY_TIMEOUT_SECONDS="${VERIFY_TIMEOUT_SECONDS:-420}"

az_blob() { az storage blob "$@" --auth-mode login --account-name "$ACCOUNT"; }
step()    { printf '\n=== %s\n' "$*"; }
die()     { echo "error: $*" >&2; exit 1; }

environment_url() {
  case "$1" in
    staging)    echo "${STAGING_URL:-https://mcp-staging.tiun.business}" ;;
    production) echo "${PRODUCTION_URL:-https://mcp.tiun.business}" ;;
    *)          die "unknown environment '$1' (expected staging or production)" ;;
  esac
}

blob_exists() {
  [ "$(az_blob exists --container-name "$CONTAINER" --name "$1" --query exists -o tsv)" = "true" ]
}

# Versions referenced by a pointer file, given its contents on stdin.
versions_in_index() {
  jq -r '.skills[].url' 2>/dev/null | sed -nE 's#.*/agent-skills/([0-9]+-[0-9a-z]+)/.*#\1#p' | sort -u
}

# --- publish -----------------------------------------------------------------

cmd_publish() {
  local version="${1:?usage: publish <version> [dist-dir]}"
  local dist="${2:-dist}"

  [ -f "${dist}/index.json" ] || die "no ${dist}/index.json — run build-skills.sh first"

  # Catch a version that doesn't match the one baked into the index URLs.
  local indexed
  indexed="$(versions_in_index < "${dist}/index.json")"
  [ "$indexed" = "$version" ] || die "index.json references '${indexed:-<none>}', not '${version}'"

  step "Publishing ${version}"
  local f blob
  for f in "$dist"/*.tar.gz; do
    blob="${version}/$(basename "$f")"
    if blob_exists "$blob"; then
      echo "  already present: $blob"
    elif [ "$DRY_RUN" = "1" ]; then
      echo "  would upload: $blob"
    else
      az_blob upload --container-name "$CONTAINER" --name "$blob" --file "$f" \
        --content-type application/gzip --no-progress >/dev/null
      echo "  uploaded: $blob"
    fi
  done

  # Index last, so a complete version folder never advertises a missing artifact.
  if [ "$DRY_RUN" = "1" ]; then
    echo "  would upload: ${version}/index.json"
  else
    az_blob upload --container-name "$CONTAINER" --name "${version}/index.json" \
      --file "${dist}/index.json" --content-type application/json --overwrite --no-progress >/dev/null
    echo "  uploaded: ${version}/index.json"
  fi
}

# --- verify ------------------------------------------------------------------

cmd_verify() {
  local version="${1:?usage: verify <version>}"
  step "Verifying ${version}"

  local work index
  work="$(mktemp -d)"; trap 'rm -rf "$work"' RETURN
  index="${work}/index.json"

  blob_exists "${version}/index.json" || die "${version}/index.json not published"
  az_blob download --container-name "$CONTAINER" --name "${version}/index.json" \
    --file "$index" --no-progress >/dev/null

  local failed=0 name url digest blob actual
  while IFS=$'\t' read -r name url digest; do
    blob="${url#/.well-known/agent-skills/}"

    if ! blob_exists "$blob"; then
      echo "  MISSING  ${name}: ${blob}" >&2
      failed=1
      continue
    fi

    az_blob download --container-name "$CONTAINER" --name "$blob" \
      --file "${work}/artifact" --no-progress >/dev/null
    actual="sha256:$(sha256sum "${work}/artifact" | cut -d' ' -f1)"
    rm -f "${work}/artifact"

    if [ "$actual" = "$digest" ]; then
      echo "  ok       ${name}  ${digest}"
    else
      echo "  MISMATCH ${name}: published ${actual}, index says ${digest}" >&2
      failed=1
    fi
  done < <(jq -r '.skills[] | [.name, .url, .digest] | @tsv' "$index")

  [ "$failed" = "0" ] || die "${version} is not intact"
  echo "  ${version} is intact"
}

# --- promote -----------------------------------------------------------------

cmd_promote() {
  local environment="${1:?usage: promote <environment> <version>}"
  local version="${2:?usage: promote <environment> <version>}"
  local pointer="${environment}.json"
  local base_url; base_url="$(environment_url "$environment")"

  step "Promoting ${environment} to ${version}"

  blob_exists "${version}/index.json" || die "${version} is not published"

  if [ "$DRY_RUN" = "1" ]; then
    echo "  would copy: ${version}/index.json -> ${pointer}"
  else
    # Round-trip through the runner rather than `az storage blob copy start`. It's a few hundred
    # bytes, and the pointer is written by the same upload path as everything else.
    local tmp; tmp="$(mktemp -d)"
    az_blob download --container-name "$CONTAINER" --name "${version}/index.json" \
      --file "${tmp}/index.json" --no-progress >/dev/null
    az_blob upload --container-name "$CONTAINER" --name "$pointer" --file "${tmp}/index.json" \
      --content-type application/json --overwrite --no-progress >/dev/null
    rm -rf "$tmp"
    echo "  copied: ${version}/index.json -> ${pointer}"

    # Read back rather than trust the write.
    local landed
    landed="$(az_blob download --container-name "$CONTAINER" --name "$pointer" \
              --no-progress 2>/dev/null | versions_in_index)"
    [ "$landed" = "$version" ] || die "${pointer} names '${landed:-<none>}' after the copy, not '${version}'"
    echo "  ${pointer} confirmed at ${version}"
  fi

  if [ "${SKIP_ENDPOINT_CHECK:-0}" = "1" ] || [ "$DRY_RUN" = "1" ]; then
    echo "  endpoint check skipped"
    return 0
  fi
  check_endpoint "$base_url" "$version"
}

# The CLI drops a skill with a bad digest or archive by returning null — no error, no message — so
# a broken publish looks exactly like an empty one. Installing for real is the only way to tell.
check_endpoint() {
  local base="$1" version="$2"
  step "Checking ${base}"

  local work index expected_names expected_digests served deadline
  work="$(mktemp -d)"; trap 'rm -rf "$work"' RETURN
  index="${work}/index.json"
  az_blob download --container-name "$CONTAINER" --name "${version}/index.json" \
    --file "$index" --no-progress >/dev/null

  expected_names="$(jq -r '.skills[].name' "$index" | LC_ALL=C sort)"
  expected_digests="$(jq -r '.skills[].digest' "$index" | LC_ALL=C sort)"

  # X-Tiun-Deploy makes the pod answering this request re-read the blob, so the new index is
  # checked immediately rather than after CacheSeconds. Deliberately just the one pod: versions
  # are immutable, so a replica still holding the old index serves a complete older version, and
  # that resolves itself within CacheSeconds. This is checking the index loads, not invalidating
  # the cluster.
  local -a flush_header=()
  local wait_seconds="$VERIFY_TIMEOUT_SECONDS"
  if [ -n "${CACHE_FLUSH_KEY:-}" ]; then
    flush_header=(-H "X-Tiun-Deploy: ${CACHE_FLUSH_KEY}")
    wait_seconds=30   # nothing to wait out — only tolerate a transient blip
  fi

  deadline=$(( SECONDS + wait_seconds ))
  while :; do
    served="$(curl -sf --max-time 30 "${flush_header[@]}" "${base}/.well-known/agent-skills/index.json" \
              | jq -r '.skills[].digest' 2>/dev/null | LC_ALL=C sort || true)"
    [ "$served" = "$expected_digests" ] && break
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "::error::${base} did not serve ${version} within ${wait_seconds}s"
      echo "  expected: $(echo $expected_digests)"
      echo "  served:   $(echo ${served:-<none>})"
      exit 1
    fi
    sleep 5
  done
  echo "  index is live"

  local output installed
  output="$(cd "$work" && npx -y skills@latest add -l "$base" 2>&1 \
            | tr -d '\r' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')" || true

  # No match is the failure being reported, so don't let pipefail abort before it prints.
  installed="$(printf '%s\n' "$output" | grep -oE 'Skill: [a-z0-9-]+' | awk '{print $2}' | LC_ALL=C sort -u || true)"

  if [ "$installed" != "$expected_names" ]; then
    echo "::error::${base} did not serve every expected skill"
    echo "  expected: $(echo $expected_names)"
    echo "  got:      $(echo ${installed:-<none>})"
    echo "--- CLI output ---"
    printf '%s\n' "$output" | grep -v 'Discovering' | tail -30
    exit 1
  fi
  echo "  installed: $(echo $installed)"
}

# --- prune -------------------------------------------------------------------

# Anything a pointer references is kept regardless of age. If production is held back while
# staging moves on, keeping only the newest $KEEP would delete what production is serving.
cmd_prune() {
  step "Pruning (keeping ${KEEP} plus anything in use)"

  local pointers pinned="" body all_versions recent keep doomed

  # Every *.json at the container root is an environment pointer.
  pointers="$(az_blob list --container-name "$CONTAINER" --query "[].name" -o tsv \
              | grep -E '^[^/]+\.json$' || true)"

  local pointer
  for pointer in $pointers; do
    body="$(az_blob download --container-name "$CONTAINER" --name "$pointer" --no-progress 2>/dev/null || true)"
    [ -n "$body" ] || continue
    pinned="${pinned}$(printf '%s' "$body" | versions_in_index)
"
  done
  pinned="$(printf '%s' "$pinned" | grep -v '^$' | LC_ALL=C sort -u || true)"

  all_versions="$(az_blob list --container-name "$CONTAINER" \
                    --query "reverse(sort_by([].{n:name,c:properties.creationTime}, &c))[].n" -o tsv \
                  | sed -nE 's#^([0-9]+-[0-9a-z]+)/.*#\1#p' | awk '!seen[$0]++')"

  recent="$(printf '%s\n' "$all_versions" | head -n "$KEEP")"
  # grep exits 1 when everything filters out (nothing published yet); pipefail would abort silently.
  keep="$(printf '%s\n%s\n' "$pinned" "$recent" | grep -v '^$' | LC_ALL=C sort -u || true)"

  echo "  pointers: $(echo ${pointers:-<none>})"
  echo "  pinned:   $(echo ${pinned:-<none>})"
  echo "  recent:   $(echo ${recent:-<none>})"

  doomed="$(printf '%s\n' "$all_versions" | grep -v '^$' | grep -vxF -f <(printf '%s\n' "$keep") || true)"
  if [ -z "$doomed" ]; then
    echo "  nothing to prune"
    return 0
  fi

  local version
  for version in $doomed; do
    if [ "$DRY_RUN" = "1" ]; then
      echo "  would delete: ${version}/"
    else
      az storage blob delete-batch --auth-mode login --account-name "$ACCOUNT" \
        --source "$CONTAINER" --pattern "${version}/*" >/dev/null
      echo "  deleted: ${version}/"
    fi
  done
}

# --- dispatch ----------------------------------------------------------------

command="${1:-}"; shift || true
case "$command" in
  publish) cmd_publish "$@" ;;
  verify)  cmd_verify  "$@" ;;
  promote) cmd_promote "$@" ;;
  prune)   cmd_prune   "$@" ;;
  *)
    sed -n '3,10p' "$0" | sed 's/^# \?//'
    exit 2
    ;;
esac
