# React Native

tiun's React Native SDK is `@tiun/react-native-sdk`. It is a **separate package with a separate API** from the web SDK — a `<TiunProvider>` plus the `useTiun()` / `useTiunEvent()` hooks, not the `tiun` singleton. It does not wrap or depend on `@tiun/sdk`; a React Native app never installs the web SDK, and nothing written for `tiun.init()` / `tiun.on()` applies here.

Upstream guide: "Monetize in React Native" on [docs.tiun.io](https://docs.tiun.io). Stay faithful to it (Rule 11 in `SKILL.md`).

## What it covers

- **Authentication** — `login()` / `logout()`, session restored at launch.
- **Checkout** — **subscriptions and one-time purchases** via `checkout({ productId })`.
- **Not time-based.** There is no `start()`, `paywallShow`, or `paywallHide` in React Native. If the user wants time-based billing in a React Native app, say so plainly and point them at support@tiun.io — do not improvise a WebView workaround.

The SDK renders the tiun snippet inside a `WebView`, bridges login and checkout to native, and binds the user's session to a hardware-backed device key (Secure Enclave / Android Keystore). The session survives restarts without the app storing anything.

## The one rule that breaks most integrations: the return scheme

After payment, the in-app browser returns to the app through a deep link the integrator chooses, e.g. `myapp://tiun/return`. **The same scheme must appear in three places**, or checkout can never complete:

| Where | Value (example) |
|---|---|
| Dashboard → **Settings → Environment setup → App → App scheme**, in the environment the app targets | `myapp://` |
| Native registration — iOS `Info.plist` `CFBundleURLSchemes`, Android intent-filter `android:scheme` | `myapp` |
| SDK config `returnUrl` | `myapp://tiun/return` |

Only the **scheme** has to match the dashboard. The host and path after it are the integrator's choice — but the Android intent filter's `host` / `pathPrefix` must match the `returnUrl` they pass.

Before writing config, **ask for the app's existing URL scheme** (check `Info.plist` / `AndroidManifest.xml` first — many apps already register one). Do not invent a scheme; reuse the app's own and remind the user to enter it in the dashboard. The dashboard holds **one** app scheme per environment; additional schemes are managed by tiun via support@tiun.io.

## Install

```bash
npm install @tiun/react-native-sdk react-native-webview \
  react-native-secure-sign react-native-keychain \
  react-native-inappbrowser-nitro react-native-nitro-modules
```

```bash
cd ios && bundle exec pod install
```

All five dependencies are **peer dependencies** with no JavaScript fallback — a missing one fails at bundle time. Use the project's package manager (`pnpm add` / `yarn add`) if it isn't npm.

| Package | Role |
|---|---|
| `react-native-webview` | Hosts the tiun snippet. Verified against **13.x** — pin it there unless there's a reason not to. |
| `react-native-secure-sign` | Hardware-backed device key. |
| `react-native-keychain` | Stores the session token in Keychain / Keystore. |
| `react-native-inappbrowser-nitro` | Opens the payment redirect in the in-app browser. |
| `react-native-nitro-modules` | Runtime required by the in-app browser. |

These are native modules: after installing, the app must be **rebuilt and reinstalled**. A JS reload is not enough — tell the user.

> Expo is not covered by the upstream docs. These native modules cannot run in Expo Go; if the project uses Expo, say that a native (dev/prebuild) build is required and that the setup isn't documented upstream — don't improvise config plugins.

## Register the return deep link

### iOS

`ios/<YourApp>/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>tiun.checkout.return</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

Then forward incoming links to React Native's `Linking` module in `ios/<YourApp>/AppDelegate.swift` — **`Info.plist` alone is not enough**; without this, the link reaches the app and stops there, and checkout never resolves:

```swift
func application(
  _ application: UIApplication,
  open url: URL,
  options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
  return RCTLinkingManager.application(application, open: url, options: options)
}
```

If the app already has this method (deep linking for its own routes), keep it — don't add a second one.

### Android

`android/app/src/main/AndroidManifest.xml`, on the main activity:

```xml
<activity
  android:name=".MainActivity"
  android:launchMode="singleTask"
  android:exported="true">

  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" android:host="tiun" android:pathPrefix="/return" />
  </intent-filter>
</activity>
```

**`android:launchMode="singleTask"` is required.** Without it, returning from payment starts a second activity instance instead of delivering the link to the running app. Add the intent filter alongside the existing `MAIN` / `LAUNCHER` filter; don't replace it.

## Configure the provider

Keep config and product IDs in one module, as a **module-level constant** (not built inline per render):

```tsx
// tiun.ts
import type { TiunConfig } from '@tiun/react-native-sdk';

export const TIUN_CONFIG: TiunConfig = {
  snippetId: 'YOUR_SANDBOX_SNIPPET_ID',
  host: 'https://api-sandbox.tiun.live',
  returnUrl: 'myapp://tiun/return',
  language: 'en',
  debug: true,
};

export const TIUN_PRODUCTS = {
  light: 'p-test-light',
  pro: 'p-test-pro',
} as const;
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `snippetId` | `string` | — | **Required.** From the dashboard, same environment as `host`. |
| `returnUrl` | `string` | — | **Required.** Scheme must match native registration and the dashboard App scheme. |
| `host` | `string` | `https://api.tiun.live` | Environment origin, no trailing slash. `https://api-sandbox.tiun.live` for sandbox. |
| `language` | `string` | `'en'` | `'en' \| 'de' \| 'fr'` only. |
| `debug` | `boolean` | `false` | Logs native bridge traffic, prefixed `[tiun]`. Turn off for release. |

Wrap the app root. The one placement rule: the provider sits **above every component that uses the hooks** (they throw otherwise). The overlay sizes itself to the window, and the provider takes no space until login or checkout opens.

```tsx
import { TiunProvider } from '@tiun/react-native-sdk';
import { TIUN_CONFIG } from './tiun';

export default function App() {
  return (
    <TiunProvider config={TIUN_CONFIG}>
      <RootNavigator />
    </TiunProvider>
  );
}
```

## Environments: `host`, not `sandbox`

**The React Native SDK has no `sandbox` flag.** The environment is selected by `host`:

| Environment | `host` | IDs |
|---|---|---|
| Live | omit (defaults to `https://api.tiun.live`) | live snippet ID, `p-live-…` |
| Sandbox | `https://api-sandbox.tiun.live` | sandbox snippet ID, `p-test-…` |

Switch `host`, snippet ID, and product IDs **together** — IDs never cross environments. Do not generate `sandbox: true` in a React Native config. Live and sandbox each have their own Environment setup in the dashboard, so the app scheme must be registered in whichever environment `host` points at.

## Hooks

`useTiun()` returns state and actions; it re-renders when the user changes.

| State | Type | Notes |
|---|---|---|
| `isAuthenticated` | `boolean` | |
| `user` | `TiunUser \| null` | `{ userId, email, productAccess: string[] }` |
| `ready` | `boolean` | Snippet initialized. |
| `cryptoOk` | `boolean \| null` | `false` ⇒ authentication cannot work on this device. |

| Action | Returns |
|---|---|
| `login()` | `void` |
| `logout()` | `void` — clears session and device credentials |
| `checkout({ productId })` | `void` |
| `getUserVerificationToken()` | `Promise<string \| null>` — 5-minute JWT; `null` if signed out or no answer within 5s |

`login`, `logout`, and `checkout` are **queued until ready** — wire them straight to buttons. Do not wrap them in `ready` guards; use `ready` only for a loading state.

`useTiunEvent(event, handler)` subscribes and unsubscribes on unmount automatically; the latest handler is always used, so don't memoize it.

| Event | Payload |
|---|---|
| `ready` | — |
| `userChange` | `{ isAuthenticated, user }` — **no `event` field** |
| `login` | `{ user }` |
| `logout` | — |
| `error` | `{ code?, message?, details? }` |

**`userChange` has no `event` field in React Native.** When porting web code, replace `data.event === 'login'` / `'logout'` checks with the separate `login` and `logout` events. There is no `'checkout'` discriminator — treat `userChange` as "re-read `user`". It also fires on the session restore at launch.

Prefer reading `user` from `useTiun()` for rendering; use `useTiunEvent('userChange', …)` only to *react* (refetch, reset a screen, mirror into a store).

## Gating

`user.productAccess` is the source of truth. Derive the tier in one place:

```tsx
import { useTiun } from '@tiun/react-native-sdk';
import { TIUN_PRODUCTS } from './tiun';

type Tier = 'free' | 'light' | 'pro';

export function useTier(): Tier {
  const { user } = useTiun();
  const access = user?.productAccess ?? [];

  if (access.includes(TIUN_PRODUCTS.pro)) return 'pro';
  if (access.includes(TIUN_PRODUCTS.light)) return 'light';
  return 'free';
}
```

The web skill's mode rules still hold: purchases open `checkout({ productId })`, account entry opens `login()` (Rule 19); one-time product IDs are permanent in `productAccess` (Rule 13); never infer mode from inventory (Rule 12). The hosted overlay is a black box here too (Rule 5) — don't inject into or restyle the WebView content.

## Server verification

Same backend as the web SDK: get `getUserVerificationToken()`, send it as a bearer token, verify server-side with the matching environment's base URL and API key. See [server-verification.md](server-verification.md).

## Device testing

- **iOS Simulator cannot do login or checkout** — no Secure Enclave. A physical iPhone is required. Android emulators work.
- On iOS, checkout shows a one-time system prompt (*"…wants to use…to sign in"*) — expected, not an error.
- `debug: true` shows `[tiun]` logs in the Xcode / Android console.
- If code changes seem to have no effect on a physical iPhone, Metro probably can't reach it (office/guest Wi-Fi client isolation) and the app is running its last cached bundle. Personal Hotspot rules it out.

## Going live

1. In the dashboard's **live** view: Settings → Environment setup → turn on **App** and enter the app scheme; create live products.
2. Remove `host` from the config (or set `https://api.tiun.live`).
3. Swap in the live snippet ID and `p-live-…` product IDs.
4. Turn off `debug`.
5. If verifying server-side, switch to the live base URL and a live API key.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Checkout opens, payment succeeds, but the app never resolves it | Scheme mismatch between dashboard App scheme, native registration, and `returnUrl`; or missing `RCTLinkingManager` forwarding (iOS); or missing `singleTask` (Android) |
| Login / checkout fails on iOS Simulator | Expected — no Secure Enclave. Use a physical iPhone |
| `cryptoOk` is `false` | The WebView can't do the crypto the session needs; auth can't work on this device |
| Bundle fails with a missing module | A peer dependency isn't installed |
| Native module errors right after install | App wasn't rebuilt — rebuild and reinstall |
| Product IDs / snippet don't match the dashboard | `host` points at a different environment than the IDs |
| Hooks throw | Component is outside `<TiunProvider>` |
| Changes don't show up on a physical iPhone | Metro unreachable; app running a cached bundle |
