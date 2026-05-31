# Dimensional Modeling Reference

Kimball-style dimensional discipline for Power BI tabular models. The goal is a **star schema**: central fact tables surrounded by conformed dimensions, joined 1-to-many on single-column keys.

## 1. Grain first

Declare the grain of each fact before modeling anything: *"one row per ___"*. The grain fixes which dimensions can attach and what additivity each measure has. Mixed-grain facts cause double counting — split them.

## 2. Facts vs dimensions

| | Fact | Dimension |
|---|------|-----------|
| Content | Events, measurements | Descriptive attributes |
| Rows | Many (millions) | Few to moderate |
| Numeric columns | Additive measures + hidden FKs | Rare (keys only) |
| Examples | Orders, Transactions, Filings | Date, Customer, Product, Region |

A table that holds both measurements and rich descriptive attributes is two tables wearing one coat. Split it: keep the numbers + keys in the fact, move the descriptions to a dimension.

## 3. Star vs snowflake

- **Star (default):** each dimension is one flat table directly related to the fact. Fewer relationships, simpler DAX, better compression, better for Copilot/AI consumption.
- **Snowflake:** dimension normalized across multiple related tables (e.g. `Product → Subcategory → Category`). Avoid in tabular. Flatten into a single `Product` table with `Subcategory` and `Category` as columns.
- **Deviate** only when a normalized level is reused by a *different* fact at that level's grain, or the dimension is huge and slowly changing and duplication is costly. Document the reason.

## 4. Conformed dimensions

A conformed dimension (e.g. one `Date`, one `Customer`) is shared by multiple facts so a slicer filters all of them consistently. Multiple facts each carrying their own private copy of "date" is a classic defect — it breaks cross-fact slicing. Build one, relate all facts to it.

## 5. Role-playing dimensions

When a fact references the same dimension in several roles (Order Date, Ship Date, Due Date), do **not** import three date tables. Keep one `Date` dimension, create multiple relationships (one active, the rest inactive), and switch with `USERELATIONSHIP` inside measures. See `relationship-and-model-integrity`.

## 6. Degenerate dimensions

A transaction/order/invoice number with no descriptive attributes of its own lives **on the fact table** as a degenerate dimension column — do not build a one-attribute dimension just to hold it.

## 7. Slowly changing dimensions (SCD)

- **Type 1** — overwrite; keep only the current value. Simplest; default when history is not required.
- **Type 2** — add a new row per change with `ValidFrom`/`ValidTo`/`IsCurrent` and a new surrogate key so facts point at the version that was true at event time. Use when history must be preserved.
- Implement SCD logic upstream (source / Power Query / warehouse), not in DAX.

## 8. Many-to-many and bridge tables

True many-to-many (e.g. accounts ↔ customers) needs a **bridge table** at the intersection grain, related 1-to-many from each side. Avoid native `*:*` relationships unless you understand the ambiguity and performance cost — see `relationship-and-model-integrity`. Disconnected dimensions (no relationship, driven by `SELECTEDVALUE` in measures) are a valid pattern for what-if / scenario selectors — the project's `Region` and `AdjustmentBridge` tables use it.

## 9. Surrogate keys

Prefer a meaningless integer surrogate key on each dimension over a natural business key: smaller dictionary, faster joins, stable across source changes, and required for SCD Type 2. Hide the surrogate key column; expose human-readable attributes for slicing.

## 10. Checklist

- [ ] Each fact has a single declared grain.
- [ ] No mixed fact/dimension tables.
- [ ] Dimensions flat (no snowflake) unless justified.
- [ ] One conformed `Date` (and any other shared dim).
- [ ] Role-playing handled with inactive relationships + `USERELATIONSHIP`.
- [ ] Degenerate dimensions live on the fact.
- [ ] SCD strategy chosen and implemented upstream.
- [ ] Many-to-many resolved via bridge or a deliberate disconnected dim.
- [ ] Integer surrogate keys, hidden, unique on the one-side.
