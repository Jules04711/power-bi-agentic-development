# Session Handover

> Generated: 2026-05-27 | Project: Power BI Agentic Development / STLA_Power_BI

## Session Summary

User invoked `/build` against `specs/document-semantic-model.md` — a plan to produce a developer-facing reference document for the `STLA_20-F_Model.SemanticModel` Power BI tabular model. Goal: regenerate-on-demand Markdown covering every table, column, measure, relationship, M expression, role, culture, perspective, plus security/governance posture and Mermaid diagrams (ERD, lineage, AOI dependency, M-expression dependency, risk-scoring pipeline). Delivered the full 2169-line reference at `STLA_Power_BI/docs/Semantic_Model_Reference.md` plus a reusable TOM extraction PowerShell script. All entities cross-validate against the live model (zero unmatched in either direction).

## What Was Done

- **Pre-flight** — verified PBI Desktop is running with `STLA_20-F_Model.pbip` loaded, discovered `msmdsrv` PID `37744` listening on port `56746`, wrote `tmp/runtime.env`.
- **Created reusable extraction script** `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1` (238 lines) — takes `-Port` and `-OutputPath`, dumps the full TOM model (database metadata, query groups, expressions, tables, columns, measures, relationships, roles, cultures, perspectives, dataSources, counts) to JSON.
- **Generated the live snapshot** at `tmp/model_snapshot.json` (6109 lines, ~530KB). Live counts: 25 tables (16 visible), 88 measures (all on `AOI_FY2025`), 9 relationships (8 are auto-LocalDateTable bindings + 1 user-defined `Company_Name`↔`CIK_Lookup`), 6 M expressions, 3 query groups (`SEC Queries`, `EDGAR 20-F`, `Text Analysis`), 0 roles, 1 culture (`en-US` with `translationCount = 0`), 0 perspectives. Compatibility level `1600`.
- **Spawned 6 parallel sub-agents** for section authoring:
  - `ms-learn-researcher` → `tmp/ms_learn_citations.json` (13 topics: compatibility level, DAX UDF, RLS, OLS, perspectives, refresh, lineage tags, sensitivity labels, OneLake security, Pdf.Tables, Web.BrowserContents, auto date/time, TMDL overview).
  - `table-cataloger` → `tmp/sections/04-table-catalog.md` (451 lines, all 16 visible tables + 8-row auto-date summary).
  - `relationship-and-erd-author` → `tmp/sections/05-relationships.md` (50 lines) + `tmp/diagrams/erd.mmd`.
  - `measure-cataloger` → `tmp/sections/06-measure-catalog.md` (1380 lines — all 88 measures by display folder) + `tmp/diagrams/measure-deps.mmd`.
  - `source-and-m-documenter` → `tmp/sections/02-sources-and-queries.md` (487 lines initial → ~675 after diagram additions) + `tmp/diagrams/lineage.mmd`.
  - `governance-auditor` → `tmp/sections/07-security-governance.md` (106 lines covering RLS/OLS/perspectives/cultures/sensitivity/auto-date/CL1600/best-practice-deviations).
- **Wrote 6 framing sections directly** (no agent — depended only on snapshot): `01-front-matter.md` (executive summary, conventions, model metadata), `09-calc-cols-hierarchies.md`, `15-reproduction.md`, `16-glossary.md`, `17-references.md`, `18-changelog.md`.
- **Added 2 inline Mermaid diagrams** (§5.7 M-expression dependency, §5.8 risk-scoring pipeline) to meet the acceptance criterion of ≥5 mermaid blocks. Diagram sources saved to `tmp/diagrams/risk-pipeline.mmd` and `tmp/diagrams/m-expression-deps.mmd`.
- **Assembled the final document** via `[System.IO.File]::ReadAllText(path, UTF8)` + `WriteAllText(path, content, new UTF8Encoding($false))` to produce `STLA_Power_BI/docs/Semantic_Model_Reference.md` (2169 lines, UTF-8 no BOM).
- **Validated against the live model** by re-querying TOM independently — confirmed every visible table (16/16), every measure (88/88), and every M expression (6/6) appears in the doc by name.
- **Cross-linked the new doc** from `CLAUDE.md` (Key references section), `STLA_Power_BI/docs/AOI_Overview.md` (new §10 References + changelog entry), and `STLA_Power_BI/docs/Risk_Tab.md` (new §9 References + changelog entry).
- **Recorded the run** at `tmp/last-doc-run.txt` (timestamp `2026-05-27 14:07:41`, snapshot SHA256 `10F66737…1FA`, doc line count 2169).

