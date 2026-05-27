# Plan: Document the STLA_20-F_Model Semantic Model

## Task Description

Produce a professional, developer-facing reference document for the **`STLA_20-F_Model.SemanticModel`** Power BI tabular model. The document will be saved to `STLA_Power_BI/docs/Semantic_Model_Reference.md` and must allow another Power BI developer to understand the model end-to-end without opening Power BI Desktop. Scope:

- **Model metadata** — compatibility level, culture, data-access options, auto Date/Time state, model-level annotations.
- **Data sources & lineage** — every external system (PostgreSQL `public.*` tables, SEC EDGAR API, the Stellantis FY2025 20-F PDF, Web.BrowserContents scrapes), how data enters the model, and how it flows downstream to tables and measures.
- **Query groups & M expressions** — the four query groups (`SEC Queries`, `EDGAR 20-F`, `PostgreSQL_GM_Analysis`, `Text Analysis`) and the six shared M expressions (`fxGetEntities`, `CIK1`, `20f_full_text`, `20f_risk_section`, `RiskCategories_Config`, `fnCountPattern`).
- **Table catalog** — every visible table (22) and meaningful hidden table, classified as fact / dimension / calculated / reference / auto-generated. Per-table: purpose, source system, partition mode, key columns with data types and `summarizeBy`, calculated columns, hierarchies.
- **Relationships** — all 36, presented as a Mermaid ERD plus a tabular listing with cardinality, cross-filter direction, and active flag.
- **Measure catalog** — all 88+ measures on `AOI_FY2025` (and any others), grouped by display folder, each with name, DAX expression, format string, and description. Includes a Mermaid dependency graph for the AOI measure family showing how dynamic dispatch measures (`Region AOI`, etc.) chain to core measures.
- **Security & governance** — Role-Level Security (currently zero roles — gap documented), Object-Level Security state, cultures, perspectives, lineage tags, sensitivity labels, workspace + capacity posture.
- **Best-practice deviations** — auto Date/Time clutter, hard-coded absolute PDF paths, fnCountPattern's substring-only matching, compatibility 1600 vs DAX UDFs, etc. Cross-referenced to Microsoft Learn citations.
- **Mermaid diagrams**: (a) ERD, (b) data-source lineage flow, (c) M-expression dependency, (d) AOI measure dependency tree, (e) risk-scoring pipeline.

The plan also explicitly defines an extraction-and-assembly pipeline so that the document can be **regenerated on demand** from the live model state — this is not a one-shot artifact, it is a reproducible deliverable.

## Objective

When this plan is executed, `STLA_Power_BI/docs/Semantic_Model_Reference.md` will exist as a 800–1500 line professional Markdown document that:

1. Maps 1:1 to the live `STLA_20-F_Model` semantic model state at the moment of generation.
2. Reads cleanly cold (no prior context required) — a senior Power BI developer can use it to onboard, troubleshoot, or extend the model.
3. Renders correctly on GitHub / Azure DevOps / any CommonMark renderer with Mermaid support.
4. Cross-references Microsoft Learn for every architectural concept it uses (compatibility level, RLS, perspectives, refresh, lineage tags, sensitivity labels).
5. Sits alongside the existing `AOI_Overview.md` and `Risk_Tab.md` as the third pillar of the project's developer-doc corpus.

## Problem Statement

The `STLA_20-F_Model.SemanticModel` has grown organically across sessions:

- **53 tables** before recent work, now 55+ after adding `Region` and `AdjustmentBridge`. 30+ of those are `LocalDateTable_*` auto-generated noise.
- **88+ measures** added on `AOI_FY2025` in eight display folders, plus 5 SWITCH-dispatching dynamic measures on the disconnected `Region` dim.
- **Multiple heterogeneous source systems** — PostgreSQL (`public.*` schema, ~10 tables), SEC EDGAR API (CIK lookup, filings, 20-F text, 20-F text), web-scraped press releases (`Web.BrowserContents` in `AOI_FY2025`), and a PDF (`Stellantis-FY2025-20-F.pdf` for `20f_full_text` / `20F_risk_section`).
- **Two computed risk artefacts** — `risk_heatmap` (M-computed register with category scoring) plus a Python heatmap visual that consumes it.
- **Zero documented Role-Level Security, no perspectives, no cultures beyond `en-US`** — a real governance gap for a model containing financial data and external-filing analysis.

