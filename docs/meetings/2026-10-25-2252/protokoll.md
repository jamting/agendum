# Minutes of the panel meeting, 2026-10-25-2252

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, Great-Uncle Joe, David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `a388a78`

*A late, still evening after a long day of tagging. Owl had lit the lamp and put out the good biscuit tin, which turned out to hold one biscuit and a ball of string; Little Marie-Who-Folds thanked the string and put it in the drawer. Great-Uncle Joe took the stairs, and Old Mitch Lilypad's papers went on the floor, as they always do. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and welcomed everyone at some length.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude keeps the minutes; Old Mitch Lilypad and Little Marie-Who-Folds approve them.

## § 3 Adoption of the agenda

The agenda was adopted with two changes. The owner's thought "menu bar in boxes" was struck, as it has been taken care of, and the owner will remove it from the project file. A new item was added as § 7: the definition of done, what "optional" means, and what it means for the roadmap. David the Squirrel, invited for § 7, joined then.

## § 4 The previous minutes

| Decision (2026-10-24-2) | Status | Evidence |
| --- | --- | --- |
| Principles 7 to 10 for Wol | done | `docs/plans/WOL-IN-THE-MACHINE.md`, Principles |
| Objections, what Wol will not do, how we would know it helps, learning over time | done | `docs/plans/WOL-IN-THE-MACHINE.md` |
| Local models as of 2026-10, and a trial on an M1 MacBook Air | recorded; waits (frozen) | `docs/plans/WOL-IN-THE-MACHINE.md`, Local models |
| Marie's six boundaries, each kept by a test | recorded; waits (frozen) | `docs/plans/WOL-IN-THE-MACHINE.md`, What Wol will not do |
| The owner tries Wol on their own files first | recorded; waits (frozen) | `docs/plans/WOL-IN-THE-MACHINE.md`, How we would know it helps |

Nothing is stuck: Wol stays frozen until the truthful clone is declared done.

## § 5 External note files: build them, or leave them out on purpose?

**Background.** In Agenda a note can be kept in a text file of its own (the note editor's F10 ▸ File ▸ Attach, Detach, Erase): the Agenda file stores only the path, and the item shows ♫. The User's Guide (12-16 to 12-21) gives three reasons: sharing a note with another program, using one note in several Agenda files, and keeping large notes out of the file (Agenda could not edit a note file over 10,000 characters). It is the last open step of the note editor plan (`docs/plans/NOTE_EDITOR.md`, step 7); building it would need a new stored field, an ADR, and file reading and writing outside the core.

**Discussion.** **Mitch** said note files answered DOS-era limits on size and memory, and were not part of what made Agenda itself: few users relied on them. **Carsten** liked plain-text files that outlive a program, but noted that Agendum already keeps notes as plain text in its own file; a link from an item to a file would be a better idea for later than a copy of Attach. **Joe** pointed to the cost: two sources of truth, file input and output in the middle of editing, missing or changed files. **Claude** observed that the planned web version can never reach a person's local files, and that one self-contained file is easier to give an agent as context. **Marie** advised thanking the feature and letting it go, written on the "done differently" list so the record stays true.

The chair then raised a use the panel had not: attaching files of any kind, such as an image that is part of a note, or the CV a note is about, and said that this belongs beyond Agenda. **Carsten** called it a different and better feature than Agenda's note files: attachments, as org-mode has long had them, with the file copied into a folder of its own and linked from the note. **David** said reference material kept with the person or project it belongs to is what a trusted system needs. **Russell** said it saves a search at the moment the thing is needed. **Joe** said a terminal would open such files with the system's viewer, an effect like opening a link, and that a folder beside the Agendum file keeps the core pure and the file small. **Claude** said attachments suit the web better than Agenda's paths did (uploads kept by the server), and that an attached file's text, read by an agent, must be data and never instructions. **Mitch** agreed, as long as it waits for the clone.

*Carsten had sat up so suddenly at the word "attachments" that his tea reached Owl's portrait of Uncle Robert, who did not seem to mind.*

**Decided:** Agenda's external note files are left out of the clone on purpose, listed on the parity plan's "done differently" list, and the note editor plan's step 7 is closed. Attachments of any kind (images, PDFs, a CV on an item or a category; kept as org-mode keeps them, opened with the system's viewer, uploaded on the web) go to the roadmap's Ideas, frozen until the clone is declared done.

## § 6 The panel's view on the last days' progress

**Background.** Since 22 October there have been 140 commits (39 on the 23rd, 19 on the 24th, 78 on the 25th) and sixteen tagged versions, v0.35 to v0.50, all parity work: the control panel, key bars, boxes, menus, editing, unindexed categories, Section Select, the date format, the ♦ and the clock, and alarms; the Screens and texts part of the parity plan is done. The owner wants the truthful clone, but is getting a little tired of parity work.

