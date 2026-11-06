# Events

Subscribe with `tiun.on(event, callback)` or `tiun.once(event, callback)`. You can also pass event callbacks directly to `tiun.init({ onReady, onError, ... })` — see [installation.md](installation.md).

| Event | Fires when | Payload |
|---|---|---|
| `ready` | Snippet has loaded and is operational. | none |
| `userChange` | The user or their access changed. **Primary event for checkout-based gating** (subscriptions and one-time purchases) — re-check access every time it fires. | `{ event: 'init' \| 'login' \| 'checkout' \| 'logout' \| 'update', isAuthenticated: boolean, user: TiunUser \| null }` |
| `login` | A user successfully logs in. | `{ user: TiunUser }` |
| `logout` | Session is cleared. | none |
| `paywallShow` | Time-based: user has no access (no payment method yet, or session ended). | `{ isConnected: boolean }` — `isConnected` is `true` if a payment method exists but the session ended |
| `paywallHide` | Time-based: a session is active. **Primary event for time-based gating.** | `{ sessionId: string, isConnected: boolean }` — `sessionId` is usable for [server-side verification](server-verification.md) |
| `error` | An SDK error occurred. Not fired for the product methods — their errors only reject the Promise. | `{ code: string, message: string, details?: any }` |

## `userChange.event` — what changed

The `event` field tells you what triggered the fire:

| `event` value | Meaning |
|---|---|
| `'init'`     | First state after the snippet loads (session restored on page load). Fires once after `ready`. |
| `'login'`    | The user signed in. |
| `'logout'`   | The user signed out. `user` is `null`. |
| `'checkout'` | **The user's access changed** — gained or lost, for any product type. |
| `'update'`   | Profile details changed (email, newsletter opt-in). |

`'checkout'` fires whenever access changes:

- a completed purchase, a subscription that ends, or a limited-access one-time purchase reaching its end date;
- a repeatable product bought with a new reference ID; `productAccess` does not name it;
- access that changed in another tab, once this tab is visible again.

**Rule: re-check access on every `userChange`.** Read `user.productAccess` for subscriptions and one-time products; call `tiun.checkProductAccess(productId, { referenceId })` for a repeatable product (or `tiun.listProductAccess()` for a "My purchases" list). Branch on `event` only for one-off side effects (e.g. a "Welcome!" toast on `'login'` but not on `'init'`). For a post-purchase message on `'checkout'`, check that access was gained, since `'checkout'` also fires when access ends.

In React Native, the payload has `event` from `@tiun/react-native-sdk` 0.5.0; before that, use the separate `login` / `logout` events.

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

### Repeatable products (`@tiun/sdk` 0.12.0+)

```javascript
tiun.on('userChange', async ({ isAuthenticated, user }) => {
  showPro(isAuthenticated && user.productAccess.includes('p-live-pro'));

  const { hasAccess } = await tiun.checkProductAccess('p-live-article', { referenceId: articleId });
  showArticle(hasAccess);
});
```

### Always unsubscribe in framework cleanups

`tiun.on` returns an unsubscribe function. Call it in React `useEffect` cleanup / Vue `onUnmounted` / etc. to avoid leaks during navigation. For SPA roots that never unmount, `tiun.destroy()` cleans everything up.
