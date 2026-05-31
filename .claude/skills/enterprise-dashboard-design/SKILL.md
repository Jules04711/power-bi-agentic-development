---
name: enterprise-dashboard-design
version: 1.0.0
description: Build production-grade Power BI reports and dashboards in PBIR with enterprise UX, theming, accessibility, and performance. Automatically invoke when the user asks to "build a dashboard", "design a report page", "add a visual", "lay out a page", "apply a theme", "brand the report", "make it accessible", "WCAG", "choose a chart", "add slicers / bookmarks / drill-through", "fix report performance", or mentions report layout, KPI cards, or visual selection.
---

# Enterprise Dashboard Design

Builds reports a professional BI team would ship: deliberate layout, branded accessible theme, the right chart for each question, and a performance budget. Decides design; delegates mechanics — PBIR JSON structure to `pbir-format`, CLI ops to `pbir-cli`, design-principle depth to `pbi-report-design`, theme edits to `modifying-theme-json`, review to `review-report`, and custom visuals to `deneb-visuals`/`svg-visuals`/`python-visuals`/`r-visuals`. Honor `../AUTHORING.md`.

## Critical mechanics (thick byPath reports — this project)

Per `CLAUDE.md`:
1. **Stop `PBIDesktop` and `msmdsrv` before editing report files** — Desktop does not watch files and will overwrite your edits on next save.
2. **Write `page.json` / `visual.json` directly** (use `pbir-format`), then **`pbir validate`** (`scripts/validate-report.ps1`).
3. **`pbir add page` / `pbir model` reject byPath thick reports** — do not use them here.
4. Always read the actual `page.json` `width`/`height` before positioning visuals.

## Operating procedure

1. **Define the question per page.** Each page answers a specific decision. No "kitchen-sink" pages. Max ~5-8 pages.
2. **Lay out on a grid.** Detail gradient: KPIs top-left, trends middle, detail tables bottom-right. Equal gaps everywhere (e.g. 16px) and equal edge margins (e.g. 24px) — compute positions arithmetically. Misaligned spacing is the most visible quality defect. See `references/report-layout-ux.md`.
3. **Apply the enterprise theme** (`assets/enterprise-theme.json`) — never ship default Power BI styling. The theme carries brand colors, accessible contrast, muted palette, fonts (Segoe UI), and shadow-off defaults. Apply via `scripts/apply-theme.ps1` / `modifying-theme-json`. See `references/theme-and-branding.md`.
4. **Choose visuals by intent**, not by novelty (`references/visual-selection-guide.md`). Bar for comparison, line for trend, matrix for hierarchy, card/KPI for headline + target. No pie charts past a few slices; no 3D; no chart-junk.
5. **KPIs carry meaning.** Every KPI shows a target and gap ("good/bad?") and a trend ("better/worse?"). Use the `kpi` visual when a target exists. Round aggressively at summary level. Conditional-format the gap, not the value, and pair color with an icon/arrow.
6. **Accessibility to WCAG AA** (`references/accessibility-checklist.md`): alt text on every data visual, 4.5:1 text contrast, 12pt minimum font, set tab order, never rely on color alone, colorblind-safe palette, minimal shadows/motion.
7. **Interactivity with restraint:** max ~3 slicers per page (use the filter pane otherwise); bookmarks for views; drill-through for detail; sync slicers across pages where it helps.
8. **Performance budget** (`references/report-performance.md`): ~12-15 visuals/page max, avoid high-cardinality fields on visuals, reduce the number of queries per page, prefer measures over visual-level calculations.
9. **Validate** with `scripts/validate-report.ps1` (wraps `pbir validate`) and run an accessibility-checklist pass before handoff.

## Defaults

| Decision | Default |
|----------|---------|
| Theme | Custom enterprise theme, shadows off, Segoe UI |
| Layout | Grid, equal gaps + margins, detail gradient |
| Page title | Present (textbox top-left) |
| KPI | `kpi` visual with target + gap + trend |
| Slicers per page | <= 3 (else filter pane) |
| Visuals per page | <= 12-15 |
| Color | Muted, colorblind-safe; sentiment colors only for sentiment |
| Alt text | On every data visual |
| Contrast | >= 4.5:1 text, >= 3:1 large text |

## Dogfood: STLA_20-F_Model.Report

```
.\scripts\validate-report.ps1 -ReportPath "STLA_20-F_Model.Report"
```
Confirm zero validation errors, then run the objective accessibility/layout checklist over the existing AOI Overview page (title present? equal spacing? alt text? <=3 slicers? muted palette?) and report pass/fail per item.

## References

- `references/report-layout-ux.md` — grid math, detail gradient, titles, spacing, page count.
- `references/theme-and-branding.md` — theme JSON structure, brand palette, when theme vs visual.
- `references/accessibility-checklist.md` — WCAG AA items + how to set each in PBIR.
- `references/visual-selection-guide.md` — which chart for which question; anti-patterns.
- `references/report-performance.md` — query reduction, visual budget, high-cardinality.

## Related plugin skills

`pbi-report-design`, `pbir-format`, `pbir-cli`, `modifying-theme-json`, `review-report`, `deneb-visuals`, `svg-visuals`, `python-visuals`, `r-visuals`.
