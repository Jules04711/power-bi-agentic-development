---
description: Generate a HANDOVER.md session summary for seamless continuity between Claude sessions
allowed-tools: Write, Read, Glob
---

# Session Handover

Generate a comprehensive handover document that captures everything from this session so the next Claude session can pick up exactly where we left off. Think of this as a shift-change report.


## Manual Handover (this command)

You can still use `/handover` at any point to manually generate a handover — not just before compaction.

## Instructions

1. **Review the entire conversation** from start to finish. Identify every task worked on, every decision made, every bug encountered, and every file touched.

2. **Scan the project for context** using `Glob` to identify recently modified files if needed.

3. **Read the existing `HANDOVER.md`** first (if it exists) — this is required before the Write tool can overwrite it.

4. **Write `HANDOVER.md`** to the project root using the exact format below. Replace all bracketed placeholders with real content from this session. If a section has nothing to report, write "None this session." — do not skip sections.

4. **Be specific and precise.** Use exact file paths, exact error messages, exact tool names. The next Claude has zero context — give it everything.

## HANDOVER.md Format

Write this exact structure to `HANDOVER.md` in the project root:

```markdown
# Session Handover

> Generated: [today's date] | Project: [project folder name]

## Session Summary
[2-3 sentence overview of what this session accomplished. What was the user's goal? How far did we get?]

## What Was Done
- [Completed work item with file paths, e.g., "Created `.claude/commands/handover.md` — new /handover slash command"]
- [Another completed item]
- [Continue for all work items]

## What Worked & What Didn't
### Worked Well
- [Approaches, tools, or patterns that succeeded]
- [Things that went smoothly]

### Issues Encountered
- [Bug or error encountered] — **Resolution**: [how it was fixed]
- [Another issue] — **Resolution**: [how it was fixed or "unresolved"]

## Key Decisions
| Decision | Reasoning | Alternatives Considered |
|----------|-----------|------------------------|
| [What was decided] | [Why this choice was made] | [What other options were discussed] |

## Lessons Learned & Gotchas
- [Things the next session should know to avoid repeating mistakes]
- [Platform-specific issues, version quirks, API limitations, etc.]
- [Patterns that work well in this codebase]

## Current State
- **Working**: [What's functional right now]
- **Broken/Incomplete**: [What still needs work]
- **Blocked**: [Anything waiting on external input, API keys, user decisions, etc.]

## Next Steps
1. [Highest priority next action — include enough context to start immediately]
2. [Second priority]
3. [Continue as needed]

## Important Files Map
| File | Purpose | Status |
|------|---------|--------|
| [file path] | [what this file does/is for] | [created / modified / needs-work] |

## Environment & Config Notes
- [Runtime requirements, e.g., "Python 3.9+", "Node 18+"]
- [API keys or credentials status, e.g., "xAI key in ~/.config/last30days/.env but no credits"]
- [Any local setup the next session needs to be aware of]
```

## After Writing HANDOVER.md — Update Lessons Learned

After writing `HANDOVER.md`, you MUST also update the persistent lessons learned document at `knowledge-base/lessons-learned-best-practices.md`.

### Steps:

1. **Read** `knowledge-base/09-lessons-learned-best-practices.md` to understand its current structure and content.

2. **Compare** the "Lessons Learned & Gotchas" section you just wrote in `HANDOVER.md` against the existing content in `09-lessons-learned-best-practices.md`.

3. **For each lesson from this session**, decide:
   - **Already covered?** — Skip it. Do not add duplicates.
   - **New lesson?** — Add it to the appropriate existing category section (1–14). Place it under the most relevant heading.
   - **Updates/contradicts an existing lesson?** — Edit the existing entry to reflect the latest understanding.
   - **Doesn't fit any existing category?** — Add it to the closest category, or if it represents a genuinely new topic, add a new `## 15. [Topic]` section (and update the Table of Contents).

4. **Use the Edit tool** to surgically add new lessons — do NOT rewrite the entire file.

5. **Keep the same style**: bold keyword lead, dash-prefixed bullets, backtick code references, same level of specificity as existing entries.

### Example of a good addition:

```markdown
- **`newFunction()` silently returns null on missing input** — always guard with `if (!input) return defaultValue;`. Discovered when Schedule X rendered $0 for all rows.
```

### Do NOT:
- Add session-specific context (dates, "this session", task descriptions)
- Duplicate lessons already in the file
- Add vague lessons ("be careful with data") — be specific with function names, field names, and error descriptions
- Remove or reorganize existing content unless correcting an error

## After Both Writes

Respond with:

```
Handover document saved to HANDOVER.md
Lessons learned updated in knowledge-base/09-lessons-learned-best-practices.md

Tip: Commit it to git if you want to keep a history of session handovers.
```
