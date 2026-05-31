# Relationship Design

## Cardinality

| Cardinality | Use | Notes |
|-------------|-----|-------|
| One-to-many (1:*) | Dimension to fact | The default. One-side key must be unique. |
| One-to-one (1:1) | Vertically partitioned table; extension table | Rare; consider merging. |
| Many-to-many (*:*) | Two dimensions sharing a granularity issue | "Limited" relationship; ambiguity + perf cost; prefer a bridge. |

The **one-side key must be unique and non-blank**. A duplicate on the one-side either silently fails to create the relationship or produces wrong results. Validate uniqueness explicitly.

## Cross-filter direction

- **Single (default):** filters flow one way, dimension to fact. Predictable, fast.
- **Both (bidirectional):** filters flow both ways. Needed for some bridge-table slicing scenarios, but introduces:
  - **Ambiguity** when multiple paths exist,
  - **Performance** overhead,
  - **Security** exposure under RLS.
- Prefer single direction + `CROSSFILTER(..., BOTH)` inside the specific measure that needs it, over a permanently bidirectional relationship.

## Ambiguity & circular paths

Between any two tables there must be exactly **one active** filter path. If two dimensions both relate to two facts that also relate to each other, you can create a loop or multiple paths — the engine then cannot deterministically resolve the filter. Keep one active path; set alternates inactive.

## Inactive relationships & role-playing

- Multiple relationships between the same two tables: only one can be active.
- Role-playing date example: `Sales[Order Date]` (active) and `Sales[Ship Date]` (inactive) both to `Date[Date]`.
- Activate an inactive relationship inside a measure:
  ```dax
  Revenue by Ship Date = CALCULATE ( [Total Revenue], USERELATIONSHIP ( 'Sales'[Ship Date], 'Date'[Date] ) )
  ```
- An inactive relationship that is **never** referenced by `USERELATIONSHIP` is dead weight — wire it up or delete it.

## Bridge tables for many-to-many

For a real many-to-many (e.g. `Account` ↔ `Customer`):
1. Build a bridge at the intersection grain (`AccountCustomer` with both keys).
2. Relate `Account` 1:* to bridge and `Customer` 1:* to bridge.
3. Set the bridge-to-one-dimension relationship bidirectional only if slicing requires it, and accept the documented trade-offs.

## Disconnected dimensions

A table with **no** relationship, used to drive measures via `SELECTEDVALUE`, is a legitimate pattern for what-if parameters and scenario selectors. The project's `Region` and `AdjustmentBridge` dispatch through `SWITCH ( SELECTEDVALUE ( 'Region'[Region] ) )`. Mark such tables as intentional so integrity checks don't flag them as orphans.

## securityFilteringBehavior

On a bidirectional relationship, `securityFilteringBehavior` controls whether RLS filters propagate across the bidirectional edge. Set it deliberately when RLS is in play; the default can either over- or under-restrict depending on the model.
