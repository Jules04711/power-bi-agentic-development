# Model Hygiene Checklist

The pre-handoff gate. `scripts/validate-model-shape.ps1` automates the machine-checkable items; the rest are review items. Severities: **CRITICAL** blocks release, **WARN** needs justification, **INFO** is advisory.

## Structure
- [ ] CRITICAL — No orphaned tables (every table relates or is an intentional disconnected dim).
- [ ] CRITICAL — No direct fact-to-fact relationships.
- [ ] WARN — No snowflaked dimensions without a documented reason.
- [ ] WARN — No table with > 30 columns (denormalization smell).
- [ ] INFO — Measures distributed across subject tables, not piled on one table.

## Date
- [ ] CRITICAL — Exactly one explicit `Date` table, marked `dataCategory: Time`.
- [ ] CRITICAL — Date table contiguous daily, spans all fact dates.
- [ ] CRITICAL — Auto Date/Time **disabled** (`__PBI_TimeIntelligenceEnabled = 0`, no `LocalDateTable_*`).

## Keys & types
- [ ] CRITICAL — One-side relationship key is unique.
- [ ] CRITICAL — No columns with missing/ambiguous data types.
- [ ] CRITICAL — No currency stored as `Double`; no numbers stored as `String`.
- [ ] WARN — Foreign keys hidden; `summarizeBy = none` on all keys and non-additive numerics.
- [ ] WARN — High-cardinality `DateTime` split into `Date` + `Time`.

## Formatting & docs
- [ ] WARN — Every measure has a format string and a display folder.
- [ ] WARN — Friendly Title Case display names throughout.
- [ ] WARN — Tables and key columns have descriptions.
- [ ] INFO — No duplicate field names across tables (AI readiness).

## Size & performance
- [ ] WARN — Large facts partitioned + incremental refresh configured.
- [ ] INFO — Unused columns/tables removed.
- [ ] INFO — `isAvailableInMdx = false` on hidden/high-cardinality non-MDX columns.

## Compatibility
- [ ] INFO — Compatibility level recorded; note 1600 < 1601 means no DAX UDFs.

## Expected findings on STLA_20-F_Model (dogfood baseline)
Auto Date/Time ON (8 shadow tables) — CRITICAL; compat 1600 — INFO; 88 measures on one wide string table — INFO/WARN; numeric values stored as strings — CRITICAL; zero RLS roles — handled by `relationship-and-model-integrity`.
