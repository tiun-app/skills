#!/usr/bin/env bash
#
# Builds a tarball per skill plus the discovery index.
#
# Tarballs must be reproducible: the index carries a sha256 of each one and the skills CLI
# re-checks it after download, so drifting mtimes would churn the index on every run.
#
# Usage: scripts/build-skills.sh [output-dir]   (default: dist)
set -euo pipefail

OUT_DIR="${1:-dist}"
SKILLS_DIR="skills"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "error: no '$SKILLS_DIR' directory — run from the repository root" >&2
  exit 1
fi

# The version names a commit, so uncommitted work must not borrow one. Untracked files count —
# they'd end up in the tarball.
if [ -n "$(git status --porcelain -- "$SKILLS_DIR")" ]; then
  if [ "${ALLOW_DIRTY:-0}" != "1" ]; then
    echo "error: uncommitted changes under ${SKILLS_DIR}/ — the digest would not match the commit" >&2
    echo "       it claims. Commit first, or set ALLOW_DIRTY=1 for a throwaway build." >&2
    git status --short -- "$SKILLS_DIR" >&2
    exit 1
  fi
  VERSION="$(date +%s)-dirty"
  echo "warning: dirty tree — building as ${VERSION}, not for publishing" >&2
else
  VERSION="$(git log -1 --format=%ct)-$(git rev-parse --short HEAD)"
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

entries=()

for dir in "$SKILLS_DIR"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"

  if [ ! -f "${dir}SKILL.md" ]; then
    echo "error: ${dir} has no SKILL.md" >&2
    exit 1
  fi

  fm_name="$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "${dir}SKILL.md")"
  if [ "$fm_name" != "$name" ]; then
    echo "error: ${dir}SKILL.md declares name '$fm_name' but lives in '$name'" >&2
    exit 1
  fi

  description="$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "${dir}SKILL.md")"
  description="${description%\"}"; description="${description#\"}"
  if [ -z "$description" ]; then
    echo "error: ${dir}SKILL.md has no description" >&2
    exit 1
  fi
  if [ "${#description}" -gt 1024 ]; then
    echo "error: ${dir}SKILL.md description is ${#description} chars (max 1024)" >&2
    exit 1
  fi

  # Timestamp per skill, not repo HEAD, so an unrelated commit doesn't change this digest.
  epoch="$(git log -1 --format=%ct -- "$dir")"

  # Explicit file list rather than "-C dir .", which would prefix every path with "./" —
  # the CLI rejects any "." path segment and silently drops the skill. Files only: a
  # directory entry would land in its file map as an empty file.
  filelist="$(mktemp)"
  find "$dir" -mindepth 1 -type f -printf '%P\n' | LC_ALL=C sort > "$filelist"

  tar --format=posix \
      --mtime="@${epoch}" --owner=0 --group=0 --numeric-owner \
      --pax-option='exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime' \
      -C "$dir" --no-recursion -T "$filelist" -cf - \
    | gzip -n -9 > "${OUT_DIR}/${name}.tar.gz"
  rm -f "$filelist"

  digest="sha256:$(sha256sum "${OUT_DIR}/${name}.tar.gz" | cut -d' ' -f1)"

  entries+=("$(jq -n \
    --arg name "$name" \
    --arg description "$description" \
    --arg url "/.well-known/agent-skills/${VERSION}/${name}.tar.gz" \
    --arg digest "$digest" \
    '{name: $name, type: "archive", description: $description, url: $url, digest: $digest}')")

  echo "built ${name}.tar.gz  ${digest}"
done

if [ "${#entries[@]}" -eq 0 ]; then
  echo "error: no skills found under $SKILLS_DIR" >&2
  exit 1
fi

# Relative URLs, so the same index works on staging and production.
printf '%s\n' "${entries[@]}" | jq -s \
  '{"$schema": "https://schemas.agentskills.io/discovery/0.2.0/schema.json", skills: .}' \
  > "${OUT_DIR}/index.json"

[ -n "${GITHUB_OUTPUT:-}" ] && echo "version=${VERSION}" >> "$GITHUB_OUTPUT"
echo "version ${VERSION}"
