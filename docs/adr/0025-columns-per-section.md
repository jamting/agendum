# ADR 0025 — Columns belong to sections, linked by a shared number

**Status:** accepted · 2026-10-13

## Context

Columns used to belong to the view: every section showed the same
columns. In Agenda each section has its own (User's Guide 3-16, 3-27,
5-22 to 5-25; screenshots 42, 60, 127). A column added "to all sections"
is shown in all of them and is changed as one: widen it in one section
and it widens everywhere. A column added to one section changes alone.
The Planner starter application and Agenda's Activities view depend on
this. In them, each section's item text fills the width its own columns
leave.

How to store this needed a choice:

1. **Columns per section, linked by head**: a flag `linked`, and the
   linked columns of the same head in a view are one column. We did this
   first (format 25). Checking in DOSBox showed it was wrong: adding When
   to all sections joined the When already there, and removing it took
   every linked When. In Agenda each column added is a column of its own,
   even with the same head as another.
2. **Columns per section, linked by a number**: each column has a `link`,
   a number shared by the places of one column, or `nil` for "this
   section only".
3. **Columns stored once in the view, with a list of sections each is
   in.** This makes "one column" explicit, but the order of columns in a
   section (and moving one, which Agenda does in the current section
   only) would have to be stored somewhere else.

## Decision

- Columns are stored per section (`section.columns`), in their order
  (option 2). A datebook view's slots share one set (`view.columns`,
  R47).
- `View.Column.link` joins the places of one column. Columns with the same
  `link` in a view are one column: a change to the width, format or head
  is made in each of them. `nil` means the column is in this section only.
  A link number is used in one view only.
- A column is addressed as `{section index, column index}` (`View.at`).
  The facade's column functions take this place.
- The rules (adding to all sections or one, where the other sections get
  it, removing from all or one, linking and unlinking, changing the head)
  live in the pure `Agenda.Core.ViewColumns`, not in the TUI.
- Where a new column goes is a file setting, File Properties ▸ Insert new
  columns in (All sections by default, R55), stored in
  `Database.insert_columns`.
- Old files are upgraded on load (ADR 0003). Before format 25, every view
  column goes into every section, linked. Formats 25 and 26, and JSON with
  `linked`, get one link for the first linked column of a head in each
  section, another for the second, and so on (format 27).

## Consequences

- The same head can be a column twice in one section, and each copy is
  removed or widened on its own, as in Agenda.
- Working out the linked places means scanning the view's sections. Views
  are small, so we do not keep an index of them.
- Some decisions are ours, because Agenda's manual does not cover them
  (marked "ours" in R55): where the other sections place a column, and
  that a new section gets the linked columns of the section the cursor
  was in.
- Moving a column is not done yet. With columns per section, it moves in
  the current section only, as in Agenda.
- The JSON format, `DATA_MODEL.md` and `DATA_ACCESS.md` describe the
  `link` field. A front end reads columns per section from the view model.
