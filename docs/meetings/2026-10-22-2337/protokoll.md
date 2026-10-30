# Minutes of the panel meeting, 2026-10-22-2130 (third)

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews, Little Marie-Who-Folds, David the Squirrel, Carsten Stargazer, Old Mitch Lilypad, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** David the Squirrel and Carsten Stargazer
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `b6c9e36`

*The third meeting of the day, late in the evening; it ran past midnight. Owl, a little surprised to see the same faces again so soon, had laid out three cards. A portrait of Uncle Robert, moved into the hall at Marie's gentle suggestion, now watched over the coats; Owl said he looked happier there, and nobody argued. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and remarked that three meetings in one day was either a record or a habit.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude is secretary; David the Squirrel and Carsten Stargazer approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted with one item from the owner's Agendum project file (§ 5) and two the chair added at the meeting, the RSS reader's open questions (§ 6 and § 7). Carsten Stargazer and Old Mitch Lilypad were invited for those two, beside José Who Brews, Little Marie-Who-Folds and David the Squirrel for § 5.

## § 4 The previous minutes

| Decision (meeting 2026-10-22-2130, second) | Status | Evidence |
| --- | --- | --- |
| § 3 The Markdown agenda retired; thoughts come from the project file | Done | this meeting's § 5 came from it |
| § 5 The project's documents imported into the owner's file as Disposable items | Not yet: still the roadmap's next action | ROADMAP, Sharpen the saw |
| § 6 The import before the extras shelf | Recorded | ROADMAP, Next action |

