# ADR 0014 — Negative links between any two categories (an extension)

**Status:** accepted · 2026-10-10

## Context

The Agenda patent (US 5,115,504, FIG. 6) describes negative links: two categories that may not share an item. Agenda 2.0 as shipped only offered this between siblings, as "mutually exclusive" children (R7). The owner chose to add general negative links as an extension (ADR 0006), so there was no original screen, key or storage to follow.

## Decision

- A negative link is a list on each category, `Category.excludes`, kept on both categories of a pair by one facade function, `Core.toggle_exclude/3`. It is a property of the categories, like `also_assign`, not a third relation in the database.
- It is enforced where mutual exclusion is, in `Agendum.Core.Assign`: assigning an item to a category (or below it) removes it from the categories it, or an ancestor, excludes, and their subtrees; `Assign.conflict?/3` treats a negative link like an exclusive family, so text matching never puts an item in both and existing assignments win.
- The file never holds a contradiction. A link is refused rather than resolved: between a category and its lineage, with MAIN, date or numeric categories, and while items are already in both (the user moves them first). A move that would put a category under one it excludes is refused (`:excluded_lineage`).
- The UI reuses the category picker from Category Properties (an "Excludes" row, ENTER toggles), and the rule is marked "not in Agenda" in the SPEC and listed under "Beyond Agenda" in the roadmap.

## Consequences

- The mutual-exclusion code path now covers both rules; changes to one must keep the other (`test/agendum/core/negative_links_test.exs`).
- Refusing instead of resolving is simpler than Agenda's conflict boxes (R7a) but asks more of the user; a resolution box could be added later without changing the storage.
- A category link and a negative link between the same pair settle on the last assignment: the item ends up in one of them, never both.
- STF export (ADR 0010) has no place for negative links; they would be lost when exporting to Agenda 2.0.
