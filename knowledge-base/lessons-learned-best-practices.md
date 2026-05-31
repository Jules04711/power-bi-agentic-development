# Lessons Learned & Best Practices

Persistent record of project-specific gotchas, working patterns, and platform quirks discovered across Claude Code sessions in this workspace. Each lesson is specific (named function/file/error message) and generalizable (applies to future work, not just one task).

## Table of Contents

1. [TOM (Tabular Object Model) & ADOMD.NET](#1-tom-tabular-object-model--adomdnet)
2. [TMDL Authoring & Serialization](#2-tmdl-authoring--serialization)
3. [PBIR (Report Layout) Authoring](#3-pbir-report-layout-authoring)
4. [Power BI Desktop Runtime Behavior](#4-power-bi-desktop-runtime-behavior)
5. [`pbir-cli` Usage](#5-pbir-cli-usage)
6. [DAX Patterns](#6-dax-patterns)
7. [Calculated Tables](#7-calculated-tables)
8. [Environment & Tooling](#8-environment--tooling)
9. [Data Modeling for Wide-Format Source Tables](#9-data-modeling-for-wide-format-source-tables)
10. [PBIP Project Hygiene](#10-pbip-project-hygiene)
11. [Power Query M for PDF & Text Sources](#11-power-query-m-for-pdf--text-sources)
12. [Refresh & Dependency Order](#12-refresh--dependency-order)
13. [Skill Authoring (.claude/skills)](#13-skill-authoring-claudeskills)

---

## 1. TOM (Tabular Object Model) & ADOMD.NET

- **`$model.SaveChanges()` is in-memory only** — it writes to the running Power BI Desktop Analysis Services process, NOT to TMDL files on disk. To persist, either press Ctrl+S in PBI Desktop OR use `[Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeDatabaseToFolder($db, $path)` while PBI Desktop is closed and copy the resulting files into the project.
- **`msmdsrv.exe` port changes on every PBI Desktop relaunch.** Never cache the port literal in a script. Rediscover via `netstat -ano | Select-String "LISTENING" | Where-Object { ($_ -split "\s+")[-1] -eq "$msmdsrvPid" }`.
- **Multiple PBI Desktop windows = multiple `msmdsrv.exe` processes on different ports.** Connect to each port, read `$server.Databases[0].Name`, and disambiguate.
- **ADOMD reader returns fully-qualified column names** (`'Table'[Column]`, not `Column`). Use `$reader.GetName($i)` to discover names; access by index, not by short name. Short-name lookup fails silently and returns blank.
- **`Microsoft.AnalysisServices.retail.amd64` NuGet package's TOM is sometimes older** than the newer `Microsoft.AnalysisServices` package. If a TOM operation throws a compatibility-level error, try the newer .NET 8+ package.
- **TOM `$db.Name` is a GUID** for TMDL-authored models (`PBI_ProTooling = ["TMDLView_Desktop","DevMode"]`) — the display name lives on `$model.Name` which itself defaults to `"Model"`. Don't expect either property to be human-readable; treat them as opaque identifiers.
- **TOM partition source detection requires `-is` type-checks**, not string-name comparison. `$p.Source -is [Microsoft.AnalysisServices.Tabular.MPartitionSource]` (Power Query M), `[CalculatedPartitionSource]` (DAX `CALENDAR`/`DATATABLE`), or `[EntityPartitionSource]` (Direct Lake / lakehouse). All three share `.Expression`; only `EntityPartitionSource` has `.EntityName` and `.ExpressionSource`.
- **`$model.Cultures.Count > 0` does NOT mean the model is localised.** A culture object can exist with `ObjectTranslations.Count == 0`. Inspect `Cultures[0].ObjectTranslations.Count` to determine whether any captions are actually translated.
- **For dumping the full model to JSON**, the reusable script lives at `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1`. Pass `-Port <port>` (discovered via `netstat`) and `-OutputPath tmp\model_snapshot.json`; emits database metadata, query groups, expressions, tables (with columns + measures + partitions + hierarchies), relationships, roles, cultures, perspectives, dataSources, and an aggregate `counts` block. ~25 tables / 88 measures snapshot to ~530KB JSON in ~5 s.

## 2. TMDL Authoring & Serialization

- **`TmdlSerializer.SerializeDatabaseToFolder($db, $path)` dumps to the path root, not into a `definition/` subfolder.** Project structure is `SemanticModel/definition/tables/*.tmdl` but the dump is `<tempDir>/tables/*.tmdl`. Copy from `<tempDir>/tables/` into `<project>/SemanticModel/definition/tables/`.
- **TMDL uses tab indentation, semantically.** Properties of a measure declared at table-level (depth 1) sit at depth 2; multi-line DAX body sits at depth 3 (two deeper than the declaration).
- **Calculated table partition DAX body is at depth 4** — `partition X = calculated` is at depth 1, `mode: import` and `source =` at depth 2, the DAX body at depth 4.
- **`///` (triple-slash) sets the `Description` property on the next declaration.** Must be immediately followed by `measure`/`column`/`table` — no blank line, no other comment.
- **TMDL file edits while PBI Desktop is open are silently ignored.** PBI Desktop reads TMDL only at file-open time and writes it only on Save. External edits to the running project will be overwritten on next save.
- **Compatibility level 1600 does not support DAX User-Defined Functions.** Repeating helper patterns cannot be refactored into reusable functions until upgraded to 1610+.

## 3. PBIR (Report Layout) Authoring

- **`Edit` tool's exact-string matching fails on JSON-escaped embedded scripts.** When a `visual.json` embeds Python/DAX as a JSON string, newlines are literal `\n` characters, not actual line breaks. Use `py -c "open(fp).read().replace(old, new)"` via `Bash` for precise substitutions on those payloads.
- **PBIR column projection order = displayed column order** in `tableEx` and `pivotTable` visuals. Appending to the `Values.projections` array adds the column at the right of the visual; reordering requires reordering the array entries.
- **Python visual sources live under `objects.script[0].properties.source`** in `visual.json`. The full Python script is one big JSON string with escaped `\n` separators — surgical edits via `replace()` are safe; structural edits should regenerate the whole `source` value.
- **`pbir add page` rejects byPath thick reports** with `"Thin reports require a connection (workspace + model)"`. For local PBIP projects, write `page.json` and `visual.json` directly via PowerShell `ConvertTo-Json -Depth 30`, then validate with `pbir validate`.
- **PBIR `visual.json` has two separate object containers**:
  - `objects` — visual-data-area formatting (`labels`, `categoryAxis`, `valueAxis`, `legend`, `dataPoint`)
  - `visualContainerObjects` — chrome formatting (`title`, `background`, `border`, `dropShadow`)
  Putting formatting under the wrong container silently drops the property.
- **PBIR JSON values must be wrapped as expressions**, not raw literals. Booleans are `{ "expr": { "Literal": { "Value": "true" } } }`; numbers use `Value: "16D"` (double) or `"16L"` (long); strings need single quotes inside: `"Value": "'My Title'"`.
- **Schema versions in this workspace**: `pagesMetadata/1.1.0`, `page/2.1.0`, `visualContainer/2.9.0`. Match these to avoid local-cache `SCHEMA_DEGRADED` warnings.
- **Page width × height defaults to 1280 × 720 (`FitToPage`).** Visual positions and sizes must fit within these bounds or PBI Desktop crops them.
- **The `pages.json` `activePageName` controls which page loads first** when the report opens — useful for hand-off ("open the report and see your new page immediately").

## 4. Power BI Desktop Runtime Behavior

- **PBI Desktop does not watch its files.** Always `Get-Process PBIDesktop, msmdsrv | Stop-Process -Force` before editing report files on disk.
- **`Stop-Process` is safe when the runtime state has been TOM-persisted via `TmdlSerializer`** — no Ctrl+S needed because the TMDL files already reflect the in-memory model.
- **PBI Desktop's window title shows the project name without an asterisk** when there are no unsaved changes, and with `*` appended when there are. A clean title after re-launch confirms the on-disk TMDL/PBIR was loaded successfully.
- **Auto Date/Time** (enabled by default on new PBIP projects) generates ~30 hidden `LocalDateTable_*` and one `DateTableTemplate_<guid>` table per project. They inflate `pbir tree` output and `model.Tables.Count` but are unrelated to most work.

## 5. `pbir-cli` Usage

- **`pbir-cli` requires Python 3.10+.** Default Python 3.9 installs reject the wheel with `Requires-Python >=3.10`. Use `py -3.11 -m pip install pbir-cli`.
- **`pbir.exe` lands at `C:\Users\golfc\miniconda3\Scripts\pbir.exe` (in this workspace)** and is NOT on PATH by default after install. Prepend `C:\Users\golfc\miniconda3\Scripts` to PATH in each shell.
- **`pbir model -q` requires a thin report connection** — it cannot query a local PBI Desktop AS. For byPath thick reports, use TOM/ADOMD directly.
- **`pbir validate` works on thick reports** for structure/schema checks even when query operations don't.
- **`pbir validate --json` output structure**: walk `report_files[].issues[]` recursively; `severity` is lowercase (`"error"`, `"warning"`).

## 6. DAX Patterns

- **String → number parsing for accounting-format values** (thousand separators, parenthesised negatives, em-dash for blanks):
  ```dax
  VAR _c = TRIM ( SUBSTITUTE ( SUBSTITUTE ( SUBSTITUTE ( SUBSTITUTE (
              _raw, ",", "" ), "(", "-" ), ")", "" ), "—", "" ) )
  RETURN  IF ( _c IN { "", "-" }, BLANK(), VALUE ( _c ) )
  ```
- **`CALCULATE ( SELECTEDVALUE ( … ), ALL ( <table> ), <table>[Index] = N )`** returns a single cell from a row-keyed wide-format table regardless of surrounding filter context. The `ALL` removes any external filter; the predicate selects the target row.
- **Dynamic dispatch by disconnected dim** uses SWITCH on `SELECTEDVALUE` with a sane default for grand totals:
  ```dax
  VAR _r = SELECTEDVALUE ( 'Region'[Region], "STELLANTIS" )
  RETURN SWITCH ( TRUE (),
      _r = "North America", [AOI - North America],
      …,
      [Adjusted Operating Income]  -- grand total fallback
  )
  ```
- **Scenario constants belong in DAX, not in visuals.** `VCP Cost Save Target 2028 = 6000` as a measure is auditable, reusable, and easy to update centrally.

## 7. Calculated Tables

- **Calculated tables need a `calculate` refresh after creation.** Without it, every query returns `"calculated table <name> does not hold any data because it needs to be recalculated or refreshed."` TMSL payload:
  ```json
  { "refresh": { "type": "calculate", "objects": [{ "database": "<dbName>" }] } }
  ```
- **`DATATABLE` is the right tool for small inline disconnected dims** (region lists, category mappings, scenario buckets). Faster than maintaining a Power Query table and round-trips through `TmdlSerializer` cleanly.
- **Set `SortByColumn` after the columns are added to the table.** TOM requires the columns to exist on the parent table before `column.SortByColumn = otherColumn` is valid. Save once to add columns, then save again to set the sort.
- **`isHidden` flag on a sort column** keeps it out of the field list but still allows `SortByColumn` to reference it.

## 8. Environment & Tooling

- **`nuget` from `winget install Microsoft.NuGet`** lands at `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Microsoft.NuGet_<id>\nuget.exe` and is NOT on PATH until shell restart. Call via full path or restart shell.
- **TOM NuGet install command** (idempotent, caches at `%TEMP%\tom_nuget\`):
  ```powershell
  nuget install Microsoft.AnalysisServices.retail.amd64 -OutputDirectory $env:TEMP\tom_nuget -ExcludeVersion
  nuget install Microsoft.AnalysisServices.AdomdClient.retail.amd64 -OutputDirectory $env:TEMP\tom_nuget -ExcludeVersion
  ```
- **Load TOM DLLs** from `lib\net45\`:
  ```powershell
  Add-Type -Path "$env:TEMP\tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Core.dll"
  Add-Type -Path "$env:TEMP\tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\Microsoft.AnalysisServices.Tabular.dll"
  ```
- **PowerShell `Start-Sleep` with long delays before commands is blocked by the harness.** Use `run_in_background: true` for long-running tasks or poll a condition with a short loop.
- **`WebFetch` returns HTTP 403 on `sec.gov`** for direct URL fetches. Power Query's `Web.BrowserContents` works because it presents a browser-like fingerprint; for SEC data, rely on the existing M partition.
- **Windows PowerShell 5.1's `Get-Content -Raw` + `Out-File -Encoding utf8` corrupts UTF-8 round-trips.** The read side interprets unbom'd UTF-8 source bytes as Latin-1; the write side then re-encodes the mangled characters as UTF-8-with-BOM. Symptoms: `—` becomes `â€"`, `§` becomes `Â§`, `÷` becomes `Ã·`. For multi-fragment Markdown / TMDL / JSON assembly under PS 5.1, use `[System.IO.File]::ReadAllText(path, [System.Text.Encoding]::UTF8)` and `[System.IO.File]::WriteAllText(path, content, (New-Object System.Text.UTF8Encoding($false)))`. PowerShell 7+ does not have this issue (its `utf8` default is NoBOM).
- **`netstat -ano` token positions are not stable across lines.** IPv4 (`TCP 127.0.0.1:56746 …`) and IPv6 (`TCP [::1]:56746 …`) `LISTENING` rows split into different column counts. Don't `[2]`-index the split array; match `:(\d+)$` against the LocalAddress token explicitly, and filter `port -gt 1024` to drop kernel-reserved low ports.
- **Microsoft Learn MCP tools** (`mcp__plugin_fabric-cli_microsoft-learn__microsoft_docs_search` + `microsoft_docs_fetch`) are the right way to fetch `learn.microsoft.com` citations — not `WebFetch`. The MCP tools return clean Markdown-formatted excerpts with verified URLs; one search + one fetch per topic builds a citations JSON cheaply.

## 9. Data Modeling for Wide-Format Source Tables

- **Wide-format scraped tables (one column per dimension value) are common in SEC filings.** They can be left as-is by using disconnected dim tables + SWITCH-dispatching measures, which avoids reshaping the source.
- **String-encoded numerics with thousand separators, accounting parens, and em-dash blanks** are common in financial source data. Standardize the parse pattern as a reusable VAR chain (see §6).
- **Column names with literal special characters** like `OTHER(*)` (footnote markers) must be referenced verbatim in DAX: `'AOI_FY2025'[OTHER(*)]`. The parentheses are part of the name, not syntax.
- **Index/Sort columns are essential for wide-format P&L tables** — they preserve the source row order (Net Revenues → Operating Income → adjustments → AOI) for matrix visuals.

## 10. PBIP Project Hygiene

- **No git in this workspace.** Backups are the only rollback mechanism. Before any TMDL or PBIR mutation:
  ```powershell
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  Copy-Item .\STLA_Power_BI\STLA_20-F_Model.SemanticModel ".\STLA_Power_BI\.claude\backups\$stamp\" -Recurse
  Copy-Item .\STLA_Power_BI\STLA_20-F_Model.Report        ".\STLA_Power_BI\.claude\backups\$stamp\" -Recurse
  ```
- **Reusable scripts belong in `.claude/scripts/`** (Claude Code harness convention), not in project root or `tmp/`. They survive across sessions and are version-controlled if the workspace ever gets git.
- **`model.tmdl` `ref table <Name>` lines must be added when new tables are created.** `TmdlSerializer` handles this automatically; hand-edits must add the line manually or the table won't load.
- **The `OTHER(*)` column quirk is project-specific** to `AOI_FY2025` — comes from the SEC press release footnote `(*)`. Future tables sourced from EDGAR filings may carry similar markers.
- **Custom themes live at `<Report>/StaticResources/RegisteredResources/<Name>.json`**. This project uses `CY23SU08.json`. Modifying the theme cascades to all visuals; modifying `visualContainerObjects` in individual `visual.json` overrides the theme for that visual only.
- **Multi-section developer docs should be assembled from per-section fragments** under `tmp/sections/NN-name.md` rather than written as one big file. Each fragment is independently regeneratable; assembly is a UTF-8-aware concatenation. Avoids the cognitive load of editing a 2000-line file and lets parallel sub-agents own one fragment each.
- **A plan's pre-stated entity counts are aspirational, not measured.** Before committing to acceptance criteria like "must document 36 relationships", run the extraction script against the live model and rebaseline. Otherwise the doc either pads with stubs or under-delivers. The pattern: extract → count → adjust acceptance bounds → write.
- **For sub-agent reports, always re-verify the claimed line count with `Measure-Object -Line` or `wc -l`.** Sub-agents sometimes self-report inaccurate counts (observed: agent claimed "969 lines", file was 1380 lines).

## 11. Power Query M for PDF & Text Sources

- **`Pdf.Tables(File.Contents("<path>"), [Implementation="1.3"])`** returns one row per detected element with a `[Kind]` column (`"Page"`, `"Table"`, etc.). Filter to `"Page"` to iterate by page. The page's content is in the `[Data]` table column — combine via `Table.ToList` + `Text.Combine` to get per-page text.
- **PDF path in M is hard-coded absolute** unless wrapped in a parameter expression. Moving the project to another machine requires updating every `Pdf.Tables(File.Contents("..."))` occurrence; centralise via an `expression PdfPath = "..."` if multiple queries share the same source.
- **Page-range section classifiers in M are filing-specific.** GM 10-K is ~108 pages with Risk Factors at pages 14–24; Stellantis 20-F is ~356 pages with Item 3.D Risk Factors at pages 80–103. When swapping PDFs from different filers, find the new section anchors first (via `pypdf` TOC scan), then rewrite the classifier.
- **Form 20-F vs Form 10-K terminology**: 20-F uses "Item 3.D Risk Factors" / "Risks Related to Our Business"; 10-K uses "Item 1A - Risk Factors". M filter strings must match the exact section label produced by the classifier.
- **`fnCountPattern` is regex alternation, NOT full regex.** The helper splits patterns on `|` then `Text.Replace`s each term as a substring (case-insensitive via `Text.Lower`). Anchor or boundary regex syntax (`\b`, `^`, `$`, `[...]`, `(?:)`) is treated as literal text and will match zero occurrences.
- **Severity-language adjustment in `risk_heatmap` is global, not per-category.** The `WithImpact` step counts high-impact vs low-impact words across the *entire* filtered text and adds +1 to every Impact if `highCount > 2 × lowCount`. Stellantis 20-F: 257 vs 9 → all Base_Impacts boosted by 1, capped at 5.
- **Pypdf is the fastest way to locate sections in a 100+ page PDF.** `for i in range(len(r.pages)): r.pages[i].extract_text()[:400]` plus keyword search on each first-page header finds anchors in seconds. Reading the whole PDF into the conversation costs orders of magnitude more context.

## 12. Refresh & Dependency Order

- **TMSL `full` refresh of one table via TOM**:
  ```powershell
  $tmsl = '{ "refresh": { "type": "full", "objects": [{ "database": "' + $db.Name + '", "table": "<TableName>" }] } }'
  $server.Execute($tmsl) | Out-Null
  ```
- **Chained M-table dependencies must be refreshed in dependency order.** If `risk_heatmap` ← `10k_risk_section` ← `20f_full_text`, refreshing `risk_heatmap` alone is NOT sufficient when upstream M source changed — refresh `20f_full_text` → `10k_risk_section` → `risk_heatmap` explicitly. The engine does NOT auto-cascade upstream refreshes.
- **Refresh types**: `full` (drop + re-query + recalculate), `calculate` (DAX only — for calc tables/columns), `automatic` (engine decides), `dataOnly` (re-query but skip DAX recalc). For Power Query M changes, use `full`.
- **Computed risk-register tables persist across PBI Desktop saves.** The `risk_heatmap` rows are saved with the model on Ctrl+S. Closing PBI Desktop without saving loses the refreshed rows, but reopening re-runs the M and reproduces them. Edits to the M source itself ARE saved to TMDL on disk before the refresh runs.

## 13. Skill Authoring (.claude/skills)

- **Plugin skill cache path includes a version folder.** Upstream `power-bi-agentic-development` skills live at `~/.claude/plugins/cache/power-bi-agentic-development/<category>/26.20/skills/<name>/SKILL.md` — the `26.20` sits between the category (`semantic-models`, `pbip`, `reports`, `pbi-desktop`, `tabular-editor`, `fabric-cli`, `fabric-admin`) and `skills`. Read these to mirror conventions before authoring new skills.
- **Project-local skill structure.** A skill is `.claude/skills/<kebab-name>/SKILL.md` plus optional `references/*.md`, `scripts/*.ps1`, `assets/*`. Frontmatter is YAML with required `name` (MUST equal the directory name) and `description` (write as trigger phrasing, e.g. "Automatically invoke when the user asks to …"); `version` recommended. Body uses progressive disclosure — short summary pointing to `references/` — plus a "Related Skills" delegation section.
- **Delegate, don't duplicate.** Methodology/gating skills should reference the plugin's granular skills by name (`tmdl`, `dax`, `power-query`, `pbir-format`, `bpa-rules`, `connect-pbid`, etc.) instead of re-implementing mechanics. The shared contract for this repo's enterprise skills is `.claude/skills/AUTHORING.md`.
- **Resolve cross-skill references against the skills root, not the owning folder.** An orchestrator skill (e.g. `production-readiness-gate`) legitimately references sibling scripts like `semantic-model-architect/scripts/validate-model-shape.ps1`; a within-folder existence check false-positives them as missing. At runtime resolve via `$skillsRoot = Join-Path $PSScriptRoot '..\..'`.

## 13. Skill Authoring (.claude/skills)

- **Plugin skill cache path includes a version folder.** Upstream `power-bi-agentic-development` skills live at `~/.claude/plugins/cache/power-bi-agentic-development/<category>/26.20/skills/<name>/SKILL.md` — the `26.20` sits between the category (`semantic-models`, `pbip`, `reports`, `pbi-desktop`, `tabular-editor`, `fabric-cli`, `fabric-admin`) and `skills`. Read these to mirror conventions before authoring new skills.
- **Project-local skill structure.** A skill is `.claude/skills/<kebab-name>/SKILL.md` plus optional `references/*.md`, `scripts/*.ps1`, `assets/*`. Frontmatter is YAML with required `name` (MUST equal the directory name) and `description` (write as trigger phrasing, e.g. "Automatically invoke when the user asks to …"); `version` recommended. Body uses progressive disclosure — short summary pointing to `references/` — plus a "Related Skills" delegation section.
- **Delegate, don't duplicate.** Methodology/gating skills should reference the plugin's granular skills by name (`tmdl`, `dax`, `power-query`, `pbir-format`, `bpa-rules`, `connect-pbid`, etc.) instead of re-implementing mechanics. The shared contract for this repo's enterprise skills is `.claude/skills/AUTHORING.md`.
- **Resolve cross-skill references against the skills root, not the owning folder.** An orchestrator skill (e.g. `production-readiness-gate`) legitimately references sibling scripts like `semantic-model-architect/scripts/validate-model-shape.ps1`; a within-folder existence check false-positives them as missing. At runtime resolve via `$skillsRoot = Join-Path $PSScriptRoot '..\..'`.
