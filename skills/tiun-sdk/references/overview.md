# tiun SDK: Overview

tiun is a commercial backend platform that provides authentication, payments, and products through a single JavaScript SDK, so product teams do not have to build a backend, payment UI, or session/entitlement layer themselves.

Upstream documentation: [docs.tiun.io](https://docs.tiun.io) (LLM-friendly bundle at [docs.tiun.io/llms-full.txt](https://docs.tiun.io/llms-full.txt)).

## What tiun provides

- **Authentication.** Email + one-time passcode (OTP). Returning subscribers can receive OTPs via SMS to a registered phone number. No passwords.
- **Subscription billing.** Recurring charges on a repeating interval, set as a count plus a unit — daily, weekly, monthly, or yearly, or any multiple of those ("every 3 months"). Optionally preceded by a trial. Suited for SaaS and memberships.
- **One-time purchases.** A single fixed fee, with no interval, trial, renewal, or cancellation. Access is permanent by default, and each customer buys the product once — lifetime access, a course, a report. **Limited access** ends that access after a set time. **Repeat purchases** charges the price again, once per `referenceId` (articles, bookings, tickets). See [one-time.md](one-time.md).
- **Time-based billing.** Per-session, anonymous metering — users pay for time spent with paid content (e.g. EUR 0.22 per minute) up to a configured monthly cap.
- **Access control / entitlements.** Delivered to the frontend and verifiable on the server.
- **Hosted UI overlays.** Checkout and login overlays are rendered by tiun, inside shadow DOM. The integrator calls SDK methods to open them and does not modify what is inside — see [Hosted UI is a black box](#hosted-ui-is-a-black-box).

## Supported platforms

The SDK is a single JavaScript library (`@tiun/sdk`) that works in:

- Vanilla JavaScript / plain HTML
- React (including Next.js)
- Vue 3 (including Nuxt with SSR)
- Any modern JS framework

Supported payment methods: credit/debit cards (Visa, Mastercard, American Express), PayPal, Apple Pay, Google Pay, and TWINT (region-dependent).

**Mobile / native.** In the dashboard, **Settings → Environment setup** has a **Web** section (one live domain) and an **App** section (one app scheme, for iOS/Android). The integrator turns on either or both, per environment.

There are two mobile routes:

- **React Native** has its own SDK, `@tiun/react-native-sdk` — a **different package with a different API surface**: a `<TiunProvider>` plus `useTiun()` / `useTiunEvent()` hooks rather than the `tiun` singleton, its own configuration (`host` instead of `sandbox`, a required `returnUrl`), and its own event payloads. It covers authentication, subscriptions, and one-time purchases — not time-based. See [react-native.md](react-native.md), and do **not** apply `@tiun/sdk` code (`tiun.init`, `tiun.on`, `sandbox: true`) to a React Native app.
- **Native shells hosting web content** (`WKWebView` / `Android WebView`) run the web SDK unchanged inside the WebView — see [frameworks.md](frameworks.md).

Swift, Kotlin, and Flutter SDKs remain on the upstream roadmap. If the user wants one of those, do not improvise: point them at support@tiun.io.

## Environments — live and sandbox

tiun runs **two fully independent parallel environments**. Each has its own snippet ID, products, product ID prefix (`p-live-...` vs `p-test-...`), API keys, webhook endpoints, customers, sessions, and analytics. Nothing syncs between them.

- **Live** — real customers, real payments, your live domain and/or app scheme (Settings → Environment setup). `localhost` is blocked.
- **Sandbox** — simulated payments, test customers, `localhost` enabled by default on any port.

You select an environment by setting (or omitting) `sandbox: true` in `tiun.init`. The SDK routes to the matching API host automatically. See [installation.md](installation.md) for the full setup. (React Native uses `host` instead — see [react-native.md](react-native.md#environments-host-not-sandbox).)

## The three modes

- **Subscriptions** — persistent user accounts (email + OTP). `user.productAccess[]` lists active subscriptions. Entry point: `tiun.checkout({ productId })`. See [subscriptions.md](subscriptions.md).
- **One-time purchases** — same accounts and same entry point as subscriptions, charged as a fixed fee. By default the product ID enters `user.productAccess[]` and stays there. Limited access removes it at the end date. Repeat purchases are checked per `referenceId`, in the browser with `tiun.checkProductAccess()` (0.12.0+) or on the server. See [one-time.md](one-time.md).
- **Time-based** — anonymous per-session billing, no account required. Entry point: `tiun.start()` + `paywallShow` / `paywallHide` events. See [time-based.md](time-based.md).

A single tiun account can offer any combination at once. `user.productAccess[]` mixes subscription and one-time entitlements freely — the array itself does not distinguish them, so gate on the specific product ID you care about.

## Hosted UI is a black box

Checkout, login, and the time-based connect overlay are rendered by tiun inside shadow DOM. They ship as-is: the integrator opens them and does not touch what is inside.

**Never:**

- Pierce `shadowRoot` — no `querySelector`, `appendChild`, `innerHTML`, or `MutationObserver` against the overlay's internals.
- Inject content into it: help text under the email field, hints, tooltips, badges, trust seals, banners, extra buttons.
- Style it: host selectors, `::part()`, `::slotted()`, global `!important` overrides, or any rule written to reach inside.
- Reposition, resize, wrap, or cover it with your own chrome.
- Read data out of it, such as scraping the value of its email input.

This is a hard line, not a preference. The overlay's internal structure is unversioned and changes without notice, so an injection that works today breaks silently on the next snippet release — and it breaks *inside a live payment flow*, where the failure mode is a customer who cannot pay.

**The supported surfaces are** `init()` config (`language`, `tone`, `appearance`), `tiun.setAppearance()`, and dashboard settings:

| Want to change | Where |
|---|---|
| Overlay language | `tiun.init({ language })` — `'en' \| 'de' \| 'fr'` |
| Copy style (formal / informal) | `tiun.init({ tone })` |
| Color theme | `appearance: 'light' \| 'dark' \| 'auto'` (default `'light'`) on `tiun.init` (web `@tiun/sdk` 0.10.0) or React Native `TiunProvider` (`@tiun/react-native-sdk` 0.3.0). On the web SDK, `tiun.setAppearance(appearance)` switches the theme without a reload and is safe before ready. |
| Product names, prices, intervals, fees | tiun dashboard (`my.tiun.business`) |
| Colors | Colors are set in the dashboard at the moment. |
| Anything else — branding, custom fields, extra copy inside the overlay | Dashboard settings. Ask support@tiun.io whether the dashboard exposes it. |

**If a customer wants extra explanation around payment**, it belongs on their own page, next to the button that opens the overlay — before it opens. That surface is fully theirs and never breaks.

## Core mental model

1. **Init once** with `tiun.init({ snippetId })` early in app startup. `init` is idempotent.
2. **Wait for ready** before relying on snippet state (`tiun.waitForReady()` or the `ready` event). Methods like `checkout` / `login` / `start` queue internally.
3. **Subscribe to events** (`userChange`, `paywallShow` / `paywallHide`, `login`, `logout`, `error`) to drive UI state.
4. **Open hosted overlays** (`checkout`, `login`, `start`); do not build your own payment UI, and do not modify tiun's — see [Hosted UI is a black box](#hosted-ui-is-a-black-box).
5. **Verify on the server** when access must be trusted — see [server-verification.md](server-verification.md). Webhooks keep your own systems in sync and are not a substitute for that check — see [webhooks.md](webhooks.md).

## Dashboard

Product configuration, analytics, snippet IDs, and API keys live at `my.tiun.business`. The dashboard has a Sandbox toggle in the sidebar that switches which environment you're viewing/editing; the first click enables sandbox (no setup required). Where tiun may run — the live domain and/or app scheme — is configured per environment in **Settings → Environment setup**.

## Products are configured in the dashboard and read at runtime

Products (subscription, one-time, and time-based alike) are **created and managed in the tiun dashboard**. Each product has a stable `productId` string (`p-live-...` for live, `p-test-...` for sandbox) that the integrator passes to calls like `tiun.checkout({ productId: 'p-live-pro' })`.

From `@tiun/sdk` 0.12.0 (`@tiun/react-native-sdk` 0.5.0), the SDK can read the catalog and the user's access at runtime:

- `tiun.listProducts()` — the products on this snippet (`productId`, `name`, `type`). Works signed out.
- `tiun.getProduct(productId)` — one product with a localized `pricingLine` (e.g. `"CHF 240 /year"`), so a pricing page doesn't hardcode prices.
- `tiun.listProductAccess()` / `tiun.checkProductAccess(productId, { referenceId })` — what the current user has access to, with `referenceId`, `activatedAt`, and `expiresAt`.

Backends can read the same data with the server-to-server Product and Product Access APIs. See [api-reference.md](api-reference.md#products).

- The SDK cannot create or edit products. That happens in the dashboard (or through the MCP during setup).
- **Do not invent** other method names, such as `tiun.getProducts()`, or REST endpoints that aren't in the docs.

The tiun MCP server also exposes providers and products to the agent during setup (see [mcp.md](mcp.md)). That's an integration-time read of the dashboard, separate from the SDK methods above.
