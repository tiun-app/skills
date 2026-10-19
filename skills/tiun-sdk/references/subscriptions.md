# Subscriptions

Use subscriptions when you need persistent user accounts and **recurring** revenue (SaaS, memberships). For a product bought once with permanent access, see [one-time.md](one-time.md) instead — it shares this entry point but has no renewal, trial, or expiry.

If you arrived here without first doing Step 0 in [../SKILL.md](../SKILL.md), go back — confirm the mode (subscription, one-time, or time-based) and gather identifiers before generating code.

## Flow

1. Create subscription products in the dashboard. Each has a `productId` (`p-live-...` for live, `p-test-...` for sandbox).
2. `tiun.init({ snippetId, language: 'en' })` on app start.
3. Bind checkout to each purchase action — a plan's button, an upgrade prompt, wherever the user chooses a product:

   ```javascript
   tiun.checkout({ productId: 'p-live-pro' });
   ```

   This opens the hosted checkout overlay, which handles the customer's account as part of the purchase — see [Choosing checkout or login](#choosing-checkout-or-login). After success, tiun fires `userChange` with `event: 'checkout'`; see [events.md](events.md#userchangeevent--what-changed) for how event values are delivered.

4. Subscribe to `userChange` to drive the UI:

   ```javascript
   tiun.on('userChange', ({ event, isAuthenticated, user }) => {
     if (!isAuthenticated) return showSignedOutUI(); // whatever your app shows signed-out visitors
     const hasPro = user.productAccess.includes('p-live-pro');
     hasPro ? showProUI() : showFreeUI();
   });
   ```

5. Wire the app's sign-in action to `tiun.login()` and its sign-out action to `tiun.logout()`. Returning users need a way into their account that doesn't start a purchase; where it sits is a design decision. OTP is sent to their registered email (and SMS if configured).

## Choosing checkout or login

Use authentication for account entry and checkout for purchases:

- **Entering an account** — signing up or signing in → `tiun.login()`. It covers both; there is no separate sign-up method.
- **Buying a product or plan** → `tiun.checkout({ productId })`.
- **Leaving an account** → `tiun.logout()`.

Choose by the action's purpose, not its label. "Get started" on a plan card is a purchase; "Get started" on the front door of an app that needs an account is account entry. The surrounding experience decides.

**Why a purchase can open checkout directly.** Checkout handles the customer's account state within its own flow. A new customer proceeds through it, and so can a returning one. If someone enters an email that already has the purchase, checkout shows its already-purchased experience, and a past purchaser can choose the sign-in option inside checkout without entering their email first. There is nothing to orchestrate around it — don't rebuild existing-purchase messaging, identity checks, or returning-customer routing on your own page.

Both of these journeys are valid. Follow the one the app is built for:

- **Purchase-first.** Visitors see an offering or pricing page and choose a plan; the plan's button opens checkout. The app also has a conventional sign-in entry point for returning users.
- **Account-first.** Users sign up or sign in to use the app — a free tier, a workspace — and meet a paid offer later; the upgrade button opens checkout. Keep this structure rather than redesigning it into a public pricing funnel.

The line is between authentication as the way *into the app*, which is fine, and authentication inserted *into a purchase action*. That second one is the mistake to avoid: a visitor clicks "Buy" and the app opens a separate login instead of checkout — for example, a purchase handler that picks `tiun.login()` or `tiun.checkout()` based on `tiun.isAuthenticated`, or that waits for a standalone login before opening checkout. The purchase action should open checkout for the selected product.

Opening checkout doesn't grant or gate anything by itself. Paid functionality still checks `productAccess` — see [Gating rules](#gating-rules).

## Branching on `userChange.event`

The `event` field tells you what triggered the fire (`'init' | 'login' | 'checkout' | 'logout' | 'update'`). Most gating logic does not need it — `isAuthenticated` + `productAccess` are enough. Branch when you want one-off side effects:

```javascript
tiun.on('userChange', ({ event, isAuthenticated, user }) => {
  if (!isAuthenticated) return showSignedOutUI(); // whatever your app shows signed-out visitors

  if (event === 'checkout') {
    showWelcomeToast(`Subscribed to ${user.productAccess.join(', ')}`);
  }
  // event === 'init' on returning visitors — no toast
  // event === 'update' when entitlements change (renewal, cancellation, tier change).
  // Subscriptions only — a one-time entitlement never changes. See one-time.md.

  renderGatedUI(user);
});
```

## User object shape

```typescript
{
  userId: 'u-abc123',
  email: 'user@example.com',
  productAccess: ['p-live-pro'],
}
```

Use `userId` if your backend needs a stable identifier across sessions, and `productAccess` for client-side gating.

## Multi-tier products

Real apps usually have more than one product. Use a const map so productIds are typed and discoverable:

```javascript
const TIUN_PRODUCTS = {
  basic: 'p-live-basic',
  pro:   'p-live-pro',
};

tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return showSignedOutUI(); // whatever your app shows signed-out visitors

  if (user.productAccess.includes(TIUN_PRODUCTS.pro))   return showProUI();
  if (user.productAccess.includes(TIUN_PRODUCTS.basic)) return showBasicUI();
  return showUpgradePrompt();
});

document.querySelector('#buy-pro').onclick =
  () => tiun.checkout({ productId: TIUN_PRODUCTS.pro });
```

## Gating rules

- **UI-level gating**: `user.productAccess.includes(productId)` is sufficient for showing/hiding UI.
- **Trusted access (paid API, protected downloads, etc.)**: do server-side verification (see [server-verification.md](server-verification.md)). Never trust `productAccess` alone for anything a user could bypass by editing their own client.

## Common mistakes

- **Wrapping `tiun.checkout` / `tiun.login` in helper functions that re-check `isInitialized` and `await waitForReady`.** These methods already do both internally. Call them directly from your event handler.
- **Reading `tiun.user` once at mount.** Subscription entitlements can change mid-session (upgrade, downgrade, renewal). Use `userChange` as the source of truth, not a one-shot read.
- **Applying this file's renewal/cancellation handling to a one-time product.** One-time entitlements are permanent — see [one-time.md](one-time.md).
- **Opening login from a purchase action.** See [Choosing checkout or login](#choosing-checkout-or-login).
- **Building custom payment forms.** The checkout overlay is hosted by tiun; do not reimplement card collection.
- **Reaching into the checkout or login overlay.** It is shadow DOM and off limits — no injected help text, no CSS overrides, no scraping its inputs. Extra copy goes on your own page, next to the trigger. See [overview.md](overview.md#hosted-ui-is-a-black-box).
