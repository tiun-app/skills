# Subscriptions

Use subscriptions when you need persistent user accounts and recurring revenue (SaaS, memberships).

## Flow

1. Create subscription products in the dashboard. Each has a `productId` (e.g. `p-live-pro`).
2. `tiun.init({ snippetId })` on app start.
3. On the pricing page, bind checkout:

   ```javascript
   tiun.checkout({ productId: 'p-live-pro' });
   ```

   This opens the hosted checkout overlay. After success, tiun fires `login` (if the user was new) and `userChange`.

4. Subscribe to `userChange` to drive the UI:

   ```javascript
   tiun.on('userChange', ({ isAuthenticated, user }) => {
     if (!isAuthenticated) return showSignedOutUI();
     const hasPro = user.productAccess.includes('p-live-pro');
     hasPro ? showProUI() : showFreeUI();
   });
   ```

5. For returning users: call `tiun.login()` to open the login overlay. OTP is sent to their registered email (and SMS if configured).

## Gating rules

- **UI-level gating**: `user.productAccess.includes(productId)` is sufficient for showing/hiding UI.
- **Trusted access (paid API, protected downloads, etc.)**: do server-side verification (see [server-verification.md](server-verification.md)). Never trust `productAccess` alone for anything a user could bypass by editing their own client.

## Common mistakes

- **Calling `checkout()` before `ready`.** Wrap in `await tiun.waitForReady()` or do it inside the `ready` event.
- **Reading `tiun.user` once at mount.** Entitlements can change mid-session (upgrade, downgrade, renewal). Use `userChange` as the source of truth, not a one-shot read.
- **Building custom payment forms.** The checkout overlay is hosted by tiun; do not reimplement card collection.
