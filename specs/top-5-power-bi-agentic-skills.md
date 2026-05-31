# Plan: Top 5 Power BI Agentic Development Skills (Enterprise-Grade)

## Task Description

Author the **top 5 Claude Code skills** that a Power BI Agentic Development agent needs to take a Power BI solution from requirements to a **production-ready, enterprise-grade** deliverable across the four domains the user named — **semantic models, DAX, relationships, and Power BI visualizations** — plus the cross-cutting **production-readiness** discipline that makes the output deployable in a professional environment.

The five skills are *opinionated methodology + automation* skills. They do **not** re-implement the mechanical primitives that already ship in the `power-bi-agentic-development` plugin (the 25 granular skills: `tmdl`, `dax`, `power-query`, `pbir-format`, `pbir-cli`, `pbi-report-design`, `bpa-rules`, `connect-pbid`, `review-semantic-model`, `review-report`, etc.). Instead, each new skill is the **enterprise layer on top** of those primitives: it encodes the standards (Kimball dimensional discipline, DAX correctness/perf, relationship & RLS integrity, dashboard UX/accessibility, deployment gating), the decision rules, the validation gates, and the orchestration that turn "can edit a TMDL file" into "produces a model an enterprise BI team would accept."

Each skill is a self-contained directory under `.claude/skills/<name>/` containing a `SKILL.md` (YAML frontmatter + progressive-disclosure body), `references/*.md` deep-dive docs, and `scripts/*.ps1` / `assets/*` where automation or templates add value. Every skill explicitly delegates to the existing plugin skills by name (progressive disclosure / "load the `tmdl` skill for serialization mechanics") so there is no duplication.

The five skills will be **dogfooded** against the workspace's own `STLA_20-F_Model` (and a throwaway scratch copy) as the reference test case — the model has known, documented issues (auto Date/Time clutter, a disconnected `Region` dim, zero RLS roles, compatibility level 1600, string-typed wide-format facts) that each skill must correctly detect and advise on.

> **Interpretation note (assumption):** "Develop the top 5 skills" is read as *author 5 new skills as deliverables*, layered on the existing plugin, stored project-local in `.claude/skills/`. This is the strong reading of "develop … skills" and matches the objective ("for the agents to develop a semantic model / dashboard"). The skills are project-local rather than a fork of the plugin so the workspace owns them and they ship with this repo. If the intent was instead to *curate/select* among existing skills, only Phase 1 and the orchestration skill change materially.

## Objective

When this plan is executed, the workspace contains **five production-ready skills** under `.claude/skills/` that, loaded by a Power BI agent, let it:

1. **Architect** an enterprise tabular semantic model (star schema, storage mode, partitions, incremental refresh, naming & format standards, model hygiene) — `semantic-model-architect`.
2. **Engineer** correct, performant, tested DAX (measures, calculation groups, time intelligence, format strings, performance tuning, a repeatable DAX test harness) — `dax-measure-engineering`.
3. **Design and validate** model integrity (relationship cardinality & cross-filter direction, ambiguity avoidance, inactive relationships, RLS/OLS) — `relationship-and-model-integrity`.
4. **Build** an enterprise dashboard in PBIR (layout/UX, theming/branding, accessibility to WCAG AA, visual selection, report performance) — `enterprise-dashboard-design`.
5. **Gate and ship** the whole solution (end-to-end orchestration, BPA + DAX-perf + relationship + accessibility quality gate, PBIP source-control hygiene, deployment/CI-CD posture, generated documentation) — `production-readiness-gate`.

Acceptance is measured by: every skill's frontmatter parses and is discoverable; every bundled `references/`/`scripts/` path resolves; every script parses (`-Syntax` / AST check); and a dogfood run of each skill against `STLA_20-F_Model` produces the expected, correct findings (e.g., the integrity skill flags the disconnected `Region` dim; the architect skill flags auto Date/Time and compat 1600).

## Problem Statement

The `power-bi-agentic-development` plugin already gives an agent **mechanical fluency** — it can serialize TMDL, run DAX, format PBIR, run BPA. What it does **not** give the agent is **enterprise judgment**:

- *Modeling:* nothing enforces a star schema, a single marked date table, surrogate keys, hidden FKs, `summarizeBy = none` on keys, a storage-mode/partition/incremental-refresh decision, or naming/format standards. An agent can happily produce a snowflaked, badly-named, auto-date-time-bloated model — exactly the state `STLA_20-F_Model` is in today.
- *DAX:* nothing enforces explicit-measure discipline, variables, `DIVIDE`, time-intelligence-with-a-real-date-table, calculation groups, format strings/display folders/descriptions, or a *test* that the measure returns the right number and performs acceptably.
- *Relationships:* nothing enforces 1:* cardinality, single-direction-by-default, ambiguity/circular-path avoidance, key uniqueness on the one-side, or any RLS/OLS at all (the model has **zero** roles).
- *Visualization:* nothing enforces layout discipline, accessible contrast, colorblind-safe themes, visual-selection rules, alt text/tab order, or report-performance budgets.
- *Production readiness:* there is no single gate that runs all the checks, enforces PBIP source-control hygiene and the open/closed-Desktop sequencing rules from `CLAUDE.md`, and produces a pass/fail sign-off plus documentation before "release."

