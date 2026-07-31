# tiun MCP server

The tiun MCP server (`https://mcp.tiun.business/`) gives agents access to the user's tiun providers and products during integration. It replaces copy-paste of `snippetId` and `productId` strings with direct lookups against the dashboard.

> The trailing slash matches the upstream docs. Both forms (`https://mcp.tiun.business` and `https://mcp.tiun.business/`) resolve to the same endpoint.

## Tools

| Tool | Kind | What it does |
|---|---|---|
| `get_providers` | read | Lists the user's providers, each with its `snippetId` and a sandbox/live tag. |
| `get_products` | read | Lists a provider's products for one environment. Requires `providerId` + `sandbox`. |
| `create_subscription_product` | **write** | Creates a subscription product. Subscription only — one-time and time-based products must be created in the dashboard. |
| `update_subscription_product` | **write** | Edits an existing subscription product's name and pricing. Replaces values wholesale. |

The two write tools mutate a real account and carry their own confirmation protocol in their tool descriptions — read it before calling, default to `sandbox: true`, and never source a price you weren't given. There is no delete.

## Detection

Check your tool list for `get_providers` and `get_products` to detect availability.

States:

- **Present and authed** → use it.
- **Present but unauthed** → prompt the user to authenticate once. If declined, proceed in manual mode.
- **Absent** → offer to install (below). If declined, proceed in manual mode.

## Reading product types from `get_products`

Each product carries a **`pricingType`** field — the only reliable signal of what kind of product it is:

| `pricingType` | Mode | Entry point |
|---|---|---|
| `'Subscription'` | Subscription | `tiun.checkout({ productId })` |
| `'OneTime'` | One-time purchase | `tiun.checkout({ productId })` |
| `'TimeBased'` | Time-based | `tiun.start()` |

**The `productId` prefix does not tell you the type** — `p-live-...` / `p-test-...` encode the *environment* only. `Subscription` and `OneTime` share an entry point, so `pricingType` is the only thing that distinguishes them, and the difference matters: one grants a renewable entitlement, the other a permanent one. See [one-time.md](one-time.md).

Field note: `recurringPrice` is overloaded. For `Subscription` it is the recurring charge. For `TimeBased` it holds the per-interval usage fee (e.g. price per day of access), not a subscription charge, and `trialPrice` is always null. Do not present a `TimeBased` product's `recurringPrice` to the user as a subscription price.

## Inventory is not intent

The MCP returns what *exists* in the user's account. It does **not** report what they want to build. Always confirm integration mode and chosen products with the user — see [discovery.md](discovery.md) Step 0b and 0c.

A single-type catalog is a reasonable **default to confirm**, not a decision: "I see only one-time products — wire that up, or set up subscriptions first?" A mixed catalog means ask open-ended.

## Sandbox and live providers are tagged separately

Each provider returned by `get_providers` is tagged sandbox or live. If the user has both:

- Use **sandbox providers + sandbox snippet ID + `sandbox: true`** for local development (live is hard-blocked on `localhost`).
- Use **live providers + live snippet ID** (no `sandbox` flag) for production deploys.

Ground discovery questions in inventory — e.g. "you have a sandbox provider and a live provider; should I wire up the sandbox one for local dev?" — rather than asking blind.

## Install

### Quickstart via `gh skill` (recommended)

If the user installs the tiun-sdk skill from this repo with the GitHub CLI, the MCP is wired automatically:

```bash
gh skill install tiun-app/skills tiun-sdk
```

Then add the MCP server in the agent's MCP settings (Cursor: Settings → MCP; Claude Code: `claude mcp add ...`; etc.).

### Universal config (works for any MCP-compatible client)

```json
{
  "mcpServers": {
    "tiun": {
      "type": "http",
      "url": "https://mcp.tiun.business/"
    }
  }
}
```

Paste this into your client's MCP config file. The exact location depends on the client.

### Per client

- **Claude Code:** the [tiun-app/skills plugin](https://github.com/tiun-app/skills) auto-wires this MCP via the repo's `.mcp.json` when you run `/plugin install tiun-sdk@tiun-sdk`. To add manually: `claude mcp add tiun https://mcp.tiun.business/ --transport http` (verify the flag against your Claude Code version's `mcp add --help`).
- **Cursor:** Settings → MCP → "Add new MCP server" → paste the JSON block above. Or merge into `~/.cursor/mcp.json`.
- **OpenAI Codex:** add the universal config block to your Codex MCP config (typically under `~/.codex/`). See the Codex docs for the exact path.
- **Gemini CLI:** add the universal config to the Gemini MCP config. See the Gemini CLI docs.
- **Other MCP-compatible clients:** use the universal config above with your client's MCP config path.

## On first call

The user is prompted to authenticate against `my.tiun.business` if they haven't already. Subsequent calls reuse the session.

## What to do if MCP is absent and the user declines to install

Proceed in **manual mode**: ask the user directly for `snippetId`, `productId`(s), and sandbox/live. See [discovery.md](discovery.md) for the manual-mode question scripts.
