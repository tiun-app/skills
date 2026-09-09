# Troubleshooting

## The overlay never appears

- Verify `tiun.init` was called with a valid `snippetId`. (Calling `init` more than once is fine — it's idempotent.)
- `snippetId` is environment-specific. Confirm the ID matches the dashboard environment you're targeting (`sandbox: true` → sandbox snippet ID; default → live snippet ID).
- Check `tiun.isReady`. Methods called before `ready` may silently queue or no-op. Use `await tiun.waitForReady()` or the `ready` event if you need a hard sync point.
- Enable `debug: true` in `init()` to see SDK logs in the console.

## Checkout / connect overlay opens but errors out

- **Product ID prefix doesn't match environment.** `p-live-...` only works with the live environment (no `sandbox` flag); `p-test-...` only works when `sandbox: true`. Mismatched prefixes produce silent failures.
- **Dashboard sandbox toggle vs SDK `sandbox` flag are out of sync.** Both must point at the same environment.
- **Live + `localhost`.** `localhost` is blocked in live; use `sandbox: true` with a sandbox snippet ID for local development.

## `userChange` never fires

- Confirm there is an `on('userChange', ...)` subscription and that it is registered before (or synchronously after) `init`.
- In frameworks: unsubscribe on unmount. A stale listener from a previous mount can look like "new ones don't fire" if you are checking the wrong instance.

## SSR errors on import

- `@tiun/sdk` is a browser SDK. In Next.js / Nuxt, initialize it from a client-only component/plugin (`'use client'`, `*.client.ts`, or inside `onMounted` / `useEffect`).

## Server-side verification fails

- **401**: API key is wrong, or doesn't belong to the environment the token came from. Sandbox keys do not work against live, and vice versa.
- **JWT expired**: verification tokens are valid for 5 minutes. Re-fetch via `tiun.getUserVerificationToken()`; do not cache verification results past the token's lifetime.
- **Wrong header name**: it's `X-TIUN-API-KEY`. (Older example code referencing `X-ACCESS-TOKEN` is out of date.)
- **404 on session verification**: the session has expired, was invalidated, or the user is out of funds — fail closed and deny the request.

## Custom markup or styles inside the overlay stopped working

Expected. The overlay's internals are shadow DOM, unversioned, and change without notice — see [overview.md](overview.md#hosted-ui-is-a-black-box). Remove the injection or CSS override rather than repairing it: a patched selector will break again, and it breaks inside checkout. Move the copy onto your own page next to the trigger, and take branding or extra-field requests to support@tiun.io.

## First-time visitors cannot buy — they hit a login screen

The plan CTA is wired to `tiun.login()`, or to an `isAuthenticated` check that falls back to login. `tiun.checkout()` authenticates by itself; a visitor with no account signs up inside the checkout overlay. Wire plan CTAs directly to `tiun.checkout({ productId })` and keep login as a separate link — see [subscriptions.md](subscriptions.md#wiring-ctas--checkout-vs-login).

## `error` event codes look unfamiliar

`err.code` is a string but is **not** a stable enum. Display `err.message` to users, log `err.code` for support, and do not branch application logic on specific codes — they can change between SDK versions.

## Quick reference

| Issue | Likely cause | Try |
|---|---|---|
| Events not firing | SDK not initialized | Confirm `tiun.init()` ran before subscribing |
| Checkout not opening | Wrong/stale product ID, or env mismatch | Compare ID prefix and SDK `sandbox` flag against dashboard view |
| Connect overlay not opening | SDK not initialized, or no time-based product on the snippet | Confirm `init` ran and the snippet has a time-based product |
| Sandbox payments not working | App and dashboard on different envs | Use sandbox snippet ID + `p-test-...` + `sandbox: true`; dashboard sandbox toggle on |
| User state not updating | Relying only on `tiun.user` snapshot | Listen for `userChange` and update from the event payload |
| Session not restoring | Different browser or cleared storage | Sessions are per-browser; clearing cookies/site data clears the session |
| Injected help text / CSS inside the overlay vanished | Overlay internals are shadow DOM and change without notice | Remove the injection; put the copy on your own page next to the trigger |
| New visitors stuck at login on the pricing page | Plan CTA wired to `login()`, or behind an auth check | Wire plan CTAs straight to `tiun.checkout({ productId })` |
