---
name: opentui-expert
description: Expert guidance for building Terminal User Interfaces (TUIs) using OpenTUI (React). Handles setup, component structure, rendering, and common TUI pitfalls.
license: MIT
---

## What I do
- Generate production-ready TUI code using `@opentui/react` and `@opentui/core`.
- Structure React-based TUI applications with clean component separation.
- Handle terminal-specific constraints (resizing, input focus, colors).
- Prevent common TUI anti-patterns like blocking the event loop or layout breakage.

## When to use me
- When the user asks to "build a CLI dashboard".
- When creating interactive terminal tools using OpenTUI.
- When debugging rendering issues in OpenTUI applications.
- Triggers: "use opentui", "create a TUI", "terminal interface in react".

## Instructions

### 1. Setup & Boilerplate
- ALWAYS use the React integration unless specifically asked for core-only.
- Standard entry point structure:
  ```tsx
  import { createRoot } from "@opentui/react";
  import { createCliRenderer } from "@opentui/core";
  import App from "./App";

  const renderer = await createCliRenderer();
  const root = createRoot(renderer);
  root.render(<App />);
  ```
- Recommend `bun` for execution speed if environment allows, otherwise `node`.

### 2. Component Patterns
- **Layouts**: Use Flexbox-like containers. Do NOT hardcode absolute positions unless necessary for overlays.
- **Text**: Always wrap text in `<text>` components. Raw strings in generic containers can cause layout shifts.
- **Input**: Use controlled components for inputs to manage state effectively.
- **Async Data**: Use `useEffect` for data fetching. Display a "Loading..." state or spinner component to prevent the UI from looking frozen.

### 3. Anti-Patterns to Avoid (CRITICAL)
- **Console Logs**: NEVER use `console.log` for debugging while the TUI is running. It destroys the layout. Use a dedicated debug pane in the UI or write to a log file.
- **Blocking Main Thread**: Do not run heavy synchronous computations (e.g., large file reads, complex loops) on the main thread. Use worker threads or break up work with `setImmediate`.
- **Global State**: Avoid prop drilling deep trees. Use React Context or lightweight state management (Zustand/Jotai) for complex TUIs.
- **Hardcoded Dimensions**: Do not assume terminal size (e.g., 80x24). Use the `useTerminalSize` hook (or equivalent) to adapt to resize events.

### 4. Styling & UX
- Adhere to "Senior Engineer" standards: clean borders, consistent padding, clear focus indicators.
- Use meaningful colors (Green for success, Red for error, Yellow for warning). Do not overuse colors; keep it accessible.
- Ensure keyboard navigation (Tab/Arrow keys) works logically.

### 5. Example "Senior" Component
```tsx
// Clean, functional, typed component
import React, { useState } from 'react';
import { Box, Text } from '@opentui/react';

interface StatusProps {
  label: string;
  active: boolean;
}

export const StatusIndicator: React.FC<StatusProps> = ({ label, active }) => {
  return (
    <Box flexDirection="row" gap={1}>
      <Text color={active ? 'green' : 'gray'}>●</Text>
      <Text bold={active}>{label}</Text>
    </Box>
  );
};
```
