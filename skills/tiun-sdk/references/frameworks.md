# Framework Integration Snippets

These examples match the canonical snippets from https://docs.tiun.io. Do not deviate from this shape; if a user needs a pattern not shown here, point them at the upstream docs rather than inventing one.

## Vanilla JS

```javascript
import { tiun } from 'https://unpkg.com/@tiun/sdk/tiun.js';

tiun.init({ snippetId: 'YOUR_SNIPPET_ID' });

document.getElementById('btn-checkout').onclick = () => {
  tiun.checkout({ productId: 'p-live-pro' });
};
```

## React

```javascript
import { tiun } from '@tiun/sdk';
import { useEffect } from 'react';

function App() {
  useEffect(() => {
    tiun.init({ snippetId: 'YOUR_SNIPPET_ID' });
    return () => tiun.destroy();
  }, []);
  return <>app content</>;
}
```

## Vue 3

```vue
<script setup>
import { tiun } from '@tiun/sdk';
import { ref, onMounted } from 'vue';

const isAuthenticated = ref(false);
const user = ref(null);

onMounted(() => {
  tiun.on('userChange', (data) => {
    isAuthenticated.value = data.isAuthenticated;
    user.value = data.user;
  });
});
</script>
```

## Content gating (subscription)

```javascript
tiun.on('userChange', (data) => {
  if (!data.isAuthenticated) {
    showPricingPage();
    return;
  }

  const hasPro = data.user.productAccess.includes('p-live-pro');
  hasPro ? showProContent() : showUpgradePrompt();
});
```

## Nuxt / Next.js / other SSR frameworks

The SDK is browser-only; do **not** call `tiun.init` on the server. Initialize it from client-side code (a `"use client"` component in Next.js App Router, a `*.client.ts` plugin in Nuxt, etc.).

Specific SSR-framework wiring is **not documented upstream**. When a user asks for it, send them to https://docs.tiun.io rather than inventing a pattern. The upstream docs are the source of truth and this skill must stay consistent with them.
