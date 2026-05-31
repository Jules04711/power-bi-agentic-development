# RLS & OLS Patterns

## Row-Level Security (RLS)

RLS restricts which **rows** a user sees by applying DAX table filters per role. The model defines roles + filters; the workspace maps users/groups to roles.

### Static RLS

A role with a hard-coded filter:
```dax
-- Role "East", filter on 'Region':
[Region] = "East"
```
Simple, but needs one role per slice — does not scale to many users.

### Dynamic RLS

One role, filter parameterized by the logged-in user:
1. Add a `Users` (security) table: `Email`, plus the key(s) they may see (e.g. `Region`).
2. Relate `Users` to the dimension/fact so the filter cascades.
3. Role filter on the `Users` table:
   ```dax
   [Email] = USERPRINCIPALNAME ()
   ```
4. The filter on `Users` propagates to the dimension and then to facts via relationships. Cascading from the security table to facts sometimes requires a bidirectional relationship on the bridge — set `securityFilteringBehavior` carefully and test.

Use `USERPRINCIPALNAME()` (returns the UPN/email in the Service) rather than `USERNAME()` (returns DOMAIN\user locally) for portability between Desktop and Service.

### Pitfalls

- A role with **no** filter on a table sees all of it — confirm every sensitive table is covered.
- Measures that use `ALL`/`REMOVEFILTERS` can bypass RLS context for totals — verify totals under each role.
- Bidirectional + RLS can leak rows — review propagation.

## Object-Level Security (OLS)

OLS hides **tables or columns** from a role entirely (not just rows). Authored as object permissions in TMDL/Tabular Editor. Caveats:
- A visual or measure that references an OLS-hidden object errors for that role — design measures to avoid hard dependencies on hidden objects.
- OLS and RLS compose; test the combination.

## Testing

- **Desktop:** Modeling > View as > pick role (and, for dynamic RLS, supply a user) and confirm visuals filter correctly.
- **Programmatic:** run a query in a role context / with `EffectiveUserName` via `scripts/test-rls.ps1` and compare row counts / totals against expected.
- Test **every** role, including the totals and any `ALL`-based measures.

## Production posture

A model containing financial or externally-filed data (like `STLA_20-F_Model`) should have at least a defined read role for downstream consumers and, if multi-tenant, dynamic RLS. Zero roles is a documented governance gap, not a neutral default.
