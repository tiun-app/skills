# One-time purchases

A one-time product charges a **single fixed fee**. There is no interval, no trial, no renewal, and no cancellation.

Access is **permanent by default**, and each customer can buy the product **once**. Two optional switches on the product change that. Turn them on in the dashboard under **Products** when you create or edit the product:

- **Limited access** — access ends a set time after purchase. Nothing renews.
- **Repeat purchases** — the customer can buy the product again, once per `referenceId`. The price is charged each time.

The two switches combine: a repeatable product can also have limited access, and each purchase then has its own end date.

If you arrived here without first doing Step 0 in [../SKILL.md](../SKILL.md), go back — confirm the mode and gather identifiers before generating code.

Upstream: [Sell one-time products](https://docs.tiun.io/guides/one-time-purchases/sell-one-time-products), [One-time purchases](https://docs.tiun.io/reference/checkout/one-time-purchases), [Repeatable one-time purchases](https://docs.tiun.io/guides/one-time-purchases/repeatable-one-time-purchases).

## Default product

`tiun.init` → `tiun.checkout({ productId })` → `userChange` with `event: 'checkout'` → gate on `user.productAccess`. The overlay shows a fixed fee.

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

`userChange`, the user object, and UI-vs-trusted gating are in [subscriptions.md](subscriptions.md). Read them there.

Leave `referenceId` off checkout unless the product has **Repeat purchases** turned on. Passing it on any other product — a subscription, a time-based product, or a one-time product with the switch off — shows a configuration error and charges nothing.

## What's different from a subscription

| | Subscription | One-time, default | Limited access | Repeat purchases |
|---|---|---|---|---|
| Charge | Recurring fee + interval | Fixed fee, once | Fixed fee, once | Fixed fee, each purchase |
| Trial | Optional | None | None | None |
| After payment | Renews until it ends | Stays in `productAccess` | Leaves `productAccess` at the end date | Checked per `referenceId` with `checkProductAccess()` or on the server |
| Cancel | Yes | No | No | No |
| Buy again | After it ends | Never | Never | Once per `referenceId` |
| Tiers | Yes | No | No | No |

## Bought once per customer

This is the default, and it still applies to a product that has limited access and does **not** have Repeat purchases.

tiun blocks a second purchase before any money moves:

- **Signed in and already entitled** — checkout links the existing entitlement and shows an "already purchased, no new charge was made" screen.
- **Signed out** — checkout signs the customer in. Once it recognizes them as the owner, it shows the same screen. Nothing is charged.

Hide or disable the buy button once `productAccess` contains the product ID. Give returning customers a sign-in entry point (`tiun.login()`). Checkout will not hand them the content.

Copy for this product: "Buy", "Purchased", "You own this". There is no "Subscribe", "Manage your plan", "Renews on", or "Cancel".

There are no quantities, carts, or credit packs. A second purchase of the same product is a **Repeat purchases** product with a new `referenceId`, not a quantity on this one.

You cannot cancel a one-time purchase, so you cannot reset it for a test customer. Re-test a first purchase in sandbox with a new email address.

## Limited access

**Limited access** ends access a count of **days, weeks, months, or years** after the day of purchase. When that date is reached, tiun removes the product ID from `productAccess` and fires `userChange`. Nothing starts a new period.

Gate the same way as the default product: `productAccess.includes(productId)` is true until the end date and false after it. Do not add a renewal job, a cancel action, or a trial.

On the server, the same `user.productAccess` check applies. See [server-verification.md](server-verification.md).

## Repeat purchases

Turn on **Repeat purchases** for articles, bookings, tickets, reports, and anything the same customer buys more than once. Each purchase is tied to a `referenceId` your app already has — an article ID, a booking ID, or an order ID. Use the same ID whenever you mean the same thing.

`referenceId` is **required**. Checkout without it shows a configuration error and charges nothing. Use 1–200 characters: letters (`A–Z`, `a–z`), digits, hyphens (`-`), underscores (`_`), or dots (`.`). No spaces. Anything else shows a configuration error and charges nothing.

```javascript
tiun.checkout({
  productId: TIUN_PRODUCTS.article, // e.g. 'p-live-article'
  referenceId: articleId,           // e.g. 'article-1042'
});
```

Requires `@tiun/sdk` **0.11.0** or later. React Native: `checkout({ productId, referenceId })` from `useTiun()`, `@tiun/react-native-sdk` **0.4.0** or later.

The once-per-customer rule applies **per reference ID**. A new reference ID charges again. The same reference ID shows the "already purchased" screen and charges nothing.

`productAccess` is a list of product IDs. The product ID shows up after the first reference and stays until the last one ends, and it never names which reference was bought, so do not gate a repeatable product with `productAccess.includes(productId)`. Check the product and the reference ID together, in one of two places:

- **In the browser** with `tiun.checkProductAccess(productId, { referenceId })` (`@tiun/sdk` **0.12.0+**, React Native `checkProductAccess` on `useTiun()` **0.5.0+**). No backend needed.
- **On the server**, a good fit when the integrator already has a backend or wants a more secure setup where the content stays on the server until the purchase is confirmed.

You can combine them: the browser check for the page, the server check for the content it loads.

### In the browser

```javascript
async function loadArticle(articleId) {
  const { hasAccess } = await tiun.checkProductAccess(TIUN_PRODUCTS.article, {
    referenceId: articleId,
  });
  hasAccess ? showArticle(articleId) : showSalesPage(articleId);
}

// Re-check on every userChange: page load, login, logout, and any access change
tiun.on('userChange', () => loadArticle(currentArticleId));
```

Signed out, or no purchase for that reference: `{ hasAccess: false, access: null }`, not an error. For a list of items (an article index, "My purchases"), call `tiun.listProductAccess()` once and match each item's `referenceId`, instead of `checkProductAccess()` per item.

`userChange` fires with `event: 'checkout'` when a repeatable product is bought with a new reference ID.

### On the server

After verifying the user:

```
GET /live_api/s2s/v1/users/{userId}/product_access/{productId}?referenceId={referenceId}
```

Details and response shape: [server-verification.md](server-verification.md#repeatable-product-access). The frontend asks your backend on every `userChange`, and the backend calls the product-access URL above.

A repeatable product with **Limited access** still uses that URL. `expiresAt` on the access object is the end of that purchase; it is `null` when limited access is off.

To mirror purchases into your own database, handle `product_access.add` and `product_access.remove` and confirm each one with the same API. See [webhooks.md](webhooks.md).

## Mixed catalogs

A one-time unlock is not a rung on a subscription ladder. Check it on its own:

```javascript
const TIUN_PRODUCTS = {
  pro:      'p-live-pro',       // subscription
  lifetime: 'p-live-lifetime',  // one-time, default
};

tiun.on('userChange', ({ isAuthenticated, user }) => {
  if (!isAuthenticated) return showSignedOutUI();

  const owned      = user.productAccess.includes(TIUN_PRODUCTS.lifetime);
  const subscribed = user.productAccess.includes(TIUN_PRODUCTS.pro);

  renderContent({ hasAccess: owned || subscribed });
  renderLifetimeOffer({ hidden: owned });
  renderSubscriptionOffer({ hidden: subscribed });
});
```

A repeatable product does not belong in this `productAccess` check. Check the reference ID with `tiun.checkProductAccess()` or on the server.

## Common mistakes

- **Gating a repeatable product with `productAccess.includes(productId)`.** That array cannot tell references apart.
- **Opening checkout for a repeatable product without `referenceId`.** The overlay stops before payment.
- **Passing `referenceId` on a product that is not repeatable.** Checkout stops with a configuration error. Omit it for subscriptions, time-based products, and one-time products with Repeat purchases off.
- **A `referenceId` outside the allowed characters above.**
- **Checking each item of a list separately.** Use one `tiun.listProductAccess()` call and match `referenceId`s.
- **Re-checking only after a checkout.** Re-check on every `userChange`, so login, logout, and access that ends are covered too.
- **Leaving the buy button up after a confirmed purchase** of that product (default or limited access) or of that reference ID (repeatable). Checkout will not charge again.
- **Generating renewal, cancellation, or trial handling.** None of those exist on a one-time product. Limited access removes the ID when the period ends; it does not renew.
- **Quantity selectors, carts, or credit packs.** Repeat purchases are another `referenceId`, not a quantity.
- **Subscription copy.** Use "Buy" / "Purchased" / "You own this".
- **Reading the product type from the ID prefix.** `p-live-…` / `p-test-…` are the environment. `pricingType` distinguishes subscription, one-time, and time-based, and it does not say whether Repeat purchases or Limited access is on. See [mcp.md](mcp.md).
- **Reaching into the checkout overlay.** See [overview.md](overview.md#hosted-ui-is-a-black-box).
- **Offering a trial.** Trials are subscription-only.
