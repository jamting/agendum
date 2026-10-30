# Minutes of the panel meeting, 2026-10-26-1524

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad, David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `3c5b530`

*Owl had lit the lamp although it was early afternoon. All nine fitted only because Mitch gave up his chair for the stairs, his papers on his knees; Little Marie-Who-Folds noted with quiet pleasure the empty place where the umbrella stand used to be. Pooh put his head round the door to ask whether "the feeds" were anything to eat, and was told they were not. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting, the fourth of the day and the first with a whole review on the table.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude keeps the minutes; Old Mitch Lilypad and Little Marie-Who-Folds approve them.

## § 3 Adoption of the agenda

No thoughts were waiting under Next meeting. The agenda was the roadmap's first item, the review of 2026-10-26 (`docs/reviews/2026-10-26.md`, § 18), with the owner's two additions: the review's points of disagreement (§ 17) and "SPEC is becoming a diary" (§ 15). Where an addition overlapped a resolution, the two were merged into one item. The agenda was adopted as proposed.

## § 4 The previous minutes

| Decision (2026-10-26-3) | Status | Evidence |
| --- | --- | --- |
| § 5 Update defaults as Agenda's, kept in the preferences, only what differs; F8 Default checked first | Done | `3c5b530` (v0.63.0, R82a); F8 gives the person's defaults (checked in Agenda 2.0) |
| § 6 Update defaults the only way; only for empty files the person makes; the help says where | Done | `3c5b530`; help topic Set Defaults for New Files, Display Format's F1 |

## § 5 The faded feed entries keep only their ids

**Background.** In the owner's file, 13,184 of 14,423 feed entry snapshots have faded or been discarded, yet each keeps its title, note and link (`lib/agendum/core/extras/feed.ex:22-28`): 12.7 MB of the file's 17.0 MB, and the reason a save takes about 480 ms. Compression at zlib's default level takes 460 ms of it (`lib/agendum/store.ex:109`); level 1 measured 134 ms. The panel had disagreed on whether the simple fix is enough or ingested items belong elsewhere (review § 17.2).

**Discussion.** **Marie** called it the largest thing she has found in any review, and advised keeping the id (and the publish date, if `keep_days` needs it) and letting the rest go. **Joe** wanted the simplest fix first, measured before and after on a copy of the file, and compression only afterwards if the save is still slow, so that it is clear which change helped. **Carsten** saw a larger question behind it: ingested items (`docs/plans/ITEM_LEVELS.md`) may not belong in the person's file at all; he agreed the simple fix comes first. **Claude** noted it is a format change (version, golden file, `docs/JSON_FORMAT.md`) and that the JSON export becomes readable again. No habit changes: a faded entry is already out of view. The chair took the panel's advice and added that the extras might need data structures that are not a natural fit for Agendum's data format, and asked for the general case to be planned at a separate meeting.

**Decided:** faded or discarded entries keep only their id and publish date, as a format change measured before and after on a copy of the owner's file; compression level 1 only if the save is still slow. A separate meeting plans the general case: data structures the extras need that are not a natural fit for Agendum's format, with Carsten's separate store as one input.

## § 6 The clone's safety before going public

