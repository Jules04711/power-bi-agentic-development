---
name: dax-measure-engineering
version: 1.0.0
description: Author correct, performant, tested DAX for enterprise semantic models. Automatically invoke when the user asks to "write a measure", "create DAX", "add measures", "time intelligence", "YoY / YTD / running total", "calculation group", "format string for a measure", "test a measure", "is this DAX correct", "make this measure faster", or mentions filter context, CALCULATE, variables, or measure display folders. For pure performance/anti-pattern optimization of existing DAX, also load the plugin `dax` skill.
---

# DAX Measure Engineering

Produces DAX that is **correct first, fast second, and always verified**. LLM-generated DAX is frequently plausible-but-wrong (see the Tabular Editor caveat in the project notes) — so every measure this skill authors is tested against the live engine before it is considered done. Delegate the deep performance framework (tiers, engine internals, xmSQL) to the plugin `dax` skill; delegate trace capture to `connect-pbid`; delegate object writes to `tmdl`. Honor `../AUTHORING.md` and `CLAUDE.md`.

## Operating procedure

1. **State intent.** One sentence: what business question the measure answers and at what grain.
2. **Write with variables.** Use `VAR`/`RETURN`; name intermediates; never repeat a subexpression. Variables are evaluated once and clarify filter context.
3. **Guard division.** Use `DIVIDE(n, d)` (optionally a 3rd blank-result arg) instead of `/` unless the denominator is provably non-zero.
4. **Filter columns, not tables.** In `CALCULATE`, prefer `KEEPFILTERS('T'[Col] = x)` over `FILTER('T', …)`. Filtering whole tables is both a correctness and performance hazard.
5. **Respect context transition.** Know when a measure reference triggers context transition; wrap row-context aggregations in `CALCULATE` deliberately, not by accident.
6. **Time intelligence needs a real date table.** Every time-intel function (`TOTALYTD`, `SAMEPERIODLASTYEAR`, `DATEADD`) requires the explicit marked `Date` table from `semantic-model-architect`; they return BLANK against auto-date shadows used incorrectly. See `references/time-intelligence.md`.
7. **Prefer calculation groups** for repetitive measure variants (Actual / YoY / YTD across many base measures) instead of hand-writing the cross-product. See `references/calculation-groups.md`. (Calc groups work at compat 1500+; this project's 1600 is fine. Note 1600 < 1601 means no DAX UDFs.)
8. **Set metadata.** Every measure: explicit format string, display folder, description. Set `discourageImplicitMeasures = true` on the model so report authors use explicit measures.
9. **TEST before commit.** Run the measure through `scripts/test-dax.ps1` (an `EVALUATE`/`DEFINE MEASURE` harness over ADOMD) and confirm the value against a known figure. Untested DAX is not done.
10. **Tune only after correct.** If slow, capture server timings (`connect-pbid`) and apply the plugin `dax` tier framework; see `references/dax-performance-tuning.md`.

## Defaults

| Decision | Default |
|----------|---------|
| Calculations | Measures, not calculated columns |
| Division | `DIVIDE()` |
| Filtering in CALCULATE | Column predicate + `KEEPFILTERS`, not `FILTER(table)` |
| Readability | `VAR`/`RETURN`, no repeated subexpressions |
| Repetitive variants | Calculation group |
| Implicit measures | Disabled (`discourageImplicitMeasures = true`) |
| Every measure | Format string + display folder + description + a passing test |

## Authoring measures in bulk

Use `scripts/add-measures-from-spec.ps1` with a JSON spec to create many measures with expression, format string, display folder, and description in one TOM pass, then trigger a `calculate` refresh (required for calculated tables; safe for measures). Mirrors the project's `add-aoi-measures.ps1` pattern. Persisting to disk follows the `CLAUDE.md` rule (serialize while Desktop closed, or Ctrl+S).

## Project-specific caveat: wide-format string facts

`STLA_20-F_Model` stores numeric values as strings with thousands separators, parenthesised negatives, and em-dash blanks, parsed with a repeating `SUBSTITUTE` chain (compat 1600 means this cannot be refactored into a DAX UDF). When writing measures on such tables, reuse the documented parse pattern verbatim and **test the returned number** — do not assume the parse succeeded. See `references/dax-patterns.md`.

## Dogfood: STLA_20-F_Model

Evaluate an existing measure to prove the harness works:
```
.\scripts\test-dax.ps1 -Port <port> -Dax 'EVALUATE ROW("AOI", [Adjusted Operating Income])'
```
Confirm a non-blank numeric result.

## References

- `references/dax-patterns.md` — core patterns, variables, CALCULATE/context, the string-parse pattern.
- `references/time-intelligence.md` — YTD/YoY/MAT/running totals; date-table prerequisites; `USERELATIONSHIP` for role-playing dates.
- `references/calculation-groups.md` — when and how; ordinal, format-string expression, selection functions.
- `references/dax-performance-tuning.md` — diagnosis order, common fixes, when to hand off to the plugin `dax` tiers.
- `references/dax-testing-harness.md` — how `test-dax.ps1` works and how to assert expected values.

## Related plugin skills

`dax`, `connect-pbid`, `tmdl`, `bpa-rules`, `review-semantic-model`.
