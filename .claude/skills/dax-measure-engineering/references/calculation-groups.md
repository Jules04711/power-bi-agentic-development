# Calculation Groups

A calculation group replaces N base-measures x M variants (Actual, YoY, YoY%, YTD, MAT...) with one set of reusable calculation items. Available at compatibility level 1500+; `STLA_20-F_Model` at 1600 supports them. They dramatically reduce measure sprawl and keep variant logic in one place.

## When to use

- You would otherwise hand-write the same time-intelligence (or currency, or scenario) transformation across many base measures.
- You want a single "Time Calculation" slicer that re-expresses any selected measure.

## When NOT to use

- A one-off transformation on a single measure (just write the measure).
- Logic that differs per base measure (calc items must apply uniformly via `SELECTEDMEASURE()`).

## Structure

A calculation group is a special table with:
- a single text column (the items' names, used as a slicer/axis),
- calculation **items**, each an expression over `SELECTEDMEASURE()`,
- an explicit ordinal to control display order.

```dax
-- Calculation group: "Time Calculation"
-- Item: Current
SELECTEDMEASURE ()

-- Item: YTD
CALCULATE ( SELECTEDMEASURE (), DATESYTD ( 'Date'[Date] ) )

-- Item: PY
CALCULATE ( SELECTEDMEASURE (), SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

-- Item: YoY %
VAR _cur = SELECTEDMEASURE ()
VAR _py  = CALCULATE ( SELECTEDMEASURE (), SAMEPERIODLASTYEAR ( 'Date'[Date] ) )
RETURN DIVIDE ( _cur - _py, _py )
```

## Format string expressions

A calc item can override the result format string (e.g. force `0.0%` for the YoY % item) via its format-string expression — so one item can return a percentage while the base measure is currency.

## Authoring

Create via Tabular Editor (`tmdl` / `te2-cli` / `c-sharp-scripting` plugin skills) or TOM; calculation groups are not authorable through the basic Desktop UI. Set `Precedence` when multiple calc groups can apply, to make evaluation order deterministic.

## Testing

Test each item against a base measure with `scripts/test-dax.ps1`, e.g. evaluate `[Total Revenue]` with the "YTD" item applied via `CALCULATE ( [Total Revenue], 'Time Calculation'[Time Calculation] = "YTD" )` and confirm the value.