No single document explains how it all fits together. New developers must read TMDL by hand, run TOM queries, and reverse-engineer the M chain to understand the data flow. That is the gap this plan closes.

## Solution Approach

Two-track approach:

**Track 1 — Extraction**: Spin up a discovery agent that connects to the live Power BI Desktop AS instance via TOM/ADOMD, dumps a complete metadata snapshot (tables, columns, measures, relationships, M expressions, roles, cultures, perspectives, annotations), and serialises it to a structured intermediate file (`tmp/model_snapshot.json`). This makes every downstream agent's work deterministic — they read JSON, not the live model.

**Track 2 — Authoring**: Five parallel content agents each own one section of the final document. They consume `tmp/model_snapshot.json` and produce Markdown fragments. A diagram-builder agent produces Mermaid blocks from the same JSON. An MS Learn researcher pulls authoritative citations in parallel. Finally a doc-assembler agent stitches the fragments into a single file matching the style of `AOI_Overview.md` (sectioned, table-heavy, code-block-rich, with a Reproduction Guide + Known Caveats + Changelog).

Both tracks complete in well under an hour wall-clock if run in parallel. Sequential single-agent execution is also supported as a fallback.

A validator agent re-queries the live model after assembly and confirms every table/relationship/measure in the document maps to a real model object (and vice versa — no orphan documentation).

## Relevant Files

Use these files to complete the task:

- **`STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/database.tmdl`** — compatibility level + model ID.
- **`STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/model.tmdl`** — model-level config, query groups, ref-table list, model annotations.
- **`STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/expressions.tmdl`** — 6 shared M expressions (`fxGetEntities`, `CIK1`, `20f_full_text`, `10k_risk_section`, `RiskCategories_Config`, `fnCountPattern`).
- **`STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/relationships.tmdl`** — all 36 relationships with cardinality + cross-filter direction.
- **`STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/cultures/en-US.tmdl`** — linguistic metadata.
- **`STLA_Power_BI/STLA_20-F_Model.SemanticModel/definition/tables/*.tmdl`** — 50+ table definitions including the new `AOI_FY2025.tmdl` (now with 88 measures), `Region.tmdl`, `AdjustmentBridge.tmdl`, `risk_heatmap.tmdl`, and the `public.*` PostgreSQL-sourced tables.
- **`STLA_Power_BI/docs/AOI_Overview.md`** — style template for the new document.
- **`STLA_Power_BI/docs/Risk_Tab.md`** — second style template; reference for how to document M expressions and computed tables.
- **`CLAUDE.md`** — workspace-level guidance (TOM sequencing rules, port discovery, etc.).
- **`knowledge-base/lessons-learned-best-practices.md`** — gotchas to cite (compat 1600, em-dash parsing, etc.).

### New Files

- **`specs/document-semantic-model.md`** — this plan (already being written).
- **`tmp/model_snapshot.json`** — intermediate extraction output (gitignored, regenerated on each run).
- **`tmp/ms_learn_citations.json`** — MS Learn URLs + excerpts for compatibility level, RLS, OLS, refresh, perspectives, sensitivity labels, OneLake security, lineage tags.
- **`STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1`** — reusable TOM PowerShell that dumps the full snapshot. Saved as a persistent script (per `CLAUDE.md` script convention).
- **`STLA_Power_BI/.claude/scripts/build-erd-mermaid.ps1`** — generates the Mermaid ERD block from the snapshot.
- **`STLA_Power_BI/docs/Semantic_Model_Reference.md`** — the final deliverable.

## Implementation Phases

### Phase 1: Foundation — extraction infrastructure

Build the reusable PowerShell scripts that dump the live model to a JSON snapshot and emit the Mermaid ERD. Decide the JSON schema once so every content agent consumes the same shape. This phase produces no Markdown — only the intermediate artefacts and a vetted JSON snapshot. Done when `tmp/model_snapshot.json` exists and contains every table/column/measure/relationship/M expression visible in the running model.

