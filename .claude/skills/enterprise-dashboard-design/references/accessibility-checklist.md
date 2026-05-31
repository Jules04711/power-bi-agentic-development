# Accessibility Checklist (WCAG 2.1 AA)

Run this before handoff. Each item maps to a PBIR setting (delegate JSON detail to `pbir-format`).

## Perceivable
- [ ] **Alt text** on every data visual (`visualContainerObjects.general.altText`). Describe what the visual shows, not "chart".
- [ ] **Text contrast** >= 4.5:1 (normal), >= 3:1 (>= 18pt / bold 14pt). Verify against background.
- [ ] **Not color alone** — pair color encodings with icons/labels/patterns (e.g. up/down arrows on KPIs).
- [ ] **Colorblind-safe palette** — avoid red/green adjacency; prefer the blue-led enterprise palette.
- [ ] **Font size** >= 12pt for body, >= 14pt charts, titles 16-24pt, KPI values large.

## Operable
- [ ] **Tab order** set deliberately per page (logical reading order; hide decorative items from tab order).
- [ ] **Minimal motion** — avoid animations; no auto-playing transitions.
- [ ] **Minimal shadows** — `dropShadow.show = false` in the theme (vestibular safety).
- [ ] Interactive elements reachable by keyboard.

## Understandable
- [ ] Page has a clear title; visuals have meaningful titles (or are intentionally title-less with alt text).
- [ ] Consistent layout/navigation across pages.
- [ ] Number formatting consistent and driven by model measures.

## Robust
- [ ] Report opens and validates (`pbir validate`).
- [ ] No reliance on custom fonts that may not render.

## How to verify quickly
- Contrast: compute luminance ratio for each text/background pair; reject < 4.5:1.
- Alt text + tab order: inspect each `visual.json` for the relevant properties.
- Palette: confirm `dataColors` matches the accessible enterprise theme.

The plugin `review-report` skill can perform a broader objective audit; this checklist is the accessibility-specific gate.
