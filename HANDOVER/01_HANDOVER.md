# Session Handover

> Generated: 2026-05-27 | Project: Power BI Agentic Development / STLA_Power_BI

## Session Summary

The user opened `STLA_Power_BI/STLA_20-F_Model.pbip` (Stellantis 20-F PBIP project) and asked me to (1) connect to it, (2) build DAX measures on the `AOI_FY2025` table to analyze FY2025 Adjusted Operating Income and the €6 B Value Creation Program cost-cut commitment from Stellantis' FaSTLAne 2030 strategy, (3) build a report page presenting those measures, and (4) document everything for other Power BI developers. We delivered 88 measures, 2 calculated tables, a complete `AOI Overview` report page (11 visuals), full developer documentation (`docs/AOI_Overview.md`), and a workspace `CLAUDE.md`.

## What Was Done

- **Installed tooling** — NuGet CLI (`winget install Microsoft.NuGet`), TOM (`Microsoft.AnalysisServices.retail.amd64` 19.84.1), ADOMD.NET (`Microsoft.AnalysisServices.AdomdClient.retail.amd64` 19.84.1), and `pbir-cli` 0.9.21 (`py -3.11 -m pip install pbir-cli`, installed at `C:\Users\golfc\miniconda3\Scripts\pbir.exe`).
- **Connected to PBI Desktop's local Analysis Services** via TOM PowerShell, discovered port through `netstat -ano | findstr <msmdsrv PID>`.
- **Authored `STLA_Power_BI/.claude/scripts/add-aoi-measures.ps1`** — creates 82 measures on `AOI_FY2025` across folders `1. AOI Core`, `2. AOI by Region`, `3. Revenue by Region`, `4. Margin by Region`, `5. Adjustment Bridge`, `6. FaSTLAne 2030 Targets`, `7. VCP Save Allocation`. All measures parse the wide-format string-encoded AOI table.
- **Authored `STLA_Power_BI/.claude/scripts/add-region-dim.ps1`** — creates two calculated tables (`Region`, `AdjustmentBridge`), sorts `Region[Region]` by `Region[Sort]`, and adds 6 dynamic SWITCH-dispatching measures (`Region AOI`, `Region Net Revenues`, `Region AOI Margin %`, `Region Pro-Forma AOI`, `Region VCP Save Allocation`, `Adjustment Value`).
- **Authored `STLA_Power_BI/.claude/scripts/build-aoi-overview-page.ps1`** — writes `STLA_20-F_Model.Report/definition/pages/AOIOverview/page.json` plus 11 `visual.json` files (title textbox, 4 KPI cards, region pivotTable, adjustment barChart, 4 strategic-narrative cards), and updates `pages.json` to set `AOIOverview` as `activePageName`.
- **Persisted runtime model changes to TMDL** via `[Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder($db, $tempPath)`, then file-copied `AOI_FY2025.tmdl`, `Region.tmdl`, `AdjustmentBridge.tmdl`, and `model.tmdl` into the project's `STLA_20-F_Model.SemanticModel/definition/` folder.
- **Created backup** at `STLA_Power_BI/.claude/backups/20260527_123038/` containing pre-change copies of both `STLA_20-F_Model.SemanticModel` and `STLA_20-F_Model.Report`.
- **Validated** with `pbir validate "STLA_20-F_Model.Report"` — 0 errors on the AOI Overview page (warnings are pre-existing `SCHEMA_DEGRADED` on `visualContainer/2.9.0` from local schema cache).
- **Verified live values via ADOMD** — AOI = -842, AOI Margin = -0.55%, Gap to 2030 AOI Target = 14,142, Gap Closed by VCP = 42.4%, Pro-Forma AOI = 5,158, Strategic Realignment Charges = 15,898, One-Time Non-Recurring = 4,285, Annual Lift Required = 2,828.4.
- **Wrote `STLA_Power_BI/docs/AOI_Overview.md`** (604 lines, 10 sections) — full developer documentation: data sources, PBIP project structure, semantic model additions with TMDL, full measure catalog by display folder, page specification with ASCII layout diagram, agentic development framework + skills used, end-to-end command transcript, reproduction guide, known caveats.
- **Wrote workspace `CLAUDE.md`** at `C:\Users\golfc\OneDrive\Desktop\Power BI Agentic Development\CLAUDE.md` — high-level architecture, critical sequencing rules, common commands, project-specific gotchas.

## What Worked & What Didn't