**Background.** Three items are open (ROADMAP, Fixes and polish; The clone's safety): a recovery file on a crash, hostile-text tests for `.AG` files and feeds, and Erlang's logger, which can print over the screen (seen once by the owner, on a closed laptop, offline).

**Discussion.** **Joe** said an old user's first crash or garbled screen costs more than any missing command; the logger is small, the recovery file the largest and the one that saves work. **Claude** said the hostile-text tests matter more once the repository is public and agents read files, and are cheap now. **Russell** said losing an evening's work is the kind of setback that makes someone give up on a tool.

**Decided:** all three before the public repository, in this order: the logger, the recovery file, the hostile-text tests.

## § 7 No private addresses in the debug log

**Background.** The debug log writes feed and calendar fetches with their full addresses, private calendar tokens included (`lib/agendum/tui/debug_log.ex:182`, through `inspect`), and keeps five sessions (`@keep 5`, line 31); in the review all five were from one day.

**Discussion.** **Claude** asked for fetches logged by name or host, never the query string, before anyone else is asked to send a log. **Carsten** said ten sessions or a week would answer "since when?" at little cost.

**Decided:** fetches are logged by feed or calendar name or by host, without the query string, and the last ten sessions are kept.

## § 8 Keep the long fuzz run's output

**Background.** A long fuzz failure on 2026-10-26 could not be repeated: its seed was lost with the output, cut to its last line. CI runs a nightly fuzz (`.github/workflows/fuzz.yml`).

**Discussion.** **Joe** observed that the one failure that got away came from the one step done by hand, and asked for it to be automatic. **José** asked that the seed stand at the top, so one line repeats the run. The chair asked how large the logs would be. Claude answered from the run earlier in the session: 153 bytes for a passing run (the seed, the dots, the result), a few kilobytes for a failing one; the last 30 kept would stay far under a megabyte, and GitHub deletes artifacts after 90 days.

**Decided:** each local run writes a dated log file with the seed at the top, and the last 30 are kept; the nightly CI run uploads its output as an artifact when it fails.

## § 9 A tidy pass and a dry run before going public

**Background.** Stale texts remain (VISION's freeze paragraph; AGENDA_PARITY's "three differences remain" where one is listed). Going public rewrites the history with `git filter-repo` (`docs/plans/GITHUB.md` § 7), which cannot be undone once pushed.

**Discussion.** **Marie** said a `tidy-docs` pass finds these and their cousins, so a first visitor meets a project in order. **José** asked for the filtered copy to be built and checked by `mix check` before anything is pushed: an hour that protects the history.

**Decided:** both, just before the public repository: a `tidy-docs` pass, then the dry run on a copy, checked by `mix check`.

## § 10 The pace

**Background.** Ninety commits on 2026-10-25 and fourteen versions on 2026-10-26. The feature skill's last step is that the owner tries a habit change before the next is built on it.

**Discussion.** **Russell** advised a few slower days on the owner's own file, so that the next work comes from use, and a finish line is felt. **David** asked that each session summary say, for each version, whether the owner tried it. **José** disagreed in part: the gate held at full speed, and momentum has value. At the chair's request Claude explained the reasoning in plain words: feedback comes from use, changes stack on unchecked ground, understanding falls behind at that pace, while the fixes of §§ 5–8 change no habits. The chair answered that the work had been parity, checked against Agenda in DOSBox, and that they had good faith in that testing.

**Decided:** the pace stays; the session summaries get a line per version saying whether the owner tried it.

*Russell accepted that "like Agenda, checked in Agenda" is another kind of change than a new habit. David wrote "tried it?" on his pad and underlined it twice.*

## § 11 `Update`'s shell answers

**Background.** `lib/agendum/tui/update.ex` is 987 lines; about lines 479–934 are the shell's answers (a file loaded, saved, imported, fetched). The review offered a choice: move them to `Update.Results`, with no change in behaviour, or decide it is not worth it.

**Discussion.** **José** said `Update` is the module everyone reads first, and half of it being the outside world's answers hides the key handling; the move is mechanical and the tests cover it. **Marie** said a thing raised in three reviews and never done is clutter in itself. **Claude** said the shell's answers are what a second front end would share, so a module of their own shows that boundary. The panel advised it, not urgently. The chair chose to do it now, before the public repository, and added two more steps before the public repository: a general code review, and a meeting on what information to make public in the docs.

**Decided:** the shell's answers move to `Agendum.TUI.Update.Results` before the public repository, with no change in behaviour. Also before the public repository: a general code review, and a meeting on what information to make public in the docs.

## § 12 The sort box's three Credo suppressions

**Background.** The Sort box builds its eight setting names (`order` … `then_line`) with `String.to_atom/1` and silences Credo's warning three times, twice without the reason CLAUDE.md asks for (`lib/agendum/tui/boxes/sort_box.ex:266,360,384`).

**Discussion.** **José** advised writing the names out once, which removes the suppressions and the risk together. At the chair's request Claude explained: atoms are never freed and the VM allows about a million, so Credo flags any atom made from text; here the text is always the same eight names, so there is no danger today, but silenced warnings without reasons are the first thing a reviewer asks about, and the warning would no longer catch a later change. About fifteen minutes of work.

**Decided:** the eight names are written out and the three suppressions go, before the code review.

## § 13 SPEC is becoming a diary

**Background.** SPEC grew from 135 KB to 185 KB in five days; R80 is one line of 6,169 characters, and many rules tell when and how they were checked in Agenda or chosen by the owner. The panel had disagreed on where that provenance belongs (review § 17.1).

**Discussion.** **Marie** would keep SPEC to the rule and move the provenance to the done list, slimming each rule when next touched. **Carsten** and **Mitch** would keep the provenance on the rule: "as Agenda's (checked)" tells a reader it is not a guess. **Claude** noted that a model pays for every word but also uses the provenance to decide whether a behaviour may change. The panel's middle way: each rule keeps a short "(checked in Agenda)" or "Our choice", and the longer story moves to `docs/ROADMAP_DONE.md`. The chair chose to do it in one sweep, before the public repository.

**Decided:** the middle way, as one sweep of SPEC in the tidy pass before the public repository; from then on the same rule whenever a rule is touched.

*Marie stacked Owl's copy of SPEC into two piles, "rules" and "stories", and left them on the table. Owl looked at them for a long time.*

## § 14 What comes after the public repository

**Background.** The panel disagreed (review § 17.3): **Mitch** would look for users; **Claude** would start a read-only headless command and golden tasks (resolution 9); **David** would build the GTD starter; **Russell** the gentler starter for the easily overwhelmed. Each serves a different group in `docs/VISION.md`.

**Discussion.** The panel gave no single advice and noted that today's decisions put much before the public repository. The chair added that the project is entering a period of brainstorming and making general plans on ideas, with coding too, and that what is needed is clarity in the ideas and whether an overarching strategy is needed.

**Tabled:** to a meeting for brainstorming and general plans after the public repository, where the four directions are weighed with the question of an overarching strategy.

## § 15 The order of the work decided here

**Background.** Claude proposed an order: what the owner feels or what protects their data first, the steps of going public last, and the two new meetings after the public repository.

**Discussion.** The panel advised that the meeting on the extras' data need not block going public, since § 5's trim fixes today's problem. The chair chose to hold it right after the trim.

**Decided:** 1 the faded feed entries trimmed; 2 the meeting on the extras' data; 3 the logger; 4 the recovery file; 5 the debug log; 6 the fuzz output; 7 the hostile-text tests; 8 the sort box; 9 `Update.Results`; 10 a general code review; 11 the meeting on what to make public in the docs; 12 the tidy pass with the SPEC sweep; 13 the dry run; 14 the public repository; 15 the meeting for brainstorming and general plans.

## § 16 Any other business

None.

## § 17 Next meeting

The meeting on the extras' data, after the faded feed entries are trimmed (ROADMAP, In order 2).

## § 18 Closing of the meeting

Owl closed the meeting and, while the panel unfolded itself from the stairs, asked Little Marie-Who-Folds whether the two piles of SPEC might be thanked and let go. She said only one of them, and not yet.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | Faded feed entries keep id and publish date; measure; compression only if still slow; a meeting on the extras' data | `docs/ROADMAP.md` (In order; Fixes and polish; Beyond Agenda), `docs/plans/ITEM_LEVELS.md` (open questions) |
| 6 | Logger, recovery file, hostile-text tests, in that order, before the public repository | `docs/ROADMAP.md` (In order; Fixes and polish; The clone's safety) |
| 7 | Fetches logged by name or host; ten sessions | `docs/ROADMAP.md` (In order; Fixes and polish) |
| 8 | Dated local fuzz logs, the last 30 kept; a CI artifact on failure | `docs/ROADMAP.md` (In order; Sharpen the saw) |
| 9 | `tidy-docs` and a dry run before the public repository | `docs/ROADMAP.md` (In order; Housekeeping), `docs/plans/GITHUB.md` § 7 |
| 10 | The pace stays; summaries note per version whether the owner tried it | `.claude/skills/end-session/SKILL.md`, memory |
| 11 | `Update.Results` before the public repository; a general code review and a meeting on what to make public in the docs | `docs/ROADMAP.md` (In order; Sharpen the saw; Housekeeping), `docs/plans/GITHUB.md` § 7 |
| 12 | The sort box's names written out, before the code review | `docs/ROADMAP.md` (In order; Sharpen the saw) |
| 13 | SPEC keeps the rule with a short marker, the story in the done list; one sweep before the public repository | `CLAUDE.md` (Conventions), `docs/ROADMAP.md` (Housekeeping) |
| 14 | Tabled to a meeting for brainstorming and general plans | `docs/ROADMAP.md` (In order; Users and direction) |
| 15 | The order of the work | `docs/ROADMAP.md` (In order) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
