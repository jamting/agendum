# Minutes of the panel meeting, 2026-10-16-1905 (third)

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host. David the Squirrel sent apologies.
**Secretary:** Claude · **Approvers:** José Who Brews, Carsten Stargazer
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `b5bc95e`

*Late in the evening, the third meeting of the day. The room in the beech tree was warm from the two before it, and the teacups Little Marie-Who-Folds had thanked at the last meeting were still on the windowsill, as agreed. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and welcomed the chair and the panel. *He pulled the bell-pull to mark the occasion, and the bell came off in his wing. Marie caught it, thanked it, and set it on the windowsill beside the teacups.*

## § 2 Election of a chair, a secretary and two approvers

The owner was chair, Claude secretary; José Who Brews and Carsten Stargazer were chosen to approve the minutes.

## § 3 Adoption of the agenda

The owner's note on Zettel ids was worded as three items (§ 5–7). The agenda was adopted as proposed.

## § 4 The previous minutes

| Decision | Status | Evidence |
| --- | --- | --- |
| § 5 The owner's own uses and candidate users in `VISION.md` | Done | `c5361d4`, `docs/VISION.md:15` |
| § 6 "Beyond Agenda" sorted by group | Done | `c5361d4`, `docs/ROADMAP.md` |
| § 7 An RSS reader in two steps | On the roadmap, not built | `docs/ROADMAP.md`, Beyond Agenda |
| § 8 The micro-blog, next after the disk guard | Not built; the owner chose to build the `.AG` import first that evening, released as v0.10.0 (`b5bc95e`) | `docs/ROADMAP.md`, Beyond Agenda |

Claude noted that the roadmap's **Next:** line still asked the owner to try the import; it was brought up to date after the meeting.

## § 5 Should Quadsyl-24 be Agendum's Zettel id, and should it be brought into the project?

**Background.** The owner has designed Quadsyl-24: a counter number (0 to 16,777,215) is scrambled and spelled as four consonant-vowel syllables (`bonalaku`), and the id decodes back to the number; the 267 ids that are real English or Swedish words are reserved for special notes. The documents and an Elixir module with tests are in `import-into-project/`. The roadmap's earlier design used the creation time, `YYMMDDHHMM` plus a digit (`26101311140`).

**Discussion.** **José** found the module already in the core's style: pure, with `@spec`s, doctests and the reserved list as compile-time sets. It would become `Agendum.Core.ZettelId`, with `{:ok, _} | {:error, atom}` as its interface, the `!` forms for tests, and the `:exhaustive` tag left out of `mix test`. **Joe** observed that the syllable table, the multipliers and the round count may never change (QUADSYL.md, "Never change the configuration"), which makes them part of the file format: pinned by a known-values test, checked by the full bijection test, and recorded in an ADR; the counter is a stored field and needs a format version and a golden file. **Carsten** said timestamp ids are the custom in Zettelkasten tools, but that nothing is lost here, since the Entry date keeps the creation time; as ids outlive programs, the JSON should store the word, and `JSON_FORMAT.md` describe the scheme. **Russell** said four syllables are four chunks, easy to hold in working memory, to say aloud and to copy by ear, unlike eleven digits; ordinary ids that sound funny (`fisasava`) are still given out, and words to skip could be added to the reserved list, though only above the counter. **Marie** gave each thing one home: the module in the core, its tests beside the others, `QUADSYL.md` in `docs/` with `PRIOR_ART.md` merged into its section on prior art, the appendix kept for readers but naming the code as its source, and the tables of funny ids kept, since they spark joy. **Mitch** said Agenda never showed an id, so this belongs on the list of enhancements. **Claude** noted that Quadsyl has no checksum, so a typo gives another well-formed id; with a few thousand zettels among 16 million ids it almost always names no zettel, and the link shows as broken.

*Russell said `bonalaku` aloud, and the room said it back. Owl wrote it down, in a spelling of his own.*

**Decided:** The panel's advice. Quadsyl-24 replaces the timestamp design. The module and its tests come into the core as `Agendum.Core.ZettelId`, and `QUADSYL.md` into `docs/` with the prior art merged in. ADR 0039 records the frozen configuration as part of the file format; the JSON stores the id as its word.

## § 6 How an item gets its Zettel id

**Background.** The owner proposes a command that attaches the next available Zettel id to an item; the special (reserved) ids are kept for later, mainly as reserved entry places through which Agendum instances can communicate. The ids would be kept as a category ZID, whose children are never shown in the category manager.

**Discussion.** Claude reported that a category fits Agenda's model, where a column's entries are the children of its head category, and that every category takes part in text matching unless `match_name` is off (`lib/agendum/core/category.ex:12`). Giving ids by a command, not to every item, partly answers the first open question of `docs/plans/ITEM_LEVELS.md`.

