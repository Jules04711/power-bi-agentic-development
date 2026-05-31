# Naming & Formatting Standards

Consistent names and formats are the cheapest, highest-visibility quality signal in a model. Delegate bulk remediation to the `standardize-naming-conventions` plugin skill; this document is the standard it should enforce.

## 1. Display names

- **Friendly Title Case** for everything user-facing: `Close Price`, not `close_price` or `ClosePrice`.
- Tables: singular business noun for dimensions (`Customer`, `Date`), plural or process noun for facts (`Sales`, `Filings`).
- Measures: `Verb/Noun` business language (`Total Revenue`, `Revenue YoY %`). No table prefixes.
- Columns: human terms; expand abbreviations (`Qty` → `Quantity`) unless the abbreviation is the business standard.
- Hidden technical keys can keep a `…Key` / `…ID` suffix; they are hidden anyway.

## 2. Hiding

- Hide all foreign keys on fact tables.
- Hide surrogate keys on dimensions (expose readable attributes).
- Hide raw helper / staging columns.
- Hide entire technical tables (bridges, config) unless users slice on them.

## 3. Data types

| Content | Type | Never |
|---------|------|-------|
| Money | `Decimal` / Fixed Decimal (Currency) | `Double` |
| Counts / integer keys | `Int64` | `Double`, `String` |
| Ratios needing precision | `Double` | `String` |
| Dates | `DateTime` split to `Date` + `Time` | high-cardinality `DateTime` |
| Flags | `Boolean` | `String` "Y"/"N" |
| Codes used only as labels | `String` | numeric type that invites accidental aggregation |

Numbers stored as `String` are a defect: they force fragile DAX parse logic (the `STLA_20-F_Model` wide-format tables show the cost). Convert in Power Query.

## 4. Format strings

Every measure and every displayed column gets an explicit format string:

- Large currency: `#,0` or `#,0,,"M"` (no cents where they are noise).
- Ratios / percentages: `0.0%`.
- Counts: `#,0`.
- Dates: `mm/dd/yyyy` (or the org standard) — set once, consistently.
- Thousands separators always on for numbers ≥ 1,000.

## 5. Display folders

Group measures into display folders by subject area (`Revenue`, `Margin`, `Targets`, `Time Intelligence`). A flat list of 80+ measures (as in `STLA_20-F_Model`) is unusable — folders are mandatory past ~10 measures.

## 6. Descriptions

- Every table: one sentence on what it represents and its grain.
- Every measure: what it computes and any non-obvious filter behavior.
- Descriptions feed tooltips and AI/Copilot consumption — treat them as user-facing.

## 7. `summarizeBy`

- Keys (surrogate + foreign): `none`.
- Non-additive numerics (rates, ratios, prices): `none` — never let Power BI implicitly `Sum` a price.
- Additive fact numerics intended for ad-hoc sum: `sum` (but prefer explicit measures and `discourageImplicitMeasures = true`).

## 8. AI / Copilot readiness

- No duplicate field names across tables (confuses Copilot and data agents).
- Descriptions present and meaningful.
- Synonyms added for common business aliases where the linguistic layer is used.
