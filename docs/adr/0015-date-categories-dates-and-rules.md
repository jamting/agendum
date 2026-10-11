# ADR 0015 — Dates of date categories, and the rules that set them

**Status:** accepted · 2026-10-11

## Context

Agenda 2.0 has three built-in date categories (Entry, When, Done) and
lets the user make more ("Due", "Called"; User's Guide 7-3 to 7-8). Each
date category has Advanced settings that say where its dates come from:
the clock when an item is entered or edited, a date in the item text or
note, or F4/ALT-F2. Our first version stored the built-in dates as `Item`
fields (`entry`, `when`, `when_time`, `done`) and kept one file setting
for where When dates came from (`db.auto_date`, later `db.when_from`).

## Decision

- The built-in dates stay fields of `Item`; they are on every item and
  much of the code reads them. A date category the user makes keeps its
  dates in one map, `db.dates`, keyed `{item_id, category_id}` and holding
  `{date, time, explicit}`. `explicit` marks a date set by hand, which
  text never overwrites, as `Item.when_explicit` does for When.
- Code reads every date category the same way, through
  `Database.item_date/3`, `item_time/3`, `date_explicit?/3` and
  `put_item_date/6`, so views, filters, conditions and columns need not
  know where a date is stored.
- How a category gets dates is a property of the category,
  `Category.date_rule` (`Core.DateRule`: assign, which, done key, when
  key), for built-in and user date categories alike. When's rule
  replaced the file-wide `when_from`; Entry, When and Done get Agenda's
  defaults (`DateRule.builtin/1`), and a new date category starts at
  Never.
- Rules run in the core, never in the UI: clock stamps on entry, edit or
  assignment and dates read from text in `Assign`, as part of settling
  after a change (ADR 0011); the F4 and ALT-F2 keys in the facade
  (`Core.when_key/4` and marking done), applying every rule that has them.
- Making a standard category a date category (`Core.make_date/3`) follows
  the manual: its children are removed and their items get the child's
  name as their date (set by hand); children whose names are not dates,
  and items assigned to the category itself, get none. It also drops
  what a date category cannot have (its assignments, name matching,
  exclusive children, negative links), refuses a category with
  grandchildren, and cannot be undone except by undo. The UI shows
  what will happen (`Core.date_conversion/3`) and asks first.

## Consequences

- Two storage places for dates is a small asymmetry, hidden behind the
  `Database` reads; tests for user date categories cover both.
- Deleting an item or a category must also clear `db.dates`
  (`Database.delete_item/2`, `delete_category/2` do).
- Files before format 18 are upgraded: When's rule takes the old
  `when_from` (`Store.upgrade`).
- JSON and STF export (ADR 0010) must write user dates as assignments
  with a date, as Agenda's STF does.
