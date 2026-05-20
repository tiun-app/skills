# tiun SDK: Overview

tiun is a commercial backend platform that provides authentication, payments, and products through a single JavaScript SDK, so product teams do not have to build a backend, payment UI, or session/entitlement layer themselves.

Upstream documentation: https://docs.tiun.io (full LLM-friendly dump at https://docs.tiun.io/llms-full.txt).

## What tiun provides

- **Authentication.** Email + one-time passcode (OTP). Returning subscribers can receive OTPs via SMS to a registered phone number. No passwords.
- **Subscription billing.** Recurring charges on fixed schedules (monthly, quarterly, yearly). Suited for SaaS and memberships.
- **Access control / entitlements.** Delivered to the frontend and verifiable on the server.
- **Hosted UI overlays.** Checkout and login overlays are rendered by tiun; the integrator calls SDK methods to open them.

## Supported platforms

The SDK is a single JavaScript library (`@tiun/sdk`) that works in:

- Vanilla JavaScript / plain HTML
- React (including Next.js)
- Vue 3 (including Nuxt with SSR)
- Any modern JS framework

Supported payment methods: credit/debit cards, PayPal, Apple Pay, Google Pay, PrePaid (tiun credits), Twint (region-dependent).

## Subscriptions

- **User identity.** Email + OTP, persistent sessions.
- **Access check.** `user.productAccess` includes the product ID.
- **Entry point.** `tiun.checkout({ productId })`.
- **Typical use.** SaaS, memberships.

## Core mental model

1. **Init once** with `tiun.init({ snippetId })` early in app startup.
2. **Wait for ready** before calling methods (`tiun.waitForReady()` or the `ready` event).
3. **Subscribe to events** (`userChange`, `login`, `logout`, `error`) to drive UI state.
4. **Open hosted overlays** (`checkout`, `login`); do not build your own payment UI.
5. **Verify on the server** when access must be trusted, via `getUserVerificationToken()`.

## Dashboard

Product configuration, analytics, and the snippet ID live at `my.tiun.business`. The `snippetId` passed to `init()` is the environment-specific identifier issued by the dashboard.

## Products are configured in the dashboard. There is no runtime product-list API.

Subscription products are **created and managed in the tiun dashboard** at `my.tiun.business`. Each product has a stable `productId` string that the integrator hardcodes into calls like `tiun.checkout({ productId: 'p-live-pro' })`.

The SDK does **not** expose a method to list or fetch products at runtime. If an agent is asked "how do I get a product list?":

- Tell the user to manage products in the tiun dashboard, then hardcode the relevant `productId`s in the pricing page.
- If a dynamic catalog is needed (e.g. an admin-managed list), the user must maintain it in their own backend or CMS and pass the selected `productId` to the SDK.
- **Do not invent** methods like `tiun.getProducts()`, `tiun.listProducts()`, or a `https://api.tiun.io/products` REST endpoint. None of these exist.
