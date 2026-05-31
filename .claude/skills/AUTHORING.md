# Skill Authoring Contract — Power BI Agentic Development (Enterprise Skills)

This file is the shared contract every skill under `.claude/skills/` must follow. It exists so the five enterprise skills stay consistent with each other and with the upstream `power-bi-agentic-development` plugin, and so they **delegate to** the plugin's 25 granular skills rather than duplicating them.

## 1. Directory layout

```
.claude/skills/<skill-name>/
  SKILL.md          # required — frontmatter + progressive-disclosure body
  references/*.md   # deep-dive docs, loaded on demand
  scripts/*.ps1     # automation (PowerShell 5.1-safe), optional
  assets/*          # templates (themes, specs), optional
```

`<skill-name>` is kebab-case and **must equal** the `name:` in the frontmatter.

## 2. SKILL.md frontmatter schema

```yaml
---
name: <kebab-case, == directory name>
version: 1.0.0
description: <one paragraph written as trigger phrasing — "Use when the user asks to …" with concrete keywords the model can match>
---
```

- `name` and `description` are **required**. `version` is recommended.
- The `description` is the only thing the model sees before loading the skill, so it must be dense with trigger keywords (verbs + nouns the user is likely to say). Mirror the upstream plugin style: *"Automatically invoke when the user asks to …"*.
- Do **not** add `allowed-tools` unless the skill must be restricted; these skills use the full tool set.

## 3. Progressive disclosure

`SKILL.md` is the always-loaded summary. It states the **decision rules and defaults**, then points to `references/*.md` for depth ("for the full pattern catalog, read `references/<file>.md`"). Keep `SKILL.md` to roughly 150–280 lines. Put long catalogs, tables, and worked examples in `references/`.

## 4. Delegate, don't duplicate

These five skills are the **enterprise methodology + gating layer**. The mechanical "how to" already exists in the plugin and must be referenced by name, never re-implemented:

| Need | Delegate to (plugin skill) |
|------|----------------------------|
| Serialize / edit TMDL objects | `tmdl` (pbip) |
| DAX optimization framework, engine internals | `dax` (semantic-models) |
| Power Query / M authoring, query folding | `power-query` (semantic-models) |
| Naming audit + remediation | `standardize-naming-conventions` (semantic-models) |
| Downstream impact / lineage | `lineage-analysis` (semantic-models) |
| Refresh monitoring / troubleshooting | `refresh-semantic-model` (semantic-models) |
| Model audit (structural) | `review-semantic-model` (semantic-models) + `semantic-model-auditor` agent |
| Connect to local PBI Desktop AS (TOM/ADOMD) | `connect-pbid` (pbi-desktop) |
| PBIR JSON structure (visual.json/page.json) | `pbir-format` (pbip) |
| PBIR CLI operations | `pbir-cli` (reports) |
| Report design principles | `pbi-report-design` (reports) |
| Theme JSON edits | `modifying-theme-json` (reports) |
| Report review | `review-report` (reports) |
| Custom visuals | `deneb-visuals` / `svg-visuals` / `python-visuals` / `r-visuals` (reports) |
| BPA rule authoring + audit | `bpa-rules` (tabular-editor) |
| Bulk model changes (C#) | `c-sharp-scripting` (tabular-editor) |
| Tabular Editor CLI | `te2-cli` / `te-docs` (tabular-editor) |
| Fabric workspace / deployment | `fabric-cli` + `audit-tenant-settings` (fabric-admin) |

## 5. Cross-skill interlock (canonical end-to-end order)

```
requirements
  → power-query (ingest, fold)                     [plugin]
  → semantic-model-architect                       [this set]
  → relationship-and-model-integrity               [this set]
  → dax-measure-engineering                        [this set]
  → enterprise-dashboard-design                    [this set]
  → production-readiness-gate (validates all)      [this set]
  → docs (specs/document-semantic-model.md)
```

`production-readiness-gate` is the orchestrator: its `run-quality-gate.ps1` invokes the validate scripts shipped by skills 1–4 plus BPA and `pbir validate`.

## 6. The CLAUDE.md sequencing rules are law

Every skill that touches the model or report **must** stay consistent with the workspace `CLAUDE.md` and cross-reference it rather than restating it in full:

1. TOM `SaveChanges()` is **in-memory only**. To persist, Ctrl+S in PBI Desktop or `TmdlSerializer.SerializeDatabaseToFolder` then copy while Desktop is **closed**.
2. PBI Desktop does **not** watch its files — stop `PBIDesktop`/`msmdsrv` before editing `page.json`/`visual.json`/TMDL on disk.
3. Calculated tables need a `calculate` refresh after creation.
4. byPath thick reports reject `pbir add page` / `pbir model` — write JSON directly + `pbir validate`.

## 7. PowerShell 5.1 UTF-8 rule

Scripts that assemble Markdown/JSON/TMDL fragments must use `[System.IO.File]::ReadAllText/WriteAllText` with `New-Object System.Text.UTF8Encoding($false)` — **not** `Get-Content -Raw` + `Out-File -Encoding utf8` (corrupts em-dash / `§`). Keep `.ps1` source ASCII-only. Discover the AS port with the `:(\d+)$` regex pattern from `CLAUDE.md`, not positional token indexing.

## 8. Dogfood requirement

Every skill ships proof it works against the workspace reference model `STLA_20-F_Model`, which has known issues each skill must correctly surface: auto Date/Time on (8 shadow date tables), compatibility level 1600 (no DAX UDFs), disconnected `Region`/`AdjustmentBridge` dims, zero RLS roles, all 88 measures on one wide-format string table. **Mutating** dogfood checks run against a scratch copy, never the source model.

## 9. Doc style

No emojis. No marketing language. Identifiers in backticks. Verified values in tables. Code blocks for every DAX/M/PowerShell reference. Match the cadence of `STLA_Power_BI/docs/AOI_Overview.md` and `specs/document-semantic-model.md`.
