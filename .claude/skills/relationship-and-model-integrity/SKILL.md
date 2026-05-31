---
name: relationship-and-model-integrity
version: 1.0.0
description: Design and validate Power BI model relationships, cardinality, cross-filter direction, and row/object-level security. Automatically invoke when the user asks to "create a relationship", "set cardinality", "cross-filter direction", "bidirectional filtering", "fix ambiguous relationships", "inactive relationship", "USERELATIONSHIP", "role-playing dimension", "set up RLS", "row-level security", "dynamic security", "object-level security", "test as role", or mentions model integrity, circular paths, or many-to-many.
---

# Relationship & Model Integrity

Owns the **join graph and the security model** — the two places where a wrong default silently corrupts every number a report shows. Decides shape and gates correctness; delegates object writes to `tmdl`, downstream impact to `lineage-analysis`, and structural audit to `review-semantic-model`. Honor `../AUTHORING.md` and `CLAUDE.md`.

## Operating procedure

1. **Confirm the star.** Relationships flow from dimensions (one side) to facts (many side). No fact-to-fact relationships. Resolve true many-to-many with a bridge table, not native `*:*`.
2. **Cardinality: one-to-many by default.** The one-side key must be unique (validate it). Avoid `*:*` unless you understand the limited-relationship semantics and have a reason.
3. **Cross-filter: single direction by default.** Bidirectional only with explicit justification — it creates ambiguity, can change measure results, and adds Storage Engine cost. If used, document why and check `securityFilteringBehavior`.
4. **No ambiguity / no circular paths.** Multiple active paths between two tables create ambiguity; keep exactly one active path and make alternates inactive.
5. **Role-playing dims:** one shared dimension, one active relationship, the rest inactive, switched per measure with `USERELATIONSHIP` (see `dax-measure-engineering`).
6. **Inactive relationships must be used.** An inactive relationship with no `USERELATIONSHIP` reference anywhere is a modeling smell — either wire it up or remove it.
7. **Disconnected dimensions are deliberate.** A table with no relationship driving `SELECTEDVALUE`-based measures (the project's `Region`/`AdjustmentBridge`) is valid — mark it as intentional so the validator does not flag it as orphaned.
8. **Security:** decide RLS posture. Static roles (fixed table filters) or dynamic roles (`USERPRINCIPALNAME()` against a security/users dimension). Add OLS where columns/tables must be hidden from some roles. Test every role.
9. **Validate** with `scripts/validate-relationships.ps1`, then test security with `scripts/test-rls.ps1` before handoff.

## Defaults

| Decision | Default | Deviate only when |
|----------|---------|-------------------|
| Cardinality | One-to-many | Bridge for true many-to-many; `1:1` for vertical partition |
| Cross-filter | Single | Bidirectional with documented reason (e.g. bridge slicing) |
| Active paths between two tables | Exactly one | Others inactive + `USERELATIONSHIP` |
| Many-to-many | Bridge table | Native `*:*` only with justification |
| RLS | At least one role for downstream consumers | Internal dev-only model |
| Inactive relationship | Referenced by `USERELATIONSHIP` | Otherwise remove |

## Why bidirectional is dangerous

- **Ambiguity:** the engine may have multiple filter paths; results become order-dependent and hard to reason about.
- **Performance:** extra cross-filtering work in the Storage Engine.
- **Security holes:** bidirectional + RLS can leak rows across tables; review `securityFilteringBehavior` and prefer single direction with `CROSSFILTER` in specific measures if needed.

Read `references/relationship-design.md` before enabling any bidirectional relationship.

## Security (RLS / OLS)

- **Static RLS:** role with a fixed table filter, e.g. `[Region] = "East"`.
- **Dynamic RLS:** a `Users` table mapping login to allowed keys; filter via `USERPRINCIPALNAME()`:
  ```dax
  [Email] = USERPRINCIPALNAME ()
  ```
  Cascade the filter from the security dimension to facts through relationships (bidirectional may be required on the bridge — handle carefully).
- **OLS:** hide specific tables/columns per role (TMDL object permissions); note OLS can break visuals/measures that reference hidden objects.
- **Test** with "View as role" in Desktop or `EffectiveUserName`/role context via `scripts/test-rls.ps1`. See `references/rls-ols-patterns.md`.

## Dogfood: STLA_20-F_Model

`scripts/validate-relationships.ps1 -Port <port>` must report: the disconnected `Region` and `AdjustmentBridge` dims (intentional), the 8 auto-LocalDateTable relationships (auto-date noise), the single user relationship (`Company_Name` to `CIK_Lookup`), and **zero RLS roles** (gap for a financial model). `scripts/test-rls.ps1` confirms no roles exist to test.

## References

- `references/relationship-design.md` — cardinality, cross-filter, ambiguity, inactive/role-playing, bridges, `*:*` semantics.
- `references/rls-ols-patterns.md` — static & dynamic RLS, OLS, security-filtering-behavior, testing.
- `references/model-validation-checklist.md` — the integrity gate the validate script encodes.

## Related plugin skills

`tmdl`, `lineage-analysis`, `review-semantic-model`, `connect-pbid`, `bpa-rules`.
