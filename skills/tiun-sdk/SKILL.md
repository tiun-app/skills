---
name: tiun-sdk
description: Use when integrating or debugging the tiun SDK (@tiun/sdk), tiun's JavaScript library for authentication, subscription billing, and time-based paywalls. Triggers on imports of `@tiun/sdk`, calls like `tiun.init`, `tiun.checkout`, `tiun.login`, `tiun.start`, or questions about tiun products, entitlements, time-based sessions, or server-side verification.
---

# tiun SDK skill

Use this skill whenever the user is integrating, extending, or debugging code that uses `@tiun/sdk`. Authoritative upstream docs: https://docs.tiun.io/llms-full.txt.

## What tiun is

A commercial backend platform providing authentication, payments, and entitlements through a single JS SDK. The `tiun` singleton supports two flows; you pick based on the integrator's intent (see "Step 0 — Discovery before code"):

- **Subscriptions** — persistent user accounts (OTP login), recurring billing, per-product entitlements in `user.productAccess[]`. Entry point: `tiun.checkout({ productId })`. See [references/subscriptions.md](references/subscriptions.md).
- **Time-based** — per-session anonymous access (no account required), metered by time spent on paid content. Entry point: `tiun.start()` + `paywallShow` / `paywallHide` events. See [references/time-based.md](references/time-based.md).

Install: `npm install @tiun/sdk`. Init: `tiun.init({ snippetId })` once on app start.

## Step 0 — Discovery before code

Before writing any integration code, establish four things. Ask only for items the user has not already stated. If their prompt is fully specified ("wire up subscription with product `p-pro` in sandbox to gate `/watch/*`"), skip discovery.

Use a structured question primitive (e.g. `AskQuestion`) if your client supports one; otherwise ask inline in chat.

**0a. Detect the MCP and offer to install if missing.** See [references/mcp.md](references/mcp.md) for per-client install instructions and detection. Three states:

- MCP present and authed → use it to enumerate providers/products in 0c.
- MCP present, not authed → prompt auth once; if declined, proceed in manual mode.
- MCP absent → offer to install (single-sentence value proposition: "fetch your snippetId and productIds directly so we avoid copy-paste errors"). If declined, proceed in manual mode.

**0b. Establish integration mode.** Subscription, time-based, or both? See [references/discovery.md](references/discovery.md) for cues that map user language to each mode. **Do not infer mode from `get_products` inventory.** A provider with only one product type today may be planning the other tomorrow.

**0c. Gather identifiers.** Questions depend on mode and MCP availability:

- Subscription, MCP present → list providers, ask user to pick; list products, ask user to pick one or multiple tiers; confirm sandbox from the provider's `sandbox` flag.
- Subscription, no MCP → ask for `snippetId`; ask one product or multiple tiers; for each, ask `productId` and label; confirm sandbox/prod.
- Time-based, MCP present → list providers, ask user to pick; confirm sandbox from provider flag.
- Time-based, no MCP → ask for `snippetId`; confirm sandbox/prod.

When the MCP is present, ground questions in inventory ("you have a time-based product `t-xxx` — wire that up, or set up subscription products?") rather than asking blind.

**0d. Identify what to gate.** Without this step the agent is generating boilerplate with no target. Ask:

- Which routes/components/features require access?
- What should non-authenticated users see? (inline login + checkout buttons / redirect to pricing page / full-screen paywall / teaser + subscribe)
- What should authenticated-but-no-access users see? (typically the same UX with "upgrade" copy)
- Is there a free preview? (If yes, this is often a cue the user actually wants **time-based**, not subscription — feed back into 0b.)
- For multi-tier: which routes/features map to which tier?

## When to do what

| Task | Route to |
|---|---|
| Discovery, scoping, MCP detection, mode selection | [references/discovery.md](references/discovery.md) |
| MCP installation per client, detection, auth | [references/mcp.md](references/mcp.md) |
| What tiun is, supported platforms, product model | [references/overview.md](references/overview.md) |
| Install / init / config / per-host env injection | [references/installation.md](references/installation.md) |
| Method or property lookup | [references/api-reference.md](references/api-reference.md) |
| Event names and payloads | [references/events.md](references/events.md) |
| Subscription gating (accounts + recurring billing) | [references/subscriptions.md](references/subscriptions.md) |
| Time-based paywall (per-session, anonymous, metered) | [references/time-based.md](references/time-based.md) |
| Trusted backend authorization | [references/server-verification.md](references/server-verification.md) |
| Framework wiring (any stack) + lifecycle matrix | [references/frameworks.md](references/frameworks.md) |
| "Overlay not appearing", SSR errors, sandbox mismatch | [references/troubleshooting.md](references/troubleshooting.md) |

