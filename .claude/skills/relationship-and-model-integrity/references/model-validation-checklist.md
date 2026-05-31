# Model Integrity Checklist

`scripts/validate-relationships.ps1` automates the machine-checkable items. Severities: CRITICAL blocks release, WARN needs justification, INFO advisory.

## Relationships
- [ ] CRITICAL — One-side key unique on every 1:* relationship.
- [ ] CRITICAL — No fact-to-fact relationships.
- [ ] CRITICAL — Exactly one active path between any two tables (no ambiguity/loops).
- [ ] WARN — No bidirectional cross-filter without a documented reason.
- [ ] WARN — No native many-to-many without a bridge or justification.
- [ ] WARN — Every inactive relationship referenced by `USERELATIONSHIP` somewhere.
- [ ] INFO — Disconnected dims confirmed intentional (not accidental orphans).
- [ ] INFO — Auto-date `LocalDateTable_*` relationships flagged (artifact of Auto Date/Time).

## Security
- [ ] CRITICAL (for shared/production models) — At least one RLS role defined for downstream consumers.
- [ ] WARN — Dynamic RLS uses `USERPRINCIPALNAME()` (not `USERNAME()`).
- [ ] WARN — Every sensitive table covered by a role filter.
- [ ] WARN — `securityFilteringBehavior` set deliberately on any bidirectional relationship under RLS.
- [ ] WARN — Totals and `ALL`-based measures verified under each role.
- [ ] INFO — OLS-hidden objects not hard-referenced by visuals/measures used by that role.

## Expected findings on STLA_20-F_Model (dogfood baseline)
- Disconnected `Region`, `AdjustmentBridge` dims — INFO (intentional).
- 8 auto-LocalDateTable relationships — INFO (Auto Date/Time artifact; fix via `semantic-model-architect`).
- 1 user relationship `Company_Name` to `CIK_Lookup` — INFO.
- 0 RLS roles — CRITICAL for a financial model intended for sharing.
