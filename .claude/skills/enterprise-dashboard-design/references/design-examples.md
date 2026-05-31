# Worked Design Examples

Two reference dashboards that exemplify the standards this skill enforces. Use them as concrete targets when deciding layout, theming, KPI design, and visual selection. Both images ship with the skill in `../assets/examples/`.

- **Example 1 — Executive operational dashboard (dark, branded):** `../assets/examples/altitude-hospitality-overview.png`
- **Example 2 — Financial statement report (light, IBCS):** `../assets/examples/income-statement-ibcs.png`

They are deliberately different archetypes. Match the one whose *job* fits the request: Example 1 for an executive/operational overview; Example 2 for a finance/variance report. Do not copy the cosmetics blindly — copy the principles.

---

## Example 1 — "Altitude Hospitality Performance Overview"

A branded executive overview on a dark navy theme with gold accents and cream content cards.

### What it does well (emulate these)
- **Clear detail gradient (3-30-300).** Header/brand at the top; a single row of KPI cards; trend + breakdown charts in the middle band; narrative insights on the right. Most important and least detailed is top-left.
- **Branded, consistent theme.** One navy/gold/cream palette applied through a theme, not per-visual. Rounded card containers, consistent corner radius, shadows kept subtle. This is the `theme-and-branding.md` standard realized.
- **KPI cards that carry meaning.** Six KPIs (Total Revenue, Occupancy Rate, ADR, RevPAR, Avg Satisfaction Score, Recommend Rate), each with an icon, label, value, **and a trend delta** (green up-triangle / red down-triangle + %). Color is paired with an arrow shape — accessible, not color-alone. Values are rounded at summary level.
- **Persistent left navigation** with icon + label per page (Overview, Revenue, Occupancy, Guest Experience, Loyalty, Channels, Properties, Trends, Insights) — consistent wayfinding across the report.
- **Combo chart with dual axis** ("Performance Over Time": navy columns = Total Revenue, gold line = ADR) with a clear legend — the right visual for "magnitude + rate over time".
- **Sorted horizontal bar** ("Dynamic Performance Breakdown") descending by value (Resort > Urban Hotel > Boutique > Business > Family Resort) — comparison done correctly.
- **Field-parameter dropdowns** ("Metric View", "Business Breakdown") let one chart re-express many measures/dimensions — reduces visual count without losing flexibility.
- **Narrative "Key Insights" panel** — icon + bold headline + one supporting sentence each (Revenue up, Occupancy improved, Guest satisfaction strong, Recommend rate increased). Turns numbers into takeaways.
- **Context chrome:** a "Data as of: May 31, 2025" refresh stamp, a Date + Region slicer grouped in a corner card, and a footer restating the active Metric View / Business Breakdown and the brand tagline.

### Watch-outs when adapting
- Dark themes must still clear **WCAG AA contrast** (>= 4.5:1) for the small KPI labels and axis text — verify, do not assume.
- A hero/background image (the resort photo) is acceptable as brand chrome but must not sit behind data or reduce legibility.
- Keep the KPI row to ~6; more becomes a scoreboard nobody reads.

### Maps to
`report-layout-ux.md` (detail gradient, KPI target+trend, <=3 slicers via the corner card), `theme-and-branding.md` (single branded palette), `accessibility-checklist.md` (color + arrow, contrast), `visual-selection-guide.md` (combo for magnitude+rate, sorted bars for comparison).

---

## Example 2 — "Income Statement" (IBCS-style P&L)

A clean, light financial report — the reference for **finance/variance reporting** and IBCS conventions.

### What it does well (emulate these)
- **IBCS-style P&L matrix.** A hierarchy (Revenue > Products Sales / Misc Income / Other; Cost of Goods Sold; Gross Profits; Operating Expenses > each expense line) with expand/collapse (+/-). Columns deliver full variance context: **CY, CY % Rev, PY, PY % Rev, Δ PY, Δ% PY, Δ% Rev (CY-PY) in basis points**. This is how finance audiences expect to read a statement.
- **Restraint ("subtract, don't add").** No heavy gridlines or banding; whitespace separates rows; the eye goes to the numbers. Full precision shown (this is the detail layer — no display-unit rounding in the matrix).
- **Negatives in red parentheses** only — sentiment color reserved for actual negatives, never decorative.
- **KPI cards with prior-year comparison.** Revenue, COGS, Gross Profit, EBITDA, EBIT, Net Profit — each shows the value plus **PY, Change ($), and % Change** with a green/red arrow. Same "target + gap" principle as Example 1, in a finance idiom.
- **Unit toggle** ("Thousand" / "Absolute") — lets the reader switch scale without rebuilding the visual.
- **Auto-narrative "Summary for Revenue"** — bullet points generated from the data ("Revenue improved modestly toward period end", "Peak revenue contribution was recorded in May-24") turn the table into a story.
- **CY vs PY overlay line** with data labels — current vs prior year on one axis, immediately showing where the year diverged.
- **Slicers grouped top-right** (date range, Year, Quarter) — consistent filter placement, off the main reading path.

### Watch-outs when adapting
- IBCS density is correct **for finance**; do not bring this column count to an executive overview — that audience needs Example 1's altitude.
- Basis-point and %-of-revenue columns must use correct format strings driven by model measures (see `semantic-model-architect` naming/formatting standard), not visual-level overrides.
- Keep variance columns the *only* place conditional formatting/color appears — "format everything = format nothing".

### Maps to
`visual-selection-guide.md` (matrix for hierarchy, CY/PY line, IBCS variance), `report-layout-ux.md` (KPI PY+gap, grouped slicers), `report-performance.md` (one dense matrix beats a dozen small visuals), `accessibility-checklist.md` (red for negatives + sign, not color-alone).

---

## How to use these in a build

1. Pick the archetype that matches the request (executive overview vs finance/variance).
2. Reproduce the **principles** — detail gradient, branded theme, KPI target+trend, sorted/sensible visuals, narrative panel, grouped slicers, refresh stamp — not the literal colors or logos.
3. Apply the workspace theme (`../assets/enterprise-theme.json`) or the client brand; verify contrast.
4. Validate with `../scripts/validate-report.ps1` and the `accessibility-checklist.md` before handoff.
