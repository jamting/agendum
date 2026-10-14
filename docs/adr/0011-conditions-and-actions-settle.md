# ADR 0011 — Conditions and actions run in one step after every change

**Status:** accepted · 2026-10-10

## Context

Agenda's conditions *pull* items into categories and are checked again
whenever an item changes; its actions *push* items on, and run once, when an
item joins a category (User's Guide chapters 18–21). Both can trigger each
other: a condition pulls an item into a category whose action assigns it
elsewhere, which may meet another condition. Date conditions with relative
dates ("this week") also depend on today's date and on the reader's date
languages (ADR 0009), and must be checked again when the date changes.

Two questions had to be settled: where in the code these rules run, and how
they learn today's date without the core reading the clock (ADR 0001).

## Decision

- Every facade function that changes an item's assignments, text, dates or
  numbers ends in one private step, `settle(db, before, item, clock)` in
  `Agendum.Core`: first the conditions are checked again
  (`Assign.apply_conditions`), then the actions of every category the item
  belongs to now but did not belong to in `before` run, children's before
  their parents', special actions last; repeated until nothing new happens,
  with a bound. Nothing else runs actions.
- "Once" is decided by comparing membership before and after the change, not
  by remembering which actions ran. Utilities Execute (`Core.execute/3`) can
  pretend an item has just arrived to run actions on old assignments.
- Today's date and the date languages reach conditions and actions as an
  optional `clock` argument (a `Date`, `NaiveDateTime` or `Agendum.Core.Context`),
  passed by the TUI as `State.context(state)`. Without a clock only ISO dates
  in conditions and actions can be read; nothing falls back to the system
  clock. The clock tick re-checks every item when the date changes.
- Rejected: storing today's date (and the languages) in the database. It
  would make an unsaved file look modified at midnight, and would put a
  personal setting into the file (ADR 0008).

## Consequences

- New features that change items only need to end in `settle` to respect
  conditions and actions; undo still sees one change per key (ADR 0005).
- Many facade functions gained an optional trailing clock argument; callers
  that omit it get correct results except for relative dates in conditions
  and actions.
- A special action may discard the item during the change, so callers (and
  the TUI) must not assume the item still exists afterwards.
- Re-checking every item on a new day is linear in the number of items,
  which is fine for personal files.
