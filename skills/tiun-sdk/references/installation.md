# Installation & Initialization

## Install

```bash
npm install @tiun/sdk
# or
pnpm add @tiun/sdk
# or
yarn add @tiun/sdk
```

For vanilla HTML/JS without a bundler, import the ESM build from a CDN:

```html
<script type="module">
  import { tiun } from 'https://unpkg.com/@tiun/sdk/tiun.js';
  tiun.init({ snippetId: 'YOUR_SNIPPET_ID' });
</script>
```

## Initialize

```javascript
import { tiun } from '@tiun/sdk';

tiun.init({
  snippetId: 'YOUR_SNIPPET_ID', // required, from my.tiun.business
  language: 'en',               // optional, UI language, default 'en'
  tone:     'formal',           // optional, 'formal' | 'informal'
  debug:    false,              // optional, console logging
  sandbox:  false,              // optional, test environment
});
```

### Config options

| Option | Type | Default | Notes |
|---|---|---|---|
| `snippetId` | string | none | **Required.** From dashboard. |
| `language` | string | `'en'` | UI language for hosted overlays. |
| `tone` | `'formal'` \| `'informal'` | `'formal'` | Copy style in overlays. |
| `debug` | boolean | `false` | Enable console logging. |
| `sandbox` | boolean | `false` | Test mode with simulated payments. The dashboard has a separate sandbox toggle; both must be aligned. |

## Lifecycle

- `tiun.init(config)`: call once on app start.
- `tiun.waitForReady()`: returns a Promise that resolves when the hosted snippet is loaded.
- `tiun.destroy()`: tear down the instance (e.g. in a React `useEffect` cleanup).
- `tiun.isInitialized` / `tiun.isReady`: boolean status flags.

## Where to call `init`

- **React.** Inside a top-level `useEffect(..., [])` with `tiun.destroy()` in the cleanup.
- **Vue 3.** In `onMounted()` of the root component.
- **Nuxt / Next.js.** In a client-only plugin or a `"use client"` root provider. Do not call `init` on the server.
- **Vanilla.** At the end of `<body>` or after `DOMContentLoaded`.

Only initialize once per page load. Re-initializing without `destroy()` is unsupported.
