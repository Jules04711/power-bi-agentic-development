# Report Performance

A report is fast when each page issues few, cheap queries. Most report slowness is really model slowness (see `dax-measure-engineering` tuning) — but the report layer contributes.

## Budgets

- <= 12-15 visuals per page (each visual is one or more queries). Simple shapes/text/images are cheap exceptions.
- Page should render interactively in ~1s on representative data; investigate > 3s.
- <= 3 on-canvas slicers; the filter pane is cheaper and cleaner.

## Reduce queries

- Fewer visuals; combine where a single visual answers the question.
- Avoid high-cardinality fields on a visual axis (thousands of categories = huge query + unreadable).
- Turn off visual interactions that are not needed (each cross-highlight re-queries other visuals).
- Avoid unnecessary "show items with no data".
- Use bookmarks to swap views instead of stacking many always-on visuals.

## Push work to the model

- Prefer model measures over report-scoped (visual/extension) calculations.
- Pre-aggregate in the model (or aggregations in a composite model) rather than summarizing huge detail at query time.
- Ensure the date table and relationships are correct so time-intel measures don't fall back to expensive scans.

## Diagnose

- Use Performance Analyzer in Desktop to capture per-visual DAX + render time.
- For the slow measures, capture server timings via `connect-pbid` and apply the plugin `dax` tier framework.
- Record the worst visuals per page and their durations so improvements are auditable.

## Checklist
- [ ] Visual count within budget.
- [ ] No high-cardinality axis fields.
- [ ] Slicers <= 3; rest in filter pane.
- [ ] Report-scoped calculations minimized.
- [ ] Worst-visual durations captured and acceptable.
