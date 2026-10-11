# The JSON file format

File ▸ Transfer ▸ Export writes a whole Agenda file as JSON, and File ▸
Transfer ▸ Import reads one back (SPEC R44, ADR 0010). The JSON holds
everything in the file, so an export imported again gives the same file. It
is meant for backups you can read, diffs, scripts and moving data to other
tools. The working format stays the Erlang-term `.agenda` file (ADR 0003).

The code is `Agenda.Core.JSONFile`; `test/agenda/core/json_file_test.exs`
and `json_round_trip_test.exs` check that a round trip changes nothing.

## Conventions

- The file is UTF-8, pretty-printed with two spaces; every object lists its
  keys in the order given here, so exports of the same file are identical.
- Ids are the file's integer ids (one counter for categories, items and
  views); references are by id.
- Enumerations are lowercase strings (`"standard"`, `"item_text"`).
- Dates are ISO 8601 (`"2026-10-31"`), times `"15:30:00"`, moments
  `"2026-10-09T14:45:00"`. `null` means none.
- Numbers are JSON numbers (`1234.5`).
- Reading: a key left out takes its default (as for a new category, item or
  view), so hand-written files can be short. Unknown values, wrong types and
  references to ids that do not exist are refused with a message naming the
  place (`categories[3].kind: unknown value "cheese"`). Unknown keys are
  ignored.
- Settings that belong to the person (theme, date languages, input format)
  are never in a file (ADR 0008).

## The document

```json
{
  "format": "agenda-json",
  "version": 1,
  "next_id": 21,
  "main": 1,
  "special": {"entry": 2, "when": 3, "done": 4},
  "settings": { … },
  "categories": [ … ],
  "items": [ … ],
  "views": [ … ],
  "calendars": [ … ]
}
```

| Key          | Meaning                                                                  |
| ------------ | ------------------------------------------------------------------------ |
| `format`     | Always `"agenda-json"`.                                                  |
| `version`    | The schema version, 1. Later versions of the program will still read it. |
| `next_id`    | The next id to hand out; above every id in the file.                     |
| `main`       | The id of MAIN, the root category.                                       |
| `special`    | The ids of the Entry, When and Done date categories.                     |
| `settings`   | The file's settings (below).                                             |
| `categories` | Every category, in hierarchy order (MAIN first, then depth-first).       |
| `items`      | Every item, in file order.                                               |
| `views`      | Every view, in the view manager's order.                                 |
| `calendars`  | Calendar subscriptions (R45).                                            |

## Settings

| Key                   | Meaning                                                                                                                                                                                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `date_format`         | How dates display (R41, R41a): `order` (`"yyyymmdd"`, `"mmddyy"`, … `"week"`, `"relative"`), `separator`, `clock` (12 or 24), `day_of_week`, `show` (`"date_time"`, `"date"`, `"time_date"`, `"time"`), `am_pm`, `time_separator` (`":"` or `"hm"`). |
| `date_settings`       | How dates are read (R14e): `week_start`, `week_end` (1 = Monday … 7), `quarter_start`, `year_start` (1–12), `month_alone` (`"first"`, `"last"` or a day), `morning`, `afternoon`, `evening` (times).                                                 |
| `match_settings`      | Text matching (R16a): `enabled`, `match_on` (`"item"`, `"note"`, `"both"`), `strength` (`"exact"`, `"partial"`, `"minimal"`), `enclosed_by` (`"quotes"`, `"brackets"`, …), `ignore_suffixes`, `ignore_accents`.                                      |
| `confirm_assignments` | `"never"`, `"always"` or `"sometimes"` (R16).                                                                                                                                                                                                        |

## Categories

| Key               | Meaning                                                                                                                              |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `id`, `name`      | Required.                                                                                                                            |
| `short_name`      | Or `null`.                                                                                                                           |
| `parent`          | The parent's id; `null` only for MAIN.                                                                                               |
| `children`        | The children's ids, in order. Must agree with their `parent`.                                                                        |
| `kind`            | `"standard"`, `"date"` or `"numeric"`.                                                                                               |
| `exclusive`       | Its children are mutually exclusive (R7).                                                                                            |
| `match_name`      | Its name and short name match item text (R10).                                                                                       |
| `also_match`      | Text conditions (R15d), as typed.                                                                                                    |
| `also_assign`     | Category ids an item joining it also joins (R8).                                                                                     |
| `excludes`        | Category ids it may not share an item with (R9).                                                                                     |
| `conditions`      | Criteria (below) an item must meet to be assigned (R15).                                                                             |
| `actions`         | `{"category": id, "action": "remove"}`, `"clear"`, or `"set"` with `"value"` (a date phrase or a number) (R15b).                     |
| `special`         | `"done"`, `"discard"` or `null` (R15b).                                                                                              |
| `date_rule`       | For a date category (R6b): `assign` (`"never"`, `"entered"`, `"item_text"`, …), `which` (1–10), `done_key`, `when_key`; else `null`. |
| `match_overrides` | Text matching settings of its own (R16b): any of `enabled`, `match_on`, `strength`, `confirm`, `ignore_suffixes`, `ignore_accents`.  |
| `note`            | The category's note.                                                                                                                 |