## What Worked & What Didn't

### Worked Well

- **Six parallel sub-agents** (general-purpose) running in the background while the main session did synchronous TOM extraction and framing-section authoring. End-to-end wall clock for the parallel phase: ~5 minutes for the slowest agent (measure cataloger).
- **JSON snapshot as the shared source of truth** — every section author read `tmp/model_snapshot.json` rather than re-querying TOM, so all section content is deterministic and reproducible.
- **MS Learn MCP tools** (`microsoft_docs_search` + `microsoft_docs_fetch`) produced 13 high-quality citations in one researcher pass with no hallucinated URLs.
- **TOM-side validation** — re-querying the live model and string-matching each entity name against the assembled doc caught zero misses; the snapshot-driven authoring path was sound.
- **PowerShell `[System.IO.File]::ReadAllText` / `WriteAllText` with explicit `UTF8Encoding($false)`** to round-trip UTF-8 NoBOM correctly across many fragments.

### Issues Encountered

- **First `netstat` port-parse returned `"5"`** — the regex `($_ -split "\s+")[2] -replace ".*:"` picked the wrong token. **Resolution**: switched to `($parts[1] -match ":(\d+)$")` against an explicitly split + filtered tokens array; port discovered as `56746`.
- **First assembly produced mojibake** (em-dashes rendered as `â€"`, `§` as `Â§`). Root cause: `Get-Content -Raw` + `Out-File -Encoding utf8` in Windows PowerShell 5.1 reads UTF-8 source files as Latin-1 (when there is no BOM) and re-encodes the mangled output as UTF-8-with-BOM. **Resolution**: replaced both ends with `[System.IO.File]::ReadAllText(path, [System.Text.Encoding]::UTF8)` and `[System.IO.File]::WriteAllText(path, content, (New-Object System.Text.UTF8Encoding($false)))`.
- **Initial Mermaid count = 3, but acceptance criterion requires ≥5.** **Resolution**: added two inline diagrams to `tmp/sections/02-sources-and-queries.md` — §5.7 M-expression dependency and §5.8 risk-scoring pipeline — bringing the total to 5.
- **Edit on `CLAUDE.md` failed with backslash-vs-forward-slash mismatch.** The plan's path notation was `STLA_Power_BI\docs\AOI_Overview.md` but the actual file uses forward slashes (`STLA_Power_BI/docs/AOI_Overview.md`). **Resolution**: re-read the lines verbatim, edited with the correct slash direction.
- **Plan over-estimated entity counts** — claimed 53–55 tables and 36 relationships; live model has 25 tables and 9 relationships. **Resolution**: documented the live truth in §1 of the deliverable; flagged the discrepancy in the assembly step rather than padding the doc to hit fictional counts.
- **Line count exceeded plan target** — plan called for 800–1500 lines; deliverable is 2169 (or 2881 by `wc -l`, which counts newline chars differently). With 88 measures × ~15 lines per entry (header + description + DAX block + format string), 1500 lines was always unreachable while honouring the acceptance criterion that *every measure has a code block entry*. Coverage was prioritised over the line-count band.

## Key Decisions

