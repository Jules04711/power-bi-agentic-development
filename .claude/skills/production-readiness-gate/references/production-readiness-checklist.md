# Production Readiness Checklist

The sign-off gate for an enterprise Power BI solution. CRITICAL blocks release; WARN requires documented sign-off; INFO advisory. Machine-checkable items are run by `scripts/run-quality-gate.ps1`.

## 1. Semantic model (semantic-model-architect)
- [ ] CRITICAL — Star schema; no fact-to-fact; dimensions flat or justified.
- [ ] CRITICAL — One explicit `Date` table, marked, contiguous, spanning facts.
- [ ] CRITICAL — Auto Date/Time disabled (no `LocalDateTable_*`).
- [ ] CRITICAL — Correct data types (no currency-as-Double, no numeric-as-String).
- [ ] WARN — Naming (friendly Title Case), format strings, display folders, descriptions complete.
- [ ] WARN — Large facts partitioned + incremental refresh.
- [ ] INFO — Compatibility level recorded.

## 2. Relationships & security (relationship-and-model-integrity)
- [ ] CRITICAL — One-side keys unique; one active path; no ambiguity.
- [ ] CRITICAL — RLS role(s) defined for shared/financial models.
- [ ] WARN — Bidirectional relationships justified; `securityFilteringBehavior` set under RLS.
- [ ] WARN — Inactive relationships referenced by `USERELATIONSHIP`.
- [ ] WARN — All roles tested ("View as" / `test-rls.ps1`); totals verified.

## 3. DAX (dax-measure-engineering)
- [ ] CRITICAL — Every shipped measure tested against a known value.
- [ ] WARN — `DIVIDE` for division; column-filtering in CALCULATE; variables; no anti-patterns.
- [ ] WARN — Implicit measures discouraged; time intel uses the marked date table.
- [ ] INFO — Performance budgets met on key measures.

## 4. Report (enterprise-dashboard-design)
- [ ] CRITICAL — `pbir validate` passes; all page/visual JSON valid.
- [ ] WARN — Custom theme applied; layout grid + detail gradient; titles present.
- [ ] WARN — Accessibility WCAG AA (alt text, contrast, tab order, colorblind-safe).
- [ ] WARN — <= 12-15 visuals/page, <= 3 slicers/page; perf budget met.
- [ ] INFO — Visual selection appropriate to each question.

## 5. Operations
- [ ] CRITICAL — Refresh succeeds end-to-end against all sources.
- [ ] WARN — Credentials / gateway documented; source dependencies listed.
- [ ] WARN — Sensitivity label applied where data warrants (financial/SEC data).
- [ ] WARN — PBIP source-control hygiene (see pbip-source-control.md).
- [ ] INFO — Deployment pipeline / environments configured (see deployment-and-cicd.md).

## 6. Documentation
- [ ] WARN — Semantic model reference generated (specs/document-semantic-model.md plan).
- [ ] INFO — Known caveats and decisions recorded.

## Sign-off
Gate PASSES only when: zero CRITICAL findings, and every WARN has an explicit recorded justification.
