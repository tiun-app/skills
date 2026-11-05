# Webhooks

tiun POSTs to your backend when a user is created, withdraws consent, or gains or loses product access, including while they are not in your app. Use webhooks to keep your own systems in sync. Gate the app with `userChange` and [server-verification.md](server-verification.md), not with the webhook body.

Upstream: [Receive webhooks](https://docs.tiun.io/guides/webhooks/receive-webhooks), [Events](https://docs.tiun.io/reference/webhooks/events), [Delivery](https://docs.tiun.io/reference/webhooks/delivery).

## Setup

Dashboard: add an endpoint under **API & Webhook → Webhooks** — an `https://` URL and the events it receives. More than one endpoint is allowed; each receives only the events picked for it. An endpoint's URL and events can be changed later, and it can be paused to stop deliveries for a while. Events that happen while an endpoint is paused are not delivered later.

Sandbox and live each have their own endpoints. Add both when you ship both environments.

Confirming an event uses an API key from **API & Webhook → API Keys** and the base URL of the same environment:

| Environment | Base URL |
|---|---|
| Live | `https://api.tiun.live` |
| Sandbox | `https://api-sandbox.tiun.live` |

## Event envelope

One event is one `POST` with a JSON body. There is no signature.

```json
{
  "id": "b0c22a9741be458fa36e742d3d3bb0e8",
  "type": "product_access.add",
  "version": 1,
  "occurred_at": "2026-10-30T14:45:50.6090416+00:00",
  "payload": {
    "user_id": "user-sample-0001",
    "product_id": "product-sample-0001",
    "reference": null
  }
}
```

| Field | Meaning |
|---|---|
| `id` | Stable across retries and dashboard resends. Store handled IDs and skip repeats. |
| `type` | One of the four types below. |
| `version` | Event format version. Currently always `1`. |
| `occurred_at` | When it happened, ISO 8601 UTC. |
| `payload` | IDs only. Shape depends on `type`. |

IDs belong to the endpoint's environment.

## Event types

| `type` | When it is sent | `payload` |
|---|---|---|
| `user.create` | A new tiun user is created (usually first sign-in or checkout). | `user_id` |
| `user.revoke_consent` | The user withdraws consent to your terms. | `user_id` |
| `product_access.add` | The user gains access: a completed one-time purchase, each purchase of a repeatable product, or a subscription start. Subscription renewals do not send it again. | `user_id`, `product_id`, `reference` |
| `product_access.remove` | The user loses access: a subscription ended after cancellation or a permanent payment failure, or a one-time product with limited access reached its end date. | `user_id`, `product_id`, `reference` |

`reference` is the `referenceId` passed to checkout for a repeatable product. It is `null` for every other product.

## What the handler does

1. Reply with any `2xx` within 15 seconds, then do the slow work. A `4xx`, a `5xx`, a timeout, or a connection failure is retried.
2. Skip an `id` you have already handled.
3. Read current state from tiun and act on that response.

| Payload | Confirm with |
|---|---|
| `reference` is `null` | `GET /live_api/s2s/v1/users/{userId}/info` — use `email`, `hasNewsletterOptIn`, and `productAccess` |
| `reference` is set | `GET /live_api/s2s/v1/users/{userId}/product_access/{productId}?referenceId={reference}` |
| `user.revoke_consent` | Remove or anonymize data you hold for that `user_id`. Delete only users already in your database. |

A `404` from those calls means there is nothing to sync. Test events use sample IDs such as `user-sample-0001`.

Do not grant access, revoke access, or change stored data from the webhook body alone. Re-reading current state makes delivery order irrelevant.

## Delivery

| Your response | Result |
|---|---|
| Any `2xx` within 15 seconds | **Delivered.** No further attempts. |
| `4xx` or `5xx` | **Failed attempt.** Retried. |
| No response within 15 seconds | **Timeout.** Retried. |
| DNS, TLS, or network error | **Failed attempt.** Retried. |

A delivery gets up to **10 attempts** (the first, then retries) spread over about **48 hours**. If none returns `2xx`, the delivery is **Failed** and tiun stops. Dashboard statuses: **Scheduled**, **Retrying**, **Succeeded**, **Failed**, **Cancelled**.

Resending a delivery from the dashboard sends that same event again, with the same `id`. A test event, sent from the endpoint in the dashboard, is a sample payload for checking the handler without a real purchase. You cannot send a test event to a paused endpoint.

Do not invent event types, signature headers, or payload fields.
