# Server-Side Verification

Trust nothing the client sends about its own entitlements. When access must be trusted (paid API endpoints, protected downloads, etc.), verify on the server.

## JWT pattern

1. On the frontend, call:

   ```javascript
   const token = await tiun.getUserVerificationToken();
   ```

2. Send the token to your backend.
3. On the backend, exchange the token for a verification result by POSTing to the tiun **UserVerification** endpoint:

   ```
   POST https://api.tiun.live/live_api/s2s/v1/users/verification
   X-ACCESS-TOKEN: <your s2s access token from the dashboard>
   Content-Type: application/json

   { "userVerificationToken": "<token from the frontend>" }
   ```

   Response (200):

   ```json
   {
     "isAuthenticated": true,
     "userInfo": {
       "userId": "...",
       "email": "...",
       "productAccess": ["p-live-pro"]
     }
   }
   ```

   On 401, treat the request as unauthenticated. Full schema: https://api.tiun.live/live_api/swagger/tiun_live_public/swagger.json.

4. Authorize the request based on `userInfo.productAccess`, not on anything else the client sent.

The token is short-lived. Don't cache verification results past its lifetime; the frontend can re-fetch via `getUserVerificationToken()` whenever you need a fresh one. The `X-ACCESS-TOKEN` is a server secret. Never expose it to the browser.

## Do / Don't

- **Do** treat the client as untrusted. `user.productAccess` on the client is fine for UI, never for authorization.
- **Do** fail closed. Reject requests when the token or session cannot be validated.
- **Don't** cache verification results beyond the token's/session's lifetime.
- **Don't** expose the snippet ID as a secret. It is public and identifies the environment, not the user.
