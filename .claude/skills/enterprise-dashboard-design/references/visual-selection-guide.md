# Visual Selection Guide

Pick the visual that answers the question with the least cognitive load. Visual vocabulary, not novelty.

## By question

| Question | Visual | Notes |
|----------|--------|-------|
| Headline number + target | `kpi` (or card) | Always with target + gap + trend |
| Compare categories | Bar / column | Sort by value desc unless time-based |
| Trend over time | Line | Time on X; one line per series, few series |
| Part-to-whole | Stacked bar / 100% stacked | Avoid pie beyond ~4 slices; never 3D |
| Detail / drill | Matrix or table | Matrix when 2+ categorical levels form a hierarchy |
| Distribution | Histogram / box (Python/R visual) | Use `python-visuals`/`r-visuals` |
| Correlation | Scatter | Add reference lines; beware over-plotting |
| Geographic | Map | Only when geography is the point |
| Variance / bridge | Waterfall | Good for AOI bridges, P&L walks |
| Inline magnitude in a table | Data bars / sparklines (SVG) | Use `svg-visuals` |
| Bespoke interactive chart | Vega/Vega-Lite | Use `deneb-visuals` when native cannot express it |

## Tables vs matrices

- `matrix` when 2+ categorical columns form a hierarchy (Region > Country > City).
- `table` for a flat list of records.
- Subtract, don't add: remove gridlines/heavy banding; let whitespace separate rows.
- Sort by the most important measure (often variance), not alphabetically.
- Data bars on the primary measure; color scale on variance only.
- Tables show full precision (no display units) — they are the detail layer.

## Charts

- Sort by value descending unless time-ordered.
- Minimize gridlines, axes, and labels (information:ink).
- Highlight key points sparingly; mute the rest.
- Few series — if you need a legend of 8+, rethink.

## Anti-patterns

- Pie/donut with many slices; 3D anything; dual axes that mislead.
- Gauges for non-target metrics.
- A visual with no field bindings.
- Decorative charts that encode no data.
- More than ~12-15 visuals on a page (performance + overload).