**Discussion.** **Mitch** said the screen now reads as Agenda's did and, more to the point, that each step was checked against the real program (DOSBox runs, the captured boxes and menus as tests) rather than against memory. The core of Agenda (free text, automatic filing, views) was done long ago; what is left is housekeeping, where each step matters less than the last, which is why it feels dull. **Joe** said quality held (the gate green, an old undo bug found by the fuzz walks), but that the day's slips (a too-broad `pkill`, a JSON encoder missed until checked, a fuzz walk that could not reach a new view) show speed beginning to outrun care. **Russell** called 78 commits in a day and sessions past midnight a sprint, not a pace, and the boredom information: the reward has gone out of the steps. He suggested a visible finish line, batches of small items, and ending sessions while they still go well. **Marie** found the record tidy, with the parity plan as the one list, and asked only that whatever § 7 cuts be written down as cut. **Claude** noted that every new user action this week became a named command, and that the tests comparing boxes with Agenda's own make parity something a test can confirm. Mitch and Russell would cut hard in § 7; Joe cared more about the pace than the cut.

*Owl said that his house had never had so many visitors in one week, and that he had counted them. Nobody asked for the number.*

**Noted.** The panel's advice, to slow the pace and let § 7 set a finish line close enough to see, was noted.

## § 7 The definition of done, what "optional" means, and what it means for the roadmap

**Background.** The parity plan said the clone is declared done when every step is built and every entry on the two lists of differences is tagged and confirmed by the owner. Some steps were marked Optional, without saying whether they block it. Until the clone is declared done, Beyond Agenda, Ideas and Towards many users are frozen, and the public repository waits. The open steps were listed with their sizes: DEL's question, the Show commands, the File commands and MakeCopy, File Properties' other settings, the managers' menus, the alarm leftovers, Search compared, the trash, the `.AG` date format, Agenda's help, and the optional ones (`.STF`, structured text, TXT2STF, Compose, Launch).

**Discussion.** **Marie** said an "optional" that might block "done" is a door left half open: optional should mean that it does not block, and such steps should move to the ordinary roadmap the day the clone is done. **Mitch** said the truthful clone is what an Agenda user would reach for in an ordinary week (Search, the Show and File commands, DEL's question), and that the help is what a newcomer meets first, so he would keep it; he would leave the trash out, as undo and the question before closing cover the mistakes it was for. **David** disagreed about the trash: a trusted system needs a way back from yesterday's deletion, and undo ends when the file is closed. **Russell** asked for a finish line close enough to see: small items in batches, the large one last. **Joe** said the password and the backup on open need real care, and should be done properly or not at all. **Claude** suggested that the roadmap's In order list show what the day of "declared done" sets off: the public repository, the freezes lifted, the optional steps moved in.

The chair said that all the steps the panel offered to cut are important in one way or another, and that expectations should be managed: the optional parts go back on the roadmap when the rest is done.

*Marie crossed out "cut list" in her notebook and wrote "finish line" instead. David looked pleased about the trash.*

**Decided:** Optional steps do not block declaring the clone done; that day they go back on the roadmap, each in its area. Nothing else is cut: the trash, File Properties' password and backup on open, the `.AG` date format, and File Abandon, Erase and Template are all required. Agenda's help is required and built last. The order: the small steps in one or two batches, then Search compared with Agenda's, then the help.

## § 8 Any other business

None.

## § 9 Next meeting

When the agenda has enough items.

## § 10 Closing of the meeting

*Owl closed the meeting by ringing the bell-pull, which came off in his wing. Little Marie-Who-Folds thanked it.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | External note files left out of the clone on purpose; the note editor's step 7 closed | `docs/plans/AGENDA_PARITY.md` (The note editor; Done differently; How close), `docs/plans/NOTE_EDITOR.md` (status, step 7) |
| 5 | Attachments of any kind as an idea for after the clone | `docs/ROADMAP.md`, Ideas |
| 6 | The progress, and the advice to slow the pace | — (noted) |
| 7 | Optional steps do not block "declared done"; they return to the roadmap that day; nothing else is cut; the help required, last | `docs/plans/AGENDA_PARITY.md` (Declared done) |
| 7 | The order: small steps in batches, Search compared, then the help | `docs/plans/AGENDA_PARITY.md` (Commands and behaviour still missing), `docs/ROADMAP.md` (In order) |
| 7 | What the day of "declared done" sets off | `docs/ROADMAP.md` (In order, 2) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