A **criterion** (conditions, filters) is `{"category": id, "is": "assigned"}`,
`{"category": id, "is": "not_assigned"}`, or a range on a date or numeric
category: `{"category": id, "from": …, "to": …, "outside": false}`, where a
bound is a date phrase (`"today"`, `"2026-10-31"`), a number, or `null` for
open.

## Items

| Key                     | Meaning                                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| `id`                    | Required.                                                                                        |
| `text`, `note`          | The item text and its note.                                                                      |
| `entry`, `when`, `done` | Dates or `null` (R6).                                                                            |
| `when_time`             | The When time or `null` (R14b).                                                                  |
| `when_explicit`         | The When date was set by hand, not read from the text (R14).                                     |
| `recurrence`            | `{"every": 1, "unit": "week", "weekday": 5, "day": null}` or `null` (R14a).                      |
| `alarm_minutes`         | Minutes before the When time, or `null` (R38); `alarm_rung_at` the moment it rang, or `null`.    |
| `marked`                | Marked with F7.                                                                                  |
| `categories`            | The categories it is explicitly assigned to (membership in their ancestors is computed, R3).     |
| `conditional`           | Those of its assignments made by a condition or text match, which can be undone by one (R15c).   |
| `dates`                 | Dates in the user's date categories: `{"category": id, "date": …, "time": …, "explicit": true}`. |
| `numbers`               | `{"category": id, "value": 12.5}` in numeric categories (R29).                                   |
| `depends_on`            | The ids of the items it depends on (R43).                                                        |
| `suggested`             | Assignments waiting for confirmation (R16).                                                      |

## Views

| Key                                                           | Meaning                                                                                                                                                                                                      |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`, `name`                                                  | Required.                                                                                                                                                                                                    |
| `sections`                                                    | `{"category": id, "collapsed": false, "filter": [criteria], "sort": [sort keys] or null}`.                                                                                                                   |
| `columns`                                                     | `{"category": id, "width": 12, "number": {…}, "date": {…} or null}`; `number` as Numeric Column Properties (`symbol`, `decimals`, `thousands`, `negative`, `calcs`), `date` a date format of its own (R41a). |
| `hide_done`, `hide_empty`, `hide_inherited`, `hide_dependent` | View options (R27, R43).                                                                                                                                                                                     |
| `filter`                                                      | Criteria for the whole view (R28).                                                                                                                                                                           |
| `sort`                                                        | Sort keys: `{"on": "text" or {"category": id} or {"note": id}, "order": "asc", "na": "bottom", "sequence": "hierarchy", "line": 1}` (R36).                                                                   |
| `match`                                                       | For the Show View: `{"search": {"text": …, "on": "item", "ignore_case": true}}`, `{"items": [ids]}`, or `null` (R37).                                                                                        |
| `section_sort`, `section_order`                               | How sections are ordered: `"none"`, `"category"`, `"alpha"`, `"numeric"`; `"asc"` or `"desc"`.                                                                                                               |

## Calendars

| Key                     | Meaning                                                                                                                                                                |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`, `name`            | Required.                                                                                                                                                              |
| `url`                   | Where the calendar is read from (`https://…`).                                                                                                                         |
| `category`              | The category its events' items are assigned to.                                                                                                                        |
| `ahead_days`            | How far ahead events are imported: 30, 90, 180 or 365.                                                                                                                 |
| `refresh_minutes`       | How often it is read again while Agenda runs (60, 360, 1440), or `null` for only on request.                                                                           |
| `refreshed_at`, `error` | When it was last read, and why that failed; or `null`.                                                                                                                 |
| `events`                | For each event read: `uid`, its `item`, and the `summary`, `description`, `date`, `time` and `recurrence` it had, so a refresh only changes what the calendar changed. |

## What is checked on import

Beyond the types: MAIN and the special categories exist (and the special ones
are date categories); there is a view; ids are unique and below `next_id`;
parents and children agree; every category, item and view an object refers to
exists. A file that fails opens nothing; the open file stays.
