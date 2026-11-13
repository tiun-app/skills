# One-time purchases

A one-time product charges a **single fixed fee**. There is no interval, no trial, no renewal, and no cancellation.

Access is **permanent by default**, and each customer can buy the product **once**. Two optional switches on the product change that. Turn them on in the dashboard or through the MCP one-time tools when you create or edit the product:

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

## Picking the setup

Choose by what is sold:

- **Lifetime access** (an app or SaaS tool, a pro mode, a course, a license): the default. The customer pays once and keeps access.
- **Access for a set time, one per product** (a weekly pass to a tool): turn on limited access. The product ID is enough, and the customer can buy again once it ends.
- **Many items at one price** (top-ups, articles, tickets): turn on repeat purchases and pass a `referenceId` per item.
- **Renting one of many items** (a movie or an article for a day): repeat purchases plus limited access, with a `referenceId` per item.

Unlike a subscription, there's no trial, no renewal, and nothing to cancel.

## After the purchase

Give the customer what they bought: unlock the content as soon as `productAccess` (or `checkProductAccess()` for a `referenceId`) shows it, and swap the buy button for it. Checkout won't charge twice for something they still have access to. A returning customer who opens it is signed in and sees "already purchased".

Copy for this product: "Buy", "Purchased", "You own this". There is no "Subscribe", "Manage your plan", "Renews on", or "Cancel".

There are no quantities, carts, or credit packs. A second purchase of the same product is a **Repeat purchases** product with a new `referenceId`, not a quantity on this one.

You cannot cancel a one-time purchase, so you cannot reset it for a test customer. Re-test a first purchase in sandbox with a new email address.

## Limited access

**Limited access** ends access a count of **days, weeks, months, or years** after the day of purchase. When that date is reached, tiun removes the product ID from `productAccess` and fires `userChange`. Nothing starts a new period.

Gate the same way as the default product: `productAccess.includes(productId)` is true until the end date and false after it.

On the server, the same `user.productAccess` check applies. See [server-verification.md](server-verification.md).

## Repeat purchases

Each purchase is tied to a `referenceId`: an ID your app already has (an article or booking ID), or a new one you generate per purchase for top-ups. Use the same ID whenever you mean the same thing.

`referenceId` is **required**. Checkout without it shows a configuration error and charges nothing. Use 1–200 characters: letters (`A–Z`, `a–z`), digits, hyphens (`-`), underscores (`_`), or dots (`.`). No spaces. Anything else shows a configuration error and charges nothing.

```javascript
tiun.checkout({
  productId: TIUN_PRODUCTS.article, // e.g. 'p-live-article'
  referenceId: articleId,           // e.g. 'article-1042'
});
```

Requires `@tiun/sdk` **0.11.0** or later. React Native: `checkout({ productId, referenceId })` from `useTiun()`, `@tiun/react-native-sdk` **0.4.0** or later.

The once-per-customer rule applies **per reference ID**. A new reference ID charges again. The same reference ID shows the "already purchased" screen and charges nothing while its access lasts.

`productAccess` is a list of product IDs. The product ID shows up after the first reference and stays until the last one ends, and it never names which reference was bought, so do not gate a repeatable product with `productAccess.includes(productId)`. Check the product and the reference ID together, in one of two places:

- **In the browser** with `tiun.checkProductAccess(productId, { referenceId })` (`@tiun/sdk` **0.12.0+**, React Native `checkProductAccess` on `useTiun()` **0.5.0+**). No backend needed.
- **On the server**, when the integrator already has a backend that serves the content.

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

### Top-ups

Generate a new `referenceId` for each top-up (for example a UUID). A balance that goes down as credits are used needs your backend: on each `product_access.add` for the top-up product, confirm it with the API and add the credits once per `referenceId`. See [webhooks.md](webhooks.md).

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
- **Generating renewal, cancellation, or trial handling.** None of those exist on a one-time product. Trials are subscription-only. Limited access removes the ID when the period ends; it does not renew.
- **Quantity selectors, carts, or credit packs.** Repeat purchases are another `referenceId`, not a quantity.
- **Subscription copy.** Use "Buy" / "Purchased" / "You own this".
- **Reading the product type from the ID prefix.** `p-live-…` / `p-test-…` are the environment. `pricingType` distinguishes subscription, one-time, and time-based, and it does not say whether Repeat purchases or Limited access is on. See [mcp.md](mcp.md).
- **Reaching into the checkout overlay.** See [overview.md](overview.md#hosted-ui-is-a-black-box).
