# Plan: recurring items in datebooks and date filters (2026-10-15)

**Status:** done: steps 1–4 built (2026-10-23, v0.22.0), step 5 (editing shows the rule) built as its own step (2026-10-23, v0.23.0).

A recurring item ("Status meeting every Monday") should show on **every** date it recurs on, not only on its base date: in each datebook section those dates fall in, and in any view whose date filter covers one of them. It stays one item. Today Agendum stores the rule (`Item.recurrence`, R14a) but uses it only when the item is marked done; datebooks and filters see only the base date. SPEC R14a lists this as not done.

## What Agenda does (the evidence)

Checked in the real Agenda 2.0 (headless, on a copy, 2026-10-15), and in its manuals and file format:

| Question            | Agenda's answer                                                                                                                                                                                   | Source                                                                                             |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| What is stored?     | One date per item: the base date (first occurrence) and the rule (unit, weekday, interval, time); kind 2 = recurring                                                                              | `docs/AGENDA_FILE_FORMAT.md`, Date expressions                                                     |
| Where does it show? | In every datebook section, at any distance, that contains an occurrence counted from the base date, and never before the base date                                                                | tried: "every day" from Fri 10/16 shows Fri, Sat and every later day, not Tue–Thu before it        |
| Intervals           | Kept from the base date: "every other day" from 10/17 shows on 10/27, 10/29, 10/31, 11/4…; "every 2nd Tuesday" from 10/20 on 11/3, not 10/27                                                      | tried                                                                                              |
| Ordinary views      | A date filter matches too: a view filtered on When 10/26–10/30 lists every Monday, every day, every other day and every 2 weeks, but not every other Monday (next 11/2) or each month (next 11/1) | tried                                                                                              |
| Timed items         | Shown in the hour or half-hour slot of a day view                                                                                                                                                 | Lotus Q&A "Recurring Item at 5:30 AM Disappears From Datebook View" (a 2.0 bug, fixed in Update B) |
| How many items?     | One; discarding it in one section discards it everywhere                                                                                                                                          | User's Guide 7-11                                                                                  |
| Done                | Marks this item done and adds a copy with the next base date                                                                                                                                      | User's Guide 7-12; Agendum does this already (R14a)                                                |
| Which categories?   | Date categories with "Category can use recurring dates" (When by default); with No, "every Tuesday" is read as "Tuesday"                                                                          | User's Guide 7-8                                                                                   |
| Editing the date    | ALT-F2 shows `every day (strtng 10/16/2026)`: the rule and its base date in one phrase                                                                                                            | tried                                                                                              |
| Item Properties     | Only the base date: `When(10/16/26)`                                                                                                                                                              | tried                                                                                              |

Agenda never stores the occurrences: a datebook section is a date-range filter (`docs/AGENDA_FILE_FORMAT.md`, Datebook view), worked out again each time it is drawn, and the range test asks the item's rule whether an occurrence falls inside. That is the design to copy.

## Habit changes to settle with the owner first (CLAUDE.md, step 0)

What someone already using Agendum will notice:

1. **More rows.** A weekly datebook shows "every day" five or seven times, and an ordinary view filtered on "this week" or "next week" lists recurring items it did not list before. (Agenda does both.)
2. **F4 on a future occurrence.** The row is the item itself, so F4 marks the item done and creates the next one, as on its base date. Not yet checked in Agenda: whether it refuses, or marks it done with the occurrence's date. Check before step 3 (see "How to check" below).
3. **The When column on an occurrence row.** It could show the base date (what is stored; Item Properties shows it too) or the occurrence's date. Not yet checked in Agenda; a datebook shows only the time, but an ordinary view filtered on next week has a When column if the view has one. Proposal: the occurrence's date in datebooks and filtered views, since the row is there because of it; check Agenda before deciding.
4. **Editing the When date** (ALT-F2, the When column): show the rule with its base date, `every day (starting 2026-10-16)`, as Agenda does, so editing does not lose the rule. Today Agendum shows the date alone.
5. **Discard, move, edit** on an occurrence act on the one item (it disappears from every date at once).

Decide 2 and 3 (and whether 4 belongs in this change) before code.

## Steps

Each step is one commit, test first, `mix check` green.

### 1. Occurrences in the core

`Agendum.Core.Recurrence` gains the pure question both uses need:

    occurrences(rule, base, from, to) :: [Date.t()]   # dates in [from, to], none before base
    occurs?(rule, base, from, to) :: boolean

- Counted from the base date with `next/2`, so months keep their day (the 30th stays the 30th, as R14a already does). For long distances, jump close to `from` first (days and weeks by arithmetic, months and years by counting months) instead of stepping one by one.
- Tests in `test/agendum/core/recurring_dates_test.exs`: the table above as cases (every day from a Friday, every other day, every 2nd Tuesday, the 30th of every month across February, every quarter, every year on 29 February), nothing before the base date, an empty range.

### 2. Date filters match an occurrence

