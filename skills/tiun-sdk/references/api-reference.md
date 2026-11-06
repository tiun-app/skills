# API Reference

All methods are on the `tiun` singleton imported from `@tiun/sdk`.

## Lifecycle

| Method | Purpose |
|---|---|
| `tiun.init(config)` | Initialize the SDK. **Idempotent** — calling again on an initialized instance merges config rather than re-initializing. See [installation.md](installation.md) for config. |
| `tiun.setAppearance(appearance)` | Switch the snippet color theme to `'light'`, `'dark'`, or `'auto'` without a reload. Safe to call before `init()` or before the snippet is ready. |
| `tiun.destroy()` | Tear down the instance, clearing listeners, runtime config, and cached user state. The snippet stays loaded. **Only call where the subtree can remount** — see the lifecycle matrix in [frameworks.md](frameworks.md). Not needed at an SPA root. A later `init()` works from `@tiun/sdk` 0.12.0; `tiun.user` then stays empty until the next login, logout, or checkout. |
| `tiun.waitForReady()` | Returns a Promise resolving when the snippet is loaded. From 0.12.0 it also resolves when called before `init()`. |
| `tiun.on(event, cb)` | Subscribe to an event. Returns an unsubscribe function. |
| `tiun.once(event, cb)` | Subscribe to an event and auto-unsubscribe after first fire. |

`tiun.init` also accepts event callbacks directly in the config (`onReady`, `onError`, `onUserChange`, etc.) — see [installation.md](installation.md).

## Auth & checkout

| Method | Purpose |
|---|---|
| `tiun.login()` | Opens the hosted login overlay. |
| `tiun.logout()` | Clears the session and fires `logout` / `userChange`. |
| `tiun.checkout({ productId, referenceId })` | Opens the hosted checkout overlay for a subscription or one-time product. `referenceId` is required for a repeatable one-time product. Omit it for every other product; passing it there is a configuration error. 1–200 characters: letters, digits, `-`, `_`, `.`, no spaces. Needs `@tiun/sdk` 0.11.0 or later when passed. See [one-time.md](one-time.md). |
| `tiun.start()` | Opens the time-based connect overlay (no product required). See [time-based.md](time-based.md). |
| `tiun.setContent({ type, contentId, mediaType })` | Updates the current content context. Used by time-based billing to meter sessions per route. See [time-based.md](time-based.md). |
| `tiun.getUser()` | Returns `{ isAuthenticated, user }`. `user` is `null` when nobody is signed in. |
| `tiun.getUserVerificationToken()` | Returns a signed JWT (5-minute lifetime) for server-side verification, or `null` when there's none (not signed in, or the request failed — `tiun.isAuthenticated` tells you which). Fetch a fresh token per backend request; parallel calls each get their own from 0.12.0 (before, all but the last returned `null`). |

`tiun.setContent` accepts:

| Field | Type | Notes |
|---|---|---|
| `type` | `'active' \| 'inactive' \| 'paused'` | `'active'` meters; `'inactive'` pauses; `'paused'` temporary pause (ad break, user paused video). |
| `contentId` | `string` | Stable identifier (article slug, episode ID). Surfaces in dashboard analytics. |
| `mediaType` | `'text' \| 'audio' \| 'video'` | Defaults to `'text'`. Controls how engagement is interpreted (visibility/scroll vs. play state). |

## Products

Read the catalog and the current user's access. Needs `@tiun/sdk` **0.12.0** or later; React Native has the same four on `useTiun()` (`@tiun/react-native-sdk` **0.5.0**).

| Method | Returns | Notes |
|---|---|---|
| `tiun.listProducts()` | `Promise<Product[]>` | Products of this snippet. Works signed out. |
| `tiun.getProduct(productId)` | `Promise<ProductDetail>` | Localized pricing, e.g. `pricingLine: "CHF 240 /year"`. Works signed out. Unknown ID rejects with `http_404`. |
| `tiun.listProductAccess()` | `Promise<ProductAccess[]>` | The user's active access, with `referenceId`, `activatedAt`, `expiresAt`. `[]` when signed out. |
| `tiun.checkProductAccess(productId, { referenceId })` | `Promise<ProductAccessCheck>` | One product, or one purchase of a repeatable product (`referenceId` = the one passed to `checkout()`). `{ hasAccess: false, access: null }` when signed out, without access, or for an unknown ID. |

