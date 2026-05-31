# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this workspace is

A **Power BI Project (PBIP)** workspace, not a software repository. There is no build system, no test suite, and no package manager. The single artifact is `STLA_Power_BI/STLA_20-F_Model.pbip` — a thick PBIP project (byPath connection to a co-located semantic model). The "code" is split across three layers:

- **TMDL** (`STLA_20-F_Model.SemanticModel/definition/**/*.tmdl`) — tabular model: tables, columns, measures, relationships, M expressions.
- **PBIR** (`STLA_20-F_Model.Report/definition/**/*.json`) — report layout: pages, visuals, theme.
- **PowerShell automation** (`STLA_Power_BI/.claude/scripts/*.ps1`) — TOM-based scripts that author the model programmatically.

The parent folder name reflects the **Power BI Agentic Development** plugin ecosystem that ships the skills used here — `connect-pbid`, `pbir-cli`, `pbir-format`, `tmdl`, `pbip`. Skills are loaded with the `Skill` tool and cached at `~/.claude/plugins/cache/power-bi-agentic-development/` (under a `<category>/26.20/skills/<name>/` path).

On top of those granular plugin skills, this workspace ships its own **project-local enterprise skills** in `.claude/skills/` — the opinionated methodology + gating layer for building production-ready models and dashboards. They *delegate to* the plugin skills, never duplicate them. See `.claude/skills/README.md` for the index and `.claude/skills/AUTHORING.md` for the authoring contract.

## Working with the model: critical sequencing

Edits to TMDL/PBIR happen against a **running** Power BI Desktop instance and/or **on disk while PBI Desktop is closed**. Mixing the two corrupts state. The rules:

1. **TOM writes are in-memory only.** `$model.SaveChanges()` updates the running Analysis Services process, *not* the TMDL files on disk. To persist, either Ctrl+S in PBI Desktop, or use `[Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder($db, $tempPath)` and copy the resulting `.tmdl` files into the project while PBI Desktop is closed.
2. **PBI Desktop does not watch its files.** Editing `page.json` / `visual.json` / TMDL while PBI Desktop is open is silently ignored, and the next save overwrites your changes. Always `Stop-Process PBIDesktop, msmdsrv` before editing report files.
3. **Calculated tables need a `calculate` refresh** after creation. Without it, queries fail with *"calculated table … does not hold any data."* Use `$server.Execute('{ "refresh": { "type": "calculate", "objects": [{ "database": "<dbName>" }] } }')`.
4. **`pbir add page` rejects byPath thick reports** — pbir cannot query a local PBI Desktop AS. For this project, write `page.json` + `visual.json` directly via the `pbir-format` skill and validate with `pbir validate`.

## Common commands

### Discover the running PBI Desktop AS port
```powershell
$pid_msmd = (Get-Process msmdsrv).Id
$port = (netstat -ano | Select-String "LISTENING" |
         Where-Object { ($_ -split "\s+")[-1] -eq "$pid_msmd" } |
         ForEach-Object {
             $parts = ($_ -split "\s+") | Where-Object { $_ -ne "" }
             if ($parts[1] -match ":(\d+)$") { $matches[1] }
         } |
         Sort-Object -Unique |
         Where-Object { [int]$_ -gt 1024 } |
         Select-Object -First 1)
```
Note: don't `[2]`-index into the split tokens — IPv4 (`TCP 127.0.0.1:<port>`) and IPv6 (`TCP [::1]:<port>`) `LISTENING` rows split into different column counts. Match `:(\d+)$` against the LocalAddress token and filter `> 1024` to drop the small set of kernel-reserved ports also listening on `msmdsrv`'s PID.

### Run the model-authoring scripts (in order)
```powershell
& .\STLA_Power_BI\.claude\scripts\add-aoi-measures.ps1 -Port <port>     # 82 measures
& .\STLA_Power_BI\.claude\scripts\add-region-dim.ps1   -Port <port>     # 2 calc tables + 6 dynamic measures
& .\STLA_Power_BI\.claude\scripts\build-aoi-overview-page.ps1            # PBIR page (run while PBI Desktop closed)
```

### Dump the full model to JSON (for documentation / diffing)
```powershell
& .\STLA_Power_BI\.claude\scripts\extract-model-metadata.ps1 -Port <port> -OutputPath tmp\model_snapshot.json
```
Emits a structured JSON snapshot of database metadata, query groups, expressions, all tables (with columns + measures + partitions + hierarchies), relationships, roles, cultures, perspectives, dataSources, and an aggregate `counts` block. ~530 KB JSON for the current 25-table / 88-measure model; runs in ~5 s. Used to regenerate `STLA_Power_BI/docs/Semantic_Model_Reference.md`.

