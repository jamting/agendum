# The JSON file format

File ▸ Transfer ▸ Export writes a whole Agendum file as JSON, and File ▸ Transfer ▸ Import reads one back (SPEC R44, ADR 0010). The JSON holds everything in the file, so an export imported again gives the same file. It is meant for people: exchanging data with others and other tools, and looking at a file (backups you can read, diffs, scripts). The working format stays the Erlang-term `.agendum` file (ADR 0003, ADR 0034). It is Agendum's counterpart of Agenda's structured files (STF), whose export also chooses what goes in; Agendum's will ask which item levels to include once there are levels (`docs/plans/ITEM_LEVELS.md`).

The code is `Agendum.Core.JSONFile`; `test/agendum/core/json_file_test.exs` and `json_round_trip_test.exs` check that a round trip changes nothing.

## Conventions

- The file is UTF-8, pretty-printed with two spaces; every object lists its keys in the order given here, so exports of the same file are identical.
- Ids are the file's integer ids (one counter for categories, items and views); references are by id.
- Enumerations are lowercase strings (`"standard"`, `"item_text"`).
- Dates are ISO 8601 (`"2026-10-31"`), times `"15:30:00"`, moments `"2026-10-09T14:45:00"`. `null` means none.
- Numbers are JSON numbers (`1234.5`).
- Reading: a key left out takes its default (as for a new category, item or view), so hand-written files can be short. Unknown values, wrong types and references to ids that do not exist are refused with a message naming the place (`categories[3].kind: unknown value "cheese"`). Unknown keys are ignored.
- Settings that belong to the person (theme, date languages, input format) are never in a file (ADR 0008).

## The document

```json
{
  "format": "agendum-json",
  "version": 1,
  "next_id": 21,
  "next_zettel": 3,
  "main": 1,
  "special": {"entry": 2, "when": 3, "done": 4},
  "settings": { … },
  "categories": [ … ],
  "items": [ … ],
  "views": [ … ],
  "trash": {"day": "2026-10-26", "items": [ … ]},
  "calendars": [ … ]
}
```

| Key          | Meaning                                                                  |
| ------------ | ------------------------------------------------------------------------ |
| `format`     | Always `"agendum-json"`; `"agenda-json"` (before the rename) is read too. |
| `version`    | The schema version, 1. Later versions of the program will still read it. |
| `next_id`    | The next id to hand out; above every id in the file.                     |
| `next_zettel` | The number of the next Zettel id to give (R73); above every item's. Left out: one above the highest. |
| `main`       | The id of MAIN, the root category.                                       |
| `special`    | The ids of the Entry, When and Done date categories.                     |
| `settings`   | The file's settings (below).                                             |
| `categories` | Every category, in hierarchy order (MAIN first, then depth-first).       |
| `items`      | Every item, in file order.                                               |
| `views`      | Every view, in the view manager's order.                                 |
| `trash`      | The trash (R24a): `day`, the date the oldest item in it was discarded (`null` when empty), and `items`, the discarded items, oldest first, written as items are but without categories, dates or alarms. Left out, an empty trash. |
| `calendars`  | Calendar subscriptions (R45).                                            |
| `feeds`      | Feed subscriptions (R75), below.                                         |
| `macros`     | Macros, in the macro manager's order (R50).                              |
| `blog`       | The micro-blog's settings (R74), below.                                  |

## Settings

| Key                   | Meaning                                                                                                                                                                                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `date_format`         | How dates display (R41, R41a): `order` (`"yyyymmdd"`, `"mmddyy"`, … `"week"`, `"relative"`), `separator`, `clock` (12 or 24), `day_of_week`, `show` (`"date_time"`, `"date"`, `"time_date"`, `"time"`), `am_pm`, `time_separator` (`":"` or `"hm"`). |
| `date_settings`       | How dates are read (R14e): `week_start`, `week_end` (1 = Monday … 7), `quarter_start`, `year_start` (1–12), `month_alone` (`"first"`, `"last"` or a day), `morning`, `afternoon`, `evening` (times).                                                 |
| `match_settings`      | Text matching (R16a): `enabled`, `match_on` (`"item"`, `"note"`, `"both"`), `strength` (`"exact"`, `"partial"`, `"minimal"`), `enclosed_by` (`"quotes"`, `"brackets"`, …), `ignore_suffixes`, `ignore_accents`.                                      |
| `insert_columns`      | Where a new column goes: `"all"` sections (the default) or the current `"section"` (R55).                                                                                                                                                             |
| `description`         | File Properties ▸ File description, up to 40 characters (`""` by default, R82). |
| `backup_on_open`      | File Properties ▸ Make backup on open: `true` copies the file to `NAME.agendum.bak` each time it is opened (`false` by default, R82). |
| `empty_trash`         | File Properties ▸ Empty trash: `"on_demand"`, `"file_closed"`, `"end_of_day"` (the default) or `"discarded"` (R24a). |
| (password)            | Never exported: a file's password (ADR 0046) is not in its JSON, which is plain text; an imported JSON file has none. |
| `tab_size`            | How far apart a note's tab stops are, 1 to 16 (5 by default; File Properties ▸ Tab size, R64e).                                                                                                                                                       |
| `confirm_assignments` | `"never"`, `"always"` or `"sometimes"` (R16).                                                                                                                                                                                                        |

