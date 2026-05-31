# PBIP Source Control & Sequencing

PBIP stores the model (TMDL) and report (PBIR JSON) as text, so it is Git-friendly — but only if the save/serialize sequencing is respected.

## The sequencing rules (from CLAUDE.md — law)

1. **TOM `SaveChanges()` is in-memory only.** It updates the running Analysis Services process, not the TMDL files. To persist: Ctrl+S in PBI Desktop, or `TmdlSerializer.SerializeDatabaseToFolder($db, $tempPath)` then copy the `.tmdl` files into the project **while PBI Desktop is closed**.
2. **PBI Desktop does not watch its files.** Editing `page.json`/`visual.json`/TMDL while Desktop is open is silently ignored and overwritten on next save. Stop `PBIDesktop`/`msmdsrv` before editing report/model files on disk.
3. **Calculated tables need a `calculate` refresh** after creation, or queries fail with "does not hold any data".
4. **byPath thick reports reject `pbir add page` / `pbir model`** — write JSON directly + `pbir validate`.

## Recommended .gitignore

```
# Power BI cache / local
.pbi/
*.pbix
# Ephemeral working artifacts
tmp/
**/.claude/backups/
# Local environment
tmp/runtime.env
```

Commit the `.SemanticModel/definition/**` TMDL, the `.Report/definition/**` PBIR JSON, and the `.pbip` file. Do not commit `.pbix` (binary) or `tmp/` snapshots.

## Workflow

1. Branch per change (model and report can be reviewed as text diffs).
2. Make TOM changes; persist (serialize-while-closed or Ctrl+S).
3. Run the quality gate.
4. Commit TMDL + PBIR text; review the diff (TMDL is indentation-sensitive — keep formatting stable).
5. Open a PR; the diff is human-reviewable.

## Backup / restore

Use `scripts/pbip-backup.ps1` before risky changes. Restore by closing PBI Desktop, removing the live `.SemanticModel`/`.Report`, and copying the backup back (see CLAUDE.md restore block).

## TMDL hygiene

- Keep indentation/structure identical; do not inject comments or extra blank lines (TMDL is whitespace-sensitive and noisy diffs hide real changes).
- Friendly display names in the model, not source-style snake_case.
- Use the PS 5.1 UTF-8 file APIs when assembling fragments to avoid em-dash/`§` corruption.