### Validate the report
```bash
# pbir is installed under miniconda3 — add to PATH first
export PATH="/c/Users/golfc/miniconda3/Scripts:$PATH"
pbir -q validate "STLA_20-F_Model.Report"
pbir -q --json validate "STLA_20-F_Model.Report"   # machine-readable
```

### Query the model with DAX (PBI Desktop must be open)
```powershell
Add-Type -Path "$env:TEMP\tom_nuget\Microsoft.AnalysisServices.AdomdClient.retail.amd64\lib\net45\Microsoft.AnalysisServices.AdomdClient.dll"
$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection
$conn.ConnectionString = "Data Source=localhost:$port"
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "EVALUATE ROW(`"AOI`", [Adjusted Operating Income])"
$reader = $cmd.ExecuteReader()
while ($reader.Read()) { Write-Output $reader.GetValue(0) }
$conn.Close()
```

### Backup & restore
```powershell
# Backup
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item .\STLA_Power_BI\STLA_20-F_Model.SemanticModel ".\STLA_Power_BI\.claude\backups\$stamp\" -Recurse
Copy-Item .\STLA_Power_BI\STLA_20-F_Model.Report        ".\STLA_Power_BI\.claude\backups\$stamp\" -Recurse

# Restore (close PBI Desktop first)
Get-Process PBIDesktop, msmdsrv -ErrorAction SilentlyContinue | Stop-Process -Force
$b = ".\STLA_Power_BI\.claude\backups\<timestamp>"
Remove-Item .\STLA_Power_BI\STLA_20-F_Model.SemanticModel, .\STLA_Power_BI\STLA_20-F_Model.Report -Recurse -Force
Copy-Item "$b\STLA_20-F_Model.SemanticModel" .\STLA_Power_BI\ -Recurse
Copy-Item "$b\STLA_20-F_Model.Report"        .\STLA_Power_BI\ -Recurse
```

## Architecture: how the AOI Overview page actually works

The `AOI_FY2025` table is **wide-format** scraped HTML — one row per P&L line item, one column per segment, numeric values stored as **strings** with thousand separators, parenthesised negatives, and em-dash for blanks. The reusable parse pattern (see `docs/AOI_Overview.md` §4.2):

```dax
VAR _raw = CALCULATE ( SELECTEDVALUE ( 'AOI_FY2025'[<col>] ),
                       ALL ( 'AOI_FY2025' ),
                       'AOI_FY2025'[Index] = <line> )
VAR _c   = TRIM ( SUBSTITUTE ( SUBSTITUTE ( SUBSTITUTE ( SUBSTITUTE (
              _raw, ",", "" ), "(", "-" ), ")", "" ), "—", "" ) )
