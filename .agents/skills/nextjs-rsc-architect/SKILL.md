---
name: nextjs-rsc-architect
description: Expert guidance for Next.js 15+ App Router applications. Enforces security for Server Actions, proper Data Access Layer (DAL) separation, and React Server Component (RSC) best practices.
license: MIT
---

## What I do
- Architect Next.js apps using the "Data Access Layer" (DAL) pattern.
- Secure Server Actions against unauthorized access and input injection.
- Optimize rendering with Suspense streaming and partial prerendering (PPR).
- Prevent common pitfalls like hydration mismatches and waterfall fetching.

## When to use me
- When building features in Next.js App Router.
- When creating Server Actions (`"use server"`).
- When asked to "optimize nextjs" or "secure server actions".
- Triggers: "app router", "server component", "server action", "rsc".

## Instructions

### 1. Security & Server Actions
- **Authentication Check**: EVERY Server Action must explicitly verify authentication/authorization. Middleware is NOT enough for actions.
- **Input Validation**: usage of Zod inside the action is mandatory.
  ```ts
  "use server";
  
  import { z } from "zod";
  import { verifySession } from "@/lib/dal";
  
  const schema = z.object({ id: z.string() });
  
  export async function deleteItem(formData: FormData) {
    const session = await verifySession(); // Security Check
    if (!session.isAdmin) throw new Error("Unauthorized");
    
    const parsed = schema.safeParse(Object.fromEntries(formData));
    if (!parsed.success) return { error: "Invalid data" };
    
    // ... logic
  }
  ```

### 2. Data Access Layer (DAL)
- **Rule**: Components should not query the DB directly. Create a `data/` folder (DAL).
- **Pattern**:
  - `app/page.tsx` -> calls `getDashboardData()`
  - `data/dashboard.ts` -> calls `db.query()` AND performs React `cache()` if needed.
- **DTOs**: Never return raw ORM objects to the client. Sanitize sensitive fields (passwords, internal IDs) in the DAL.

### 3. Fetching & Suspense
- **No Waterfalls**: Parallelize data fetching using `Promise.all` in the parent component where possible.
- **Streaming**: Wrap slow components in `<Suspense fallback={<Skeleton />}>`.
- **Client Components**: Push `"use client"` down the tree as far as possible (Leaf nodes).

### 4. Anti-Patterns
- **Async Client Components**: Client components cannot be async.
- **Secrets in Client**: NEVER pass API keys or secrets to client components via props.
- **State in Server**: Server Components are stateless. Don't try to use `useState` in them.
