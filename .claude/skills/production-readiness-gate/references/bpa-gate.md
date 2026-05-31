# BPA in the Quality Gate

The Best Practice Analyzer (BPA) is the standardized model-quality check. Author/curate rules with the `bpa-rules` plugin skill; run them in the gate.

## Running BPA

- **Interactively:** Tabular Editor 2/3 against the live model or TMDL.
- **Headless / CI:** Tabular Editor 2 CLI (`te2-cli` plugin skill):
  ```
  TabularEditor.exe "<model.bim or .SemanticModel>" -A <rules.json> -V
  ```
  `-A` analyzes against a rules file; `-V` returns non-zero on violations (usable as a gate).

## Rule sources

- Microsoft's standard BPA rule set (good baseline).
- Team/org rules authored via `bpa-rules` (naming, format strings, no-bidirectional, key hygiene, etc.).
- These can overlap with the sibling skills' validators — that is fine; BPA is the portable, CI-friendly expression of the same standards.

## Interpreting in the gate

- Map BPA severities to the gate: Error -> CRITICAL, Warning -> WARN, Info -> INFO.
- A BPA Error fails the gate.
- If Tabular Editor CLI is not installed, the gate degrades this check to a WARN ("BPA not run") rather than failing — but production sign-off should not skip BPA.

## What BPA catches that complements the validators

- Naming-convention violations across many objects at once.
- Missing format strings / descriptions at scale.
- Hidden columns still `isAvailableInMdx`.
- Calculated columns that should be measures.
- Relationship/key best-practice violations.

## Recommendation

Keep one canonical `rules.json` in the repo, referenced by both interactive Tabular Editor and the CI gate, so local and pipeline checks are identical.
