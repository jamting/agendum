# ADR 0016 — File-wide defaults, with local overrides stored as differences

**Status:** accepted · 2026-10-11

## Context

Agenda 2.0 often sets something for the whole file and lets one part of it differ: text matching is set in the Auto-assign Global Settings, and each category may set its own (Advanced settings, User's Guide 19-8); dates display in the file's Display format, and a date column may have its own ("Global defaults" vs "Local settings", User's Guide 6-19). We had to decide how to store a local setting so that changing the global one still reaches every place that has not set its own.

## Decision

- The file holds the whole global setting (`db.match_settings`, `db.confirm_assignments`, `db.date_format`).
- A local setting stores only what differs:
  - a category's text matching is a map of the fields it sets, `Category.match_overrides`; a field set back to Global is removed (`Core.set_match_override/4` with `:global`);
  - a date column's format is `View.Column.date`, `nil` for the global defaults, or a whole `DateFormat` once any setting is changed, as Agenda's column box switches from "Global defaults" to "Local settings" as a whole.
- The effective setting is computed by one function each, never copied: `Assign.match_settings/2` and `confirm_mode/2` merge a category's overrides into the file's; `ViewModel.cell/6` uses the column's format or the file's. Display and matching code call these only.
- The UI shows what is inherited: "Global (Item text)" for a category field, "Global defaults" for a column.

## Consequences

- Changing a global setting changes every category or column that has not set its own, with nothing to update.
- The two granularities differ (per field for categories, whole format for columns), following the manual; a new override should pick the one its Agenda box uses.
- New fields in a global setting reach local ones automatically for categories; a column's own `DateFormat` gets the new field's default on upgrade (`Store.upgrade`).