### Worked Well
- **TOM via PowerShell** for adding measures and calculated tables — engine validates DAX on `SaveChanges()`, so any syntax error surfaced immediately. 82 measures landed cleanly on first save.
- **String-parse pattern in DAX** (`SUBSTITUTE` chain + `VALUE`) to convert wide-format string-encoded financial data ("60,962", "(842)", "—") to numerics. Reused identically in 60+ measures.
- **`TmdlSerializer.SerializeDatabaseToFolder`** for persisting runtime model state to TMDL after PBI Desktop was closed without saving. Diff against project showed only the 3 changed table files + 2 added `ref table` lines in `model.tmdl` — clean round-trip.
- **Direct PBIR JSON write** for the report page once `pbir add page` failed. Authoring `page.json` + `visual.json` files from PowerShell with `ConvertTo-Json -Depth 30` and matching the schema versions already in use (`visualContainer/2.9.0`, `page/2.1.0`) produced visuals that PBI Desktop opened without complaint.
- **Disconnected calculated dim tables (`Region`, `AdjustmentBridge`) with SWITCH-dispatching dynamic measures** so a single matrix/bar visual can iterate by region or adjustment line.

### Issues Encountered
- **PBI Desktop closed without saving after first measure batch** — all 87 TOM-added measures + 2 calc tables were lost (they lived only in the running AS process). **Resolution**: re-launched PBI Desktop, re-ran the same scripts, this time used `TmdlSerializer` to write the runtime state to TMDL files on disk, then killed PBI Desktop and copied the TMDL files in before re-launching.
- **`pbir add page` returned `Thin reports require a connection (workspace + model)`** even though `pbir connect` warned this was a thick byPath report. **Resolution**: skipped pbir CLI for page creation; built `page.json` and `visual.json` directly via PowerShell, then validated structure with `pbir validate`.
- **Calculated tables returned `does not hold any data because it needs to be recalculated or refreshed`** on first query. **Resolution**: ran `$server.Execute('{ "refresh": { "type": "calculate", "objects": [{ "database": "<dbName>" }] } }')` after creating them.
- **PBI Desktop's `msmdsrv` got a new port on every re-launch** (`58907` → `61273` → `61865` → `64623` across the session). **Resolution**: always re-discovered via `netstat -ano | Select-String "LISTENING" | Where-Object { ($_ -split "\s+")[-1] -eq "$msmdsrvPid" }`.
- **`WebFetch` against `sec.gov/Archives/.../stellantisnvfy2025pressrel.htm` returned HTTP 403.** **Resolution**: didn't need the URL — the FY2025 data was already scraped into the model via `Web.BrowserContents` in the `AOI_FY2025` Power Query partition.
- **`pip install pbir-cli` failed on the default Python 3.9** (pbir-cli requires 3.10+). **Resolution**: used `py -3.11 -m pip install pbir-cli` to install under the miniconda 3.11.
- **`nuget` was not on PATH** after `winget install Microsoft.NuGet`. **Resolution**: called via full path `C:\Users\golfc\AppData\Local\Microsoft\WinGet\Packages\Microsoft.NuGet_Microsoft.Winget.Source_8wekyb3d8bbwe\nuget.exe` (winget noted PATH would update on next shell restart).

## Key Decisions

| Decision | Reasoning | Alternatives Considered |
|----------|-----------|------------------------|
| Use TOM (PowerShell) instead of hand-edited TMDL for measure creation | DAX is validated server-side on `SaveChanges()`; 88 measures is too many to hand-craft TMDL reliably | Direct TMDL editing (per `pbip:tmdl` skill); Tabular Editor 2 CLI |
| Add disconnected `Region` and `AdjustmentBridge` dim tables with SWITCH dispatch | The `AOI_FY2025` source is wide-format (region as columns), so there's no natural region row dimension. SWITCH lets one matrix visual iterate by region | Create 7 separate measure visuals; reshape `AOI_FY2025` in Power Query (would have touched untested model logic) |
| Write `page.json` / `visual.json` directly when `pbir add page` failed | pbir requires workspace + model for byPath thick reports, which the local PBI Desktop AS cannot satisfy | Convert report to byConnection thin report first (out of scope) |
| Persist via `TmdlSerializer` rather than asking the user to Ctrl+S again | First Save attempt was missed and 87 measures were lost; serializer is mechanical and round-trip-safe for these specific tables | Hand-craft TMDL with `///` descriptions, `lineageTag` GUIDs, multi-line DAX indentation |
| Encode FaSTLAne 2030 targets (€6B, €190B, 7%) as DAX constants in `Folder 6` | Magic numbers belong in the model, not in visuals; auditable, easy to update if Stellantis revises targets | Put values in a parameter table; hardcode in visual.json (worse — invisible to dataset consumers) |
| Allocate VCP save by revenue share | Simple, defensible default that any consumer can override with their own region weights | Allocate by AOI deficit (would over-weight NA); ad-hoc weights (less defensible) |

