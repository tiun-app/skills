# tiun MCP server

The tiun MCP server (`https://mcp.tiun.business`) gives agents read access to the user's tiun providers and products during integration. It replaces copy-paste of `snippetId` and `productId` strings with direct lookups against the dashboard.

## Detection

The MCP exposes (at minimum) `get_providers` and `get_products`. Check your tool list for these to detect availability.

States:

- **Present and authed** → use it.
- **Present but unauthed** → prompt the user to authenticate once. If declined, proceed in manual mode.
- **Absent** → offer to install (below). If declined, proceed in manual mode.

## Inventory is not intent

The MCP returns what *exists* in the user's account. It does **not** report what they want to build. Always confirm integration mode and chosen products with the user — see [discovery.md](discovery.md) Step 0b and 0c.

## Install

### Universal config (works for any MCP-compatible client)

```json
{
  "mcpServers": {
    "tiun": {
      "type": "http",
      "url": "https://mcp.tiun.business"
    }
  }
}
```

Paste this into your client's MCP config file. The exact location depends on the client.

### Per client

- **Claude Code:** the [tiun-app/skills plugin](https://github.com/tiun-app/skills) auto-wires this MCP via the repo's `.mcp.json` when you run `/plugin install tiun-sdk@tiun-sdk`. To add manually: `claude mcp add tiun https://mcp.tiun.business --transport http` (verify the flag against your Claude Code version's `mcp add --help`).
- **Cursor:** Settings → MCP → "Add new MCP server" → paste the JSON block above. Or merge into `~/.cursor/mcp.json`.
- **OpenAI Codex:** add the universal config block to your Codex MCP config (typically under `~/.codex/`). See the Codex docs for the exact path.
- **Gemini CLI:** add the universal config to the Gemini MCP config. See the Gemini CLI docs.
- **Other MCP-compatible clients:** use the universal config above with your client's MCP config path.

## On first call

The user is prompted to authenticate against `my.tiun.business` if they haven't already. Subsequent calls reuse the session.

## What to do if MCP is absent and the user declines to install

Proceed in **manual mode**: ask the user directly for `snippetId`, `productId`(s), and sandbox/prod. See [discovery.md](discovery.md) for the manual-mode question scripts.
