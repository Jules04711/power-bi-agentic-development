# DAX Function Library — Research Reference

The authoritative, always-current catalog of every DAX function is the Microsoft DAX function reference:

**<https://learn.microsoft.com/en-us/dax/>**

This skill's `references/dax-patterns.md`, `time-intelligence.md`, and `calculation-groups.md` cover *how to apply* the common functions correctly. This file covers *how to research* a function you are unsure about — because guessing a signature or its evaluation-context behavior is the most common source of plausible-but-wrong DAX.

## When to research before writing

Look the function up first whenever any of these is true:
- You are not 100% sure of the **argument order** or which arguments are optional.
- You are unsure whether it returns a **scalar** or a **table**.
- The function's behavior depends on **filter vs row context** (most `CALCULATE` modifiers, iterators, and relationship functions).
- It is a **newer** function (e.g. `WINDOW`, `OFFSET`, `INDEX`, `RANK`, `LINEST`, `NETWORKDAYS`, `TOCSV`/`TOJSON`) that may not exist at this model's compatibility level.
- You are about to hand-roll logic that a built-in function already does (check before reinventing).

> Compatibility note: this project's model is **compatibility level 1600**, which does **not** support DAX user-defined functions (UDFs require 1601+). Newer scalar/table functions also have version floors — confirm availability on the function's reference page before relying on it. See `../SKILL.md` and the project `knowledge-base`.

## How to research efficiently

Prefer the Microsoft Learn MCP tools over raw web fetches — they return clean, citable Markdown excerpts:

1. `microsoft_docs_search` with the function name plus "DAX" (e.g. `"DAX CALCULATETABLE function"`).
2. `microsoft_docs_fetch` on the resulting `learn.microsoft.com/en-us/dax/<function>-function-dax` URL for the full signature, parameters, return value, remarks, and examples.
3. Fall back to `WebFetch` against the same URL only if the MCP tools are unavailable.

Direct URL pattern: most functions live at `https://learn.microsoft.com/en-us/dax/<name>-function-dax` (e.g. `.../calculate-function-dax`, `.../divide-function-dax`, `.../sameperiodlastyear-function-dax`).

After researching, **still test** the measure against the live engine with `scripts/test-dax.ps1` — documentation confirms the contract, the test confirms the result.

## Function-group index (entry points on learn.microsoft.com/en-us/dax/)

| Group | What it covers | Examples |
|-------|----------------|----------|
| Aggregation | Sum/avg/count and their iterators | `SUM`, `SUMX`, `AVERAGEX`, `COUNTROWS`, `DISTINCTCOUNT` |
| Filter | Context manipulation — the heart of DAX | `CALCULATE`, `CALCULATETABLE`, `FILTER`, `ALL`, `ALLEXCEPT`, `REMOVEFILTERS`, `KEEPFILTERS`, `VALUES`, `SELECTEDVALUE`, `EARLIER` |
| Time intelligence | Period-over-period, to-date, shifts (need a marked date table) | `TOTALYTD`, `DATESYTD`, `SAMEPERIODLASTYEAR`, `DATEADD`, `DATESINPERIOD`, `PARALLELPERIOD`, `PREVIOUSMONTH` |
| Date and time | Date/time scalars | `DATE`, `EOMONTH`, `CALENDAR`, `CALENDARAUTO`, `WEEKDAY`, `YEAR`, `NOW` |
| Relationship | Cross-relationship navigation | `RELATED`, `RELATEDTABLE`, `USERELATIONSHIP`, `CROSSFILTER`, `TREATAS` |
| Table | Return tables (often inside `CALCULATE`/iterators) | `SUMMARIZE`, `SUMMARIZECOLUMNS`, `ADDCOLUMNS`, `SELECTCOLUMNS`, `GENERATE`, `UNION`, `NATURALINNERJOIN`, `TOPN` |
| Filter/window (newer) | Visual-calc-style windowing | `WINDOW`, `OFFSET`, `INDEX`, `RANK`, `ROWNUMBER` (check version floor) |
| Logical | Branching and conditions | `IF`, `SWITCH`, `AND`, `OR`, `COALESCE`, `IFERROR` |
| Math & statistical | Arithmetic, rounding, stats | `DIVIDE`, `ROUND`, `INT`, `MOD`, `RANKX`, `LINEST`, `LINESTX` |
| Text | String manipulation (also used for the wide-format parse pattern) | `SUBSTITUTE`, `TRIM`, `VALUE`, `FORMAT`, `CONCATENATEX`, `LEFT`/`RIGHT`/`MID`, `SEARCH` |
| Information | Type/context introspection | `HASONEVALUE`, `ISBLANK`, `ISFILTERED`, `ISINSCOPE`, `USERPRINCIPALNAME` |
| Financial | TVM and finance | `XNPV`, `XIRR`, `PMT`, `RATE` |
| Conversion / other | Casting and formatting | `CONVERT`, `CURRENCY`, `DATATABLE`, `TOCSV`, `TOJSON` |

When the right function for a problem is unclear, browse the matching group on the reference root, read the candidate's page, then prototype and test.