## Lessons Learned & Gotchas

- **TOM `SaveChanges()` is in-memory only.** It writes to the running PBI Desktop Analysis Services process, NOT to the TMDL files on disk. To persist, either press Ctrl+S in PBI Desktop or use `[Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder($db, $path)` while PBI Desktop is closed.
- **Calculated tables need a `calculate` refresh after creation.** Without it, every query returns `"calculated table <name> does not hold any data because it needs to be recalculated or refreshed"`. TMSL payload: `{ "refresh": { "type": "calculate", "objects": [{ "database": "<dbName>" }] } }`.
- **`pbir add page` rejects byPath thick reports** with `Thin reports require a connection (workspace + model)`. Fall back to direct PBIR JSON authoring; `pbir validate` still works for structure validation on thick reports.
- **PBI Desktop does not watch its files.** Edits to TMDL or PBIR JSON while PBI Desktop is open are silently ignored, and the next save overwrites them. Always `Stop-Process PBIDesktop, msmdsrv -Force` before editing report files on disk.
- **The `msmdsrv` port changes on every PBI Desktop relaunch.** Cache scripts must rediscover via netstat against the current PID, not store the port literal.
- **`TmdlSerializer` dumps to the given folder root**, not into a `definition/` subfolder. The project's TMDL structure is `SemanticModel/definition/tables/*.tmdl` but the dump is `<tempDir>/tables/*.tmdl`. Copy from `<tempDir>/tables/` to `<project>/definition/tables/`.
- **Compatibility level 1600 does not support DAX User-Defined Functions.** The repeating SUBSTITUTE-chain in 60+ measures cannot be refactored into a single function until compat is upgraded to 1610+.
- **PBIR `visual.json` schema is brittle.** Power BI's standard `objects` vs `visualContainerObjects` split matters: `title`, `background`, `border` go under `visualContainerObjects`; `labels`, `categoryAxis`, `valueAxis`, `legend` go under `objects`. Getting the wrong container silently drops the formatting.
- **`pbir-cli` requires Python 3.10+.** Default Anaconda/conda installs of Python 3.9 will not work; use `py -3.11` or install a newer Python.
- **`nuget` from `winget install Microsoft.NuGet` is not on PATH until shell restart.** Call via full path or restart shell after install.
- **The `OTHER(*)` column name carries a literal `(*)` footnote marker.** DAX references must include the parentheses verbatim: `'AOI_FY2025'[OTHER(*)]`.
- **Wide-format scraped tables (one column per dimension value) are common in SEC filings.** They cannot be put into a star schema without unpivoting, but disconnected dim tables + SWITCH dispatch give equivalent slicing UX without touching Power Query.

## Current State

- **Working**: 
  - Power BI Desktop is open at `STLA_20-F_Model.pbip` with `AOI Overview` as the active page.
  - 88 measures on `AOI_FY2025`, 5 measures on `Region` (via dynamic dispatch), 1 on `AdjustmentBridge` — all queried successfully via ADOMD with correct values.
  - `Region` and `AdjustmentBridge` calculated tables populated.
  - 11 visuals on the new page render against the live model.
  - Backup at `STLA_Power_BI/.claude/backups/20260527_123038/`.
- **Broken/Incomplete**: 
  - The legacy `AOI.Page` (`ef0b43dedcae9040717c`) still exists with its original 5 visuals; not consolidated with the new `AOI Overview`.
  - No theme work done on the new page — uses default fonts/colours; report's `CY23SU08.json` theme inherits.
  - Bar chart's series coloring by `AdjustmentBridge[Category]` may pick arbitrary default palette colors (Strategic Reset / Operational / Non-Recurring). Consider mapping to semantic colors (red / amber / grey) via theme.
- **Blocked**: None.

## Next Steps

