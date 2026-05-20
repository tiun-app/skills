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

Do not pass `baseUrl` to `init()`. It is an internal-only field reserved for Tiun's own infrastructure (Rule 14 in `SKILL.md`). `sandbox: true` is the only public environment switch.

### NPM mode vs script-tag mode

- **NPM mode** (covered above): you bundle `@tiun/sdk` and call `tiun.init({ snippetId, ... })`. Use this for modern JS apps.
- **Script-tag mode** (legacy): the snippet is loaded by a `<script>` tag and the configuration is injected by the backend. Call `tiun.init()` with no arguments. Use this for legacy server-rendered sites where the snippet is already integrated via a CMS or platform plugin.

Pick one. Mixing both leads to a double-loaded snippet and conflicting config.

## Where to put `snippetId` per host

`snippetId` is non-secret runtime configuration. The rule is the same everywhere: write the value where the runtime can actually read it, not just where it's documented.

| Host | Read from | Common mistake |
|---|---|---|
| Vite (Vue, Svelte, Solid, vanilla bundled) | `.env` / `.env.local`, exposed as `import.meta.env.VITE_*` | Writing to `.env.example` — it is documentation, never loaded |
| Next.js | `.env.local`, exposed as `process.env.NEXT_PUBLIC_*` | Forgetting the `NEXT_PUBLIC_` prefix (value becomes server-only) |
| Nuxt | `nuxt.config.ts` under `runtimeConfig.public`, read via `useRuntimeConfig().public` | Putting it under `runtimeConfig` (server-only, never reaches the client) |
| Astro | `.env`, exposed as `import.meta.env.PUBLIC_*` | Missing `PUBLIC_` prefix |
| SvelteKit | `.env`, exposed as `import.meta.env.VITE_PUBLIC_*` or from `$env/static/public` | Importing from `$env/static/private` (server-only) |
| Plain HTML / no bundler | Inline literal in the `tiun.init({ snippetId })` call, or a `<script>` that sets `window.TIUN_SNIPPET_ID` before SDK load | Trying to use `.env` files (no bundler to load them) |
| Mobile WebView | Native host injects via `window.TIUN_SNIPPET_ID` (or query string) before page load | Hardcoding in JS that ships to all builds and environments |

The `snippetId` is not a secret — it identifies an environment, not a user — so any "public" runtime config slot is safe.

## Lifecycle

- `tiun.init(config)`: call once on app start.
- `tiun.waitForReady()`: returns a Promise that resolves when the hosted snippet is loaded.
- `tiun.destroy()`: tear down the instance. Only needed where the subtree can remount — see the lifecycle matrix in [frameworks.md](frameworks.md).
- `tiun.isInitialized` / `tiun.isReady`: boolean status flags.

## Where to call `init`

Always on the client, never on the server. Initialize once per page load. Re-initializing without `destroy()` is unsupported.

See [frameworks.md](frameworks.md) for per-framework mount points and the full `destroy()` lifecycle matrix.
