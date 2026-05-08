# Troubleshooting

## The overlay never appears

- Verify `tiun.init` was called exactly once with a valid `snippetId`.
- `snippetId` is environment-specific. Confirm the ID matches the dashboard environment you're targeting.
- Check `tiun.isReady`. Methods called before `ready` may silently queue or no-op. Use `await tiun.waitForReady()` or the `ready` event.
- Enable `debug: true` in `init()` to see SDK logs in the console.

## `userChange` never fires

- Confirm there is an `on('userChange', ...)` subscription and that it is registered before `login()` / `checkout()` is invoked.
- In frameworks: unsubscribe on unmount. A stale listener from a previous mount can look like "new ones don't fire" if you are checking the wrong instance.

## SSR errors on import

- `@tiun/sdk` is a browser SDK. In Next.js / Nuxt, initialize it from a client-only component/plugin (`'use client'`, `*.client.ts`).

## Sandbox vs. production mismatch

- `sandbox: true` in `init()` must match the dashboard's sandbox toggle. A mixed state produces "product not found" or silent checkout failures.

## Server-side verification fails

- Subscription JWTs are short-lived. Re-fetch via `getUserVerificationToken()` instead of caching.
- Verify against tiun's published signing keys; do not skip signature verification.

## Multiple `init` calls

- Re-initializing without `tiun.destroy()` is unsupported. In React, ensure the init effect has a stable dependency array (`[]`) and a `destroy()` cleanup.