**Mitch** liked the category: everything is a category in Agenda, and a ZID column would sort and search with no new machinery. **José** and **Joe** disagreed: one child category per zettel means thousands of categories, each with text matching turned off (or a note that mentions `bonalaku` would file its item there, giving it two ids), and rules to enforce (one item per child, one child per item, no renaming, since a rename would quietly change an id and break its links); a stored field has none of this and is plain in the JSON, and the roadmap's column kind still gives Mitch his column. **Carsten** said an id is identity, not classification. **Joe** asked for a counter of its own (`next_zettel`, from 1), not `db.next_id`, which categories also draw from. **Claude** pointed out that two files counting from 1 give out the same ids, which collide when instances exchange zettels; a range per instance, or ids qualified by their instance, are possible answers, and a reserved word could be a well-known mailbox; it should be written down before the counter is built, so the field does not close a door. **Russell** asked that the command say which id it gave. **Marie** asked that the special ids wait in the plan, not in the roadmap line.

No habit of a present user changes: the command is new.

**Decided:** The panel's advice. The Zettel id is a stored field on the item, with its own counter, shown by a column kind; there is no ZID category. "Attach Zettel id" gives the next unreserved id to the highlighted item, or to the marked ones, keeps an id an item already has, is one undo step and says which id it gave. The special ids and talking between instances are **referred** to `docs/plans/ITEM_LEVELS.md` as an open question.

## § 7 Run a command by name: a key, and fuzzy matching

**Background.** A new function in the terminal program: run a command by its name, from a reasonable shortcut, with fuzzy matching of the available commands.

**Discussion.** Claude reported that most of it exists: F1 then `c` lists the place's commands, typing narrows them by an exact substring (`lib/agendum/tui/help_screen.ex:125`), and ENTER runs one. ADR 0038 keeps Agenda's keys in the terminal and puts the command palette in the web. Agenda's help names no CTRL-letter keys; CTRL-X, CTRL-R and CTRL-T are free in Agendum, while ALT-X runs Execute all.

**Mitch** said a run-by-name was never Agenda's, but a new key changes no habit and ADR 0038 was about not rebinding Agenda's keys; he asked for an ADR saying how much of the palette the terminal gets. **Carsten** pointed to Emacs's M-x, and asked for matching on initials and letters in order, with the recently used first. **José** asked for one pure matcher over the command data, which the web's palette can reuse. **Russell** called one key and "type what you want" help at the point of performance, and asked for a few good matches rather than a wall. **Claude** noted that every action reachable by name is one an agent can call. **Marie** first advised one list with two doors and no new box.

The habit changes were listed: F1 `c` narrows fuzzily (more matches, another order), and CTRL-X is new; nothing moves.

The chair asked whether the matches would be shown in the help window, and proposed a box of its own. **Russell** agreed: the help screen is for reading, and a small box with an input line and a few matches is less to take in at the moment of doing. **Mitch** said it would look like Agenda's small choice lists (the F3 choices box). **Marie** withdrew her "no new box": her point was one list of commands and one matcher, and two views of it with different jobs are tidy. **José** listed what is shared (the commands, the check whether one can run, the matcher) and what the box needs (its keymap, its F1 text, `SCREENS.md`, a PNG compared with Agenda's box). **Claude** asked for each match's key beside its name, so the person learns the key, and the summary on the bottom line; only commands that can run are shown. **Carsten** asked that an empty input list the recently used.

*Marie handed the chair the bell from the windowsill to ring the decision; Owl thought it had never sounded better.*

**Decided:** CTRL-X opens a small box of its own, shaped like Agenda's choice lists: an input line, the best matches with their keys, the highlighted command's summary at the bottom; only commands that can run in the place; with an empty input, the recently used. Fuzzy matching (initials and letters in order, best and recently used first) is one pure function over the command data, used by the box and by F1 `c`'s narrowing alike. ADR 0040 amends ADR 0038.

## § 8 Any other business

The chair had nothing more to raise.

## § 9 Next meeting

When the agenda has enough items.

## § 10 Closing of the meeting

The chair closed the meeting. *Owl tried to put the bell back on the bell-pull; it is now kept on the windowsill, with the teacups, and everyone agreed that it sparks joy there.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | Quadsyl-24 is the Zettel id; module and description brought into the project; the configuration frozen | `docs/ROADMAP.md` (Beyond Agenda, Zettelkasten IDs); `docs/adr/0039-quadsyl-24-zettel-ids.md`; `docs/ARCHITECTURE.md` (ADR list); `docs/plans/AGENDA_PARITY.md` (enhancements) |
| 6 | A stored field with its own counter, no ZID category; the command "Attach Zettel id" | `docs/ROADMAP.md` (Beyond Agenda); `docs/adr/0039-quadsyl-24-zettel-ids.md` |
| 6 | Special ids and instances talking to each other: referred | `docs/plans/ITEM_LEVELS.md` (open questions) |
| 7 | CTRL-X opens a small box to run a command by name, fuzzy matching shared with F1 `c` | `docs/ROADMAP.md` (Beyond Agenda); `docs/adr/0040-run-a-command-by-name.md`; ADR 0038 (amended); `docs/ARCHITECTURE.md` (ADR list); `docs/plans/AGENDA_PARITY.md` (enhancements) |
| — | The roadmap's Next line brought up to date (the `.AG` import released) | `docs/ROADMAP.md` (Next) |

*Minutes kept by Claude. Approved by José Who Brews and Carsten Stargazer.*
