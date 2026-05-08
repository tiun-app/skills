# Events

Subscribe with `tiun.on(event, callback)` or `tiun.once(event, callback)`.

| Event | Fires when | Payload |
|---|---|---|
| `ready` | Snippet has loaded and is operational. | none |
| `userChange` | Auth state or entitlements change. **This is the primary event for gating content.** | `{ isAuthenticated: boolean, user: TiunUser \| null }` |
| `login` | A user successfully logs in. | `TiunUser` |
| `logout` | Session is cleared. | none |
| `error` | An SDK error occurred. | `{ code: string, message: string }`. No canonical list of codes is published; see https://docs.tiun.io. |

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