These five gaps are precisely the difference between "an agent that edits Power BI files" and "an agent that ships enterprise BI." The plan closes them as five reusable, discoverable skills.

## Solution Approach

A three-phase, foundation-then-fan-out approach:

**Phase 1 — Foundation (1 agent, sequential).** A standards agent (a) inventories the existing 25 plugin skills and records the exact delegation points so the new skills never duplicate them; (b) researches current Microsoft Learn guidance for each domain (dimensional modeling, storage modes/incremental refresh, DAX best practices/calc groups, relationships/RLS, report accessibility/performance, deployment pipelines) via the `microsoft-learn` MCP; (c) writes the shared **authoring contract** — `.claude/skills/AUTHORING.md` — that fixes the SKILL.md frontmatter schema (`name`, `description` trigger phrasing, `license`, optional `allowed-tools`), the `references/`/`scripts/`/`assets/` layout, the "delegate, don't duplicate" rule, the dogfood-test requirement, and the cross-skill interlock map. Every Phase-2 builder consumes this contract so the five skills are consistent.

**Phase 2 — Build the five skills (5 agents; 4 parallel + 1 dependent).** Skills 1–4 are authored in parallel, each by a domain-specialist builder, each producing `SKILL.md` + references + scripts + a dogfood transcript against `STLA_20-F_Model`. Skill 5 (`production-readiness-gate`) is authored after 1–4 because it orchestrates and references them by name; it ties their individual scripts into one `run-quality-gate.ps1` and a release checklist.

**Phase 3 — Integrate & validate (2 agents, sequential).** A validator agent verifies every skill (frontmatter parses; references/scripts resolve and parse; dogfood findings are correct against the live model — using `connect-pbid` on the running Desktop AS, or a scratch copy so the source-of-truth model is never mutated). The standards agent then registers the skills (index `README.md`, `CLAUDE.md` "Key references" entry, cross-links, a new `knowledge-base` lessons entry) and a final gate confirms acceptance criteria.

Skills are **methodology-first**: scripts are thin, composable wrappers around TOM/ADOMD/`pbir`/Tabular Editor that already work in this workspace (see `CLAUDE.md` and `STLA_Power_BI/.claude/scripts/*.ps1`). The hard value is in the `references/` standards and the `SKILL.md` decision rules, not in new tooling.

## Relevant Files

Use these files to complete the task:

- **`CLAUDE.md`** — authoritative source for PBIP/TOM/PBIR sequencing rules (in-memory `SaveChanges` vs disk serialize; edit report files only while Desktop closed; calculated-table `calculate` refresh; byPath thick-report `pbir` limitations; port discovery; PS 5.1 UTF-8 quirks). Every skill's "mechanics" sections must stay consistent with this file.
- **`knowledge-base/lessons-learned-best-practices.md`** — cross-session gotchas (compat 1600 → no DAX UDFs; em-dash parsing; calculated tables; M for PDF sources; refresh order). Skills should cite/cross-reference, and a new lesson is added in Phase 3.
- **`specs/document-semantic-model.md`** — **style + structure template** for this plan and for the skills' reference docs (numbered sections, table-heavy, code-block-rich, no emojis, monospace identifiers).
- **`STLA_Power_BI/docs/AOI_Overview.md`**, **`STLA_Power_BI/docs/Semantic_Model_Reference.md`**, **`STLA_Power_BI/docs/Risk_Tab.md`** — concrete documentation exemplars and the dogfood model's known characteristics (88 measures, disconnected dims, wide-format string facts, the SUBSTITUTE parse pattern).
- **`STLA_Power_BI/.claude/scripts/*.ps1`** (`extract-model-metadata.ps1`, `add-aoi-measures.ps1`, `add-region-dim.ps1`, `build-aoi-overview-page.ps1`) — working TOM/ADOMD/PBIR automation patterns the new skill scripts should mirror (parameterized `-Port`, in-memory save then serialize, calculate refresh).
- **Existing plugin skills** at `~/.claude/plugins/cache/power-bi-agentic-development/<category>/26.20/skills/<name>/SKILL.md` — the delegation targets. Key ones: `semantic-models/{dax,power-query,review-semantic-model,standardize-naming-conventions,lineage-analysis,refresh-semantic-model}`, `pbip/{tmdl,pbir-format}`, `reports/{pbi-report-design,pbir-cli,modifying-theme-json,review-report,deneb-visuals,svg-visuals,python-visuals}`, `pbi-desktop/connect-pbid`, `tabular-editor/{bpa-rules,c-sharp-scripting,te2-cli}`, `fabric-cli/fabric-cli`, `fabric-admin/audit-tenant-settings`. Read these so the new skills *delegate* rather than duplicate.
- **`C:\Obsidian\Power BI\Power BI Agentic Development.md`** — conceptual grounding (data-goblin repo conventions: friendly display names, indentation-sensitive TMDL, star schema preferred; SQLBI agentic-BI primer; Microsoft `powerbi-modeling-mcp`; the known limitation that complex DAX generation is unreliable → skills must include a *test/verify* step).

