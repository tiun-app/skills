# Time-based Paywall

Use time-based when you want per-session, anonymous access metered by time spent on paid content — no account required. Users connect a payment method once and are billed per interval (e.g. EUR 0.22 per minute) up to a monthly cap.

Choose this over subscriptions when: articles, single videos, podcasts, donation-prompt-style paywalls, "first N seconds free then pay" experiences.

If you arrived here without first doing Step 0 in [../SKILL.md](../SKILL.md), go back — confirm mode (subscription vs time-based) and gather identifiers before generating code.

## Flow

1. Create a time-based product in the dashboard (configure interval, fee, monthly limit). Copy the `productId`.
2. `tiun.init({ snippetId })` on app start.
3. Start with the paywall visible — in time-based, the default state is locked.
4. Listen for `paywallShow` / `paywallHide` to toggle paywall vs premium UI.
5. Add a button that calls `tiun.start()` to open the connect overlay.
6. Call `tiun.setContent({ type, contentId, mediaType })` on every route/page change to drive metering.

## Listening for paywall events

```javascript
tiun.on('paywallShow', () => {
  showPaywall();
  hidePremiumContent();
});

tiun.on('paywallHide', (data) => {
  hidePaywall();
  showPremiumContent();
  // data.sessionId — usable for server-side verification
});
```

`paywallShow` fires when the user has no access (no payment method yet, or session ended). `paywallHide` fires once a session is active.

## Starting a session

```javascript
function onClickGetAccess() {
  tiun.start();
}
```

After the user connects a payment method, `paywallHide` fires.

## Per-route content metering

Tell tiun what the user is viewing on every route change.

```javascript
function onRouteChange(path) {
  tiun.setContent({
    type: isPaidContent(path) ? 'active' : 'inactive',
    contentId: path,
  });
}
```

| Type | When to use |
|---|---|
| `'active'` | Paid content — session is running and billing |
| `'inactive'` | Free content — session pauses, no billing |
| `'paused'` | Temporarily paused (e.g. video paused) |

## Media types

For audio or video, set `mediaType` so sessions behave correctly (audio stays active during background / locked screen; video follows play/pause state).

```javascript
tiun.setContent({
  type: 'active',
  contentId: 'episode-42',
  mediaType: 'audio',
});
```

| Media type | Behavior |
|---|---|
| `'text'` (default) | Tracks page visibility and scroll |
| `'audio'` | Stays active during background and locked-screen playback |
| `'video'` | Follows video play/pause state |

## Sandbox vs production

Production is the default — if you never set `sandbox: true` in `init()`, you're live. Production product IDs are prefixed `p-live-`. The dashboard has a separate sandbox toggle that must match the SDK's `sandbox` flag, or checkout silently fails (Rule 8 in `SKILL.md`).

## Common mistakes

- **Showing premium content by default.** Time-based starts locked; render the paywall first and reveal premium content from `paywallHide`.
- **Forgetting `setContent` on route changes.** Without it, the session can't meter correctly across routes.
- **Mismatched `mediaType`.** Mark a podcast page `'audio'` only if audio is actually playing — otherwise the session keeps billing while the user is reading show notes with the screen locked.

## Full reference

`https://docs.tiun.io/guides/build-a-time-based-paywall`
