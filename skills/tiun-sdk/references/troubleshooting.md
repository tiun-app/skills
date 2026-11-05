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
- **Domain not registered.** Works locally but not on a deployed site → the site's domain isn't in **Settings → Environment setup → Web** for that environment. One domain per environment is self-service; additional ones go through support@tiun.io.

## React Native

See the troubleshooting table in [react-native.md](react-native.md#troubleshooting). The two most common ones are both return-scheme mismatches. Login or checkout opens and closes immediately → `returnUrl`'s scheme isn't the dashboard App scheme for the environment `host` points at. Payment succeeds but checkout never returns to the app → the native registration doesn't match `returnUrl`'s scheme, or iOS is missing `RCTLinkingManager` forwarding, or Android is missing `android:launchMode="singleTask"`.

## `checkout()` / `login()` do nothing after a component remount

`init()` after `destroy()` needs `@tiun/sdk` **0.12.0** or later. On older versions, `checkout()`, `login()`, `start()`, and `setContent()` wait forever after a remount. Upgrade, or init once at the app root without `destroy()`. After a re-init on 0.12.0, `tiun.user` stays empty until the next login, logout, or checkout — use `tiun.listProductAccess()` / `tiun.checkProductAccess()` for access right away.

## Code that uses `window.tiun` stops working

Something assigned the SDK to `window.tiun`. The snippet script uses that name and replaces it when it loads. Use the imported `tiun`, or another global name such as `window.tiunSdk`.

## A repeatable purchase doesn't show up

The product ID shows up in `productAccess` after the first reference and stays until the last one ends, and it never names which reference was bought. A later purchase can leave that array looking the same. `tiun.checkProductAccess(productId, { referenceId })` is the check (0.12.0+), on every `userChange` — it fires with `event: 'checkout'` for that purchase. Pass the same `referenceId` you passed to `checkout()`.

## Product methods reject

`listProducts`, `getProduct`, `listProductAccess`, and `checkProductAccess` reject with `{ code, message, details? }` and don't fire the `error` event, so wrap them in `try` / `catch`. `http_404` from `getProduct()` is an unknown product ID (check the environment prefix); `timeout` means no answer within 10s; `ssr` means it ran during server-side rendering. Signed out is **not** an error: you get `[]` or `{ hasAccess: false, access: null }`.

## `userChange` never fires

- Confirm there is an `on('userChange', ...)` subscription and that it is registered before (or synchronously after) `init`.
- In frameworks: unsubscribe on unmount. A stale listener from a previous mount can look like "new ones don't fire" if you are checking the wrong instance.

## SSR errors on import

- `@tiun/sdk` is a browser SDK. In Next.js / Nuxt, initialize it from a client-only component/plugin (`'use client'`, `*.client.ts`, or inside `onMounted` / `useEffect`).

## Server-side verification fails

- **401**: API key is wrong, or doesn't belong to the environment the token came from. Sandbox keys do not work against live, and vice versa.
- **JWT expired**: verification tokens are valid for 5 minutes. Fetch a fresh one via `tiun.getUserVerificationToken()` for every request, and don't cache verification results past the token's lifetime.
- **`null` token on parallel requests**: before `@tiun/sdk` 0.12.0, parallel `getUserVerificationToken()` calls returned `null` for all but the last. Upgrade.
- **Wrong header name**: it's `X-TIUN-API-KEY`. (Older example code referencing `X-ACCESS-TOKEN` is out of date.)
- **404 on session verification**: the session has expired, was invalidated, or the user is out of funds — fail closed and deny the request.

## Custom markup or styles inside the overlay stopped working

Expected. The overlay's internals are shadow DOM, unversioned, and change without notice — see [overview.md](overview.md#hosted-ui-is-a-black-box). Remove the injection or CSS override rather than repairing it: a patched selector will break again, and it breaks inside checkout. Move the copy onto your own page next to the trigger, and take branding or extra-field requests to support@tiun.io.

## `error` event codes look unfamiliar

`err.code` is a string but is **not** a stable enum. Display `err.message` to users, log `err.code` for support, and do not branch application logic on specific codes — they can change between SDK versions.

## Quick reference

| Issue | Likely cause | Try |
|---|---|---|
| Events not firing | SDK not initialized | Confirm `tiun.init()` ran before subscribing |
| Checkout not opening | Wrong/stale product ID, or env mismatch | Compare ID prefix and SDK `sandbox` flag against dashboard view |
| Connect overlay not opening | SDK not initialized, or no time-based product on the snippet | Confirm `init` ran and the snippet has a time-based product |
| Sandbox payments not working | App and dashboard on different envs | Use sandbox snippet ID + `p-test-...` + `sandbox: true`; dashboard sandbox toggle on |
| User state not updating | Relying only on `tiun.user` snapshot | Listen for `userChange` and re-check access on every fire |
| Methods hang after remount | `init()` after `destroy()` on `@tiun/sdk` < 0.12.0 | Upgrade to 0.12.0, or init once at the root |
| Session not restoring | Different browser or cleared storage | Sessions are per-browser; clearing cookies/site data clears the session |
| Works locally, fails on deployed site | Domain not registered for that environment | Add it in Settings → Environment setup → Web (extra domains via support@tiun.io) |
| RN: login / checkout opens and closes immediately | `returnUrl` scheme not registered as the dashboard App scheme for that environment | Compare `returnUrl` with Settings → Environment setup → App scheme in the environment `host` targets — see [react-native.md](react-native.md) |
| RN: payment succeeds, app never resolves checkout | Return scheme mismatch or missing native forwarding | Match dashboard App scheme ↔ native registration ↔ `returnUrl`; check `RCTLinkingManager` (iOS) and `singleTask` (Android) — see [react-native.md](react-native.md) |
| Injected help text / CSS inside the overlay vanished | Overlay internals are shadow DOM and change without notice | Remove the injection; put the copy on your own page next to the trigger |
| Purchase button opens login instead of checkout | Handler branches on auth state, or runs `login()` first | Open `tiun.checkout({ productId })` from the purchase action — see [subscriptions.md](subscriptions.md#choosing-checkout-or-login) |
