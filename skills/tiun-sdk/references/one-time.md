# One-time purchases

Use one-time purchases when the customer **buys once and keeps access** — consulting engagements, lifetime licenses, a single course, report, or deliverable. Configured in the dashboard with a single **fixed fee**; no interval, no trial.

If you arrived here without first doing Step 0 in [../SKILL.md](../SKILL.md), go back — confirm the mode (subscription, one-time, or time-based) and gather identifiers before generating code.

## Same as subscriptions

One-time products use the **identical integration**: `tiun.init` → `tiun.checkout({ productId })` → `userChange` with `event: 'checkout'` → gate on `user.productAccess`. The hosted overlay is the same one; it just shows a fixed fee instead of a recurring price and interval.

```javascript
const TIUN_PRODUCTS = { lifetime: 'p-live-lifetime' };

tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return showSalesPage();
  user.productAccess.includes(TIUN_PRODUCTS.lifetime)
    ? showPurchasedUI()
    : showSalesPage();
});

document.querySelector('#buy').onclick =
  () => tiun.checkout({ productId: TIUN_PRODUCTS.lifetime });
```

Everything in [subscriptions.md](subscriptions.md) about `userChange`, the user object shape, and UI-vs-trusted gating applies unchanged. Do not restate it — read it there.

## What's different

| Subscription | One-time |
|---|---|
| Recurring fee + interval | Single **fixed fee** |
| Optional trial | No trial |
| Renews automatically | Never renews |
| Can be cancelled; access ends | Cannot be cancelled |
| `productAccess` entry can disappear | `productAccess` entry is **permanent** |
| Tiers ladder (basic → pro) | Not tiered — one unlock |

## Access is permanent

Once checkout completes, the product ID enters `productAccess` and **never leaves it** — across sessions, logouts, and new devices.

**Do not generate expiry, renewal, cancellation, trial, or revocation handling for a one-time product.** `userChange` with `event: 'update'` never removes a one-time entry. Code that branches on a one-time entitlement disappearing is dead code for state that cannot occur.

The practical consequence for UX: login is the only thing between a returning customer and the content they already paid for. Make sure the sales page offers **log in**, not just a buy button — otherwise a returning customer's only visible option is to pay twice.

## Mixed catalogs

An app can sell both. The tier ladder from [subscriptions.md](subscriptions.md) does **not** compose with a one-time unlock — a permanent purchase is not a rung on the subscription ladder. Check it independently:

```javascript
const TIUN_PRODUCTS = {
  pro:      'p-live-pro',       // subscription
  lifetime: 'p-live-lifetime',  // one-time
};

tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return showSignedOutUI();

  // Independent check — not an `else if` rung.
  if (user.productAccess.includes(TIUN_PRODUCTS.lifetime)) return showProUI();
  if (user.productAccess.includes(TIUN_PRODUCTS.pro))      return showProUI();
  return showUpgradePrompt();
});
```

## Common mistakes

- **Generating revocation branches.** Copying subscription gating wholesale brings renewal/cancellation handling that can never fire for a one-time product.
- **Subscription copy on one-time UI.** "Subscribe", "Subscribed to …", "Manage your plan" are wrong. Use "Buy", "Purchased", "You own this".
- **Assuming the product ID prefix tells you the type.** It does not — `p-live-…` / `p-test-…` encode the *environment* only. The `pricingType` field from the MCP's `get_products` (`'Subscription' | 'TimeBased' | 'OneTime'`) is the only signal, and even then, inventory is not intent — confirm with the user. See [mcp.md](mcp.md).
- **Offering a one-time product a trial.** Trials are a subscription-only concept; the dashboard does not expose one here.
