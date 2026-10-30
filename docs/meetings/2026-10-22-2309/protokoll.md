# Minutes of the panel meeting, 2026-10-22-2130 (second)

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, David the Squirrel, Great-Uncle Joe, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `3711b78`

*The second meeting of the day, in the evening. Owl had dusted the bell-pull and laid a single card on the table; it had come out of Agendum rather than out of a file, which he found both modern and a little unsettling. Only five guests came, so for once nobody sat on the stairs. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and observed that it was the shortest agenda his house had seen.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude is secretary; Old Mitch Lilypad and Little Marie-Who-Folds approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as worded, with one item from the owner's Agendum project file (Thoughts ▸ Next meeting) and the five lenses invited.

The secretary noted that `docs/meetings/dagordning.md`, the Markdown agenda the owner kept until now, had been deleted. The chair said it is retired: the thoughts below its line have moved into the Agendum project file, and `docs/meetings/TEMPLATE.md` stays as the form the secretary fills in for each meeting's agenda. The `meeting` and `start-session` skills, `docs/HOW_I_WORK.md`, `docs/INDEX.md` and the template were brought in line after the meeting.

## § 4 The previous minutes

| Decision (meeting 2026-10-22-2130) | Status | Evidence |
| --- | --- | --- |
| § 5a Recurring items a parity step; what "declared done" means | Recorded | ROADMAP, Towards parity |
| § 5b The tagging in one sitting | Done: all 32 entries tagged, the owner confirming each | `8b44a3f` |
| § 5c Effect type, recovery file, hostile-text tests | Not yet | ROADMAP, the clone's safety |
| § 5d ADR 0044's tests first | Not yet; it was the roadmap's next action | ROADMAP |
| § 5e No search for old Agenda users | Recorded | ROADMAP, Users and direction |
| § 5f View Properties first, recurring items second | Not yet; the order is recorded | ROADMAP |
| § 5g An `extra` field on commands | Not yet | ROADMAP |
| § 5h The session summaries into git | Not yet: 46 summaries, none tracked | ROADMAP, Housekeeping |
| § 5i Freeze lines; the research log archived | Done at the meeting | `56c7506` |
| § 5j The study plan's pace never raised | Recorded | memory; skills |
| § 5k A gentler Overdue | In Ideas | ROADMAP |
| § 6 Modern keys in the terminal later, as an extra | Recorded | ADR 0038 |
| § 7a Agenda's help in our own words | Not yet | AGENDA_PARITY.md, step 10 |
| § 7b Thoughts in Agendum; the project as a rebuilt copy | The thoughts done (this meeting's agenda came from them); the copy is the subject of § 5 | `3711b78` |

Nothing was stuck. Since the morning the nightly long fuzz run in CI was also built (`bdc6942`).

## § 5 The project's documents in the owner's own file, as disposable items

**Background.** The owner wants a tool that imports some of the project's documents into their Agendum project file: the meeting agendas and minutes, the ADRs and the reviews. The reasons: to learn Agendum better, for inspiration, for easy reference, and to have some volume of data in it. The imported items would be tagged Disposable, every Disposable item deleted before an import and the documents read afresh, so that the documents stay current and syncing is never a concern. The owner would like it built fairly soon.

**Evidence.** The three folders hold 60 documents: the meetings 11 files (about 14,000 words), the ADRs 44 (about 19,000), the reviews 5 (about 22,000). This morning's § 7b decided a separate, rebuilt Agendum file of the roadmap, the summaries and the meetings (`docs/ROADMAP.md`, Sharpen the saw); the owner's thought differs in putting the documents into the owner's own file, in which documents, and in tagging them Disposable. The thoughts tool reads only; an import would write the file, and if Agendum has it open, Agendum's next save asks whether to save over a file changed on disk (R71, `docs/SPEC.md`), where Yes would erase the import. The roadmap already holds Agenda's own way of turning text into items, TXT2STF-style definition files, as an optional parity item.

**Discussion.** **Mitch** said this is what Agenda was made for: loose text taken in and filed by the person's own categories, so that an ADR mentioning the extras lands under Extras. The value is in watching one's categories catch things, not in the storage; he advised whole documents first, the title as the item and the text as its note, and letting text matching do the rest.

**David** agreed that it gives reference material a trusted home, with one warning: anything done to a disposable item (an assignment to Next meeting, a note, a done date) is lost at the next import. Disposable items must stay reference only; a thought a document sparks becomes a new, lasting item that names the document.

**Joe** said the tool becomes a second writer to the owner's file, which is where things go wrong. He saw two safe shapes: the import into the owner's file, run only with Agendum closed and saved, or a separate file the owner's file never depends on, as decided this morning. With one file, deleting the Disposable items and importing must be one save, all or nothing, through the store's write-then-rename, so that a crash never leaves the file half empty.

**Marie** welcomed that the Markdown documents stay the original: Disposable means nothing in Agendum is a second original, which settles her worry of the morning about drift. She asked that the import replace this morning's separate copy rather than stand beside it, since two tools importing the same documents would be clutter, and advised leaving the reviews out at first, as some 22,000 words in five notes are a lot to carry and are seldom read.

**Claude** said the import can be as pure as the reader: a function in `Agendum.Thoughts` taking the documents as path and text pairs and returning the new file, with the Mix task only reading the folders and saving. A test can then show that the Disposable items are replaced and every other item is untouched. It suggested the document's own date as the item's Entry date (the meeting's folder, the ADR's status date), so that views by date work.

*Marie straightened the single card on the table. Owl, unasked, moved the minutes of 2026-10-16-1905 an inch to the left, and was thanked.*

The panel's advice: build it into the owner's own file under a Disposable category the import owns, replacing the separate copy; one item per document, filed further by text matching; the import run only with Agendum closed and saved.

**Decided:** The panel's advice, with the chair's choice of documents. The import puts the meeting agendas and minutes, the ADRs, `docs/ROADMAP.md` and the session summaries (the reviews left out) into the owner's project file, one item per document under a Disposable category, each import deleting every Disposable item first and saving once. The import cannot see whether Agendum has the file open: it says that Agendum must be closed and saved first, and Agendum's changed-on-disk question catches a slip. It replaces this morning's separate rebuilt copy.

## § 6 Any other business

The chair raised the order of work: the import comes next, before the extras on their own shelf, as it is workshop tooling (Sharpen the saw, not frozen) and the chair wants it soon. **Decided.**

## § 7 Next meeting

When there are thoughts under Next meeting.

## § 8 Closing of the meeting

The chair closed the meeting. *Owl rang the bell and left the single card for the chair to mark done, declaring it the most orderly meeting his house had ever held.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 3 | `docs/meetings/dagordning.md` retired; thoughts for meetings come from the Agendum project file; `TEMPLATE.md` is the form for each meeting's agenda | `.claude/skills/meeting/SKILL.md`; `.claude/skills/start-session/SKILL.md`; `docs/meetings/TEMPLATE.md`; `docs/HOW_I_WORK.md`; `docs/INDEX.md`; memory |
| 5 | The project's documents imported into the owner's file as Disposable items, replacing the separate copy | `docs/ROADMAP.md` (Sharpen the saw) |
| 6 | The import next, before the extras shelf | `docs/ROADMAP.md` (Next action); memory |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