```javascript
const products = await tiun.listProducts();
const { pricingLine } = await tiun.getProduct('p-live-pro');
const access = await tiun.listProductAccess();
const { hasAccess } = await tiun.checkProductAccess('p-live-article', { referenceId: articleId });
```

- **Signed out is not an error.** The methods resolve normally; see the table.
- **Many items** (a list of articles): call `listProductAccess()` once and look items up in the result, instead of `checkProductAccess()` per item.
- **Called before ready**, they wait for the snippet. Parallel calls are fine; each gets its own answer.
- **Re-check on every `userChange`.** It fires with `event: 'checkout'` whenever access changes, including a repeatable purchase with a new reference ID. See [events.md](events.md).
- `user.productAccess` is still there and is enough for subscriptions and regular one-time products. Use these methods for repeatable products, or when you need dates or reference IDs.
- They work without a backend. If the integrator has a backend, or wants a more secure setup where content stays on the server until access is confirmed, add the server check in [server-verification.md](server-verification.md).

### Types

Exported from `@tiun/sdk`, `@tiun/types`, and `@tiun/react-native-sdk`.

```typescript
type ProductType = 'Subscription' | 'OneTime';
interface Product { productId: string; name: string; type: ProductType }
interface ProductDetail extends Product { pricingLine: string; explanationLine?: string | null }
interface ProductAccess {
  productId: string;
  referenceId?: string | null; // set for repeatable products
  type: ProductType;
  activatedAt: string;         // ISO 8601
  expiresAt?: string | null;   // null while a subscription is active and renewing;
                               // the end of the paid period once it's cancelled
}
interface ProductAccessCheck { hasAccess: boolean; access?: ProductAccess | null } // null when no access
interface ProductAccessOptions { referenceId?: string }
```

### Errors

Failures reject the Promise with `TiunError { code, message, details? }`. They do **not** fire the `error` event — wrap calls in `try` / `catch`.

| `code` | When |
|---|---|
| `http_<status>` | Backend error; `details` is its problem response. |
| `network_error` | The request didn't reach the backend. |
| `timeout` | No answer within 10 seconds. |
| `invalid_argument` | Empty `productId`. |
| `destroyed` | Web: `destroy()` while the call was waiting. React Native: the provider unmounted. |
| `ssr` | Web: called during server-side rendering. |
| `unknown_error` | Anything else. |

Log `code`, show `message`; don't build app logic on specific codes (Rule 16), apart from treating a rejection as "couldn't check".

## Properties

| Property | Type | Notes |
|---|---|---|
| `tiun.version` | string | SDK version. |
| `tiun.isInitialized` | boolean | `true` after `init()`. |
| `tiun.isReady` | boolean | `true` once the hosted snippet is loaded. From 0.12.0 it stays `true` after `destroy()`. |
| `tiun.isAuthenticated` | boolean | `true` when a valid session exists. |
| `tiun.user` | `TiunUser \| null` | Current user. |

Use properties for one-off reads. For UI that needs to stay in sync, listen to `userChange` instead — see [events.md](events.md).

## User object shape

```typescript
interface TiunUser {
  userId: string;             // stable identifier for the user in tiun
  email: string;              // email on the account
  hasNewsletterOptIn: boolean; // whether the user opted in to your newsletter; @tiun/sdk 0.11.0+
  productAccess: string[];    // product IDs the user currently has access to
}
```

Use `user.productAccess.includes(productId)` to gate a subscription tier or a non-repeatable one-time purchase (including limited access, whose ID leaves the array at the end date). A repeatable one-time product is checked per `referenceId` with `tiun.checkProductAccess()` or on the server — see [one-time.md](one-time.md). The prefix tells you the **environment**, not the product type: `p-live-...` for live, `p-test-...` for sandbox.
