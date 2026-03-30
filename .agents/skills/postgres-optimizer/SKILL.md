---
name: postgres-optimizer
description: Senior DB Engineer skills for PostgreSQL. Focuses on performance (indexing, analysis), modern schema design (UUIDv7), and safe migration patterns.
license: MIT
---

## What I do
- Optimize SQL queries using `EXPLAIN ANALYZE`.
- Design schemas with proper normalization and modern primary keys.
- Create covering indexes and partial indexes for high-performance queries.
- Advise on connection pooling (PgBouncer/Supavisor) and JSONB usage.

## When to use me
- When creating database schemas or migrations.
- When debugging "slow queries" or DB timeouts.
- When choosing data types (e.g., JSONB vs relational).
- Triggers: "optimize query", "postgres schema", "database migration", "sql performance".

## Instructions

### 1. Schema Design (2025 Standards)
- **Primary Keys**: Use **UUIDv7** (time-sortable) instead of v4 or auto-increment integers for distributed systems.
  - *Why*: Better index locality than v4, no enumeration attacks like integers.
- **Timestamps**: Always use `timestamptz` (with time zone).
- **Foreign Keys**: ALWAYS index foreign key columns. Postgres does not do this automatically, and it causes lock contention on deletes.

### 2. Indexing Strategy
- **Index-Only Scans**: Aim for this. Include the payload columns in the index using `INCLUDE`.
  ```sql
  CREATE INDEX idx_users_active_email ON users (status) INCLUDE (email) WHERE status = 'active';
  ```
- **Partial Indexes**: Index only what you query.
  - *Example*: `CREATE INDEX idx_orders_unshipped ON orders (created_at) WHERE shipped_at IS NULL;`

### 3. JSONB: The Trap
- **Rule**: Use JSONB *only* for truly unstructured data or rarely-queried metadata.
- **Anti-Pattern**: Dumping core business logic into a JSONB column. It kills join performance and type safety.
- **Gin Indexes**: If querying JSONB, a GIN index is mandatory.

### 4. Query Analysis
- **Mandatory Tool**: `EXPLAIN (ANALYZE, BUFFERS)`.
- **Red Flags**:
  - `Seq Scan` on large tables (missing index).
  - High `Buffers: shared hit` (query pulling too much data).
  - N+1 queries (detect and switch to `IN` clauses or `LATERAL` joins).

### 5. Connection Pooling
- **Requirement**: In serverless/edge environments (like Next.js), you MUST use a transaction pooler (PgBouncer, Supabase Pooler) to avoid exhausting connections.
