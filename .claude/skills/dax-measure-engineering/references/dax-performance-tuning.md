# DAX Performance Tuning

Tune only after the measure is correct and tested. For the full tiered framework (Formula Engine vs Storage Engine, xmSQL, SE fusion, model-level fixes) load the plugin `dax` skill and capture server timings via `connect-pbid` performance profiling.

## Diagnosis order

1. **Reproduce** with a representative query (`scripts/test-dax.ps1` or DAX Studio).
2. **Capture server timings** — total duration, SE vs FE split, SE query count, rows scanned. High FE% or many SE queries points at the formula; high SE duration points at the model/data.
3. **Localize** — comment parts out / build up with variables to find the expensive subexpression.
4. **Apply the smallest fix**, re-measure, repeat.

## Common formula-side fixes

- Replace `FILTER(table, col = x)` with `KEEPFILTERS(col = x)`.
- Replace repeated subexpressions with a `VAR`.
- Avoid nested iterators over large tables; push aggregation to `SUM`/`COUNTROWS` where the engine can fold it into the Storage Engine.
- Avoid `IF` around whole table scans; compute the scalar once into a variable.
- Avoid context transition inside large `SUMX`/`FILTER` unless required.
- Replace `COUNTROWS(FILTER(VALUES(...), [m] > 0))` patterns with set-based equivalents where possible.

## Common model-side fixes (hand to semantic-model-architect)

- High-cardinality columns inflating the dictionary — reduce cardinality, split `DateTime`.
- Missing/!poor relationships forcing expensive `FILTER` joins.
- String columns used where numerics belong (forces parse at query time — the project's wide-format issue).
- Bidirectional relationships causing extra SE work — see `relationship-and-model-integrity`.

## Budgets

- Interactive visual query: aim < 1s; investigate > 3s.
- A single measure on a card: should be near-instant; if not, the model is usually the cause.

Record before/after timings so the improvement is auditable.
