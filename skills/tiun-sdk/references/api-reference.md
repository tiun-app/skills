# API Reference

All methods are on the `tiun` singleton imported from `@tiun/sdk`.

## Lifecycle

| Method | Purpose |
|---|---|
| `tiun.init(config)` | Initialize the SDK. See [installation.md](installation.md) for config. |
| `tiun.destroy()` | Tear down the instance. **Only call where the subtree can remount** — see the lifecycle matrix in [frameworks.md](frameworks.md). Not needed at an SPA root. |
| `tiun.waitForReady()` | Returns a Promise resolving when the snippet is loaded. |
| `tiun.on(event, cb)` | Subscribe to an event. |
| `tiun.once(event, cb)` | Subscribe to an event and auto-unsubscribe after first fire. |

## Auth & checkout

| Method | Purpose |
|---|---|
| `tiun.login()` | Opens the hosted login overlay. |
| `tiun.logout()` | Clears the session and fires `logout` / `userChange`. |
| `tiun.checkout({ productId })` | Opens the hosted subscription checkout overlay. |
| `tiun.start()` | Opens the time-based connect overlay (no product required). See [time-based.md](time-based.md). |
| `tiun.setContent({ type, contentId, mediaType })` | Updates the current content context (`'active'` / `'inactive'` / `'paused'`). Used by time-based billing to meter sessions per route. See [time-based.md](time-based.md). |
| `tiun.getUser()` | Returns the current user state (or `null`). |
| `tiun.getUserVerificationToken()` | Returns a signed JWT for server-side verification. |

## Properties

| Property | Type | Notes |
|---|---|---|
| `tiun.version` | string | SDK version. |
| `tiun.isInitialized` | boolean | `true` after `init()`. |
| `tiun.isReady` | boolean | `true` once the hosted snippet is loaded. |
| `tiun.isAuthenticated` | boolean | `true` when a valid session exists. |
| `tiun.user` | object \| null | Current user. Includes `productAccess: string[]`. |

## User object shape

```typescript
interface TiunUser {
  email: string;
  productAccess: string[]; // product IDs the user has access to
  // plus any custom fields configured in the dashboard
}
```

Use `user.productAccess.includes(productId)` to gate features per subscription tier.
