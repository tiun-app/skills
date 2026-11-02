# Events

Subscribe with `tiun.on(event, callback)` or `tiun.once(event, callback)`. You can also pass event callbacks directly to `tiun.init({ onReady, onError, ... })` — see [installation.md](installation.md).

| Event | Fires when | Payload |
|---|---|---|
| `ready` | Snippet has loaded and is operational. | none |
| `userChange` | Auth state or entitlements change. **Primary event for checkout-based gating** (subscriptions and one-time purchases). | `{ event: 'init' \| 'login' \| 'checkout' \| 'logout' \| 'update', isAuthenticated: boolean, user: TiunUser \| null }` |
| `login` | A user successfully logs in. | `{ user: TiunUser }` |
| `logout` | Session is cleared. | none |
| `paywallShow` | Time-based: user has no access (no payment method yet, or session ended). | `{ isConnected: boolean }` — `isConnected` is `true` if a payment method exists but the session ended |
| `paywallHide` | Time-based: a session is active. **Primary event for time-based gating.** | `{ sessionId: string, isConnected: boolean }` — `sessionId` is usable for [server-side verification](server-verification.md) |
| `error` | An SDK error occurred. | `{ code: string, message: string, details?: any }` |

## `userChange.event` — what changed

The `event` field tells you what triggered the fire:

| `event` value | Trigger |
|---|---|
| `'init'`     | Session restored on page load. Fires once after `ready`. |
| `'login'`    | User completed `tiun.login()`. |
| `'checkout'` | User completed `tiun.checkout()`. |
| `'logout'`   | User called `tiun.logout()`. |
| `'update'`   | The user's ID or email changed. |

Most integrations do not need to branch on `event` — `isAuthenticated` + `user.productAccess` are enough for UI gating of subscriptions and non-repeatable one-time products. Branch on `event` when you need to fire one-off side effects (e.g. show a "Welcome!" toast on `'login'` but not on `'init'`).

When a subscription ends, or a one-time product with **limited access** reaches its end date, that product ID leaves `productAccess` and `userChange` fires. Gate on the array. The events reference does not name an `event` value for that removal. Repeatable products are not gated with `productAccess` — see [one-time.md](one-time.md).

The documented value after a completed checkout is `'checkout'`. Put post-purchase side effects on `'checkout'`. Drive gating from `isAuthenticated` and `productAccess`. `event: 'update'` means the user's ID or email changed — it is not the signal that a subscription or a limited-access purchase ended.

## Initial state arrives via the listener

As long as your `userChange` listener is registered before (or synchronously after) `tiun.init`, you will receive the initial state automatically via an `event: 'init'` fire after `ready` — no need to manually re-read `tiun.user` in a `waitForReady().then(...)` callback.

Correct — initial state arrives via the listener:

```javascript
tiun.on('userChange', syncStateFromTiun);
tiun.init({ snippetId });
```

Redundant — `userChange` fires anyway, so the extra `waitForReady().then(...)` is unnecessary:

```javascript
tiun.init({ snippetId });
tiun.on('userChange', syncStateFromTiun);
tiun.waitForReady().then(syncStateFromTiun);
```

## `error.code` is not a stable enum

`error.code` is a string, but there is no published enum of values and codes can change between SDK versions. **Display `error.message` to users and log `error.code` for support; do not branch application logic on specific codes.**

## Patterns

### Gating content (subscriptions and one-time purchases)

```javascript
tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return showSignedOutUI(); // whatever your app shows signed-out visitors
  if (user.productAccess.includes('p-live-pro')) return showProContent();
  return showUpgradePrompt();
});
```

### Always unsubscribe in framework cleanups

`tiun.on` returns an unsubscribe function. Call it in React `useEffect` cleanup / Vue `onUnmounted` / etc. to avoid leaks during navigation. For SPA roots that never unmount, `tiun.destroy()` cleans everything up.
