# Power BI Agentic Development — Enterprise Skills

Five project-local Claude Code skills that take a Power BI solution from requirements to a **production-ready, enterprise-grade** deliverable. They are the *opinionated methodology + gating* layer on top of the upstream `power-bi-agentic-development` plugin's 25 granular skills — they decide the shape and enforce the standards, and **delegate** the mechanics (TMDL edits, PBIR JSON, DAX optimization, BPA, refresh, Fabric) to the plugin. See `AUTHORING.md` for the shared contract and the full delegation map.

## The five skills

| # | Skill | Covers | Loads when the user mentions |
|---|-------|--------|------------------------------|
| 1 | [`semantic-model-architect`](semantic-model-architect/SKILL.md) | Star schema, date table, storage mode, partitions/incremental refresh, naming & formatting, model hygiene | "design a model", "star schema", "storage mode", "date table", "disable auto date/time", "naming/format" |
| 2 | [`dax-measure-engineering`](dax-measure-engineering/SKILL.md) | Correct + performant + **tested** DAX, time intelligence, calculation groups, format strings | "write a measure", "time intelligence", "calculation group", "test/optimize this DAX" |
| 3 | [`relationship-and-model-integrity`](relationship-and-model-integrity/SKILL.md) | Cardinality, cross-filter direction, ambiguity, inactive/role-playing, RLS/OLS | "create a relationship", "bidirectional", "RLS", "row-level security", "test as role" |
| 4 | [`enterprise-dashboard-design`](enterprise-dashboard-design/SKILL.md) | PBIR layout/UX, theming/branding, WCAG AA accessibility, visual selection, report performance | "build a dashboard", "lay out a page", "apply a theme", "accessibility", "choose a chart" |
| 5 | [`production-readiness-gate`](production-readiness-gate/SKILL.md) | End-to-end orchestration, consolidated quality gate, PBIP source control, deployment/CI-CD | "make production ready", "ship/deploy", "quality gate", "deployment pipelines" |

## Canonical end-to-end order

```
requirements
  -> power-query (plugin: ingest, fold)
  -> 1 semantic-model-architect
  -> 3 relationship-and-model-integrity
  -> 2 dax-measure-engineering
  -> 4 enterprise-dashboard-design
  -> 5 production-readiness-gate (validates all, signs off)
  -> docs (specs/document-semantic-model.md)
```

## The consolidated gate

`production-readiness-gate/scripts/run-quality-gate.ps1` runs the validators shipped by skills 1-4 and returns one PASS/FAIL verdict:

```powershell
.\.claude\skills\production-readiness-gate\scripts\run-quality-gate.ps1 `
    -Port <port> -ReportPath "STLA_20-F_Model.Report" `
    -SmokeDax 'EVALUATE ROW("AOI", [Adjusted Operating Income])'
```

## Scripts at a glance

| Skill | Scripts |
|-------|---------|
| semantic-model-architect | `disable-auto-datetime.ps1`, `validate-model-shape.ps1` |
| dax-measure-engineering | `test-dax.ps1`, `add-measures-from-spec.ps1` |
| relationship-and-model-integrity | `validate-relationships.ps1`, `add-relationships-from-spec.ps1`, `test-rls.ps1` |
| enterprise-dashboard-design | `validate-report.ps1`, `apply-theme.ps1` (+ `assets/enterprise-theme.json`) |
| production-readiness-gate | `run-quality-gate.ps1`, `pbip-backup.ps1` |

All scripts mirror the project's TOM/ADOMD/`pbir` patterns (`-Port`, in-memory save then serialize, port discovery, PS 5.1 UTF-8 safety) documented in the workspace `CLAUDE.md`.

## Dogfood reference

Every skill is validated against the workspace's own `STLA_20-F_Model`, which has known issues the skills must correctly surface: Auto Date/Time on, compatibility level 1600 (no DAX UDFs), disconnected `Region`/`AdjustmentBridge` dims, zero RLS roles, and 88 measures on a single wide-format string table. The gate is expected to correctly **refuse to pass** this model until those gaps are remediated. See `specs/skills-dogfood-report.md` after a validation run.
