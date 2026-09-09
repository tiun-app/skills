# Subscriptions

Use subscriptions when you need persistent user accounts and **recurring** revenue (SaaS, memberships). For a product bought once with permanent access, see [one-time.md](one-time.md) instead — it shares this entry point but has no renewal, trial, or expiry.

If you arrived here without first doing Step 0 in [../SKILL.md](../SKILL.md), go back — confirm the mode (subscription, one-time, or time-based) and gather identifiers before generating code.

## Flow

1. Create subscription products in the dashboard. Each has a `productId` (`p-live-...` for live, `p-test-...` for sandbox).
2. `tiun.init({ snippetId, language: 'en' })` on app start.
3. On the pricing page, bind checkout:

   ```javascript
   tiun.checkout({ productId: 'p-live-pro' });
   ```

   This opens the hosted checkout overlay. **It authenticates as part of the purchase** — an anonymous visitor signs up or logs in inside the overlay — so the button works identically whether or not anyone is signed in. After success, tiun fires `userChange` with `event: 'checkout'` (and `login` if the user was new).

4. Subscribe to `userChange` to drive the UI:

   ```javascript
   tiun.on('userChange', ({ event, isAuthenticated, user }) => {
     if (!isAuthenticated) return showPricingPage();
     const hasPro = user.productAccess.includes('p-live-pro');
     hasPro ? showProUI() : showFreeUI();
   });
   ```

5. Offer `tiun.login()` as a **separate** entry point for returning customers who already have access — a "Log in" link in the header or beside the plans, never a step in front of them. OTP is sent to their registered email (and SMS if configured).

## Wiring CTAs — checkout vs login

`tiun.checkout()` authenticates on its own, so a purchase CTA never needs a login step in front of it. Map each CTA by what it means, not by whether the visitor is signed in:

| The CTA... | Maps to |
|---|---|
| Names a plan, price, or product — "Subscribe", "Get Pro", "Buy", "€9.99/mo", a pricing-card button | `tiun.checkout({ productId })` |
| Is about identity only — "Log in", "Sign in", "My account", "Member area" | `tiun.login()` |
| Is time-based access — "Get access", "Connect" | `tiun.start()` (see [time-based.md](time-based.md)) |

Bind the plan CTA's handler to `tiun.checkout({ productId })` unconditionally, and the login link's handler to `tiun.login()` — whatever "bind a handler" means in the stack at hand.

The wrong pattern, in any stack: a plan CTA whose handler tests `tiun.isAuthenticated` and calls `tiun.login()` when it is false, or one that waits for login to complete before calling `tiun.checkout()`. Both add a step that does nothing — checkout already handles sign-up and login — and a first-time visitor lands on a login screen for an account they do not have.

**When you are generating the pricing UI yourself** (the user has no buttons yet), produce one checkout CTA per product, plus one login link for returning customers. Do not invent an auth step, an "account required" gate, or a sign-up form ahead of the plans.

## Branching on `userChange.event`

The `event` field tells you what triggered the fire (`'init' | 'login' | 'checkout' | 'logout' | 'update'`). Most gating logic does not need it — `isAuthenticated` + `productAccess` are enough. Branch when you want one-off side effects:

```javascript
tiun.on('userChange', ({ event, isAuthenticated, user }) => {
  if (!isAuthenticated) return showPricingPage();

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
  if (!isAuthenticated) return showPricingPage();

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
- **Putting login in front of a plan CTA.** `tiun.checkout()` signs the user up or logs them in as part of the purchase. An `isAuthenticated` check before checkout, or a `login()` → `checkout()` chain, adds a dead step and strands first-time visitors on a login screen for an account they do not have. See [Wiring CTAs](#wiring-ctas--checkout-vs-login).
- **Building custom payment forms.** The checkout overlay is hosted by tiun; do not reimplement card collection.
- **Reaching into the checkout or login overlay.** It is shadow DOM and off limits — no injected help text, no CSS overrides, no scraping its inputs. Extra copy goes on your own page, next to the trigger. See [overview.md](overview.md#hosted-ui-is-a-black-box).