RETURN  IF ( _c IN { "", "-" }, BLANK(), VALUE ( _c ) )
```

Every "core" measure is a thin wrapper around this pattern with a different `[<col>]` × `[Index]`. The `Region` and `AdjustmentBridge` calculated tables are **disconnected** dims — visuals dispatch on `SELECTEDVALUE('Region'[Region])` via SWITCH-based dynamic measures (`Region AOI`, `Region Net Revenues`, etc.) so a single matrix visual can iterate by region.

The page's three forward-looking constants live in DAX (`VCP Cost Save Target 2028 = 6000`, `2030 Revenue Target = 190000`, `2030 AOI Margin Target % = 0.07`) so the scenario logic is auditable in the measure list — no magic numbers in the visual layer.

## Key references

- `STLA_Power_BI/docs/AOI_Overview.md` — full developer documentation: PBIP structure, all 88 measures by display folder, page layout, end-to-end build transcript, reproduction guide, caveats.
- `STLA_Power_BI/docs/Semantic_Model_Reference.md` — end-to-end reference for the `STLA_20-F_Model` semantic model: every table, column, measure, relationship, M expression, plus security/governance posture and Mermaid ERD/lineage diagrams. Regeneratable via `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1`.
- `STLA_Power_BI/docs/Risk_Tab.md` — end-to-end developer documentation for the Risk tab (`20f_risk_section`, `RiskCategories_Config`, `fnCountPattern`, `risk_heatmap`, Python heatmap visual).
- `knowledge-base/lessons-learned-best-practices.md` — persistent cross-session gotchas and working patterns (TOM/ADOMD, TMDL authoring, PBIR, DAX patterns, calculated tables, M for PDF sources, refresh order, PS 5.1 UTF-8 quirks, etc.). Read this first before any non-trivial TMDL or PBIR change; add to it after any new gotcha is discovered.
- Skill cache: `~/.claude/plugins/cache/power-bi-agentic-development/` — the `pbi-desktop:connect-pbid` skill is the canonical reference for TOM PowerShell patterns.
- NuGet packages (cached at `%TEMP%\tom_nuget\`): `Microsoft.AnalysisServices.retail.amd64` (TOM) and `Microsoft.AnalysisServices.AdomdClient.retail.amd64` (ADOMD.NET). Reinstall with `nuget install <pkg> -OutputDirectory $env:TEMP\tom_nuget -ExcludeVersion` if missing.
- `.claude/skills/README.md` — index of the five project-local enterprise skills (below). `.claude/skills/AUTHORING.md` — the shared authoring contract (frontmatter schema, "delegate don't duplicate" map, cross-skill interlock order, dogfood rule).

## Project-local enterprise skills (`.claude/skills/`)

Five opinionated skills that take a solution from requirements to a production-ready, enterprise-grade deliverable. Each has a `SKILL.md`, deep-dive `references/*.md`, and `scripts/*.ps1` that mirror this workspace's TOM/ADOMD/`pbir` patterns. They are loaded automatically when the user's request matches their triggers, and they delegate mechanics to the plugin skills (`tmdl`, `dax`, `pbir-format`, `bpa-rules`, `connect-pbid`, etc.).

| Skill | Covers | Key scripts |
|-------|--------|-------------|
| `semantic-model-architect` | Star schema, marked date table, storage mode, partitions/incremental refresh, naming & formatting, model hygiene | `disable-auto-datetime.ps1`, `validate-model-shape.ps1` |
| `dax-measure-engineering` | Correct + performant + **tested** DAX, time intelligence, calc groups, format strings; researches functions at <https://learn.microsoft.com/en-us/dax/> | `test-dax.ps1`, `add-measures-from-spec.ps1` |
| `relationship-and-model-integrity` | Cardinality, cross-filter direction, ambiguity, inactive/role-playing, RLS/OLS | `validate-relationships.ps1`, `add-relationships-from-spec.ps1`, `test-rls.ps1` |
| `enterprise-dashboard-design` | PBIR layout/UX, theming/branding, WCAG AA accessibility, visual selection, report performance; two worked design examples in `assets/examples/` | `validate-report.ps1`, `apply-theme.ps1` |
| `production-readiness-gate` | End-to-end orchestration + consolidated quality gate, PBIP source control, deployment/CI-CD, BPA gate | `run-quality-gate.ps1`, `pbip-backup.ps1` |

Canonical end-to-end order: `power-query` (plugin) → `semantic-model-architect` → `relationship-and-model-integrity` → `dax-measure-engineering` → `enterprise-dashboard-design` → `production-readiness-gate`. The gate's `run-quality-gate.ps1` aggregates the four validators above plus `pbir validate` into a single PASS/FAIL verdict. See `knowledge-base/lessons-learned-best-practices.md` §13 for skill-authoring gotchas.

## Project-specific gotchas

- **Compatibility level is 1600** — DAX UDFs are not available, so the repeating SUBSTITUTE parse pattern cannot be refactored into a single function.
- **Auto Date/Time is enabled** (`__PBI_TimeIntelligenceEnabled = "1"`), producing 8 hidden auto-generated date tables — `1 × DateTableTemplate_*` + `7 × LocalDateTable_*`, one per `date` / `dateTime` column. They inflate `pbir tree` output and `model.Tables.Count` but are unrelated to the AOI work. The user-defined `Date` table is NOT joined to any fact; all 8 active date relationships flow through the auto-generated shadows.
- The **`OTHER(*)` column** in `AOI_FY2025` has a literal `(*)` footnote marker in the name; DAX references must keep the parentheses: `'AOI_FY2025'[OTHER(*)]`.
- The FY2025 source URL (`sec.gov/Archives/.../stellantisnvfy2025pressrel.htm`) returns HTTP 403 to direct `WebFetch`. The data still flows in via Power Query's `Web.BrowserContents` partition on `AOI_FY2025`.
- This is a **thick (byPath)** report. `pbir model -q` and `pbir add page` do not work; use TOM (via the `connect-pbid` skill) for any model query or modification.
- **Live model entity counts** (compatibility level `1600`): 25 tables (16 visible), 9 relationships (8 auto-LocalDateTable + 1 user `Company_Name`↔`CIK_Lookup`), 88 measures (all on `AOI_FY2025`), 6 shared M expressions, 3 query groups (`SEC Queries`, `EDGAR 20-F`, `Text Analysis`), 0 roles, 0 perspectives, 1 culture (`en-US`, `translationCount = 0`). See `STLA_Power_BI/docs/Semantic_Model_Reference.md` for the full breakdown.
- **Windows PowerShell 5.1 corrupts UTF-8 when round-tripping fragments** through `Get-Content -Raw` + `Out-File -Encoding utf8`. Symptoms: `—` becomes `â€"`, `§` becomes `Â§`. For any multi-file Markdown / TMDL / JSON assembly, use `[System.IO.File]::ReadAllText(path, [System.Text.Encoding]::UTF8)` and `[System.IO.File]::WriteAllText(path, content, (New-Object System.Text.UTF8Encoding($false)))` instead. PowerShell 7+ does not have this issue.
