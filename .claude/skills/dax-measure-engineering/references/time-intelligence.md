# Time Intelligence

## Prerequisite: a real date table

Time-intelligence functions require an explicit `Date` table that is:
- marked as a date table (`dataCategory: Time`) with a `Date` key column,
- contiguous daily with no gaps,
- spanning the full range of fact dates,
- related to facts via a single-column relationship.

Missing any of these makes `DATEADD`, `SAMEPERIODLASTYEAR`, `TOTALYTD` return BLANK. Do not depend on Auto Date/Time shadow tables. See `semantic-model-architect`.

## Standard measures

```dax
Revenue YTD   = TOTALYTD ( [Total Revenue], 'Date'[Date] )
Revenue PY    = CALCULATE ( [Total Revenue], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )
Revenue YoY   = [Total Revenue] - [Revenue PY]
Revenue YoY % = DIVIDE ( [Revenue YoY], [Revenue PY] )
Revenue MAT   = CALCULATE ( [Total Revenue], DATESINPERIOD ( 'Date'[Date], MAX ( 'Date'[Date] ), -12, MONTH ) )
```

Running total:
```dax
Revenue Running =
CALCULATE ( [Total Revenue],
    FILTER ( ALL ( 'Date'[Date] ), 'Date'[Date] <= MAX ( 'Date'[Date] ) ) )
```

Fiscal year not ending in December — pass the year-end date:
```dax
Revenue FYTD = TOTALYTD ( [Total Revenue], 'Date'[Date], "06-30" )
```

## Role-playing dates (USERELATIONSHIP)

Keep one `Date` table; relate Order Date (active) and Ship Date (inactive); switch per measure:
```dax
Revenue by Ship Date =
CALCULATE ( [Total Revenue], USERELATIONSHIP ( 'Sales'[Ship Date], 'Date'[Date] ) )
```
See `relationship-and-model-integrity` for the relationship setup.

## Pitfalls

- Time intelligence inside a measure that already removes the date filter (`ALL('Date')`) returns surprising results — apply time intel before removing context.
- Comparing partial current period vs full prior period overstates growth; gate with an `IsCompletePeriod` flag or compare like-for-like windows.
- `DATESYTD`/`TOTALYTD` need dates from the marked `Date` table column, not a fact date column.
