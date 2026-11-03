# Subscriptions

Use subscriptions when you need persistent user accounts and **recurring** revenue (SaaS, memberships). For a single fixed fee — permanent by default, or with limited access or repeat purchases — see [one-time.md](one-time.md). It shares this entry point and has no renewal, trial, or cancellation.

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

The `event` field tells you what triggered the fire (`'init' | 'login' | 'logout' | 'checkout' | 'update'`). `'checkout'` means the user's access changed — gained **or lost** — and `'update'` means profile details changed. Gating doesn't need it: re-check `productAccess` on every fire. Branch only for one-off side effects, and for a purchase message check that access was gained:

```javascript
let previousAccess = [];

tiun.on('userChange', ({ event, isAuthenticated, user }) => {
  const access = user?.productAccess ?? [];

  if (event === 'checkout') {
    const gained = access.filter((id) => !previousAccess.includes(id));
    if (gained.length) showWelcomeToast(`Subscribed to ${gained.join(', ')}`);
  }
  // event === 'init' on returning visitors — no toast
  previousAccess = access;

  if (!isAuthenticated) return showSignedOutUI(); // whatever your app shows signed-out visitors
  renderGatedUI(user);
});
```

## User object shape

```typescript
{
  userId: 'u-abc123',
  email: 'user@example.com',
  hasNewsletterOptIn: false, // @tiun/sdk 0.11.0 or later
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

- **In the app**: `user.productAccess.includes(productId)`, re-checked on every `userChange`, is all a subscription needs. It works without a backend.
- **Dates on an account page** ("Renews" vs "Ends on"): `tiun.listProductAccess()` or `tiun.checkProductAccess(productId)` (`@tiun/sdk` 0.12.0+). `expiresAt` is `null` while the subscription renews and the end of the paid period once it's cancelled.
- **On the server**: when the integrator's backend serves the paid content (a paid API, protected downloads), verify there before returning it — the more secure setup. See [server-verification.md](server-verification.md).

## Common mistakes

- **Wrapping `tiun.checkout` / `tiun.login` in helper functions that re-check `isInitialized` and `await waitForReady`.** These methods already do both internally. Call them directly from your event handler.
- **Reading `tiun.user` once at mount.** Subscription entitlements can change mid-session (upgrade, downgrade, renewal). Use `userChange` as the source of truth, not a one-shot read.
- **Applying this file's renewal/cancellation handling to a one-time product.** One-time products do not renew or cancel. Limited access and repeat purchases are in [one-time.md](one-time.md).
- **Opening login from a purchase action.** See [Choosing checkout or login](#choosing-checkout-or-login).
- **Building custom payment forms.** The checkout overlay is hosted by tiun; do not reimplement card collection.
- **Reaching into the checkout or login overlay.** It is shadow DOM and off limits — no injected help text, no CSS overrides, no scraping its inputs. Extra copy goes on your own page, next to the trigger. See [overview.md](overview.md#hosted-ui-is-a-black-box).