## Categories

| Key               | Meaning                                                                                                                              |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `id`, `name`      | Required.                                                                                                                            |
| `short_name`      | Or `null`.                                                                                                                           |
| `parent`          | The parent's id; `null` only for MAIN.                                                                                               |
| `children`        | The children's ids, in order. Must agree with their `parent`.                                                                        |
| `kind`            | `"standard"`, `"date"`, `"numeric"` or `"unindexed"` (R29b).                                                                         |
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

A **criterion** (conditions, filters) is `{"category": id, "is": "assigned"}`, `{"category": id, "is": "not_assigned"}`, or a range on a date or numeric category: `{"category": id, "from": …, "to": …, "outside": false}`, where a bound is a date phrase (`"today"`, `"2026-10-31"`), a number, or `null` for open.

## Items

| Key                     | Meaning                                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| `id`                    | Required.                                                                                        |
| `text`, `note`          | The item text and its note.                                                                      |
| `entry`, `when`, `done` | Dates or `null` (R6).                                                                            |
| `when_time`             | The When time or `null` (R14b).                                                                  |
| `when_explicit`         | The When date was set by hand, not read from the text (R14).                                     |
| `recurrence`            | `{"every": 1, "unit": "week", "weekday": 5, "day": null}` or `null` (R14a).                      |
| `alarm_minutes`         | Minutes before the When time, or `null` (R38); `alarm_category` the id of the date category whose date it rings before, `null` for When; `alarm_rung_at` the moment it was due when it rang (R70), or `null`. |
| `zettel`                | The item's Zettel id as its word (`"bonalaku"`, R73), or `null`. The word is the Quadsyl-24 spelling of a number (`docs/QUADSYL.md`), so other tools can decode it; no two items may share one. |
| `marked`                | Marked with F7.                                                                                  |
| `categories`            | The categories it is explicitly assigned to (membership in their ancestors is computed, R3).     |
| `conditional`           | Those of its assignments made by a condition or text match, which can be undone by one (R15c).   |
| `dates`                 | Dates in the user's date categories: `{"category": id, "date": …, "time": …, "explicit": true}`. |
| `numbers`               | `{"category": id, "value": 12.5}` in numeric categories (R29).                                   |
| `texts`                 | `{"category": id, "value": "12 Grant Ave"}` in unindexed categories (R29b).                      |
| `depends_on`            | The ids of the items it depends on (R43).                                                        |
| `suggested`             | Assignments waiting for confirmation (R16).                                                      |

## Views