1. **Visually verify the AOI Overview page in PBI Desktop.** Open the page (it should be the landing page already) and confirm: title textbox renders, 4 KPI cards show the verified values, region matrix sorts in the configured order (NA → Europe → MEA → SA → APAC → Maserati → Other), bar chart sorts descending, 4 bottom cards render. If anything is off-position or blank, edit the corresponding `STLA_20-F_Model.Report/definition/pages/AOIOverview/visuals/<name>/visual.json` with PBI Desktop closed.
2. **Theme the bar chart's `Category` series** with semantic colors. Either set per-data-point colors in `bar_adjustments/visual.json` or extend the report theme `CY23SU08.json` with a `dataPoint` palette section.
3. **Consider unpivoting `AOI_FY2025`** in Power Query into a tall format (`Region`, `LineItem`, `Value`) — this would eliminate the SUBSTITUTE-chain parse pattern and the 7-way SWITCH measures. Trade-off: changes the source table shape, which existing visuals on the legacy `AOI.Page` already bind to.
4. **Extend to FY2024 comparison** by adding an `AOI_FY2024` Power Query partition sourced from the prior year filing, then duplicating the helper-pattern measures with YoY variants.
5. **Optionally publish to a Fabric workspace** and rebind as a byConnection thin report so `pbir add page`, `pbir add visual`, and `pbir model -q` become usable. See `STLA_Power_BI/docs/AOI_Overview.md` §8.2 for the byPath → byConnection rewrite.

## Important Files Map

| File | Purpose | Status |
|------|---------|--------|
| `CLAUDE.md` | Workspace guidance for future Claude Code sessions | created |
| `HANDOVER.md` | This document | created |
| `STLA_Power_BI/docs/AOI_Overview.md` | Full developer documentation for the AOI Overview build | created |
| `STLA_Power_BI/.claude/scripts/add-aoi-measures.ps1` | TOM script creating 82 measures on `AOI_FY2025` | created |
| `STLA_Power_BI/.claude/scripts/add-region-dim.ps1` | TOM script creating `Region`, `AdjustmentBridge` calc tables + 6 dynamic measures | created |
| `STLA_Power_BI/.claude/scripts/build-aoi-overview-page.ps1` | PBIR JSON writer for the new page + 11 visuals | created |
| `STLA_Power_BI/.claude/backups/20260527_123038/` | Pre-change backup of SemanticModel + Report folders | created |
| `STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/tables/AOI_FY2025.tmdl` | 88 measures added | modified |
| `STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/tables/Region.tmdl` | New calc table | created |
| `STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/tables/AdjustmentBridge.tmdl` | New calc table | created |
| `STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/model.tmdl` | +`ref table Region`, +`ref table AdjustmentBridge` | modified |
| `STLA_Power_BI/STLA_20-F_Model.Report/definition/pages/AOIOverview/page.json` | New page config | created |
| `STLA_Power_BI/STLA_20-F_Model.Report/definition/pages/AOIOverview/visuals/*/visual.json` | 11 visual definitions | created |
| `STLA_Power_BI/STLA_20-F_Model.Report/definition/pages/pages.json` | Added `AOIOverview` to pageOrder, set as `activePageName` | modified |

## Environment & Config Notes

- **Platform**: Windows 11, PowerShell 5.1 (`powershell.exe`), Bash via Git Bash.
- **Python**: 3.11 via miniconda at `C:\Users\golfc\miniconda3\` (default `python` is 3.9 — pbir-cli requires `py -3.11`).
- **pbir-cli** at `C:\Users\golfc\miniconda3\Scripts\pbir.exe` — not on PATH by default; prepend `C:\Users\golfc\miniconda3\Scripts` in each shell.
- **NuGet packages** cached at `%TEMP%\tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\` and `%TEMP%\tom_nuget\Microsoft.AnalysisServices.AdomdClient.retail.amd64\lib\net45\` — survive across sessions unless temp is cleaned.
- **Power BI Desktop** is the runtime — needs to be **open** for TOM scripts to work, **closed** for direct TMDL/PBIR file edits.
- **No git repository** in the workspace — the project is not version-controlled. The `.claude/backups/<timestamp>/` folder is the only rollback mechanism.
- **No credentials** required — everything is local. Stellantis data flows in via the `AOI_FY2025` Power Query partition's `Web.BrowserContents` call (which works inside Power BI even though `WebFetch` does not).
- **Skill plugin**: `power-bi-agentic-development` at `~/.claude/plugins/cache/power-bi-agentic-development/`. Relevant skills used this session: `pbi-desktop:connect-pbid`, `reports:pbir-cli`, `pbip:pbir-format`, `pbip:tmdl`.
