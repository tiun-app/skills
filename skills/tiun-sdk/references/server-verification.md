# Server-Side Verification

Trust nothing the client sends about its own entitlements. When access must be trusted (paid API endpoints, protected downloads, premium content payloads), verify on the server.

There are three server-side flows:

- **User verification** — identity plus entitlements. JWT-based. Use for authenticated-only endpoints, subscriptions, and one-time purchases. Subscriptions and non-repeatable one-time products (including **limited access**) are a `user.productAccess` check. A limited-access one-time product ID leaves the array when the purchase reaches its end date. **Repeatable** one-time products are checked per reference ID after verification — see [Repeatable product access](#repeatable-product-access).
- **Session verification** — time-based billing sessions. Session-ID-based. Use to confirm an active time-based session before serving premium content.
- **User info lookup** — read a known user's current state by `userId`, with no session and no token. A read, **not** an authentication check. See [User info lookup](#user-info-lookup-read-a-known-users-state).

All three use the same API keys (dashboard: **API & Webhook → API Keys → Create new key**) and the same per-environment base URLs. Webhooks, which are separate from these calls, are in [webhooks.md](webhooks.md).

## Base URLs and API keys

| Environment | Base URL                       |
|---|---|
| Live        | `https://api.tiun.live`        |
| Sandbox     | `https://api-sandbox.tiun.live`|

API keys are environment-specific — sandbox keys do not work against live and vice versa. Use the base URL and key matching the SDK's `sandbox` flag (`sandbox: true` → sandbox URL + sandbox key). The `X-TIUN-API-KEY` value is a server secret; never expose it to the browser.

## User verification (auth + `productAccess` entitlements)

JWTs returned by `tiun.getUserVerificationToken()` are valid for **5 minutes**. Do not cache verification results past the token's lifetime; the frontend can fetch a fresh token whenever you need one.

### Flow

1. On the frontend, fetch a verification token:

   ```javascript
   const token = await tiun.getUserVerificationToken();
   ```

2. Send the token to your backend. The transport between your frontend and your backend is up to you — `Authorization: Bearer <token>` is a fine convention.
3. On the backend, exchange the token with the tiun **UserVerification** endpoint:

   ```
   POST {BASE_URL}/live_api/s2s/v2/users/verification
   X-TIUN-API-KEY: <your API key from the dashboard>
   Content-Type: application/json

   { "userVerificationToken": "<token from the frontend>" }
   ```

   Response codes:

   | Status | Meaning |
   |---|---|
   | `200`  | User object returned — read the body. |
   | `401`  | The API key is invalid. |

   `200` response body. `user` is `null` when `isAuthenticated` is `false`:

   ```json
   {
     "isAuthenticated": true,
     "user": {
       "userId": "u-...",
       "email": "user@example.com",
       "hasNewsletterOptIn": false,
       "productAccess": ["p-live-pro"]
     }
   }
   ```

   `hasNewsletterOptIn` is present on `@tiun/sdk` 0.11.0+ and `@tiun/react-native-sdk` 0.4.0+ user objects as well. The verification response uses the field name `user`. Do not read `userInfo`.

4. Authorize the request based on `isAuthenticated` and `user.productAccess`, not on anything else the client sent. A `200` with `isAuthenticated: false` means the API key was accepted but the underlying user session is no longer active — treat as unauthenticated. For a repeatable one-time product, `productAccess` is not the entitlement check — continue with [Repeatable product access](#repeatable-product-access).

### Multiple plans

If you offer tiers, check from the highest applicable tier down:

```javascript
// `user` is the `user` object from the v2 verification response
const hasPro   = user?.productAccess?.includes('p-live-pro');
const hasLight = user?.productAccess?.includes('p-live-light');

if (hasPro) {
  // serve full Pro content
} else if (hasLight) {
  // serve Light content
} else {
  // no qualifying subscription → reject (prompt upgrade)
}
```

## User info lookup (read a known user's state)

Reads the current state of a user you already have a `userId` for. No session, no token, no expiry.

```
GET {BASE_URL}/live_api/s2s/v1/users/{userId}/info
X-TIUN-API-KEY: <your API key from the dashboard>
```

Response codes:

| Status | Meaning |
|---|---|
| `200`  | User object returned — read the body. |
| `400`  | Invalid request. |
| `401`  | The API key is invalid. |
| `404`  | No such user. |

`200` response body:

```json
{
  "userId": "u-...",
  "email": "user@example.com",
  "hasNewsletterOptIn": false,
  "productAccess": ["p-live-pro"]
}
```

### This is not an authentication substitute

It is the easier call, so it is the one an agent reaches for by mistake. The difference decides which you need:

| | Answers | Requires |
|---|---|---|
| **User verification** (JWT) | "Is the caller of *this request* that user, right now?" | A live session — the frontend fetches a fresh token |
| **User info lookup** | "What does user `X` currently have?" | Only a `userId` you already trust |

Authorizing a request with this endpoint means trusting a `userId` the caller supplied — anyone who knows or guesses another user's ID gets their entitlements. **Never authorize an incoming request with it.** Use it for work that happens outside a user session and already knows whose data it is: refreshing entitlements in your own database, a nightly reconciliation job, an admin or support screen, enriching a record after the JWT flow already established identity. Webhook handlers use this lookup when `payload.reference` is `null` — see [webhooks.md](webhooks.md).

## Repeatable product access

A repeatable one-time product is identity verification plus a per-reference check. `user.productAccess` lists product IDs and does not say which `referenceId` was bought.

After `POST /live_api/s2s/v2/users/verification` returns `isAuthenticated: true`, call:

```
GET {BASE_URL}/live_api/s2s/v1/users/{userId}/product_access/{productId}?referenceId={referenceId}
X-TIUN-API-KEY: <your API key from the dashboard>
```

`userId` comes from `user.userId`. `referenceId` is the value your app passed to `checkout`. Use the base URL and API key of the same environment as the frontend.

| Status | Meaning |
|---|---|
| `200` | Access result — read the body. |
| `400` | The request is invalid. |
| `401` | The API key is invalid. |
| `404` | The user or product does not exist. |

`200` when the user has that purchase:

```json
{
  "hasAccess": true,
  "access": {
    "productId": "p-live-article",
    "referenceId": "article-1042",
    "type": "OneTime",
    "activatedAt": "2026-11-02T09:21:58Z",
    "expiresAt": null
  }
}
```

`expiresAt` is `null` unless the product has **limited access**. Without access, `hasAccess` is `false` and there is no `access` object. Serve the item only when `hasAccess` is `true`.

To list every product and reference pair for a user:

```
GET {BASE_URL}/live_api/s2s/v1/users/{userId}/product_access
X-TIUN-API-KEY: <your API key from the dashboard>
```

`200` body: `{ "data": [ /* the same access objects */ ] }`.

The frontend SDK cannot check a reference ID. Do not invent a client method for it.

## Session verification (time-based)

When `paywallHide` fires, its payload includes a `sessionId`. Send it to your backend on protected requests, and call the **Session** endpoint to confirm the session is still valid before serving premium content.

```
PATCH {BASE_URL}/live_api/s2s/v1/sessions/{sessionId}/status
X-TIUN-API-KEY: <your API key>
```

Response codes:

| Status | Meaning |
|---|---|
| `200`  | Session is valid — serve the content. |
| `404`  | Session is invalid, expired, or the user is out of funds. Deny. |
| `401`  | API key is invalid. |

Backend sketch:

```javascript
app.get('/api/premium-content', async (req, res) => {
  const sessionId = req.headers['x-session-id'];
  if (!sessionId) return; // missing → deny

  const upstream = await fetch(
    `${BASE_URL}/live_api/s2s/v1/sessions/${sessionId}/status`,
    {
      method: 'PATCH',
      headers: { 'X-TIUN-API-KEY': API_KEY },
    },
  );

  if (upstream.status === 200) {
    // valid → serve the premium content
  } else {
    // 404 / 401 / upstream error → deny (fail closed)
  }
});
```

## Do / Don't

- **Do** treat the client as untrusted. `user.productAccess` and `paywallHide` on the client are fine for UI, never for authorization.
- **Do** fail closed. Reject when the token or session cannot be validated.
- **Do** keep environments consistent: SDK `sandbox: true` → sandbox base URL + sandbox API key. Mixing produces silent 401s.
- **Don't** cache verification results past the JWT's 5-minute lifetime, or past a session's `Active` window.
- **Don't** authorize an incoming request with the user-info lookup. It trusts a `userId` the caller handed you, which is not authentication — use the JWT flow.
- **Don't** expose the snippet ID or the `X-TIUN-API-KEY` as the same secret. The snippet ID is public and identifies an environment; the API key is a server secret.

Full upstream API schema: [api.tiun.live/live_api/swagger/tiun_live_public/swagger.json](https://api.tiun.live/live_api/swagger/tiun_live_public/swagger.json).
