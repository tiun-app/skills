# tiun SDK: Overview

tiun is a commercial backend platform that provides authentication, payments, and products through a single JavaScript SDK, so product teams do not have to build a backend, payment UI, or session/entitlement layer themselves.

Upstream documentation: [docs.tiun.io](https://docs.tiun.io) (LLM-friendly bundle at [docs.tiun.io/llms-full.txt](https://docs.tiun.io/llms-full.txt)).

## What tiun provides

- **Authentication.** Email + one-time passcode (OTP). Returning subscribers can receive OTPs via SMS to a registered phone number. No passwords.
- **Subscription billing.** Recurring charges on fixed schedules (monthly, quarterly, yearly). Suited for SaaS and memberships.
- **Time-based billing.** Per-session, anonymous metering — users pay for time spent with paid content (e.g. EUR 0.22 per minute) up to a configured monthly cap.
- **Access control / entitlements.** Delivered to the frontend and verifiable on the server.
- **Hosted UI overlays.** Checkout and login overlays are rendered by tiun; the integrator calls SDK methods to open them.

## Supported platforms

The SDK is a single JavaScript library (`@tiun/sdk`) that works in:

- Vanilla JavaScript / plain HTML
- React (including Next.js)
- Vue 3 (including Nuxt with SSR)
- Any modern JS framework

Supported payment methods: credit/debit cards, PayPal, Apple Pay, Google Pay, PrePaid (tiun credits), Twint (region-dependent).

**Mobile / native.** Today, mobile apps integrate by loading the web SDK inside a WebView (`WKWebView` / `Android WebView`) — see [frameworks.md](frameworks.md). First-class native SDKs (Swift, Kotlin, React Native, Flutter) are on the upstream roadmap.

## Environments — live and sandbox

tiun runs **two fully independent parallel environments**. Each has its own snippet ID, products, product ID prefix (`p-live-...` vs `p-test-...`), API keys, customers, sessions, and analytics. Nothing syncs between them.

- **Live** — real customers, real payments, your production domain. `localhost` is blocked.
- **Sandbox** — simulated payments, test customers, `localhost` enabled by default on any port.

You select an environment by setting (or omitting) `sandbox: true` in `tiun.init`. The SDK routes to the matching API host automatically. See [installation.md](installation.md) for the full setup.

## Subscriptions vs time-based

- **Subscriptions** — persistent user accounts (email + OTP). `user.productAccess[]` lists active subscriptions. Entry point: `tiun.checkout({ productId })`. See [subscriptions.md](subscriptions.md).
- **Time-based** — anonymous per-session billing, no account required. Entry point: `tiun.start()` + `paywallShow` / `paywallHide` events. See [time-based.md](time-based.md).

A single tiun account can offer both at once.

## Core mental model

1. **Init once** with `tiun.init({ snippetId })` early in app startup. `init` is idempotent.
2. **Wait for ready** before relying on snippet state (`tiun.waitForReady()` or the `ready` event). Methods like `checkout` / `login` / `start` queue internally.
3. **Subscribe to events** (`userChange`, `paywallShow` / `paywallHide`, `login`, `logout`, `error`) to drive UI state.
4. **Open hosted overlays** (`checkout`, `login`, `start`); do not build your own payment UI.
5. **Verify on the server** when access must be trusted — see [server-verification.md](server-verification.md).

## Dashboard

Product configuration, analytics, snippet IDs, and API keys live at `my.tiun.business`. The dashboard has a Sandbox toggle in the sidebar that switches which environment you're viewing/editing.

## Products are configured in the dashboard. There is no runtime product-list API.

Products (both subscription and time-based) are **created and managed in the tiun dashboard**. Each product has a stable `productId` string (`p-live-...` for live, `p-test-...` for sandbox) that the integrator hardcodes into calls like `tiun.checkout({ productId: 'p-live-pro' })`.

The SDK does **not** expose a method to list or fetch products at runtime. If an agent is asked "how do I get a product list?":

- Tell the user to manage products in the tiun dashboard, then hardcode the relevant `productId`s in the pricing page.
- If a dynamic catalog is needed (e.g. an admin-managed list), the user must maintain it in their own backend or CMS and pass the selected `productId` to the SDK.
- **Do not invent** methods like `tiun.getProducts()`, `tiun.listProducts()`, or a `https://api.tiun.io/products` REST endpoint. None of these exist.

The tiun MCP server *does* expose providers and products to the agent during setup (see [mcp.md](mcp.md)), but that is an integration-time read of the dashboard, not a runtime SDK feature.