### Phase 2: Core Implementation — section authors + diagrams + research

Five content agents run in parallel — each takes the JSON snapshot and writes one section's Markdown fragment to `tmp/sections/`. A sixth agent fetches MS Learn citations. A seventh assembles the fragments into the final document in document order (executive summary → sources → query groups → tables → relationships → measures → security → governance → caveats → reproduction → glossary → changelog).

### Phase 3: Integration & Polish

The validator re-queries the live model and cross-checks every entity referenced in the document against the live state. Any orphan entries (in the doc but not in the model) or missing entries (in the model but not in the doc) become fix-up tasks. Mermaid diagrams are rendered via the `mermaid-cli` Node binary (if available) or visually inspected against the source markup. Final polish: spelling, anchor links, table-of-contents.

## Team Orchestration

- You operate as the team lead and orchestrate the team to execute the plan.
- You're responsible for deploying the right team members with the right context to execute the plan.
- IMPORTANT: You NEVER operate directly on the codebase. You use `Task` and `Task*` tools to deploy team members to do the building, validating, testing, deploying, and other tasks.
  - This is critical. You're job is to act as a high level director of the team, not a builder.
  - You're role is to validate all work is going well and make sure the team is on track to complete the plan.
  - You'll orchestrate this by using the Task* Tools to manage coordination between the team members.
  - Communication is paramount. You'll use the Task* Tools to communicate with the team members and ensure they're on track to complete the plan.
- Take note of the session id of each team member. This is how you'll reference them.

### Team Members