### New Files

- **`.claude/skills/AUTHORING.md`** — shared authoring contract + interlock map (Phase 1 output).
- **`.claude/skills/README.md`** — index of the five skills (Phase 3 output).
- **`.claude/skills/semantic-model-architect/SKILL.md`** + `references/{dimensional-modeling.md,storage-modes-and-partitions.md,naming-and-formatting-standards.md,model-hygiene-checklist.md}` + `scripts/{disable-auto-datetime.ps1,validate-model-shape.ps1}`.
- **`.claude/skills/dax-measure-engineering/SKILL.md`** + `references/{dax-patterns.md,time-intelligence.md,calculation-groups.md,dax-performance-tuning.md,dax-testing-harness.md}` + `scripts/{test-dax.ps1,add-measures-from-spec.ps1}`.
- **`.claude/skills/relationship-and-model-integrity/SKILL.md`** + `references/{relationship-design.md,rls-ols-patterns.md,model-validation-checklist.md}` + `scripts/{add-relationships-from-spec.ps1,validate-relationships.ps1,test-rls.ps1}`.
- **`.claude/skills/enterprise-dashboard-design/SKILL.md`** + `references/{report-layout-ux.md,theme-and-branding.md,accessibility-checklist.md,visual-selection-guide.md,report-performance.md}` + `assets/enterprise-theme.json` + `scripts/{validate-report.ps1,apply-theme.ps1}`.
- **`.claude/skills/production-readiness-gate/SKILL.md`** + `references/{production-readiness-checklist.md,pbip-source-control.md,deployment-and-cicd.md,bpa-gate.md}` + `scripts/{run-quality-gate.ps1,pbip-backup.ps1}`.
- **`specs/skills-dogfood-report.md`** — Phase 3 validator delta report (one section per skill).

## Implementation Phases

### Phase 1: Foundation
Inventory existing plugin skills (record delegation points), research current MS Learn guidance per domain, and write `.claude/skills/AUTHORING.md` — the frontmatter schema, directory layout, "delegate don't duplicate" rule, dogfood-test requirement, and the cross-skill interlock map. No skill is built until this contract exists. Done when `AUTHORING.md` exists and every Phase-2 builder has one canonical spec to follow.

### Phase 2: Core Implementation
Author skills 1–4 in parallel (model architecture, DAX, relationships/integrity, dashboard design), each per the authoring contract with `SKILL.md` + references + scripts + a dogfood transcript. Then author skill 5 (`production-readiness-gate`) which orchestrates and references skills 1–4 and binds their scripts into one quality gate. Done when all five skill directories exist and each script parses.

### Phase 3: Integration & Polish
Validator verifies frontmatter/paths/scripts and runs each skill's dogfood pass against `STLA_20-F_Model` (live AS via `connect-pbid`, or a scratch copy for any mutating check), producing `specs/skills-dogfood-report.md`. Standards agent registers the skills (`README.md` index, `CLAUDE.md` "Key references" link, cross-links, new `knowledge-base` lesson). Final gate confirms all acceptance criteria.

## Team Orchestration

- You operate as the team lead and orchestrate the team to execute the plan.
- You're responsible for deploying the right team members with the right context to execute the plan.
- IMPORTANT: You NEVER operate directly on the codebase. You use `Task` and `Task*` tools to deploy team members to do the building, validating, testing, and documenting tasks.
  - This is critical. Your job is to act as a high-level director of the team, not a builder.
  - Your role is to validate all work is going well and make sure the team is on track to complete the plan.
  - You'll orchestrate this by using the Task* Tools to manage coordination between team members.
  - Communication is paramount. You'll use the Task* Tools to communicate with team members and ensure they're on track.
- Take note of the session id of each team member. This is how you'll reference them.

### Team Members

