# ADR 0004 — Store explicit links, compute membership

**Status:** accepted · 2026-10-10 (recording a decision made on 2026-10-08)

## Context

Agenda's central idea (US patent 5,115,504) is that items and categories are
independent objects joined by independent links, and that an item assigned
to a category is also a member of all its ancestors ("subsumption"). The
hierarchy changes often: categories are promoted, demoted, moved and
discarded. If ancestor memberships were stored, every one of those changes
would have to rewrite many links, and a single missed update would leave the
data inconsistent.

## Decision

- Only *explicit* links are stored, in `Core.Links`, a bidirectional
  many-to-many relation (the patent's link structures). Links made by
  category links (`also_assign`, R8) and by conditions (R15) are explicit
  links too; the condition-made ones are also listed in
  `Database.conditional` so they can be taken back when the condition stops
  holding.
- Membership is always computed: `Database.member?/3` holds if the item is
  linked to the category or to any of its descendants. MAIN contains every
  item. Date categories (Entry, When, Done) derive membership from the
  item's date fields, and numeric categories keep their value next to the
  link (`Database.numbers`, R29).
- Items do not know their categories and categories do not know their items.
  Both are reached through `Links`.

## Consequences

- Moving a category moves all its items' memberships with it, and nothing
  can get out of step. Promote, demote and move only edit the hierarchy, plus
  the conflict checks for exclusive families (R7a–R7d).
- Assignment rules (exclusion, "not both a category and its ancestor",
  category links) are checked in one place, `Core.Assign`, when links are
  made.
- Membership queries walk a subtree each time. That is fast enough for
  personal data; ADR 0001 notes where to add indexes if it ever isn't.
- CLAUDE.md rule 4 forbids storing derived memberships.
