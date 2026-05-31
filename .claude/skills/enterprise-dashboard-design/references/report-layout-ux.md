# Report Layout & UX

## Detail gradient (3-30-300)

Most important + least detailed top-left; least important + most detailed bottom-right.

```
+------------------+------------------+
|   KPIs / Cards   |   KPIs / Cards   |  top: headline numbers
+------------------+------------------+
|        Charts / Trends              |  middle: context, trend
+------------------+------------------+
|        Tables / Detail              |  bottom: drill-down
+------------------+------------------+
```

## Grid math

Compute every position from four numbers so alignment is exact:
- `margin` (edge gap), e.g. 24px
- `gap` (between visuals), e.g. 16px
- `page_width`, `page_height` (read from `page.json` — do not assume 1280x720)

For `n` equal columns: `col_width = (page_width - 2*margin - (n-1)*gap) / n`; `x_k = margin + k*(col_width + gap)`. Same logic vertically. Every horizontal gap equals every other; every margin equals every other. Unequal spacing is the single most visible quality defect.

## Page rules

- Every page has a **title** (textbox, top-left, x=24 y=24, ~h=48-64).
- <= 5-8 pages per report; split by audience/topic, not by cramming.
- Keep visual sizes consistent within a row/zone.
- Include helpful context: last-refresh date, a one-line "how to read this" where needed.

## Cards & KPIs

A bare number is meaningless. Each KPI answers:
- **Good or bad?** show a target and the gap (absolute + %).
- **Better or worse?** show a trend (sparkline / trend line).
Use the `kpi` visual when a target measure exists (built-in indicator/goal/trend). If no target exists, ask the user (prior period? budget? threshold?) rather than leaving it bare. Conditional-format the **gap**, not the primary value; pair color with an arrow/icon for accessibility; round aggressively (`518M`, not `517,893,412`).

## Slicers

- <= 3 per page; use the filter pane for the rest.
- Consistent placement (top or left).
- Sync across pages when the same filter applies.

## Anti-patterns

- Kitchen-sink pages with no single question.
- Decorative imagery that adds no information.
- Inconsistent gaps / unaligned visuals.
- More than 3 slicers on the canvas.
- KPIs with no target or trend.