- Builder
  - Name: `model-discoverer`
  - Role: Connect to PBI Desktop's local AS via TOM/ADOMD; serialise the full model state (tables, columns, measures, relationships, M expressions, roles, cultures, perspectives, annotations, lineage tags, compatibility level) to `tmp/model_snapshot.json`. Also authors the reusable `.claude/scripts/extract-model-metadata.ps1` so the snapshot is regeneratable. Confirms PBI Desktop is open and discovers the `msmdsrv` port before starting.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `source-and-m-documenter`
  - Role: Reads `expressions.tmdl` and the snapshot. Documents the four query groups, the six M expressions (with full M code blocks for each), and every external source system the model touches (PostgreSQL `public.*`, SEC EDGAR API, Stellantis 20-F PDF, web-scraped press releases). Cross-references Microsoft Learn Power Query M reference. Outputs `tmp/sections/02-sources-and-queries.md`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `table-cataloger`
  - Role: Reads the snapshot + every `tables/*.tmdl`. For each of the 22 visible tables (and a summary for the 30+ `LocalDateTable_*` and `DateTableTemplate_*` hidden tables), produce a section with: purpose, classification (fact/dim/calc/auto), source, partition mode, columns with data type + `summarizeBy` + `isHidden` + `sortByColumn` + `formatString`, calculated columns, hierarchies, query-group membership. Outputs `tmp/sections/04-table-catalog.md`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `relationship-and-erd-author`
  - Role: Reads `relationships.tmdl` + the snapshot. Produces (a) the Mermaid ERD block excluding the LocalDateTable noise, (b) a tabular listing of all 36 relationships with `From`, `To`, cardinality, cross-filter direction, active flag, `securityFilteringBehavior`. Also writes a short narrative on the model's star-schema posture (or lack thereof — many of the public.* tables relate via inactive or missing relationships). Outputs `tmp/sections/05-relationships.md` and `tmp/diagrams/erd.mmd`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `measure-cataloger`
  - Role: Reads the snapshot's measure listing (88+ on `AOI_FY2025`, dynamic dispatch measures, `risk_heatmap` related measures). Organise by `displayFolder`. For each measure include: name, DAX expression (preformatted code block), format string, description, parent table. Produces a Mermaid graph showing dependencies in the AOI measure family (e.g., `Gap Closed by VCP %` → `VCP Cost Save Target 2028` + `Gap to 2030 AOI Target`). Outputs `tmp/sections/06-measure-catalog.md` and `tmp/diagrams/measure-deps.mmd`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `governance-auditor`
  - Role: Reads the snapshot's role/perspective/culture/sensitivity sections. Documents: (a) current state — 0 roles, 0 perspectives, 1 culture (en-US), no sensitivity labels visible, auto Date/Time on; (b) gap analysis vs MS Learn recommendations for production semantic models; (c) recommended actions (define at least a `Read` role for downstream consumers, consider disabling auto Date/Time, add sensitivity labels at workspace level). Outputs `tmp/sections/07-security-governance.md`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `ms-learn-researcher`
  - Role: Uses `mcp__plugin_fabric-cli_microsoft-learn__microsoft_docs_search` + `microsoft_docs_fetch` to retrieve authoritative citations for: compatibility level 1600 (and what's gained at 1601+ — DAX UDFs etc.), Role-Level Security setup in Power BI Desktop, Object-Level Security, perspectives, refresh schedules, lineage tags, sensitivity labels, OneLake / workspace governance, Power Query M `Pdf.Tables`, `Web.BrowserContents`, dataflows. Outputs `tmp/ms_learn_citations.json` — keyed by topic, each entry has `title`, `url`, `excerpt`, `last_modified`.
  - Agent Type: `general-purpose`
  - Resume: false

- Builder
  - Name: `doc-assembler`
  - Role: Reads all fragments from `tmp/sections/*.md`, all diagrams from `tmp/diagrams/*.mmd`, and the MS Learn citations JSON. Stitches them into `STLA_Power_BI/docs/Semantic_Model_Reference.md` matching the style of `AOI_Overview.md` and `Risk_Tab.md` (numbered sections, table-heavy, professional tone, no emojis, monospace identifiers, executable code blocks). Embeds Mermaid blocks inline. Builds the executive summary + glossary + reproduction guide + changelog sections from scratch. Inserts MS Learn citations inline where each architectural concept first appears.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `validator`
  - Role: Re-queries the live model independently (does not trust the snapshot blindly). For each table/measure/relationship in `Semantic_Model_Reference.md`, confirm it exists in the model with the documented properties. For each entity in the model, confirm it appears in the doc. Renders Mermaid diagrams via `mermaid-cli` (`mmdc -i diagram.mmd -o diagram.png`) if installed; otherwise visual inspection of the source. Generates a delta report. Any deltas become fix-up tasks delegated back to the relevant author.
  - Agent Type: `general-purpose`
  - Resume: false

## Step by Step Tasks

- IMPORTANT: Execute every step in order, top to bottom. Each task maps directly to a `TaskCreate` call.
- Before you start, run `TaskCreate` to create the initial task list that all team members can see and execute.

### 1. Pre-flight: confirm PBI Desktop is open and discover the AS port

- **Task ID**: preflight
- **Depends On**: none
- **Assigned To**: model-discoverer
- **Agent Type**: general-purpose
- **Parallel**: false
- Verify PBI Desktop is running with `STLA_20-F_Model.pbip` loaded (`Get-Process PBIDesktop, msmdsrv`).
- If not running, launch `Start-Process .\STLA_Power_BI\STLA_20-F_Model.pbip` and wait for `msmdsrv` plus `tablesContains("AOI_FY2025") -and tablesContains("risk_heatmap")`.
- Discover port via `netstat -ano | findstr <msmdsrv PID>`.
- Record the port in `tmp/runtime.env` so subsequent agents can read it.

### 2. Author the extraction PowerShell script and dump the model snapshot

- **Task ID**: extract-snapshot
- **Depends On**: preflight
- **Assigned To**: model-discoverer
- **Agent Type**: general-purpose
- **Parallel**: false
- Write `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1` that takes a `-Port` parameter and writes `tmp/model_snapshot.json` containing:
  - **Database**: name, compatibility level, model annotations, default mode.
  - **Query groups**: name, order, annotations.
  - **Tables**: name, lineageTag, isHidden, description, query-group, partition mode (`m` / `calculated` / `entity`), partition expression (truncated for M, full DAX for calculated), data category.
  - **Columns**: per table — name, dataType, isHidden, isKey, summarizeBy, sortByColumn, formatString, displayFolder, description, sourceColumn, type (`data` / `calculated` / `calculatedTableColumn` / `rowNumber`), expression (for calculated).
  - **Measures**: per table — name, expression (full DAX), formatString, displayFolder, description, isHidden.
  - **Relationships**: name, fromTable, fromColumn, toTable, toColumn, fromCardinality, toCardinality, crossFilteringBehavior, securityFilteringBehavior, isActive, joinOnDateBehavior.
  - **Hierarchies**: per table — name, levels[].
  - **M expressions**: name, expression, queryGroup, kind.
  - **Roles**: name, modelPermission, tablePermissions[].filterExpression, members[].
  - **Cultures**: name, translations[].
  - **Perspectives**: name, members[].
  - **Annotations**: model-level + table-level.
- Run the script against the discovered port. Verify the JSON contains ≥55 tables, ≥36 relationships, ≥88 measures, 6 M expressions.
- Output: `tmp/model_snapshot.json` (≈2–5 MB).

### 3. Research Microsoft Learn citations (parallel — no upstream dependency)

- **Task ID**: ms-learn-research
- **Depends On**: none
- **Assigned To**: ms-learn-researcher
- **Agent Type**: general-purpose
- **Parallel**: true
- Run `microsoft_docs_search` for each of: "compatibility level 1600 1601 tabular", "row level security Power BI Desktop", "object level security TMDL", "perspectives semantic model", "refresh schedule semantic model", "lineage tags TMDL", "sensitivity labels Power BI dataset", "OneLake security workspace governance", "Power Query Pdf.Tables", "Power Query Web.BrowserContents".
- For each, pick the top 1–2 results, run `microsoft_docs_fetch` on each URL to get authoritative excerpts.
- Build `tmp/ms_learn_citations.json` keyed by topic with `{title, url, excerpt (≤200 chars), last_modified}`.

### 4. Build sources & query-groups & M expressions section

- **Task ID**: section-sources
- **Depends On**: extract-snapshot
- **Assigned To**: source-and-m-documenter
- **Agent Type**: general-purpose
- **Parallel**: true (with sections 5–8)
- Read `tmp/model_snapshot.json` and `STLA_20-F_Model.SemanticModel/definition/expressions.tmdl`.
- Group queries by `queryGroup`: `SEC Queries`, `EDGAR 20-F`, `PostgreSQL_GM_Analysis`, `Text Analysis`.
- For each external source system, identify:
  - PostgreSQL — list every `public.*` table, the connection string format used, refresh implications.
  - SEC EDGAR API — endpoint patterns, `CIK1` parameter usage, `fxGetEntities` function.
  - Stellantis 20-F PDF — full path, the dual `20f_full_text` / `20f_risk_section` pipeline.
  - Web-scraped press releases — `Web.BrowserContents` usage in `AOI_FY2025`, robustness caveats.
- Document each of the 6 M expressions with a code block + 2-3 sentence explainer.
- Add Mermaid lineage flowchart: `tmp/diagrams/lineage.mmd`.
- Output: `tmp/sections/02-sources-and-queries.md`.

### 5. Build table catalog section

- **Task ID**: section-tables
- **Depends On**: extract-snapshot
- **Assigned To**: table-cataloger
- **Agent Type**: general-purpose
- **Parallel**: true
- Classify every table:
  - **Facts**: tables that are summed/aggregated (e.g., `public balance_sheets`, `public income_statements`, `public cash_flow_statements`, `public financial_ratios`, `Filings`).
  - **Dimensions**: `Date`, `CIK_Lookup`, `Company_Name`, `Company_Info`, `FiscalYear`, `20-F`, `Region`.
  - **Calculated**: `Region`, `AdjustmentBridge`, `Date` (if calculated), `risk_heatmap`, `PeerComparison`.
  - **Reference / wide-format**: `AOI_FY2025`, `Significant Accounting Policies`, `20F_Filing_Summary`.
  - **Auto-generated**: `DateTableTemplate_*`, `LocalDateTable_*` (collapse into a single summary entry — do not list each one).
- For each visible table: 1 paragraph purpose, source system, partition mode, then a column table with `Name`, `Type`, `Hidden`, `SummarizeBy`, `Format`, `SortBy`, `Description`. Mark key columns. Include calculated-column expressions inline.
- Output: `tmp/sections/04-table-catalog.md`.

### 6. Build relationships + ERD section

- **Task ID**: section-relationships
- **Depends On**: extract-snapshot
- **Assigned To**: relationship-and-erd-author
- **Agent Type**: general-purpose
- **Parallel**: true
- Filter relationships to exclude any involving `LocalDateTable_*` or `DateTableTemplate_*` (those are auto-generated and would clutter the ERD).
- Build Mermaid `erDiagram` block with each table as an entity and each relationship as a line. Use Mermaid's cardinality glyphs (`||--o{` for one-to-many).
- Below the ERD, table of relationships: `From`, `To`, `Cardinality`, `Cross-filter`, `Active`, `Security filtering`.
- Narrative: comment on the schema posture — `Date` as a shared dim, `CIK_Lookup` bridging to SEC tables, `Region` as a disconnected dim (no relationship), `risk_heatmap` as a standalone computed table.
- Output: `tmp/sections/05-relationships.md` and `tmp/diagrams/erd.mmd`.

### 7. Build measure catalog section + dependency diagram

- **Task ID**: section-measures
- **Depends On**: extract-snapshot
- **Assigned To**: measure-cataloger
- **Agent Type**: general-purpose
- **Parallel**: true
- Walk the snapshot's `measures[]` array. Group by `(table, displayFolder)`.
- For each folder, produce a section header and a list of measures with a 3-column table: `Name`, `Format`, `Description` — and below each, a DAX code block.
- For the AOI measure family, build a Mermaid `graph` block showing dependencies. Use the `Gap Closed by VCP %` → `Gap to 2030 AOI Target` → `2030 AOI Target` chain as the worked example. Show how `Region AOI` SWITCH-dispatches into the seven `AOI - <Region>` measures.
- Document the string-parse helper pattern (the SUBSTITUTE chain) once at the top of the section and link references back to it rather than repeating in every measure.
- Output: `tmp/sections/06-measure-catalog.md` and `tmp/diagrams/measure-deps.mmd`.

### 8. Build security & governance section

- **Task ID**: section-governance
- **Depends On**: extract-snapshot, ms-learn-research
- **Assigned To**: governance-auditor
- **Agent Type**: general-purpose
- **Parallel**: true (after ms-learn-research finishes)
- Document current state: 0 roles, 0 perspectives, 1 culture (`en-US`), no sensitivity labels visible, auto Date/Time on, `discourageImplicitMeasures` flag state.
- Gap analysis against Microsoft Learn best-practice citations from `tmp/ms_learn_citations.json`:
  - RLS: at least a `Read` role recommended for downstream report consumers; cite MS Learn RLS doc.
  - Auto Date/Time: inflates model size; recommend disabling and using the explicit `Date` table; cite MS Learn time-intelligence doc.
  - Sensitivity labels: model contains SEC-filing data and financial figures — should be tagged at workspace level.
  - Refresh: documents the M expressions' source dependencies and what fails on credential changes.
- Output: `tmp/sections/07-security-governance.md`.

### 9. Build executive summary, glossary, reproduction guide, changelog

- **Task ID**: section-frame
- **Depends On**: section-sources, section-tables, section-relationships, section-measures, section-governance
- **Assigned To**: doc-assembler
- **Agent Type**: general-purpose
- **Parallel**: false
- Read every fragment to understand the final shape before writing the framing sections.
- Executive Summary (≤300 words): what the model does, who uses it, headline counts (55 tables, 36 relationships, 88+ measures, 6 M expressions, 0 roles), and the three biggest known issues.
- Glossary: PBIP, TMDL, PBIR, TOM, ADOMD, AS, RLS, OLS, M, DAX, compatibility level, query group, lineageTag.
- Reproduction Guide: exact command sequence to regenerate this document from a checked-out repo — load PBI Desktop, run extraction script, run section authors, run assembler.
- Changelog: stub entry for today's date.
- Output: integrated into the final document by the next task.

### 10. Assemble final document

- **Task ID**: assemble-final
- **Depends On**: section-frame, ms-learn-research
- **Assigned To**: doc-assembler
- **Agent Type**: general-purpose
- **Parallel**: false
- Compose `STLA_Power_BI/docs/Semantic_Model_Reference.md` in this exact section order:
  1. Executive Summary
  2. Document Conventions (Mermaid notes, monospace, format-string semantics)
  3. Model Metadata (compatibility level, culture, settings, annotations)
  4. Data Sources & Lineage (with Mermaid lineage diagram)
  5. Query Groups & Power Query Expressions
  6. Table Catalog (facts → dims → calculated → wide-format → auto-generated summary)
  7. Relationships & ERD (with Mermaid ERD)
  8. Measure Catalog (per display folder with Mermaid dependency graph)
  9. Calculated Columns (if any)
  10. Hierarchies (if any)
  11. Roles, Security & Governance
  12. Cultures & Translations
  13. Perspectives
  14. Best-Practice Deviations & Caveats
  15. Reproduction Guide
  16. Glossary
  17. References (MS Learn citations table)
  18. Changelog
- Embed Mermaid blocks inline using ```` ```mermaid ```` fences.
- Insert MS Learn citations inline at first mention of each concept (e.g., `compatibility level [^cl]` with footnote-style references) and as a consolidated References section at the end.
- Total target length: 800–1500 lines.

### 11. Validate the assembled document

- **Task ID**: validate-doc
- **Depends On**: assemble-final
- **Assigned To**: validator
- **Agent Type**: general-purpose
- **Parallel**: false
- Re-query the live model independently (do not read `tmp/model_snapshot.json`).
- Cross-check: every table mentioned in the doc exists in the model; every model table appears in the doc OR is explicitly classified as auto-generated noise. Same for measures, relationships, M expressions, columns.
- Verify each Mermaid block parses (use `npx -y @mermaid-js/mermaid-cli mmdc -i <block> -o /dev/null` or visual inspection of syntax).
- Verify every MS Learn URL in the References section returns HTTP 200.
- Verify line count is within 800–1500 range.
- Produce a delta report. If any deltas exist, delegate fix-ups back to the relevant author agent and re-run validation.

### 12. Final integration & memory update

- **Task ID**: integrate
- **Depends On**: validate-doc
- **Assigned To**: doc-assembler
- **Agent Type**: general-purpose
- **Parallel**: false
- Add a new top-level entry to `knowledge-base/lessons-learned-best-practices.md` if any genuinely new gotchas were discovered during extraction (per the existing-style addition rules).
- Add a one-line link to `Semantic_Model_Reference.md` in the project's `CLAUDE.md` under the "Key references" section so future Claude sessions discover it.
- Update `STLA_Power_BI/docs/AOI_Overview.md` and `Risk_Tab.md` to cross-link the new reference doc in their "References" sections.
- Commit nothing (no git in this workspace) but record the run in `tmp/last-doc-run.txt` with timestamp + snapshot file hash.

## Acceptance Criteria

- `STLA_Power_BI/docs/Semantic_Model_Reference.md` exists, is 800–1500 lines, and renders cleanly in GitHub-flavored Markdown.
- The 18 numbered sections from task 10 are all present, in order, with non-empty content.
- The document includes at least **five Mermaid blocks**: (1) data-source lineage flowchart, (2) ERD, (3) AOI measure dependency graph, (4) risk-scoring pipeline, (5) M-expression dependency.
- **Every visible table** in the live model (excluding `LocalDateTable_*` / `DateTableTemplate_*`) has a row in the table catalog with non-empty `Purpose`, `Source`, and at least one column listed.
- **All 36 relationships** appear in the relationship listing (and the non-LocalDateTable subset appears in the Mermaid ERD).
- **Every measure** in the live model has a code block entry in the measure catalog, grouped by `displayFolder`.
- **All 6 M expressions** in `expressions.tmdl` have a code block and explanation in the Power Query section.
- The Security & Governance section explicitly documents: roles (0), perspectives (0), cultures (en-US only), sensitivity labels (none in TMDL), auto Date/Time state.
- The References section contains at least **eight MS Learn citations** for the architectural concepts the doc relies on.
- The Reproduction Guide is executable — a developer can copy-paste the commands and regenerate the doc.
- The validator's delta report shows **zero unmatched entities** in either direction (doc ↔ model).
- The new doc is cross-linked from `CLAUDE.md`, `AOI_Overview.md`, and `Risk_Tab.md`.

## Validation Commands

Execute these commands to validate the task is complete:

- `wc -l STLA_Power_BI/docs/Semantic_Model_Reference.md` — confirm 800 ≤ lines ≤ 1500.
- `grep -c '^```mermaid' STLA_Power_BI/docs/Semantic_Model_Reference.md` — confirm ≥ 5 Mermaid blocks.
- `grep -c '^## ' STLA_Power_BI/docs/Semantic_Model_Reference.md` — confirm 18 top-level sections.
- `grep -oE 'https://learn\.microsoft\.com[^ )]+' STLA_Power_BI/docs/Semantic_Model_Reference.md | sort -u | wc -l` — confirm ≥ 8 unique MS Learn URLs.
- `npx -y @mermaid-js/mermaid-cli mmdc -i tmp/diagrams/erd.mmd -o tmp/diagrams/erd.png` — confirm ERD renders (if mermaid-cli available); otherwise visually inspect.
- TOM count vs doc count for each entity type — run the model-discoverer's snapshot script a second time and diff against the doc's table/measure/relationship counts; expect zero deltas.
- `pbir validate "STLA_20-F_Model.Report"` — confirm no incidental report damage during the run.

## Notes

- **Power BI Desktop must remain open** during extraction (task 2 and validation in task 11). If it gets closed mid-run, the model-discoverer agent must relaunch it and rediscover the port.
- **No new dependencies required if the environment is already set up** per prior sessions. If running on a fresh machine: install `pbir-cli` (`py -3.11 -m pip install pbir-cli`), TOM + ADOMD NuGet packages (`nuget install Microsoft.AnalysisServices.retail.amd64 -OutputDirectory $env:TEMP\tom_nuget -ExcludeVersion` and likewise for `Microsoft.AnalysisServices.AdomdClient.retail.amd64`), and optionally `@mermaid-js/mermaid-cli` for diagram rendering (`npm install -g @mermaid-js/mermaid-cli`).
- **`tmp/` is the right place for intermediate artefacts** per the workspace `CLAUDE.md` — the `model_snapshot.json` and per-section fragments are ephemeral and should not be checked in.
- **The Microsoft Learn MCP tools** (`mcp__plugin_fabric-cli_microsoft-learn__microsoft_docs_search` and `microsoft_docs_fetch`) are available in this environment — use them for the citation pass rather than `WebFetch` against `learn.microsoft.com`.
- **PostgreSQL `public.*` table columns** require runtime data to be loaded. If the model has not been refreshed against PostgreSQL recently, the snapshot will still contain column definitions but row-count metadata may be stale. Note this in the doc's caveats section.
- **Compatibility level 1600** is below the threshold for DAX User-Defined Functions (1601+) and several newer T-SQL-like features. The governance section should flag this as upgrade-candidate territory and cite the MS Learn compatibility-level doc.
- **No RLS roles exist today**. The governance section's "recommended actions" should not invent role names — it should describe the pattern and let the team decide names. Cite MS Learn RLS doc.
- **Auto Date/Time clutter** (30+ `LocalDateTable_*` tables) should be discussed as a known issue with a recommended remediation (Power BI Desktop → Options → Current File → Data Load → Time Intelligence → uncheck Auto date/time, then save). This is the single biggest cleanup opportunity in the model.
- **The fnCountPattern substring-only limitation** (already in `Risk_Tab.md` and `lessons-learned-best-practices.md`) should be cross-referenced, not duplicated. Use a "See: Risk Tab §4.4" pointer.
- **Style match**: target the cadence of `AOI_Overview.md` and `Risk_Tab.md`. No emojis. No marketing language. Identifiers in backticks. Verified values in tables. Code blocks for every DAX/M reference.
- **The plan itself** (`specs/document-semantic-model.md`) lives outside the PBIP project so it's not confused with deliverable docs. Only the final reference doc (`STLA_Power_BI/docs/Semantic_Model_Reference.md`) goes inside the project.
