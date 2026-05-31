# DAX Testing Harness

`scripts/test-dax.ps1` runs DAX against the live PBI Desktop engine over ADOMD.NET and returns the result, so a measure can be verified before it is committed. This is the antidote to plausible-but-wrong generated DAX.

## Prerequisites

- PBI Desktop open with the model loaded; discover the port per `CLAUDE.md`.
- ADOMD.NET present at `%TEMP%\tom_nuget\Microsoft.AnalysisServices.AdomdClient.retail.amd64\...` (reinstall the NuGet package if missing).

## Usage

Evaluate an existing measure:
```
.\scripts\test-dax.ps1 -Port 51234 -Dax 'EVALUATE ROW("AOI", [Adjusted Operating Income])'
```

Test a candidate measure WITHOUT adding it to the model, using `DEFINE MEASURE`:
```
.\scripts\test-dax.ps1 -Port 51234 -Dax @'
DEFINE MEASURE 'Sales'[Test Margin %] = DIVIDE ( [Total Margin], [Total Revenue] )
EVALUATE ROW ( "Margin", 'Sales'[Test Margin %] )
'@
```

Assert an expected value (non-zero exit on mismatch) for use in the quality gate:
```
.\scripts\test-dax.ps1 -Port 51234 -Dax 'EVALUATE ROW("R", [Total Revenue])' -ExpectColumn "[R]" -ExpectValue 190000 -Tolerance 0.01
```

## Workflow

1. Write the candidate with `DEFINE MEASURE`.
2. Evaluate against a row/context where you know the answer (a published figure, a hand calc, last year's report).
3. Compare. If wrong, fix and repeat — never ship an unverified measure.
4. Once correct, author it for real with `scripts/add-measures-from-spec.ps1` and re-test in place.

## Notes

- `DEFINE MEASURE` measures exist only for that query — perfect for pre-commit testing without mutating the model.
- For tables, return `EVALUATE <table-expression>` and inspect the rows.
- Quote DAX with a single-quoted here-string (`@'...'@`) so PowerShell does not interpolate `$`/backtick (per the PowerShell tool notes).
