# Deployment & CI/CD

Delegate actual workspace/tenant operations to the `fabric-cli` and `audit-tenant-settings` plugin skills. This document is the posture the gate expects.

## Environments

Separate **dev / test / prod** workspaces (or Fabric deployment-pipeline stages). Never develop in prod. Promote tested artifacts forward; never edit prod directly.

## Source-control-driven (recommended)

- PBIP text in Git (see pbip-source-control.md).
- Fabric **Git integration**: connect a workspace to a branch; commits sync model/report definitions.
- PR review on the text diff; merge triggers promotion.

## Deployment pipelines

- Power BI/Fabric **deployment pipelines** move content dev -> test -> prod with one action.
- Use **deployment rules / parameters** to rebind data sources and parameters per stage (e.g. dev DB vs prod DB, `RangeStart`/`RangeEnd` windows), so the same artifact points at the right source in each stage.

## Parameterization

- Connection details and environment-specific values as model parameters, not hard-coded in M.
- Incremental-refresh `RangeStart`/`RangeEnd` parameters required.
- Document which parameters change per stage.

## Gate placement in CI/CD

- Run `scripts/run-quality-gate.ps1` (and BPA via TE CLI) as a pre-merge / pre-promotion check.
- Block promotion on any CRITICAL finding.
- For headless CI, BPA via Tabular Editor 2 CLI (`te2-cli`) against the TMDL is the model check; `pbir validate` is the report check.

## Operations

- Scheduled refresh configured; failures alerted.
- Gateway/credentials documented and least-privilege.
- Sensitivity labels and endorsement (certified/promoted) set appropriately for shared models.
- Capacity sizing reviewed for model size and concurrency.

## Checklist
- [ ] dev/test/prod separation.
- [ ] Git integration or pipeline promotion (no direct prod edits).
- [ ] Parameterized sources; deployment rules per stage.
- [ ] Quality gate + BPA wired into promotion.
- [ ] Refresh, credentials, labels, capacity reviewed.
