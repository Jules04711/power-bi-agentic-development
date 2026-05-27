# Power BI Agentic Development

A reference workspace for **agentic development of Power BI semantic models and reports** using [Claude Code](https://claude.com/claude-code). The single Power BI File is `STLA_Power_BI/STLA_20-F_Model.pbip` — a thick PBIP project that analyses Stellantis N.V.'s SEC Form 20-F filing and FY2025 adjusted operating income (AOI) reconciliation. Everything in the repo — the 88 measures, two calculated tables, three report pages, three developer-doc books, and the four PowerShell automation scripts — was authored interactively with an AI agent driving TOM, PBIR, and TMDL from a chat session.

This README is a working guide to that workflow: how the skills, scripts, and docs fit together, and how to extend the project the same way it was built.

---

## What "Power BI Agentic Development" means here

Three layers cooperate. Each is human-readable, each survives across Claude Code sessions, and each can be inspected, modified, or regenerated without opening Power BI Desktop:

| Layer | Where it lives | What it is |
|---|---|---|
| **Skills** | `~/.claude/plugins/cache/power-bi-agentic-development/` | Domain knowledge packs loaded with the `Skill` tool. Cover TOM, TMDL, PBIR, the `pbir` CLI, the `fab` CLI, Tabular Editor BPA, semantic-model auditing, Deneb/Python/R/SVG visuals, theme design, and more. |
| **Scripts** | `STLA_Power_BI/.claude/scripts/*.ps1` | Reusable PowerShell automation that drives TOM/ADOMD against a running Power BI Desktop. Idempotent, parameterised, and re-runnable by hand or by a future agent. |
| **Docs** | `STLA_Power_BI/docs/*.md`, `knowledge-base/`, `CLAUDE.md` | Cold-readable Markdown that captures architecture, gotchas, plans, and per-session handovers. The agent reads these on every new session to bootstrap context. |

The pattern: ask the agent to do something non-trivial → it loads the relevant skill, runs a script (or writes a new one), updates a doc, and adds a lesson to `knowledge-base/lessons-learned-best-practices.md`. Future sessions read the lesson and skip the mistake.

---

## Quick start

### Prerequisites

| Tool | Version | Why |
|---|---|---|
| Power BI Desktop | Latest (2025+) | Hosts the running `msmdsrv` Analysis Services instance that the scripts target. |
| PowerShell | 5.1 or 7+ | Runs the `.ps1` automation. PS 7+ is recommended (no UTF-8 BOM quirks). |
| Python | 3.11 | For `pbir-cli` (`py -3.11 -m pip install pbir-cli`) and ad-hoc PDF / data scripts. |
| `git` | Any modern | Cloning + version control. |
| `nuget` | Any | One-time install of the TOM + ADOMD NuGet packages (see below). |
| Claude Code | Latest | The agent. Free tier works; Opus models recommended for multi-agent orchestration. |

Optional:

| Tool | Purpose |
|---|---|
| `@mermaid-js/mermaid-cli` (`mmdc`) | Render the Mermaid diagrams in `docs/Semantic_Model_Reference.md` to PNG. |
| Tabular Editor 2 or 3 | Hand-edit TMDL with a richer UI. |
| Fabric CLI (`fab`) | Publish the model to a Fabric workspace. |

### Clone and bootstrap

```powershell
# 1. Clone
git clone https://github.com/Jules04711/power-bi-agentic-development.git
cd "power-bi-agentic-development"

# 2. Install the TOM + ADOMD NuGet packages once (cached at %TEMP%\tom_nuget)
nuget install Microsoft.AnalysisServices.retail.amd64           -OutputDirectory $env:TEMP\tom_nuget -ExcludeVersion
nuget install Microsoft.AnalysisServices.AdomdClient.retail.amd64 -OutputDirectory $env:TEMP\tom_nuget -ExcludeVersion

# 3. Open the project in Power BI Desktop (creates the .pbi/cache.abf on first load)
Start-Process .\STLA_Power_BI\STLA_20-F_Model.pbip

# 4. Discover the AS port (changes every relaunch)
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
Write-Output "PORT=$port"
```

### Dump the live model to JSON

```powershell
& .\STLA_Power_BI\.claude\scripts\extract-model-metadata.ps1 -Port $port -OutputPath tmp\model_snapshot.json
```

Produces a structured JSON snapshot of the entire model — every table, column, measure, relationship, M expression, role, culture, perspective, annotation — in about 5 seconds. The snapshot is the input to all the documentation regeneration workflows.

---

## Project structure

```
power-bi-agentic-development/
├── .claude/
│   └── commands/              # Custom slash commands (/build, /handover, /plan_w_team)
├── CLAUDE.md                  # Workspace guidance the agent reads on every session
├── HANDOVER.md                # Latest per-session handover (carries context across compactions)
├── README.md                  # This file
├── knowledge-base/
│   └── lessons-learned-best-practices.md   # Persistent cross-session gotchas
├── specs/
│   └── document-semantic-model.md           # Example implementation plan
└── STLA_Power_BI/             # The PBIP project
    ├── STLA_20-F_Model.pbip   # Project manifest (open this in PBI Desktop)
    ├── STLA_20-F_Model.SemanticModel/
    │   └── definition/         # TMDL (tabular model: tables, columns, measures, M)
    ├── STLA_20-F_Model.Report/
    │   └── definition/         # PBIR (report layout: pages, visuals, theme)
    ├── resources/
    │   └── Stellantis-FY2025-20-F.pdf       # Source for the risk-scoring pipeline
    ├── docs/                   # Three developer-doc books
    │   ├── AOI_Overview.md                  # AOI page: 88 measures + scenario design
    │   ├── Risk_Tab.md                       # Risk page: M pipeline + Python heatmap
    │   └── Semantic_Model_Reference.md       # Whole-model reference (regeneratable)
    └── .claude/
        ├── scripts/            # Reusable TOM PowerShell
        │   ├── extract-model-metadata.ps1    # Dump model to JSON
        │   ├── add-aoi-measures.ps1           # 82 measures on AOI_FY2025
        │   ├── add-region-dim.ps1             # 2 calc tables + 6 dynamic measures
        │   └── build-aoi-overview-page.ps1    # PBIR page builder
        └── backups/            # Per-session model backups (gitignored)
```

The `.pbi/` AS cache, `tmp/` scratch, and `.claude/backups/` are all gitignored — they are user-local, regenerable, or both.

---

## The skills the agent uses

`~/.claude/plugins/cache/power-bi-agentic-development/` ships with the following skills. Each is invoked via the `Skill` tool from inside a Claude Code session. The most-used skills in this repo:

| Skill | When the agent loads it |
|---|---|
| `pbi-desktop:connect-pbid` | Any TOM PowerShell — port discovery, TMSL execution, ADOMD queries, daxlib package installation. |
| `pbip:pbip` | High-level PBIP project operations: renames, forks, PBIX → PBIP conversion, post-rename verification. |
| `pbip:tmdl` | TMDL syntax authoring, BIM → TMDL conversion, formatString / summarizeBy / indentation rules. |
| `pbip:pbir-format` | Per-visual PBIR JSON authoring — `objects` vs `visualContainerObjects`, expression-wrapped literals. |
| `reports:pbir-cli` | The `pbir` CLI for thin-report metadata operations and project validation. |
| `reports:pbi-report-design` | Layout, hierarchy, KPI card design, the 3-30-300 rule. |
| `reports:create-pbi-report` | End-to-end workflow for building a new report from scratch. |
| `reports:python-visuals` / `reports:r-visuals` / `reports:deneb-visuals` / `reports:svg-visuals` | Per-visual-tech recipes. |
| `semantic-models:dax` | DAX performance optimisation, anti-pattern detection, measure tuning. |
| `semantic-models:power-query` | Power Query M authoring, partition testing, query-folding analysis. |
| `semantic-models:review-semantic-model` | Automated quality / best-practice audit. |
| `semantic-models:standardize-naming-conventions` | Interactive naming-convention sweep. |
| `tabular-editor:c-sharp-scripting` | Bulk model edits via TE2/TE3 C# scripts. |
| `tabular-editor:bpa-rules` | Best Practice Analyzer rule authoring. |
| `fabric-cli:fabric-cli` | Publishing to / managing Fabric workspaces. |

The agent auto-discovers these from the workspace's CLAUDE.md and the skill descriptions; you do not need to invoke them manually.

---

## Worked examples

### Example 1 — Build a new measure from a chat prompt

> "Add an `AOI YoY Growth` measure that compares this year's Adjusted Operating Income against last year's."

The agent will:
1. Load `pbi-desktop:connect-pbid` for TOM patterns.
2. Discover the AS port.
3. Read `STLA_Power_BI/docs/AOI_Overview.md` to learn the wide-format parse pattern (`SUBSTITUTE` chain on string-typed €M values).
4. Write a TOM PowerShell snippet that adds the measure to `AOI_FY2025`, persists via `$model.SaveChanges()`.
5. Run a TMSL `calculate` refresh.
6. Validate via `EVALUATE ROW(...)` through ADOMD.
7. Update `AOI_Overview.md` § 5 (Measure Catalog) and regenerate `Semantic_Model_Reference.md` § 8 via `extract-model-metadata.ps1`.

You see ~10 tool calls; the model state changes in PBI Desktop on screen.

### Example 2 — Document the model end-to-end

The plan at `specs/document-semantic-model.md` and the `/build` slash command (`.claude/commands/build.md`) demonstrate **multi-agent orchestration**: 6 sub-agents run in parallel — one per section of the final reference — each reading the same `tmp/model_snapshot.json` and writing a fragment to `tmp/sections/`. A 7th MS Learn researcher fetches authoritative citations. A final assembly step concatenates fragments into `STLA_Power_BI/docs/Semantic_Model_Reference.md` (2169 lines, 18 sections, 5 Mermaid diagrams, 13 MS Learn citations).

To regenerate the reference from a fresh clone:

```powershell
# Open PBI Desktop with the project, discover port, then:
& .\STLA_Power_BI\.claude\scripts\extract-model-metadata.ps1 -Port $port -OutputPath tmp\model_snapshot.json

# In Claude Code, run:
#   /build C:\Users\<you>\...\specs\document-semantic-model.md
```

The full reproduction guide lives in `STLA_Power_BI/docs/Semantic_Model_Reference.md` § 15.

### Example 3 — Convert a risk-scoring pipeline from one filer to another

The repo demonstrates this transformation: the original M pipeline scored GM 10-K text; it was repointed at Stellantis FY2025 20-F text with one chat session. Details in `STLA_Power_BI/docs/Risk_Tab.md` and the changelog of `HANDOVER.md`.

Key steps the agent ran:
1. Backed up the SemanticModel + Report folders to `.claude/backups/<timestamp>/`.
2. Used `pypdf` to locate the new Risk Factors page range (Item 3.D, PDF pages 80–103).
3. Rewrote the section classifier in `definition/expressions.tmdl` (`20f_full_text`, `20f_risk_section`).
4. Updated the Python heatmap title in `visual.json` via a Python `replace()` script (the `Edit` tool can't match across JSON-escaped `\n`).
5. Ran TMSL `full` refresh on the three dependent tables in dependency order.
6. Validated 18 risk rows via ADOMD.

---

## Authoring your own workflow

Pick one of three entry points.

### A. Ask in chat (lowest-friction)

For any single-step task: "rename the `Risk_Score` measure to `Composite Risk`", "add a slicer for `Region`", "validate that all measures have descriptions". The agent will load the relevant skill and execute.

### B. Write a plan + run `/build` (for multi-step work)

For tasks that touch many files, span sub-tasks, or need parallel sub-agents:

1. Write a plan to `specs/<task-name>.md` — see `specs/document-semantic-model.md` for the canonical shape (Task Description → Objective → Solution Approach → Relevant Files → Phases → Team Members → Acceptance Criteria → Validation Commands).
2. Run `/build C:\path\to\plan.md` in Claude Code.
3. The `/build` command (defined at `.claude/commands/build.md`) reads the plan, spawns sub-agents per the Team Members list, tracks progress in the task list, validates, and reports back.

### C. Write a reusable script (for repeatable work)

For automation that should run more than once: write a PowerShell script under `STLA_Power_BI/.claude/scripts/` and document it in `CLAUDE.md` § Common commands. The existing four scripts (see the structure tree above) are reference examples.

---

## Conventions

These conventions are enforced by the agent and described in detail in `CLAUDE.md`:

- **TOM writes are in-memory only.** `$model.SaveChanges()` updates the running `msmdsrv`, not the TMDL files. Persist with Ctrl+S in PBI Desktop or `TmdlSerializer.SerializeDatabaseToFolder` while PBI Desktop is closed.
- **PBI Desktop does not watch its files.** Editing TMDL / PBIR while PBI Desktop is open is silently ignored. Stop PBI Desktop before on-disk edits.
- **Calculated tables need a `calculate` refresh** after creation, or queries fail with *"calculated table X does not hold any data."*
- **No git in the original workspace.** Backups under `.claude/backups/<timestamp>/` are the rollback mechanism. Now that this repo exists, `git` is also available — but the backup pattern remains useful for in-session experimentation.
- **Identifiers in backticks** in all Markdown docs. No emojis. Tables for verified values; prose for narrative.
- **Reusable scripts live in `.claude/scripts/`**, plans in `specs/`, deliverable docs in `STLA_Power_BI/docs/`, per-session state in `HANDOVER.md`, cross-session gotchas in `knowledge-base/lessons-learned-best-practices.md`.
- **Compatibility level `1600`** — DAX user-defined functions are not yet available (requires `1601+`), so repeating helper patterns are intentionally copy-pasted across measures.

---

## Project at a glance

| Aspect | Value |
|---|---|
| PBIP shape | Thick (byPath) — report → model via co-located file path |
| Compatibility level | 1600 (Power BI Premium, Azure AS, SQL Server 2022 baseline) |
| Source systems | SEC EDGAR API · SEC EDGAR Archives · Stellantis FY2025 20-F PDF · Web-scraped press release HTML |
| Tables | 25 (16 visible) |
| Relationships | 9 (1 user-defined, 8 auto-LocalDateTable) |
| Measures | 88 (all on `AOI_FY2025`, in 8 display folders) |
| Shared M expressions | 6 (`fxGetEntities`, `CIK1`, `20f_full_text`, `20f_risk_section`, `RiskCategories_Config`, `fnCountPattern`) |
| Pages | 4 (AOI Overview, SEC Filings, Risk, Subsidiaries) |
| Report theme | Custom (`CY23SU08.json`) |
| RLS / OLS / perspectives / sensitivity labels | None (documented governance gap — see `Semantic_Model_Reference.md` § 11) |

---

## Further reading

- **`STLA_Power_BI/docs/Semantic_Model_Reference.md`** — comprehensive model reference (every table, column, measure, relationship, M expression; 18 sections, 5 Mermaid diagrams, MS Learn citations).
- **`STLA_Power_BI/docs/AOI_Overview.md`** — deep dive on the 88 AOI measures, the disconnected `Region` / `AdjustmentBridge` dims, the FaSTLAne 2030 scenario constants.
- **`STLA_Power_BI/docs/Risk_Tab.md`** — deep dive on the M pipeline that scores 18 risk categories from Item 3.D of the 20-F PDF, plus the Python heatmap visual.
- **`CLAUDE.md`** — workspace-level agent guidance (TOM sequencing rules, port discovery, calculated-table refresh, common commands).
- **`knowledge-base/lessons-learned-best-practices.md`** — persistent cross-session gotchas. Read this before any non-trivial TMDL or PBIR change.
- **`specs/document-semantic-model.md`** — worked example of a multi-agent plan (8 team members, 12 ordered tasks).
- **`HANDOVER.md`** — latest session summary; the next agent reads this on session start.

---

## License

This is a reference workspace. The PBIP project, scripts, and documentation are released for educational and demonstration purposes. The Stellantis Form 20-F PDF in `STLA_Power_BI/resources/` is the property of Stellantis N.V. and the SEC; redistribution is governed by their respective terms.
