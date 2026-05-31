# Storage Modes, Partitions & Incremental Refresh

## 1. Storage-mode decision matrix

| Mode | Use when | Cost |
|------|----------|------|
| **Import** (default) | Data fits in memory; near-real-time not required; best query speed | Refresh latency; memory footprint |
| **DirectQuery** | Data too large for memory; near-real-time required; security enforced at source | Slower queries; source load; DAX limits |
| **Dual** | A dimension is queried both by Import facts and DQ facts | Complexity |
| **Composite** | Mix large DQ fact + Import dims + aggregation tables | Most complex; needs aggregations |

Default to **Import**. Move a *specific* large fact to DirectQuery only when memory or latency forces it, keep dimensions Import or Dual, and add **aggregation tables** (Import) over the DQ fact so common queries never touch the source.

## 2. Aggregations (composite models)

Build an Import aggregation table at a coarser grain (e.g. daily by region) over a DirectQuery detail fact. Map it with the aggregations feature so the engine answers summary queries from the in-memory agg and falls through to DQ only for detail. Validate hit rate with performance traces (delegate to `connect-pbid` profiling).

## 3. Partitioning

Partition large fact tables so refresh processes only what changed:

- Partition by a date range column (month or year is typical).
- Each partition is an independent `m` (or `entity`) partition with a filtered query.
- Partitioning is a prerequisite for incremental refresh.

## 4. Incremental refresh

For any date-natured fact over ~1M rows:

1. Define two model parameters `RangeStart` and `RangeEnd` (type `datetime`).
2. Filter the fact's source query to `>= RangeStart and < RangeEnd`. **The filter must fold** to the source (SQL `WHERE`), or incremental refresh degrades to a full scan — verify with `power-query` query-folding diagnostics.
3. Define the incremental refresh policy: store N years/months of history, incrementally refresh the last M days, optionally detect data changes via a `LastModified` column, and only refresh complete periods.
4. After publish, the service generates and manages partitions automatically.

## 5. Memory / VertiPaq hygiene that affects storage

- Split `DateTime` into `Date` + `Time` columns — near-unique `DateTime` produces a massive dictionary.
- Drop columns not needed for reporting or relationships (especially high-cardinality IDs).
- Reduce cardinality where possible (round, bucket, or remove decimals that are noise).
- Set `isAvailableInMdx = false` on hidden / high-cardinality columns not consumed via Excel/MDX.
- Prefer the smallest correct data type (`Int64` over `Double` for counts; `Decimal`/`Currency` for money, never `Double`).

## 6. Decision record

For each fact, record: chosen mode, partition column + granularity, incremental policy (history/window/detect-changes), and whether the source folds. Keep it in the model documentation so the choice is auditable. Cross-reference Microsoft Learn for incremental refresh and composite-model guidance.
