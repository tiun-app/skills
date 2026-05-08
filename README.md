# tiun Skills

[Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) for building against the [tiun SDK](https://docs.tiun.io): auth and subscription billing in one JS library (`@tiun/sdk`).

## Installing

Works with any agent that supports the Agent Skills standard.

### Claude Code

Install through the [plugin marketplace](https://code.claude.com/docs/en/discover-plugins#add-from-github):

```
/plugin marketplace add tiun-app/skills
/plugin install tiun-sdk@tiun-sdk
```

### Cursor

Add manually via **Settings > Rules > Add Rule > Remote Rule (Github)** with `tiun-app/skills`.

### gh skill

Or use the [`gh skill`](https://cli.github.com/) extension (preview):

```
gh skill install tiun-app/skills
```

`gh skill` figures out which agents you have installed and drops the skill in the right place. Add `--scope user` to make it available across every project.

### Clone

If you'd rather wire it up by hand, clone and copy `skills/tiun-sdk/` into your agent's skills directory:

| Agent | Skill directory |
|-------|-----------------|
| Claude Code | `~/.claude/skills/` |
| Cursor | `~/.cursor/skills/` |
| OpenAI Codex | `~/.codex/skills/` |
| Gemini CLI | `~/.gemini/skills/` |

## Skills

| Skill | Useful for |
|-------|------------|
| tiun-sdk | Wiring up `@tiun/sdk`: subscription gating with `userChange` and `productAccess`, hosted checkout/login, server-side verification, and framework setup for React, Vue, Nuxt, and Next.js |

The skill triggers automatically on imports of `@tiun/sdk`, calls like `tiun.init` / `tiun.checkout`, and questions about tiun products or entitlements.

## MCP Servers

| Server | Purpose |
|--------|---------|
| tiun | Live access to tiun docs and account context (products, environments, sandbox state) |

The MCP server is wired up in [`.mcp.json`](.mcp.json) and points at `https://mcp.tiun.business`.

## Updating

When tiun's SDK changes, the reference files under `skills/tiun-sdk/references/` get refreshed against [docs.tiun.io/llms-full.txt](https://docs.tiun.io/llms-full.txt). Pull the latest with:

```
gh skill update tiun-app/skills
```

## Resources

- [tiun docs](https://docs.tiun.io) ([LLM-friendly bundle](https://docs.tiun.io/llms-full.txt))
- [tiun dashboard](https://my.tiun.business)
- [Agent Skills spec](https://agentskills.io/specification)

