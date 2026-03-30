---
name: web-performance-guru
description: Optimization of Web Vitals (INP, LCP, CLS) for 2025. Focuses on Interaction to Next Paint (INP), bundle splitting, and image strategies.
license: MIT
---

## What I do
- Audit sites for Core Web Vitals.
- Optimize "Interaction to Next Paint" (INP) by yielding to main thread.
- Implement efficient loading strategies (Lazy loading, Priority Hints).
- Analyze webpack/vite bundles.

## When to use me
- When user says "site is slow".
- When asked to "improve lighthouse score".
- Triggers: "performance", "web vitals", "lcp", "inp", "cls", "lazy load".

## Instructions

### 1. Interaction to Next Paint (INP)
- **The Killer**: Long tasks blocking the main thread.
- **Fix**: Yield to the event loop.
  ```ts
  async function yieldToMain() {
    return new Promise(resolve => setTimeout(resolve, 0));
  }
  // Inside heavy loop
  await yieldToMain();
  ```
- **React**: Use `useTransition` for state updates that cause heavy re-renders, keeping the UI responsive.

### 2. LCP (Largest Contentful Paint)
- **Priority**: The LCP element (Hero image/text) must be discovered early.
- **Preload**: `<link rel="preload" as="image" href="...">` or Next.js `<Image priority />`.
- **Hosting**: Assets must be on a CDN.

### 3. CLS (Cumulative Layout Shift)
- **Sizing**: Always define `width` and `height` (aspect-ratio) for images/videos.
- **Fonts**: Use `font-display: swap` or `optional` to prevent FOUT/FOIT layout shifts.

### 4. Bundle Optimization
- **Dynamic Imports**: Split route components.
  - `const Component = dynamic(() => import('./Component'))`
- **Dep Check**: Visualize bundle. `moment.js` is banned (use `date-fns` or `dayjs`). Lodash must be tree-shaken.