| Key                                                           | Meaning                                                                                                                                                                                                      |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`, `name`                                                  | Required.                                                                                                                                                                                                    |
| `sections`                                                    | `{"category": id, "collapsed": false, "filter": [criteria], "sort": [sort keys] or null, "columns": [columns], "item_column": {"set": "auto", "width": 40, "minimum": 10, "linked": true, "position": 0}}`; each section has its own columns (R55). `item_column` is its item text: `set` `"auto"` (as wide as the columns leave, at least `minimum`) or `"manual"` (`width` wide); `linked` item columns change together; `position` is how many of the section's columns are left of it. Missing: these defaults. |
| `columns`                                                     | A datebook view's columns, shared by its slots (R55); `[]` in a standard view. A column is `{"category": id, "width": 12, "link": 1 or null, "number": {…}, "date": {…} or null, "format": "name", "note_line": 1, "title": null}`; `format` is a standard column's Format (`name`, `parent`, `ancestor`, `star`, `yes_no`, `note`; R56), `note_line` and `title` its Category note line and title; columns of a view with the same `link` are one column shown in several sections (numbered within the view), `null` a column in its section only. Files with `"linked": true/false` instead (before links) get one link for the first linked column of a head in each section, another for the second, and so on; `number` as Numeric Column Properties (`symbol`, `decimals`, `thousands`, `negative`, `calcs`, `percent` for Display % of total), `date` a date format of its own (R41a). A standard view's `columns` from before R55 are read into every section, linked. |
| `hide_done`, `hide_empty`, `hide_inherited`, `hide_dependent`, `hide_column_heads`, `section_separators`, `number_items` | View options (R27, R43, R57, R58, R79).                                                                                                                                                                                     |
| `filter`                                                      | Criteria for the whole view (R28).                                                                                                                                                                           |
| `sort`                                                        | Sort keys: `{"on": "text" or {"category": id} or {"note": id}, "order": "asc", "na": "bottom", "sequence": "hierarchy", "line": 1}` (R36).                                                                   |
| `match`                                                       | For the Show View: `{"search": {"text": …, "on": "item", "ignore_case": true}}`, `{"items": [ids]}`, `{"alarms": true}` (the alarm list, R38), `{"done": true}` (Show ItemsDone), or `null` (R37).                                                                                        |
| `section_sort`, `section_order`                               | How sections are ordered: `"none"`, `"category"`, `"alpha"`, `"numeric"`; `"asc"` or `"desc"`.                                                                                                               |
| `datebook`                                                    | For a datebook view (R47): `{"date_category": id, "end_category": id or null, "section_category": id, "period": "week", "interval": null, "start_time": null, "end_time": null, "start_day": null, "end_day": null, "base": "today"}`; `null` for a standard view, whose `sections` it then ignores. |

## Calendars

| Key                     | Meaning                                                                                                                                                                |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`, `name`            | Required.                                                                                                                                                              |
| `url`                   | Where the calendar is read from (`https://…`).                                                                                                                         |
| `category`              | The category its events' items are assigned to.                                                                                                                        |
| `ahead_days`            | How far ahead events are imported: 30, 90, 180 or 365.                                                                                                                 |
| `refresh_minutes`       | How often it is read again while Agendum runs (60, 360, 1440), or `null` for only on request.                                                                          |
| `refreshed_at`, `error` | When it was last read, and why that failed; or `null`.                                                                                                                 |
| `events`                | For each event read: `uid`, its `item`, and the `summary`, `description`, `date`, `time`, `recurrence`, `end_date` and `end_time` it had, so a refresh only changes what the calendar changed. |

## Feeds

| Key | Meaning |
| --- | ------- |
| `id`, `name` | Required. |
| `url` | Where the feed is read from (`https://…`). |
| `category` | The category its entries' items go in (under Feeds). |
| `keep_days` | How long an entry stays, from its publish date, unless kept: a number of days, or `null` for ever. |
| `refresh_minutes` | How often it is read while Agendum runs (60, 360, 1440), or `null` for only on request. |
| `refreshed_at`, `error` | When it was last read, and why that failed; or `null`. |
| `entries` | For each entry read: its `id` (guid, else link), its `item`, and the `title`, `note`, `link` and `published` date it had, so a refresh only changes what the feed changed. Once it faded or was discarded: only `id`, `item: null` and `published` (a `title`, `note` or `link` there is ignored). |

## Macros

| Key        | Meaning                                                                                                   |
| ---------- | --------------------------------------------------------------------------------------------------------- |
| `id`, `name` | Required; names are unique, case aside.                                                                  |
| `keys`     | The keystrokes in Agenda's notation: text as typed, other keys by name in braces (`{F10}vc{ENTER}`).     |
| `key`      | The key it is attached to, in the same notation (`{ShfF4}`), or `null`.                                  |
| `run_from` | `{"view": true, "note": true, "catmgr": true, "elsewhere": false}`: where it can be run.                 |

## Blog

The micro-blog's settings (R74); left out, none: no posts category.

| Key | Meaning |
| --- | ------- |
| `posts`, `drafts` | The posts category and the drafts category (ids), or `null`. |
| `title`, `description`, `author`, `language` | What the pages and feeds say about the blog; `language` such as `"en"` or `"sv"`. |
| `base_url` | Where the site is on the web (`"https://example.com/blog/"`), for the feeds' links. |
| `me` | Addresses of the person's other profiles, for `rel="me"` links, separated by spaces. |
| `folder` | Where the site is written; a relative folder is beside the file. |
| `upload` | `"none"`, `"rsync"` or `"sftp"` (ADR 0041). |
| `target` | For rsync where to (`"me@host:www/blog"`); for SFTP the server (`"host"` or `"host:port"`). |
| `user`, `remote_dir` | For SFTP: the user name, and the folder on the server. |

No password is ever in the file.

## What is checked on import

Beyond the types: MAIN and the special categories exist (and the special ones are date categories); there is a view; ids are unique and below `next_id`; Zettel ids are unique and below `next_zettel`; the blog's categories exist; each feed's category exists; parents and children agree; every category, item and view an object refers to exists. A file that fails opens nothing; the open file stays.
