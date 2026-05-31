# Theme & Branding

A theme provides default styles for all visuals so the report is consistent and on-brand without per-visual fiddling. Always ship a custom theme; never use a default Power BI theme. Apply/edit via the `modifying-theme-json` plugin skill.

## Theme JSON structure

```json
{
  "name": "Enterprise",
  "dataColors": ["#2A6FB0", "#5AA9E6", "#7FB069", "#E8A33D", "#C25B56", "#6C6F7D", "#9B8BBF", "#3C8D8A"],
  "foreground": "#1A1A1A",
  "background": "#FFFFFF",
  "tableAccent": "#2A6FB0",
  "visualStyles": {
    "*": {
      "*": {
        "*": [{ "fontFamily": "Segoe UI", "fontSize": 11 }],
        "dropShadow": [{ "show": false }]
      }
    }
  }
}
```

- `dataColors` — the categorical palette. Keep it muted, colorblind-safe (avoid red/green adjacency), and ordered so the first colors are the most-used.
- Wildcard `visualStyles["*"]["*"]` sets global defaults (font, shadows off).
- Visual-type overrides (e.g. `lineChart`) set per-type defaults.

## Theme vs visual

| Scenario | Edit |
|----------|------|
| All visuals of a type need a change | Theme |
| Establishing standards | Theme |
| Single one-off exception | Visual |
| Content-specific highlight | Visual (or extension measure) |

## Color discipline

- Prefer theme colors (`ThemeDataColor`) over hard-coded hex in visuals.
- Sentiment colors (red/orange) only for negative sentiment; never decorative.
- Reserve a strong accent for the one thing you want noticed; mute everything else (pre-attentive attention steering).
- Verify contrast (see accessibility checklist).

## Branding

- Use the organization's primary/secondary brand colors as the first `dataColors` and `tableAccent`, adjusted if needed to meet contrast.
- Fonts: Segoe UI / Segoe UI Semibold only (guaranteed to render). No custom fonts.
- Logo/title in a consistent header zone across pages.

`assets/enterprise-theme.json` is a ready, accessible starting point — swap the brand colors and apply with `scripts/apply-theme.ps1`.
