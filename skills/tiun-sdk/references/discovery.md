# Discovery (Step 0)

Before writing any tiun integration code, gather four pieces of information. Ask only for what the user has not already stated. Use a structured question primitive (`AskQuestion` or equivalent) if your client supports one; otherwise ask inline.

## 0a. MCP availability

The Tiun MCP server (`https://mcp.tiun.business`) exposes `get_providers` and `get_products` against the user's dashboard. Detect by checking your available tools.

- **Present and authed** → use it to enumerate inventory in 0c.
- **Present but unauthed** → prompt auth once; if declined, proceed in manual mode.
- **Absent** → offer to install. Value proposition: "fetch your snippetId and productIds directly so we avoid copy-paste errors." If declined, proceed in manual mode. See [mcp.md](mcp.md) for install instructions.

## 0b. Integration mode

Subscription, time-based, or both? Map user language to mode:

| User says... | Mode |
|---|---|
| "subscription", "recurring", "members", "paid account", "tiers" | Subscription |
| "article paywall", "watch then pay", "session", "no account", "first N seconds free", "donation prompt" | Time-based |
| "videos/articles behind a paywall", "premium content" (ambiguous) | **Ask** — don't guess |
| Nothing about access model | **Ask** — don't guess |

**Do not infer mode from `get_products` inventory.** The list reports what *exists*, not what the integrator wants to *build*. A provider with one product type today may add another tomorrow.

Suggested question (when ambiguous):

> Do you want **subscription** access (accounts + recurring billing + per-product tiers, e.g. "$9.99/month for premium videos"), or **time-based** access (anonymous per-session metering, e.g. "watch any video, billed per minute up to a monthly cap")? Or both?

## 0c. Identifiers

Questions depend on mode and MCP availability.

### Subscription, MCP present

1. List providers → ask user to pick (mark sandbox flag per provider).
2. List products for chosen provider → ask user to pick one or multiple tiers. Suggest: "for multiple tiers, I'll set up a `TIUN_PRODUCTS` map like `{ basic: 'p-basic', pro: 'p-pro' }`."
3. Confirm sandbox/prod from the provider's `sandbox` flag.

### Subscription, no MCP

1. Ask for `snippetId` (from `my.tiun.business`).
2. Ask: one product or multiple tiers?
3. For each tier: ask the `productId` and a label (e.g. `pro = p-live-pro`).
4. Ask sandbox/prod.

### Time-based, MCP present

1. List providers → ask user to pick (mark sandbox flag).
2. Confirm sandbox/prod from the provider's `sandbox` flag.

### Time-based, no MCP

1. Ask for `snippetId`.
2. Ask sandbox/prod.

When MCP is present, ground questions in inventory:

> You have one time-based product (`t-xxx`) and no subscription products. Should I wire up the existing time-based flow, or set up subscription products first (you'd create them in the dashboard, then I'd wire them in)?

## 0d. Gating scope

- Which routes / components / features should require access? (Free-form, or multi-select if you've explored the routes file.)
- What should non-authenticated users see? (Inline login + checkout buttons / redirect to `/pricing` / full-screen paywall overlay / teaser + subscribe button)
- What should authenticated-but-no-access users see? (Usually the same UX with "upgrade" copy)
- Is there a free preview? (e.g. first 30 seconds of video, first paragraph of article) — if yes, the user may actually want **time-based**; feed back into 0b.
- For multi-tier: which routes/features map to which tier?

## "Ask only what's missing"

Parse the user's prompt for any of the four answers before asking. Examples:

| User prompt | Skip which steps |
|---|---|
| "Add tiun" | None — ask all four |
| "Wire up subscription for my video routes" | Skip 0b + the gating-target part of 0d; ask 0a, 0c, and the rest of 0d |
| "Wire up subscription with product `p-pro` in sandbox to gate `/watch/*`" | Skip Step 0 entirely — fully specified |
| "Add a time-based paywall to my articles" | Skip 0b + most of 0d; ask 0a, 0c, and UX details for unauthed users |

Confirmation is faster than open questions when you have a defensible default — e.g. "I see this is local dev; I'll use sandbox. OK?" beats "Sandbox or production?"
