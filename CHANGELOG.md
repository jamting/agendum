# Changelog

What changed in each version of Wol's Agendum, for the person using it.
Versions follow [semantic versioning](https://semver.org): before 1.0.0,
the minor number (0.**3**.0) goes up with every major feature or change to
the file format, the patch number (0.3.**1**) with fixes. Each version is
tagged in git (`v0.2.0`). The roadmap's Done section
([`docs/ROADMAP.md`](docs/ROADMAP.md)) lists every finished item; git log
has the detail.

## Unreleased

- Quicker answers to keys: keys typed fast or held down are answered
  with one drawing, and views showing many items draw faster.
- The debug log (`AGENDUM_LOG`) notes every answer to a key that took
  100 ms or more, with how the time was spent.

## 0.2.0 — 2026-10-15

The first numbered version: everything built since the first commit
(2026-10-08), about 80% of the way to Lotus Agenda 2.0
([`docs/plans/AGENDA_PARITY.md`](docs/plans/AGENDA_PARITY.md)).

- Items, categories and views as in Agenda: automatic filing by text,
  conditions and actions, mutually exclusive categories, dependencies.
- Dates read from plain text (English and Swedish), times, recurring
  dates, date categories, datebook views, alarms, the pop-up calendar.
- Views with sections, columns per section, sorting, date and numeric
  filters, numeric columns with totals.
- Notes with marking, cut and paste, search and replace, word wrap.
- Learn-mode macros, the Activities Planner starter file, themes,
  preferences, undo and redo.
- JSON export and import; calendar subscriptions from the web.
- Agenda's look: its colours, two-line control panel, boxes and menus.
- File format version 33.