- Builder
  - Name: `skills-architect`
  - Role: Foundation + integration. Inventory the 25 existing plugin skills and record exact delegation points; research MS Learn per domain via the `microsoft-learn` MCP; author `.claude/skills/AUTHORING.md` (frontmatter schema, layout, delegate-don't-duplicate rule, interlock map, dogfood requirement). In Phase 3, register the skills (index `README.md`, `CLAUDE.md` link, cross-links, `knowledge-base` lesson).
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `model-skill-builder`
  - Role: Author `semantic-model-architect` — star-schema/dimensional discipline, storage mode (Import/DirectQuery/Dual/Composite + aggregations), partitions + incremental refresh policy, single marked date table + disable auto Date/Time, surrogate keys, hidden FKs, `summarizeBy`/data-type/format-string standards, naming, model hygiene. Scripts: `disable-auto-datetime.ps1`, `validate-model-shape.ps1`. Delegates to plugin `tmdl`, `power-query`, `standardize-naming-conventions`, `connect-pbid`. Dogfood against `STLA_20-F_Model`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `dax-skill-builder`
  - Role: Author `dax-measure-engineering` — explicit measures, variables, `DIVIDE`, filter/row-context discipline, time intelligence with a real date table, calculation groups, format strings/display folders/descriptions, performance tuning (avoid needless iterators, cardinality awareness, VertiPaq/DAX-Studio concepts), and a repeatable EVALUATE-based test harness. Scripts: `test-dax.ps1`, `add-measures-from-spec.ps1`. Delegates to plugin `dax`, `bpa-rules`, `connect-pbid`. Dogfood against `STLA_20-F_Model`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `relationship-skill-builder`
  - Role: Author `relationship-and-model-integrity` — 1:* preferred, single-direction default (bidirectional only with justification + ambiguity/perf warning), inactive relationships + `USERELATIONSHIP`, role-playing dims, key uniqueness on the one-side, circular/ambiguous-path avoidance, disconnected-dim pattern, static & dynamic RLS (`USERPRINCIPALNAME()`), OLS, security-filtering-behavior, "View as role" testing. Scripts: `add-relationships-from-spec.ps1`, `validate-relationships.ps1`, `test-rls.ps1`. Delegates to plugin `tmdl`, `lineage-analysis`, `review-semantic-model`, `connect-pbid`. Dogfood against `STLA_20-F_Model` (must flag the disconnected `Region` dim and zero roles).
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `viz-skill-builder`
  - Role: Author `enterprise-dashboard-design` — PBIR thick-report rules (edit while Desktop closed, write `page.json`/`visual.json`, `pbir validate`), layout grid/alignment/information hierarchy, theme JSON + corporate branding, WCAG AA contrast + colorblind-safe palettes, visual-selection guide, slicers/bookmarks/drill-through, accessibility (alt text, tab order), report-performance budgets, consistent measure-driven formatting. Asset: `enterprise-theme.json`. Scripts: `validate-report.ps1`, `apply-theme.ps1`. Delegates to plugin `pbi-report-design`, `pbir-format`, `pbir-cli`, `modifying-theme-json`, `review-report`, and `deneb/svg/python-visuals` for custom viz. Dogfood against `STLA_20-F_Model.Report`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `orchestration-skill-builder`
  - Role: Author `production-readiness-gate` — end-to-end build sequence (requirements → PQ → model → relationships/RLS → DAX → visuals → validate → docs), PBIP source-control hygiene + the `CLAUDE.md` save/serialize/closed-Desktop rules, the consolidated quality gate (`run-quality-gate.ps1`: BPA + `validate-model-shape` + `validate-relationships` + `test-dax` smoke + `pbir validate` + naming/format checks → pass/fail report), deployment/CI-CD posture (dev/test/prod, Fabric Git integration, deployment pipelines), and a release sign-off checklist. Scripts: `run-quality-gate.ps1`, `pbip-backup.ps1`. References skills 1–4 by name and binds their scripts. Delegates to plugin `bpa-rules`, `review-semantic-model`, `review-report`, `refresh-semantic-model`, `fabric-cli`, `fabric-admin`.
  - Agent Type: `general-purpose`
  - Resume: true

- Builder
  - Name: `skills-validator`
  - Role: Validate all five skills — frontmatter parses (valid YAML, has `name` + `description`); every `references/`/`scripts/`/`assets/` path referenced in each `SKILL.md` exists; every `.ps1` parses (PowerShell AST / `Get-Command -Syntax`); the `enterprise-theme.json` is valid JSON. Run each skill's dogfood pass against the live `STLA_20-F_Model` (read-only via `connect-pbid`; use a scratch copy for any mutating script) and confirm findings are correct (auto Date/Time flagged, disconnected `Region` flagged, 0 roles flagged, etc.). Produce `specs/skills-dogfood-report.md` with a delta per skill; route failures back to the owning builder.
  - Agent Type: `general-purpose`
  - Resume: false

## Step by Step Tasks

- IMPORTANT: Execute every step in order, top to bottom. Each task maps directly to a `TaskCreate` call.
- Before you start, run `TaskCreate` to create the initial task list that all team members can see and execute.

### 1. Foundation: skill inventory, MS Learn research, and the authoring contract
- **Task ID**: `foundation-authoring-contract`
- **Depends On**: none
- **Assigned To**: skills-architect
- **Agent Type**: general-purpose
- **Parallel**: false
- Read every existing plugin `SKILL.md` under `~/.claude/plugins/cache/power-bi-agentic-development/**/26.20/skills/*/SKILL.md`; produce a one-line "what it does + when to delegate to it" entry per skill (the delegation map).
- Use the `microsoft-learn` MCP (`microsoft_docs_search` + `microsoft_docs_fetch`) to capture authoritative guidance for: dimensional/star-schema modeling, storage modes & incremental refresh, mark-as-date-table & auto-date-time, DAX best practices & calculation groups, relationships & cross-filtering, RLS/OLS, report accessibility (WCAG) & performance, deployment pipelines / Fabric Git integration. Save citations to `specs/skills-ms-learn-citations.json` (`{topic, title, url, excerpt}`).
- Write `.claude/skills/AUTHORING.md`: the SKILL.md frontmatter schema (`name` kebab-case == dir name; `description` written as trigger phrasing — "Use when …"; optional `license`, `allowed-tools`), the `references/`/`scripts/`/`assets/` layout, the **delegate-don't-duplicate** rule with the delegation map, the **dogfood-test** requirement (every skill ships a transcript proving it works against `STLA_20-F_Model`), the no-emoji/monospace-identifier doc style, the PS 5.1 UTF-8 file-write rule from `CLAUDE.md`, and the **cross-skill interlock map** (which skill calls which, and the canonical end-to-end order).

### 2. Build Skill 1 — `semantic-model-architect`
- **Task ID**: `build-model-architect`
- **Depends On**: `foundation-authoring-contract`
- **Assigned To**: model-skill-builder
- **Agent Type**: general-purpose
- **Parallel**: true (with tasks 3, 4, 5)
- Author `.claude/skills/semantic-model-architect/SKILL.md` per the contract: dimensional discipline (facts vs dims, avoid snowflaking, role-playing & degenerate dims, basic SCD), single marked date table + disable auto Date/Time, surrogate keys, hidden FK columns, `summarizeBy = none` on keys/non-additive, storage-mode decision matrix (Import/DirectQuery/Dual/Composite + aggregations), partition + incremental-refresh policy, query-folding awareness (delegate to `power-query`), naming standards (friendly Title Case display names), data-type & format-string discipline, VertiPaq/model-size hygiene. Each major decision states a default + when to deviate.
- Write `references/{dimensional-modeling.md, storage-modes-and-partitions.md, naming-and-formatting-standards.md, model-hygiene-checklist.md}`, citing the Phase-1 MS Learn citations.
- Write `scripts/disable-auto-datetime.ps1` (TOM: set `__PBI_TimeIntelligenceEnabled=0`, guidance to remove `LocalDateTable_*`) and `scripts/validate-model-shape.ps1` (TOM: count facts/dims, flag snowflakes, missing/unmarked date table, auto-date-time on, keys without `summarizeBy=none`, columns without format strings). Mirror the `-Port` + connect pattern from `STLA_Power_BI/.claude/scripts/extract-model-metadata.ps1`.
- Produce a dogfood transcript: run `validate-model-shape.ps1` against `STLA_20-F_Model`; confirm it flags auto Date/Time, compat 1600, and the all-measures-on-one-table anti-pattern.

### 3. Build Skill 2 — `dax-measure-engineering`
- **Task ID**: `build-dax-engineering`
- **Depends On**: `foundation-authoring-contract`
- **Assigned To**: dax-skill-builder
- **Agent Type**: general-purpose
- **Parallel**: true (with tasks 2, 4, 5)
- Author `.claude/skills/dax-measure-engineering/SKILL.md`: explicit-measure discipline (`discourageImplicitMeasures`), variables for readability/perf, `DIVIDE` over `/`, filter/row-context & context-transition rules, time intelligence requiring a real marked date table, calculation groups (note compat 1600 allows calc groups but **not** DAX UDFs at 1601 — cross-ref `knowledge-base`), `SELECTEDVALUE`/`KEEPFILTERS` patterns, mandatory format string + display folder + description per measure, performance tuning (avoid needless iterators, cardinality awareness, VertiPaq Analyzer / DAX Studio server-timings concept), and the **measure must be tested** rule (per the data-goblin caveat that LLM DAX is plausible-but-wrong).
- Write `references/{dax-patterns.md, time-intelligence.md, calculation-groups.md, dax-performance-tuning.md, dax-testing-harness.md}`.
- Write `scripts/test-dax.ps1` (generalize the `CLAUDE.md` ADOMD `EVALUATE` snippet: take `-Port`, `-Dax`, return the scalar/table; support `DEFINE MEASURE` for pre-commit testing) and `scripts/add-measures-from-spec.ps1` (TOM: read a JSON measure spec → create measures with expression/format/folder/description → `calculate` refresh — mirror `add-aoi-measures.ps1`).
- Dogfood: use `test-dax.ps1` to evaluate an existing AOI measure on `STLA_20-F_Model` and confirm the returned value; demonstrate the parse-pattern caveat is documented.

### 4. Build Skill 3 — `relationship-and-model-integrity`
- **Task ID**: `build-relationship-integrity`
- **Depends On**: `foundation-authoring-contract`
- **Assigned To**: relationship-skill-builder
- **Agent Type**: general-purpose
- **Parallel**: true (with tasks 2, 3, 5)
- Author `.claude/skills/relationship-and-model-integrity/SKILL.md`: cardinality rules (1:* preferred, avoid *:*), single cross-filter direction by default (bidirectional only with explicit justification + ambiguity/perf warning + `securityFilteringBehavior` note), inactive relationships + `USERELATIONSHIP`, role-playing dims, key uniqueness on the one-side, circular/ambiguous-path detection, the disconnected-dimension pattern (the project's `Region`/`AdjustmentBridge` SWITCH dispatch), static vs dynamic RLS (`USERPRINCIPALNAME()`), OLS, and "View as role" testing.
- Write `references/{relationship-design.md, rls-ols-patterns.md, model-validation-checklist.md}`.
- Write `scripts/add-relationships-from-spec.ps1` (TOM), `scripts/validate-relationships.ps1` (flag *:*, unjustified bidirectional, inactive, ambiguous paths, one-side key non-uniqueness, missing date relationships, **disconnected dims**, zero RLS roles), and `scripts/test-rls.ps1` (run a query impersonating a role via the AS `EffectiveUserName`/role context).
- Dogfood: run `validate-relationships.ps1` against `STLA_20-F_Model`; confirm it reports the disconnected `Region` dim, the 8 auto-LocalDateTable relationships, the single user relationship, and 0 RLS roles.

### 5. Build Skill 4 — `enterprise-dashboard-design`
- **Task ID**: `build-dashboard-design`
- **Depends On**: `foundation-authoring-contract`
- **Assigned To**: viz-skill-builder
- **Agent Type**: general-purpose
- **Parallel**: true (with tasks 2, 3, 4)
- Author `.claude/skills/enterprise-dashboard-design/SKILL.md`: PBIR thick-report mechanics (stop `PBIDesktop`/`msmdsrv` before editing report files, write `page.json`/`visual.json` directly, `pbir validate`; `pbir add page` rejects byPath thick reports — per `CLAUDE.md`), layout grid/alignment/whitespace/information hierarchy (F/Z pattern), theme JSON + corporate branding, WCAG AA contrast + colorblind-safe palettes, visual-selection guide (which chart for which question; no chart-junk), KPI/summary cards, slicers/sync/filters, bookmarks/drill-through/drill-down, report-performance budgets (visuals-per-page, high-cardinality, query reduction), accessibility (alt text, tab order, keyboard nav), and consistent measure-driven number formatting.
- Write `references/{report-layout-ux.md, theme-and-branding.md, accessibility-checklist.md, visual-selection-guide.md, report-performance.md}` and `assets/enterprise-theme.json` (accessible, colorblind-safe corporate theme template).
- Write `scripts/validate-report.ps1` (wrapper around `pbir validate`, with PATH setup for the miniconda `pbir`) and `scripts/apply-theme.ps1` (apply `enterprise-theme.json` to a report — delegate detail to `modifying-theme-json`).
- Dogfood: run `validate-report.ps1` against `STLA_20-F_Model.Report`; confirm no validation errors and produce an accessibility-checklist pass/fail for the existing AOI Overview page.

### 6. Build Skill 5 — `production-readiness-gate`
- **Task ID**: `build-production-gate`
- **Depends On**: `build-model-architect`, `build-dax-engineering`, `build-relationship-integrity`, `build-dashboard-design`
- **Assigned To**: orchestration-skill-builder
- **Agent Type**: general-purpose
- **Parallel**: false
- Author `.claude/skills/production-readiness-gate/SKILL.md`: the canonical end-to-end build order (requirements → Power Query/ingestion → `semantic-model-architect` → `relationship-and-model-integrity` → `dax-measure-engineering` → `enterprise-dashboard-design` → gate → docs), the PBIP source-control hygiene + `CLAUDE.md` save/serialize/closed-Desktop sequencing, the consolidated quality gate, deployment/CI-CD posture (dev/test/prod workspaces, Fabric Git integration, deployment pipelines — delegate to `fabric-cli`/`fabric-admin`), and a release sign-off checklist that references skills 1–4 by name.
- Write `references/{production-readiness-checklist.md, pbip-source-control.md, deployment-and-cicd.md, bpa-gate.md}`.
- Write `scripts/run-quality-gate.ps1` that invokes, in order: `bpa-rules` (Tabular Editor BPA), `semantic-model-architect/scripts/validate-model-shape.ps1`, `relationship-and-model-integrity/scripts/validate-relationships.ps1`, a `dax-measure-engineering/scripts/test-dax.ps1` smoke check, `enterprise-dashboard-design/scripts/validate-report.ps1`, and a naming/format-string compliance check — aggregating to a single PASS/FAIL report with per-check detail. Write `scripts/pbip-backup.ps1` (the `CLAUDE.md` timestamped backup pattern).
- Dogfood: run `run-quality-gate.ps1` against `STLA_20-F_Model`; confirm it produces a structured report with the model's known issues as FAIL/WARN line items (auto Date/Time, 0 RLS, disconnected dims, compat 1600).

### 7. Validate all five skills (frontmatter, paths, scripts, dogfood)
- **Task ID**: `validate-skills`
- **Depends On**: `build-model-architect`, `build-dax-engineering`, `build-relationship-integrity`, `build-dashboard-design`, `build-production-gate`
- **Assigned To**: skills-validator
- **Agent Type**: general-purpose
- **Parallel**: false
- For each skill: parse the YAML frontmatter (valid, has `name` + `description`, `name` == directory name); confirm every `references/`/`scripts/`/`assets/` path mentioned in `SKILL.md` exists; AST-parse every `.ps1`; validate `enterprise-theme.json` is valid JSON.
- Run each skill's dogfood pass against the live `STLA_20-F_Model` (read-only via `connect-pbid`; clone to a scratch copy for any mutating script so the source model is never changed). Confirm findings are correct (auto Date/Time, disconnected `Region`, 0 roles, compat 1600 all surfaced).
- Write `specs/skills-dogfood-report.md` (one section per skill: checks run, pass/fail, deltas). Route any failure back to the owning builder (resume that agent) and re-validate until clean.

### 8. Register and document the skills
- **Task ID**: `register-and-document`
- **Depends On**: `validate-skills`
- **Assigned To**: skills-architect
- **Agent Type**: general-purpose
- **Parallel**: false
- Write `.claude/skills/README.md` — index of the five skills (name, one-line purpose, trigger phrasing, interlock order).
- Add a "Power BI agentic skills" entry to `CLAUDE.md` under "Key references" so future sessions discover the skills.
- Cross-link the skills from `STLA_Power_BI/docs/` where relevant, and add a `knowledge-base/lessons-learned-best-practices.md` entry capturing any new gotcha discovered during the build (per that file's addition rules).

### 9. Final validation gate
- **Task ID**: `validate-all`
- **Depends On**: `foundation-authoring-contract`, `build-model-architect`, `build-dax-engineering`, `build-relationship-integrity`, `build-dashboard-design`, `build-production-gate`, `validate-skills`, `register-and-document`
- **Assigned To**: skills-validator
- **Agent Type**: general-purpose
- **Parallel**: false
- Run all validation commands (below) and confirm every acceptance criterion is met.
- Confirm `specs/skills-dogfood-report.md` shows zero outstanding failures and the five skills are discoverable and cross-linked.

## Acceptance Criteria

- Five skill directories exist under `.claude/skills/`: `semantic-model-architect`, `dax-measure-engineering`, `relationship-and-model-integrity`, `enterprise-dashboard-design`, `production-readiness-gate`, each with a `SKILL.md`.
- Every `SKILL.md` has valid YAML frontmatter with a kebab-case `name` matching its directory and a trigger-phrased `description`.
- Every `references/`, `scripts/`, and `assets/` path referenced inside each `SKILL.md` resolves to an existing file; no dangling links.
- Every bundled `.ps1` parses without syntax errors; `enterprise-theme.json` is valid JSON.
- `.claude/skills/AUTHORING.md` exists with the frontmatter schema, layout, delegate-don't-duplicate rule + delegation map, dogfood requirement, and the cross-skill interlock map.
- Each skill **delegates** to the relevant existing plugin skill(s) by name rather than duplicating their mechanics (verifiable in `SKILL.md` text).
- `specs/skills-dogfood-report.md` shows each skill correctly surfaces the `STLA_20-F_Model` known issues: auto Date/Time on, compatibility level 1600, disconnected `Region`/`AdjustmentBridge` dims, zero RLS roles, all-measures-on-one-table.
- `production-readiness-gate/scripts/run-quality-gate.ps1` produces a single structured PASS/FAIL report aggregating model-shape, relationship, DAX-smoke, report, and naming/format checks.
- The five skills are indexed in `.claude/skills/README.md` and linked from `CLAUDE.md`.
- No source-of-truth model/report file is mutated by validation (mutating checks run against a scratch copy).

## Validation Commands

Execute these commands to validate the task is complete:

- `Get-ChildItem .claude/skills -Recurse -Filter SKILL.md | Measure-Object` — confirm 5 `SKILL.md` files (PowerShell).
- For each `SKILL.md`, parse frontmatter — e.g. a PowerShell snippet that splits on `---`, runs the body through `ConvertFrom-... ` or a YAML check, and asserts `name`/`description` exist and `name` equals the parent folder.
- `Get-ChildItem .claude/skills -Recurse -Filter *.ps1 | ForEach-Object { $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errs); if($errs){ "FAIL $($_.Name)" } }` — confirm every script parses (no AST errors).
- `Get-Content .claude/skills/enterprise-dashboard-design/assets/enterprise-theme.json | ConvertFrom-Json` — confirm valid JSON theme.
- Reference-link check: for each `SKILL.md`, confirm every relative path it mentions under `references/`/`scripts/`/`assets/` exists on disk (script or manual).
- `export PATH="/c/Users/golfc/miniconda3/Scripts:$PATH"; pbir -q validate "STLA_20-F_Model.Report"` — confirm the dashboard-design dogfood left the report valid (Bash).
- Run `production-readiness-gate/scripts/run-quality-gate.ps1 -Port <port>` against the live `STLA_20-F_Model` and confirm it emits a structured PASS/FAIL report listing the known issues.
- Confirm `specs/skills-dogfood-report.md` exists and reports zero outstanding failures.
- `Select-String -Path CLAUDE.md -Pattern '.claude/skills'` — confirm the skills are linked from `CLAUDE.md`.

## Notes

- **Planning only.** This document is the blueprint; nothing is built here. Execute with `/build specs/top-5-power-bi-agentic-skills.md`.
- **Delegate, don't duplicate.** The single most important design rule: these five skills are the *enterprise methodology + gating* layer. The mechanical "how to serialize TMDL / run DAX / format PBIR / run BPA" already exists in the plugin's 25 skills and must be delegated to by name (progressive disclosure), never re-implemented.
- **Dogfood, because LLM DAX/modeling is plausible-but-wrong.** Per the Obsidian reference (Tabular Editor blog) and `knowledge-base`, generated DAX and model changes are unreliable until tested. Every skill ships a *verify* step and a dogfood transcript against `STLA_20-F_Model`; the DAX skill's `test-dax.ps1` and the gate's `run-quality-gate.ps1` make that verification repeatable.
- **Respect the `CLAUDE.md` sequencing rules.** TOM `SaveChanges` is in-memory only; serialize + copy while Desktop is closed to persist. Edit report `page.json`/`visual.json` only while `PBIDesktop`/`msmdsrv` are stopped. Calculated tables need a `calculate` refresh. byPath thick reports reject `pbir add page` / `pbir model`. Every skill's mechanics sections must stay consistent with these rules and cross-reference them rather than restating them in full.
- **PS 5.1 UTF-8 trap.** When any script assembles Markdown/JSON/TMDL fragments, use `[System.IO.File]::ReadAllText/WriteAllText` with `UTF8Encoding($false)` — not `Get-Content -Raw` + `Out-File -Encoding utf8` — to avoid em-dash/`§` corruption (per `CLAUDE.md`).
- **MS Learn MCP for citations.** Use `mcp__plugin_fabric-cli_microsoft-learn__microsoft_docs_search` + `microsoft_docs_fetch` (already available) for authoritative best-practice references in each skill's `references/`, rather than `WebFetch` against `learn.microsoft.com`.
- **Skill location.** Project-local `.claude/skills/` (not a plugin fork) so the workspace owns and ships them. If the team later wants them in the marketplace plugin, the directory structure is identical and portable.
- **No new global dependencies** beyond what the workspace already has (TOM/ADOMD NuGet at `%TEMP%\tom_nuget`, `pbir` under miniconda, Tabular Editor for BPA). If BPA gating needs a CLI Tabular Editor, the gate script should detect its absence and degrade gracefully (WARN, not crash).
- **Scratch-copy safety.** Any dogfood step that *writes* (e.g. `add-measures-from-spec.ps1`, `disable-auto-datetime.ps1`) must run against a copied scratch model, never the source-of-truth `STLA_20-F_Model`, per the backup pattern in `CLAUDE.md`.