`Agendum.Core.RangeFilter` (used by `Agendum.Core.Assign.criteria_met?/4`): for the When category, an item with a rule meets a date range when an occurrence falls inside it, not only the base date.

- Only for date categories that can recur. Agendum has no "Can use recurring dates" setting yet (R14a: only When recurs), so: When only, and say so in SPEC.
- "Not assigned" and "outside the range" stay as now: outside means no occurrence inside.
- Core tests with `Agendum.Fixtures` (`test/agendum/core/range_filters_test.exs`): a view filtered on next week lists "every Monday", not "every other Monday" in its off week.

### 3. Datebooks place each occurrence

`Agendum.Core.ViewModel.build/3` (datebook clause) and `Agendum.Core.Datebook`:

- For each slot, a recurring item is shown when `occurs?/4` finds an occurrence in the slot's dates; its row carries the occurrence's date (and the rule's time) instead of the base date, so ordering within the slot and time slots work as for any item (`Agendum.Core.Datebook.in_slot?/3` is given the occurrence).
- The same item can appear in several slots: rows already carry the item, and the TUI's cursor must not assume an item appears once (check `Agendum.TUI.Moves.Browse` and moving between sections).
- An end category with a recurring start: an occurrence lasts as long as the base date's span (Agenda: unknown; keep it simple, and say so).
- Tests: `test/agendum/core/datebook_test.exs` (a week with "every day" from Wednesday has rows Wednesday to Friday only; a day view with "every Monday at 9am" in the 9:00 slot), and a TUI test in `test/agendum/tui/datebook_view_test.exs` that browsing (ALT-B) to next week shows the occurrences.

### 4. The When column and F4 on an occurrence

As decided in "Habit changes" 2 and 3. Likely: the cell shows the occurrence's date; F4 marks the item done as today (R14a) and the new copy takes the next date after the base date. TUI tests drive F4 on an occurrence row.

### 5. Editing shows the rule (built 2026-10-23, v0.23.0)

ALT-F2 and the When column offer `every Monday (starting 2026-10-19)` (language pack wording; Swedish "varje måndag (från 2026-10-19)"), and reading it back keeps rule and base date. Parser work in the date language packs, not in `Agendum.Core.DateParser`.

### 6. Records

- SPEC R14a: remove "recurring items in datebook views" from "Not done"; describe filters and datebooks.
- ROADMAP: tick the item. F1 help and `docs/KEYBOARD.md` only if F4's behaviour changed. Long fuzz run after step 3 (`FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs`): several rows for one item is new for the cursor code. Smoke-test a weekly datebook in the real terminal.

## How to check the open questions in Agenda

With `tools/agformat/DRIVING_AGENDA.md`: open a copy of a file with "T42 every day" (any file with a recurring When), a datebook view with period Week and "Base date on" a later week. The highlighted row has attribute `0x4F` on the item text (other rows `0x70`); press ↓ until the wanted occurrence row has it, then:

- F4: read line 0 and the rows after; save and run `agdiff.py` to see whether the item got a Done date, which one, and whether a new item appeared with which base date.
- A standard view with a When column, filtered on that week: read the When cell of the recurring rows (base date or occurrence?).

## Progress

- 2026-10-15: research done (this document). Nothing built yet; habit changes 2–4 to settle with the owner.
- 2026-10-23: habit changes 2 and 3 checked in Agenda 2.0 (headless, RICH.AG): F4 on a later occurrence (Gym, base 10/19, on Mon 10/26) marks the item done today, keeps its base date, drops its rule, and a copy gets 10/26 with the rule, as F4 on the base date; a view filtered on 11/01–11/07 shows the occurrence, 11/02/26, in its When column, and on 11/01–11/14 still one row with 11/02; unfiltered the base date; a datebook's When column shows only the time. The owner chose step 5 as its own next step. Steps 1–4 built (b3ba6b3, d8e65cb, aeb1621, 60d4c94). Our choice: a done item keeps its rule stored but counts only on its own date (`Item.recurring/1`).
- 2026-10-23, step 5: checked in Agenda 2.0 first. ALT-F2 and F2 in the When column offer `every Mon (strtng 10/19/2026)` (with a time `… at 9:00am`); ENTER keeps the rule; `every Wed (strtng 11/04/2026)` is read back as rule and base; `every Tue` alone starts on the next Tuesday; `every Fri starting 11/6/26`, the word written out, is read as a plain date (the rule lost); Agenda wrote `every 2nd week` and `30th  of every month`, and put "every 2 weeks (strtng 11/02/2026)" on Sunday 11/01 and "the 30th of every month" typed on 10/23 on 11/30 (ours: 11/02 and 10/30). Built: each language pack words the rule (`recurrence_phrase/1`, `starting/0`, `time_phrase/1`), `DateParser.format_recurring/4` offers it only when its pack reads it back the same, `parse_recurring/3` reads the bracket (ours and Agenda's "strtng"), `Core.when_text/3` gives ALT-F2 and the When column the text.