| Decision | Reasoning | Alternatives Considered |
|----------|-----------|------------------------|
| Use 6 parallel sub-agents for section content | Each section is independent given the snapshot; serial authoring would take 6× longer; the harness supports `run_in_background: true` cleanly | Single-agent sequential pass; main-session direct authoring (rejected — would exhaust context window) |
| Author the extraction as a reusable `.ps1` script, not inline PowerShell | The plan explicitly calls for regenerate-on-demand; future sessions need a single command, not a copy-paste of 200 PS lines | Inline TOM PowerShell in the main session; lighter Python wrapper (rejected — `pythonnet` overhead on Windows) |
| Snapshot to JSON before section authoring | Makes section authoring deterministic; eliminates per-agent TOM connections; allows offline replay | Each agent queries TOM directly (rejected — risk of TOM connection contention; non-deterministic across reruns) |
| Honour live counts (25 tables, 9 rels, 88 measures) in the doc, not the plan's projections | The doc is meant to map 1:1 to the running model; documenting fictional counts would defeat its purpose | Pad the doc with stub rows to hit plan numbers (rejected — anti-truth) |
| Exceed the 800–1500 line plan target | Acceptance criterion requires every measure documented with a DAX block; with 88 measures that alone is ~1380 lines | Compress measure catalog by tabulating instead of per-entry (rejected — loses DAX blocks, violates a hard acceptance criterion) |
| UTF-8 no BOM for the final markdown | GitHub / VS Code / Azure DevOps render UTF-8 NoBOM cleanly; BOM occasionally causes pre-commit hooks to flag the file | UTF-8 with BOM (PowerShell 5.1 default — produces mojibake when round-tripping unbom'd fragments) |

## Lessons Learned & Gotchas

- **`Get-Content -Raw` + `Out-File -Encoding utf8` in Windows PowerShell 5.1 corrupts UTF-8 round-trips**. The read side interprets unbom'd UTF-8 as Latin-1; the write side re-encodes as UTF-8-with-BOM. Symptoms: `—` becomes `â€"`, `§` becomes `Â§`, `÷` becomes `Ã·`. Use `[System.IO.File]::ReadAllText(path, [System.Text.Encoding]::UTF8)` and `[System.IO.File]::WriteAllText(path, content, (New-Object System.Text.UTF8Encoding($false)))` for any multi-fragment assembly.
- **`netstat -ano` token positions are unstable** — line layout differs between IPv4 and IPv6 `LISTENING` rows. Don't index into the split array; match `:(\d+)$` against the LocalAddress (`$parts[1]`) regex'd explicitly. Filter `$port -gt 1024` to drop kernel-reserved low ports.
- **Power BI Desktop's TOM `$db.Name` is a GUID, not a human name** when the model was authored in TMDL view (`PBI_ProTooling = ["TMDLView_Desktop","DevMode"]`). The display name lives on `$model.Name` which itself defaults to `"Model"`. Use `$db.ID` and `$db.Name` interchangeably; don't expect either to be human-readable.
- **TOM `MPartitionSource` vs `CalculatedPartitionSource`** — they share a `.Expression` property but distinct .NET types. Detect with `$p.Source -is [Microsoft.AnalysisServices.Tabular.MPartitionSource]` before reading. Entity-mode partitions are a third type (`EntityPartitionSource`) with `.EntityName` + `.ExpressionSource`.
- **A model can have ≥1 culture object with `translationCount = 0`** — the culture exists in the TMDL but holds no translated captions. `$model.Cultures.Count` is misleading for "is this model localised?"; check `Cultures[0].ObjectTranslations.Count` instead.
- **The plan's pre-stated counts are aspirational, not measured.** Before committing to acceptance criteria that depend on counts (e.g. "the doc must list 36 relationships"), run the extraction against the live model and rebaseline. Otherwise the doc either pads with stubs or under-delivers.
- **Sub-agents read their result file before claiming completion is unreliable** — one agent self-reported "969 lines" but the actual file was 1380 lines. Always verify line counts with `Measure-Object -Line` after every agent reports back.
- **Parallel sub-agents writing to the same `tmp/sections/` directory is safe** as long as each agent's filename is pre-assigned (no race). Reading from `tmp/model_snapshot.json` concurrently is also safe — it's read-only.
- **Acceptance criteria can conflict.** "800–1500 lines" + "every measure has a DAX code block" with 88 measures = unsatisfiable. When two criteria fight, document which one was prioritised and why in the Executive Summary; future readers need to know the choice was deliberate.

## Current State

- **Working**:
  - `STLA_Power_BI/docs/Semantic_Model_Reference.md` (2169 lines, UTF-8 NoBOM) — renders cleanly with em-dashes, `§`, Mermaid blocks, footnote references.
  - `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1` — runnable against any port; outputs JSON snapshot.
  - All five Mermaid diagrams have source files at `tmp/diagrams/*.mmd` (not rendered to PNG — `mmdc` not installed).
  - Cross-links in `CLAUDE.md`, `AOI_Overview.md`, `Risk_Tab.md` to the new reference doc.
  - Live model validation: every visible table, every measure, every M expression in the doc by name.

- **Broken/Incomplete**:
  - Doc exceeds the plan's 800–1500 line target (currently 2169 by PS / 2881 by `wc -l`). Documented in the Executive Summary as a deliberate trade-off; not a fix-up item.
  - `mmdc` (Mermaid CLI) is not installed — Mermaid blocks render in GitHub but cannot be exported to PNG locally without `npm install -g @mermaid-js/mermaid-cli`.

- **Blocked**: None.

## Next Steps

1. **Optional Mermaid PNG renders**. If the user wants offline-renderable diagram artefacts, install `@mermaid-js/mermaid-cli` (`npm install -g @mermaid-js/mermaid-cli`) and run `mmdc -i tmp\diagrams\erd.mmd -o tmp\diagrams\erd.png` for each of the five `.mmd` files.
2. **Push to git** if the workspace ever becomes a git repo — commit `Semantic_Model_Reference.md`, the extraction script, the CLAUDE.md / AOI_Overview / Risk_Tab cross-link updates. `tmp/` is intentionally not committed.
3. **Address the governance gaps surfaced in §11–14** as the user prioritises: define at least one RLS role, disable Auto Date/Time, upgrade compatibility level to 1601+, parameterise the hard-coded PDF path. None are blocking; all are recommendations.
4. **Re-run the pipeline whenever the model changes** — `& .\STLA_Power_BI\.claude\scripts\extract-model-metadata.ps1 -Port <port> -OutputPath tmp\model_snapshot.json` + re-author sections + re-assemble (full command sequence in §15 of the deliverable).

## Important Files Map

| File | Purpose | Status |
|------|---------|--------|
| `STLA_Power_BI/docs/Semantic_Model_Reference.md` | Primary deliverable — 2169-line developer reference for the semantic model. 18 numbered sections, 5 Mermaid blocks, 13 MS Learn citations. | created |
| `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1` | Reusable TOM dumper. Takes `-Port` and `-OutputPath`; emits a structured JSON snapshot of the entire model. | created |
| `STLA_Power_BI/docs/AOI_Overview.md` | Pre-existing AOI documentation. Now carries a new §10 References pointing to the reference doc + changelog row. | modified |
| `STLA_Power_BI/docs/Risk_Tab.md` | Pre-existing Risk-tab documentation. Now carries a new §9 References pointing to the reference doc + changelog row. | modified |
| `CLAUDE.md` | Workspace-level Claude guidance. Now lists `Semantic_Model_Reference.md` and `Risk_Tab.md` under Key references. | modified |
| `tmp/model_snapshot.json` | TOM snapshot (6109 lines, 25 tables, 88 measures, 9 relationships, 6 expressions). Ephemeral / regeneratable. | created |
| `tmp/ms_learn_citations.json` | 13 MS Learn topic citations. Ephemeral / regeneratable. | created |
| `tmp/sections/01..18-*.md` | 11 section fragments authored by sub-agents + framing writes. Ephemeral; concatenated into the deliverable. | created |
| `tmp/diagrams/{erd,lineage,measure-deps,risk-pipeline,m-expression-deps}.mmd` | Mermaid source for the 5 inline diagrams. Render with `mmdc` if needed. | created |
| `tmp/runtime.env` | Records the discovered `msmdsrv` port (`PORT=56746`) for downstream scripts. | created |
| `tmp/last-doc-run.txt` | Timestamp + snapshot SHA256 + doc line count, recorded at assembly completion. | created |
| `specs/document-semantic-model.md` | The plan that drove this session (pre-existing, not modified). | unchanged |

## Environment & Config Notes

- **Power BI Desktop is running** with `STLA_20-F_Model.pbip` loaded — required for any re-extraction. `msmdsrv` PID at session end was `37744` listening on port `56746`. The port changes on every PBI Desktop relaunch; rediscover via the snippet in §15.2 of the deliverable.
- **TOM + ADOMD.NET NuGet packages** are cached at `%TEMP%\tom_nuget\Microsoft.AnalysisServices.retail.amd64\lib\net45\` (TOM) and `…\Microsoft.AnalysisServices.AdomdClient.retail.amd64\lib\net45\` (ADOMD). The extraction script loads them directly from those paths via `Add-Type`.
- **PowerShell 5.1** is the default shell on this Windows 11 machine. The mojibake fix in this session (`[System.IO.File]::ReadAllText/WriteAllText` with explicit `UTF8Encoding($false)`) is mandatory for any future multi-fragment Markdown assembly under PS 5.1. PowerShell 7+ writes UTF-8 NoBOM by default and does not have this issue.
- **MCP servers available**: `mcp__plugin_fabric-cli_microsoft-learn` for `microsoft_docs_search` + `microsoft_docs_fetch` — preferred over `WebFetch` for `learn.microsoft.com` URLs.
- **No git in this workspace.** Backups under `STLA_Power_BI/.claude/backups/<timestamp>/` are the only rollback. None taken this session — only authoring + the new reusable script + cross-link edits were performed; the model was untouched.
- **`tmp/` is ephemeral by convention** — gitignored if/when the workspace becomes a git repo. Do not check in `model_snapshot.json` or any section fragments.
- **The plan file** (`specs/document-semantic-model.md`) lives outside `STLA_Power_BI/` so it is not confused with deliverable docs. Only the final reference doc goes inside the project under `docs/`.
