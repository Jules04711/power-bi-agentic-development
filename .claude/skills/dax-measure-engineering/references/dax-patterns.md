# Core DAX Patterns

Correctness-first patterns. For the systematic performance tier framework (DAX001–DAX021 etc.), use the plugin `dax` skill.

## Variables

```dax
Revenue YoY % =
VAR _current = [Total Revenue]
VAR _prior   = CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )
VAR _delta   = _current - _prior
RETURN DIVIDE ( _delta, _prior )
```

- Name variables for the value they hold.
- A variable is computed once, in the filter context where it is declared — moving a reference inside/outside `CALCULATE` changes nothing about a captured variable's value (this is a feature: capture-before-transition).

## DIVIDE

```dax
Margin % = DIVIDE ( [Total Margin], [Total Revenue] )           -- BLANK on zero denom
Safe Rate = DIVIDE ( [A], [B], 0 )                              -- 0 on zero denom
```
Use plain `/` only when the denominator is guaranteed non-zero and the hot path needs the micro-optimization.

## Filter columns, not tables

```dax
-- Good: column predicate, keeps existing filters
Sales East = CALCULATE ( [Total Sales], KEEPFILTERS ( 'Region'[Region] = "East" ) )

-- Avoid: materializes the whole table, drops other column filters
Sales East Bad = CALCULATE ( [Total Sales], FILTER ( 'Region', 'Region'[Region] = "East" ) )
```
`FILTER(table, …)` is justified only when the predicate spans multiple columns or references a measure.

## KEEPFILTERS

Use `KEEPFILTERS` to intersect (not overwrite) the existing filter context for non-equality or set predicates:
```dax
Big Orders = CALCULATE ( [Order Count], KEEPFILTERS ( 'Sales'[Amount] > 1000 ) )
```

## SELECTEDVALUE / disconnected dimensions

```dax
Scenario Rate =
VAR _r = SELECTEDVALUE ( 'Assumptions'[Rate], 0.05 )           -- default when not exactly one
RETURN [Base Value] * ( 1 + _r )
```
This is the dispatch pattern for disconnected dims (the project's `Region` / `AdjustmentBridge` use `SWITCH ( SELECTEDVALUE (...) )`).

## Context transition

A naked measure reference inside a row context (e.g. inside `SUMX`) triggers context transition — the current row becomes a filter. Make it intentional:
```dax
Total Weighted = SUMX ( 'Sales', 'Sales'[Qty] * RELATED ( 'Product'[Price] ) )   -- row context, no transition needed
Customers w/ Sales = COUNTROWS ( FILTER ( VALUES ( 'Customer'[Id] ), [Total Sales] > 0 ) )  -- [Total Sales] transitions per customer
```

## Variables over IF-repetition

```dax
Status =
VAR _m = [Margin %]
RETURN SWITCH ( TRUE (), _m >= 0.2, "Good", _m >= 0.1, "OK", "Poor" )
```

## Wide-format string-parse pattern (project-specific, compat 1600)

`STLA_20-F_Model` facts are strings; parse with the documented chain and always test the result:
```dax
VAR _raw = CALCULATE ( SELECTEDVALUE ( 'AOI_FY2025'[<col>] ),
                       ALL ( 'AOI_FY2025' ), 'AOI_FY2025'[Index] = <line> )
VAR _c   = TRIM ( SUBSTITUTE ( SUBSTITUTE ( SUBSTITUTE ( SUBSTITUTE (
              _raw, ",", "" ), "(", "-" ), ")", "" ), "—", "" ) )
RETURN IF ( _c IN { "", "-" }, BLANK (), VALUE ( _c ) )
```
Compatibility level 1600 means this repetition cannot be collapsed into a DAX UDF (1601+). Document, do not fight it.
