# Events

Subscribe with `tiun.on(event, callback)` or `tiun.once(event, callback)`.

| Event | Fires when | Payload |
|---|---|---|
| `ready` | Snippet has loaded and is operational. | none |
| `userChange` | Auth state or entitlements change. **This is the primary event for subscription gating.** | `{ isAuthenticated: boolean, user: TiunUser \| null }` |
| `login` | A user successfully logs in. | `TiunUser` |
| `logout` | Session is cleared. | none |
| `paywallShow` | Time-based: user has no access (no payment method yet, or session ended). | none |
| `paywallHide` | Time-based: a session is active. **Primary event for time-based gating.** | `{ sessionId: string }` — usable for server-side verification |
| `error` | An SDK error occurred. | `{ code: string, message: string }`. No canonical list of codes is published; see https://docs.tiun.io. |

## `userChange` fires once with `event: 'init'` after `ready`

As long as your `userChange` listener is registered before (or synchronously after) `tiun.init`, you will receive the initial state automatically — no need to manually re-read `tiun.user` in a `waitForReady().then(...)` callback.

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

## Patterns

### Gating content (subscriptions)

```javascript
tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return showPricingPage();
  if (user.productAccess.includes('p-live-pro')) return showProContent();
  return showUpgradePrompt();
});
```

### Always unsubscribe in framework cleanups

`tiun.on` returns an unsubscribe function. Call it in React `useEffect` cleanup / Vue `onUnmounted` / etc. to avoid leaks during navigation.