## Load-bearing rules

1. **`tiun.init({ snippetId })` runs once** on the client, early in startup. In Next.js/Nuxt, wrap in a client-only component/plugin. Never call it on the server.
2. **`snippetId` is not a secret.** It identifies the environment. Use `NEXT_PUBLIC_*` / `public` runtime config.
3. **`userChange` is the source of truth for subscription gating**, not a one-shot `tiun.user` read. Entitlements change mid-session.
4. **Never trust the client for authorization.** For protected server resources: `tiun.getUserVerificationToken()` returns a JWT, send it to your backend, the backend validates it against the tiun API.
5. **Do not reimplement checkout/login UIs.** tiun hosts them. Call `tiun.checkout({ productId })` or `tiun.login()` to open them.
6. **Methods before `ready` may no-op.** Guard with `await tiun.waitForReady()` or wait for the `ready` event.
7. **Unsubscribe handlers** returned from `tiun.on(...)` on component unmount to avoid stale listeners.
8. **Sandbox flag in `init()` must match the dashboard's sandbox toggle**, or checkout silently fails.
9. **No runtime product-list API.** Products are configured in the tiun dashboard (`my.tiun.business`) and referenced by hardcoded `productId` strings. Do not invent methods like `tiun.getProducts()` or REST endpoints; direct users to the dashboard.
10. **No webhooks.** tiun does not emit webhooks. For backend integration, drive state from the JWT returned by `getUserVerificationToken()`. Do not invent webhook endpoints or event payloads.
11. **Stay upstream-faithful.** All code examples must match https://docs.tiun.io. If a pattern isn't documented upstream (custom SSR wiring, multi-env setups, backend SDKs in other languages, etc.), point the user at the upstream docs rather than inventing a snippet.
12. **Do not infer integration mode from `get_products` inventory.** Always confirm with the user (see "Step 0"). The list reports what *exists*; it does not report what the integrator *wants to build*.
13. **Do not wrap SDK methods to add `isInitialized` / `waitForReady` guards.** `tiun.checkout`, `tiun.login`, `tiun.start`, `tiun.setContent`, and `tiun.logout` already call `ensureInitialized()` and `await this.waitForReady()` internally. Wrapper helpers around these methods are noise.
14. **Do not pass `baseUrl` to `init()`.** It is an internal-only field reserved for Tiun's own infrastructure. Use `sandbox: true` for non-production environments; that is the only public environment switch.
15. **Write runtime config to files the bundler actually loads.** `.env.example` is documentation and is never evaluated. Vite loads `.env` / `.env.local`; Next.js loads `.env.local` and requires the `NEXT_PUBLIC_*` prefix for client-exposed values; Nuxt loads via `runtimeConfig.public` in `nuxt.config.ts`. See `references/installation.md` for the per-host table.

## Minimal working example

Three primitives — works in every supported environment. Adapt the reactive primitive (state hook, ref, signal, store, DOM update) to your stack.

```javascript
import { tiun } from '@tiun/sdk';

tiun.init({ snippetId: 'YOUR_SNIPPET_ID' });

const off = tiun.on('userChange', ({ isAuthenticated, user }) => {
  // push into your framework's reactive primitive
});

document.querySelector('#buy').onclick = () => tiun.checkout({ productId: 'p-pro' });

// off(); tiun.destroy();
```

Full per-mode walkthroughs in [references/subscriptions.md](references/subscriptions.md) and [references/time-based.md](references/time-based.md). Per-framework adaptations in [references/frameworks.md](references/frameworks.md).

## Decision cues

- User says "subscription", "recurring", "members", "paid account", "products and tiers" → **subscription flow**. Route to subscriptions.md.
- User says "article paywall", "watch a video then pay", "session", "no account needed", "donation prompt", "first N seconds free" → **time-based flow**. Route to time-based.md.
- User says "videos behind a paywall", "premium content" (ambiguous) → **ask** which mode. Don't guess.
- User asks "how do I list products?" / "get all products?" → products are configured in the dashboard at `my.tiun.business`; there is no runtime product-list API. (The MCP exposes inventory to the agent for setup; this is not a runtime SDK feature.)
- User mentions "verify on the backend", "protect API", "trust the client" → server verification.
- Errors like "overlay doesn't appear", "methods called before ready" → troubleshooting.
