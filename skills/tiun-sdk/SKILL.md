---
name: tiun-sdk
description: Use when integrating or debugging the tiun SDK (@tiun/sdk), tiun's JavaScript library for authentication and subscription billing. Triggers on imports of `@tiun/sdk`, calls like `tiun.init`, `tiun.checkout`, `tiun.login`, or questions about tiun products, entitlements, or server-side verification.
---

# tiun SDK skill

Use this skill whenever the user is integrating, extending, or debugging code that uses `@tiun/sdk`. Authoritative upstream docs: https://docs.tiun.io/llms-full.txt.

## What tiun is

A commercial backend platform providing authentication, payments, and entitlements through a single JS SDK. The SDK exposes a `tiun` singleton centered on **subscriptions**: recurring billing, persistent user accounts, OTP login, and entitlements in `user.productAccess[]`.

Install: `npm install @tiun/sdk`. Init: `tiun.init({ snippetId })` once on app start.

## When to do what

| Task | Route to |
|---|---|
| What tiun is, supported platforms, product model | [references/overview.md](references/overview.md) |
| Install / init / config | [references/installation.md](references/installation.md) |
| Method or property lookup | [references/api-reference.md](references/api-reference.md) |
| Event names and payloads | [references/events.md](references/events.md) |
| Subscription gating | [references/subscriptions.md](references/subscriptions.md) |
| Trusted backend authorization | [references/server-verification.md](references/server-verification.md) |
| React / Vue / Nuxt / Next.js wiring | [references/frameworks.md](references/frameworks.md) |
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

## Minimal working example

### Subscription gating (any framework)

```javascript
import { tiun } from '@tiun/sdk';

tiun.init({ snippetId: 'YOUR_SNIPPET_ID' });

tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return renderPricing();
  user.productAccess.includes('p-live-pro') ? renderPro() : renderUpgrade();
});

document.querySelector('#buy').onclick = () =>
  tiun.checkout({ productId: 'p-live-pro' });
```

## Decision cues

- User asks "how do I list products?" / "get all products?": tell them products are configured in the dashboard at `my.tiun.business`; there is no runtime product-list API.
- User mentions "checkout", "subscription", "products": subscription flow.
- User mentions "verify on the backend", "protect API", "trust the client": server verification.
- Errors like "overlay doesn't appear", "methods called before ready": troubleshooting.
