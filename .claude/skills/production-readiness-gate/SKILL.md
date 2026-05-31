---
name: production-readiness-gate
version: 1.0.0
description: Orchestrate end-to-end Power BI delivery and enforce an enterprise production-readiness quality gate. Automatically invoke when the user asks to "make this production ready", "ship / release / deploy this report", "run a quality gate", "pre-deployment checklist", "validate the whole solution", "enterprise readiness review", "set up deployment pipelines", "PBIP source control / Git", or wants the full model+report built and gated, not just one piece.
---

# Production Readiness Gate

The orchestrator. Sequences the four domain skills into one delivery flow and runs a single consolidated gate that must pass before a Power BI solution is called production-ready. It does not re-implement the domain skills — it invokes their validators and aggregates the result. Honor `../AUTHORING.md` and `CLAUDE.md`.

## Canonical delivery sequence

```
requirements
  -> power-query (ingest, parameterize, ensure query folding)        [plugin]
  -> semantic-model-architect (star schema, date table, storage, naming)
  -> relationship-and-model-integrity (cardinality, cross-filter, RLS/OLS)
  -> dax-measure-engineering (measures, calc groups, time intel, tested)
  -> enterprise-dashboard-design (layout, theme, accessibility, perf)
  -> production-readiness-gate (this: validate all, document, sign off)
  -> documentation (specs/document-semantic-model.md plan)
```

Run each phase, then the gate. Do not skip ahead — a report built on an unsound model passes visually and fails in production.

## The quality gate

`scripts/run-quality-gate.ps1` aggregates, with a single PASS/FAIL verdict:

1. **Model shape** — `semantic-model-architect/scripts/validate-model-shape.ps1`
2. **Relationships + RLS** — `relationship-and-model-integrity/scripts/validate-relationships.ps1`
3. **DAX smoke test** — `dax-measure-engineering/scripts/test-dax.ps1` on a key measure
4. **Report** — `enterprise-dashboard-design/scripts/validate-report.ps1` (`pbir validate` + structure)
5. **BPA** — Tabular Editor Best Practice Analyzer (delegate to the `bpa-rules` plugin skill); degrade to WARN if TE CLI is absent
6. **Naming/format** — surfaced by the model-shape findings

Any CRITICAL finding => gate FAIL. WARN findings are listed and require explicit sign-off. The gate writes a structured report (text or JSON).

## Production-readiness checklist (the human gate)

See `references/production-readiness-checklist.md`. Headline items:
- Star schema, one marked date table, Auto Date/Time off.
- Relationships sound; bidirectional justified; no ambiguity.
- RLS defined for shared/financial models; roles tested.
- Every measure tested, formatted, foldered, described.
- Report: themed, accessible (WCAG AA), within visual/perf budget, validates.
- Refresh succeeds end-to-end; credentials documented.
- PBIP source-control hygiene in place.
- Documentation generated.

## PBIP source control & sequencing

See `references/pbip-source-control.md`. The `CLAUDE.md` rules are law: TOM `SaveChanges` is in-memory; persist by Ctrl+S or serialize-while-closed; edit report files only while Desktop closed; calculated tables need a `calculate` refresh; byPath thick reports reject `pbir add page`. Back up before risky changes with `scripts/pbip-backup.ps1`.

## Deployment & CI/CD

See `references/deployment-and-cicd.md`: dev/test/prod workspaces, Fabric Git integration, deployment pipelines, and parameter rebinding across stages (delegate workspace/tenant operations to `fabric-cli` and `audit-tenant-settings`).

## Dogfood: STLA_20-F_Model

```
.\scripts\run-quality-gate.ps1 -Port <port> -ReportPath "STLA_20-F_Model.Report" -SmokeDax 'EVALUATE ROW("AOI", [Adjusted Operating Income])'
```
Expect FAIL with itemized issues: Auto Date/Time ON (CRITICAL), zero RLS roles (CRITICAL), compat 1600 (INFO), measures on one wide string table (WARN), plus a passing DAX smoke and a passing/zero-error report validation. The point of the dogfood is that the gate **correctly refuses to pass** a model with these known gaps.

## References

- `references/production-readiness-checklist.md` — the full sign-off checklist.
- `references/pbip-source-control.md` — gitignore, structure, save/serialize sequencing, backup/restore.
- `references/deployment-and-cicd.md` — environments, pipelines, Fabric Git, parameterization.
- `references/bpa-gate.md` — running BPA in the gate and interpreting results.

## Related plugin skills

`bpa-rules`, `review-semantic-model`, `review-report`, `refresh-semantic-model`, `fabric-cli`, `audit-tenant-settings`, plus all four sibling skills.