Nothing was stuck. Since then a smoke-test script for the real terminal (`87747f3`), a format-on-edit hook (`bdf1249`), a permission allowlist (`c2a402c`) and a tidy of the documents (`0f41522`, `652fdfe`; the roadmap's finished work now in `ROADMAP_DONE.md`) were made.

## § 5 Should building a feature become a skill of its own, `/feature`?

**Background.** Today the steps for building a feature are a long passage of prose in CLAUDE.md. Claude reads it every time and follows it from memory, so the order sometimes drifts and a small step gets forgotten, such as a line in SCREENS.md or a box's F1 text. The suggestion is a `/feature` skill: the same steps as a short checklist, done in the same order every time. The owner asked the panel to advise on three questions: (a) is the skill wanted at all; (b) should it replace the prose or only give the order; (c) should a check go with it that lists the documents a change has left untouched?

**Evidence.** The workflow is `CLAUDE.md:28-42`. Tests already catch some forgotten steps: SPEC's rule index (`test/agendum/docs_index_test.exs:11`), `docs/INDEX.md` (`:24`), SCREENS.md (`test/agendum/tui/screens_doc_test.exs:10`) and the commands' texts (`test/agendum/tui/command_docs_test.exs:20`). Nothing catches the roadmap, KEYBOARD.md, a new place's F1 text, or the version and CHANGELOG.

**Discussion.** **David** said a checklist is the point: a system is trusted when its steps need not be remembered, for the builder as for the user. On (a), yes; he asked that the list end with the step the owner relies on most, trying a habit change before the next is built on it.

**Marie** said, on (b), that two homes for one rule is how documents drift. She advised that the skill hold the steps and their order, CLAUDE.md keep the architecture rules and conventions, and its workflow section shrink to a pointer to the skill.

**José** said, on (c), that what a test can check belongs in a test, not a checklist. Two of the uncaught steps can be tests: every place and box has its F1 text, and every key in a keymap is in KEYBOARD.md. The roadmap and the CHANGELOG depend on intent, which no test sees, so they stay lines on the checklist. He advised against a separate command for untouched documents, which would guess and grow stale.

**Claude** noted that a skill is loaded only when a feature is built, so CLAUDE.md becomes shorter for every other kind of session, and that a skill can run steps side by side, such as the long fuzz run in the background while the documents are written. It agreed with José: tests first, no command.

*Marie straightened the three cards into a line; Owl moved the biscuit tin to match.*

The panel's advice: yes to the skill; the skill holds the steps and CLAUDE.md points to it; what can be checked becomes tests, not a command.

**Decided:** The panel's advice. A `/feature` skill holds the steps for building a feature, in order; CLAUDE.md's "Workflow for a feature" shrinks to a pointer to it. Two tests come with it: every place and box has its F1 text, and every key in a keymap is in KEYBOARD.md. No separate command for untouched documents. No habit of anyone using Agendum changes.

## § 6 Should feed entries be read-only?

**Background.** The owner is unsure whether the entries of a feed should be read-only. Today an entry is an ordinary item: its text and note can be edited, and an edit counts as keeping it, so it no longer fades after its keep days.

**Evidence.** An entry is kept when it has a Zettel id, its text or note differs from what the feed sent, or it has a category given by hand (`lib/agendum/core/feed_sync.ex:156-164`). A refresh updates an entry only where the person has not changed it. The extras are frozen to bug fixes (ROADMAP, Beyond Agenda). Read-only entries would change habits: editing an entry's text would be refused, its note would open read-only, and keeping by editing would end; Done, discarding, categories and Zettel ids would stay.

**Discussion.** **Mitch** said Agenda's idea is that everything taken in is an item like any other; a read-only kind of item would be a second class of item, a step away from that idea. He would keep entries editable.

**Carsten** said the text is someone else's words, and once edited the person's words cannot be told from the author's. In Org-mode the source is captured as it is and one's own thoughts are written beside it. His middle way: the entry's text stays as the feed wrote it, and the person's own words go in the note.

**David** was troubled less by editing than by keeping by accident: correcting a typo silently keeps an entry for ever, and nothing shows which entries are kept. Whatever is decided, keeping should be visible and deliberate.

**Claude** said that Wol needs to know which words are the feed's, data and never instructions, and which are the person's; today that can only be worked out by comparing the item with its snapshot. `docs/plans/ITEM_LEVELS.md` already holds this question among its open ones: ingested items, level 2, with rules to keep, promote or discard. Read-only is a property of that level.

**Marie** said that one question should have one home, and this one belongs with the item levels.

*Carsten and Mitch found they agreed more than they had expected, and shared the last biscuit.*

The panel's advice: refer the question to the item levels; change nothing until then; keeping should be visible and deliberate.

**Referred:** to `docs/plans/ITEM_LEVELS.md`, to be decided as part of what an ingested item is. Nothing changes now. David's point is recorded with it: keeping an item should be visible and deliberate, never a side effect of an edit.

## § 7 What is still missing from the OPML import?

**Background.** The owner feels the RSS reader's OPML import is not finished. What exists: I in File ▸ Transfer ▸ Feeds imports a feed list from a path, and E exports one.

**Evidence.** The import subscribes to every feed in the list the file does not have yet, reading folders through, and reads them at once (`lib/agendum/core/facade/feeds.ex:144-194`, `lib/agendum/tui/update.ex:512`); both directions have tests. Two gaps were found in preparing: F3 lists no files at either OPML prompt, though it does at every other file prompt, because the two prompts are missing from the Select File box's list (`lib/agendum/tui/boxes/select_file.ex:25-36`); and OPML is reached only from inside the Feeds box, while File ▸ Transfer ▸ Import takes JSON and `.AG` files but not a feed list.

**Discussion.** **Carsten** said OPML is how people move between feed readers, so the import is the front door for anyone coming from another reader, and should be as easy to find as any import: an `.opml` file chosen in File ▸ Transfer ▸ Import should simply work.

**Mitch** said Agenda had one place for bringing things in, File ▸ Transfer, and putting OPML there keeps it one place rather than a key hidden in a box.

**José** said the first gap is a few lines and a test: the two OPML prompts in the list, with `.opml` and `.xml`. The second is a small change to the Import prompt, choosing the reader by the file's extension as it already does for `.AG`.

**Marie** recalled the freeze: the first gap is a bug, one file prompt unlike all the others, and may be fixed now; the second is new behaviour and waits with the rest of the extras.

**Claude** noted that the import is already a facade function (`Core.import_opml/2`), so a web page or an agent can use it without keys; nothing more is needed on that side.

*Owl studied the chair's face for signs of anything else missing, found none he could read, and offered more tea instead.*

The panel's advice: fix the first gap now as a bug fix; the second when the extras thaw.

**Decided:** The panel's advice. F3 lists `.opml` and `.xml` files at the OPML import and export prompts, built now as a bug fix; File ▸ Transfer ▸ Import taking an `.opml` file waits until the extras thaw. The only habit change: F3 starts to work at those two prompts.

## § 8 Any other business

None.

## § 9 Next meeting

When there are thoughts under Next meeting.

## § 10 Closing of the meeting

The chair closed the meeting. *Owl rang the bell, wished everyone a good night (it was by then a good morning), and went to say goodnight to Uncle Robert in the hall.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | A `/feature` skill; CLAUDE.md's workflow becomes a pointer to it; tests for F1 texts and KEYBOARD.md; no untouched-documents command | `docs/ROADMAP.md` (Sharpen the saw) |
| 6 | Read-only feed entries referred to the item levels; keeping visible and deliberate | `docs/plans/ITEM_LEVELS.md` (Open questions); `docs/ROADMAP.md` (Beyond Agenda); `docs/plans/RSS_READER.md` |
| 7 | F3 at the OPML prompts fixed now as a bug fix; OPML through File ▸ Transfer ▸ Import when the extras thaw | `docs/ROADMAP.md` (Beyond Agenda); `docs/plans/RSS_READER.md` |

*Minutes kept by Claude. Approved by David the Squirrel and Carsten Stargazer.*
