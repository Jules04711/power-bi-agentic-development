---
name: semantic-model-architect
version: 1.0.0
description: Design and author enterprise-grade Power BI tabular semantic models. Automatically invoke when the user asks to "design a semantic model", "build a star schema", "model my data", "choose a storage mode", "set up incremental refresh", "partition a fact table", "fix snowflake", "set up a date table", "disable auto date/time", "name tables and columns", "set data types / format strings", or mentions dimensional modeling, fact and dimension tables, surrogate keys, or model size/hygiene.
---

# Semantic Model Architect

Turns requirements and sources into a **production-ready dimensional model**. This skill is the *methodology and gating* layer — it decides the shape; it delegates the mechanics. For TMDL serialization use the `tmdl` plugin skill; for M / query folding use `power-query`; for naming remediation use `standardize-naming-conventions`; to connect to a live model use `connect-pbid`. Honor every rule in `../AUTHORING.md` and the workspace `CLAUDE.md` sequencing rules.

## Operating procedure

1. **Understand the grain.** For each business process, state the fact grain in one sentence ("one row per order line per day"). Everything else follows from the grain. Never start from the source table shape.
2. **Separate facts from dimensions.** Facts = events/measurements (numeric, additive, many rows). Dimensions = descriptive context (who/what/when/where). If a table is both, split it.
3. **Default to a star, not a snowflake.** Collapse snowflaked dimension levels into one flat dimension unless a level is genuinely reused by another fact at a different grain or the dimension is enormous and slowly changing. Read `references/dimensional-modeling.md` before deviating.
4. **One conformed `Date` dimension**, marked as a date table (`dataCategory: Time`), contiguous daily, spanning all facts, joined by a single date key. **Disable Auto Date/Time** (`scripts/disable-auto-datetime.ps1`) — never rely on the shadow `LocalDateTable_*` tables.
5. **Keys:** integer surrogate keys on dimensions; hide foreign-key columns on facts; set `summarizeBy = none` on every key and on any non-additive numeric column; ensure the one-side key is unique.
6. **Pick a storage mode deliberately** (Import / DirectQuery / Dual / Composite + aggregations) using the decision matrix in `references/storage-modes-and-partitions.md`. Default to Import unless data volume, latency, or security forces otherwise.
7. **Plan partitions + incremental refresh** for any fact over ~1M rows or with a natural date range. Define `RangeStart`/`RangeEnd` parameters and an incremental refresh policy; confirm the source query folds (delegate to `power-query`).
8. **Apply naming + formatting standards** (`references/naming-and-formatting-standards.md`): friendly Title Case display names (`Close Price`, not `close_price`), correct data types, format strings on every measure/column, display folders, descriptions.
9. **Run the hygiene gate** (`scripts/validate-model-shape.ps1`) and resolve every finding or record an explicit, justified exception.

## Non-negotiable defaults (state the deviation if you break one)

| Decision | Default | Deviate only when |
|----------|---------|-------------------|
| Schema | Star (flat dims) | A level is reused across facts at a different grain |
| Date table | One, marked, contiguous, auto-date-time OFF | Never disable the explicit date table |
| Fact numeric keys | Hidden, `summarizeBy = none` | Never |
| Dimension key | Unique integer surrogate | Natural key proven unique and stable |
| Storage mode | Import | Volume / latency / RLS-at-source requires DQ/Composite |
| Large fact | Partitioned + incremental refresh | < ~1M rows and not date-natured |
| Bidirectional cross-filter | Off (single) | See `relationship-and-model-integrity` |
| Calculations | Measures, not calculated columns | Column genuinely needed for slicing/grouping |
| Data types | Explicit and minimal (no `Double` for currency, no `String` for numbers) | Never |

## Anti-patterns this skill exists to prevent

- Auto Date/Time left on (shadow `LocalDateTable_*` bloat) — the state `STLA_20-F_Model` is in.
- All measures piled onto one wide table with no fact/dim separation.
- Numeric values stored as strings (forces fragile parse logic in DAX).
- Snowflaked dimensions imported verbatim from a normalized source.
- High-cardinality `DateTime` columns not split into date + time.
- Calculated columns doing work that belongs in Power Query or a measure.

## Dogfood: STLA_20-F_Model

Run `scripts/validate-model-shape.ps1 -Port <port>` against the live model. It must report: Auto Date/Time ON (8 shadow tables), compatibility level 1600 (flag: < 1601 → no DAX UDFs), measures concentrated on a single table, and any columns missing format strings / `summarizeBy`. Treat each as a remediation item, not a blocker for the doc-only model.

## References

- `references/dimensional-modeling.md` — facts vs dims, grain, star vs snowflake, role-playing & degenerate dims, SCD basics, bridge tables.
- `references/storage-modes-and-partitions.md` — storage-mode decision matrix, aggregations, partition strategy, incremental refresh with `RangeStart`/`RangeEnd`.
- `references/naming-and-formatting-standards.md` — display names, data types, format strings, display folders, descriptions.
- `references/model-hygiene-checklist.md` — the full pre-handoff checklist the validate script encodes.

## Related plugin skills

`tmdl`, `power-query`, `standardize-naming-conventions`, `review-semantic-model`, `connect-pbid`, `lineage-analysis`.
