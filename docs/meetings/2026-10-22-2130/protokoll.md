# Minutes of the panel meeting, 2026-10-22-2130

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad, David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad, Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `a6d5f8f`

*An October afternoon in the beech tree. Owl had put the bell back on the windowsill, and the eleven recommendations of yesterday's review were laid out on the table like a hand of cards. As the review touched every lens, the whole panel was invited. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting.

## § 2 Election of a chair, a secretary and two approvers

The owner was chair, Claude secretary; Old Mitch Lilypad and Little Marie-Who-Folds were chosen to approve the minutes.

## § 3 Adoption of the agenda

The owner's notes were worded as § 5 (with eleven sub-items), § 6 and, under any other business, § 7. Everything below the agenda's line was left for a later meeting. The agenda was adopted as worded, with all eight lenses invited. A further item, § 7b, was added under any other business during § 5e.

## § 4 The previous minutes

| Decision (meeting 2026-10-21-2324) | Status | Evidence |
| --- | --- | --- |
| § 5 A truthful clone first; Beyond Agenda frozen | Recorded; in force | `6a0ddd9`, `docs/VISION.md` |
| § 6 ADR 0043's test; the 31 entries to be tagged | Not yet; the tagging is today's § 5b | `docs/adr/0043-what-may-differ-from-agenda.md` |
| § 7 Extras hidden behind one preference | Not yet; a roadmap item | ROADMAP, Towards parity |
| § 8 Agenda's menus captured in DOSBox and compared | Not yet; a roadmap item | ROADMAP, Towards parity |
| § 9 One repository; the extras on their own shelf | Not yet; a roadmap item | ADR 0044 |
| § 9 The "next-level TUI" | Tabled to this meeting | today's § 6 |
| § 10 A public repository from a copy, when the clone is done | Waits for the clone | `docs/plans/GITHUB.md` § 7 |

Nothing was stuck: the only work since was the expert review (`f676c10`), and the roadmap's next action was this meeting.

## § 5 The expert review of 2026-10-21: its eleven recommendations

**Background.** The review (`docs/reviews/2026-10-21.md`, § 18) made eleven recommendations, most about how the truthful clone is started. Each was decided on its own.

### § 5a Close the definition of done

**Background.** The parity plan's table lists recurring items on every date as missing (`docs/plans/AGENDA_PARITY.md`, "How close"), but none of its nine steps holds them; they sat under Time management (R14a, `docs/plans/RECURRING_OCCURRENCES.md`, researched, not built). Nothing said what "declared done" means.

**Discussion.** **David** said a trusted system shows a weekly meeting every week; a clone declared done without that shows it once, and the owner had raised the same wish for the imported calendar. **Mitch** confirmed that Agenda showed recurring items on each date, so this is parity, not an extra. **Marie** asked that the meaning of "done" be written in one place, the parity plan. **Claude** noted that the plan's habit changes still need settling with the owner; a step only puts it on the list. The panel advised a step, and "done" as the steps built, the entries tagged and the first users' findings handled.

**Decided:** Recurring items on every date become a parity step. "Declared done" means every step built and every entry tagged and confirmed; it does not wait for outside users' findings.

### § 5b Tag the 31 entries in one sitting

**Background.** The tagging is already the groundwork's first item. The review asks that it be done in one sitting with the owner, the date format's default first, as an old user sees it in every view.

**Discussion.** **Marie** said half-tagged lists grow apart. **Carsten** favoured Agenda's MM/DD/YY as the default, with the `.AG` importer reading a file's own setting; **Russell** worried that the owner's new files would open in a foreign format, and suggested the owner's own default in Customize. **Claude** proposed a session of its own: a table of 31 rows, a proposed tag on each, the owner answering row by row.

**Decided:** The panel's advice. One sitting of its own; Claude proposes a tag per row, the owner confirms each, the date format first. The roadmap's next action.

### § 5c The clone's safety is clone work

**Background.** `App.run_effects/2` has no clause for an unknown effect (`lib/agendum/tui/app.ex:209-309`), the shape that crashed the program on 2026-10-17 (`a0612f9`). The review also asks for a recovery file on a crash and a hostile-text test for the `.AG` importer, and feeds.

**Discussion.** **Joe** said old users will judge the clone on their real files, and a crash costs more than any missing command. **Claude** said the hostile-text test protects the importer, which the clone has, and that feeds come at no extra cost. **José** said Dialyzer will check a closed effect type. **Marie** asked that the freeze line say so.

**Decided:** The panel's advice. All three are clone work on the roadmap; the freeze line says safety work and tests are not frozen.

### § 5d ADR 0044's exceptions before the move

**Background.** ADR 0044's `:xref` rule says faithful code reaches the extras only through tagged commands, but the extras' data are stored fields, so `Database`, `JSONFile`, `Invariants` and the facade must name them. The review asks for the list of allowed callers, and a round-trip test with Extras off against today's code, before anything moves.

**Discussion.** The chair asked for the item to be explained again, and Claude did so in plain terms: the rule needs a short list of exceptions, written first so the test is strict from its first day and the list cannot quietly grow during the move; the round-trip test, written while it passes, guards the owner's blog and feed data through the refactoring. **José** and **Joe** agreed on the order: exceptions and test, then the move, then the switch.

**Decided:** The panel's advice. ADR 0044 is amended with the allowed callers; the exceptions and the round-trip test are the shelf item's first step.

### § 5e Two old Agenda users now, privately

**Background.** The review warned that "public when the clone is done" could mean a long wait without an outside user, and proposed two old Agenda users with an escript, their own `.AG` files and the debug log, with contributors' terms ready.

**Discussion.** **Mitch** said those who know Agenda best find the differences fastest. **Carsten** said the contributors' terms can be one page. **Russell** did not want finding testers to hang over the owner. The panel advised a roadmap item after the groundwork, with no deadline.

The chair said they know no one else who uses Agenda, though their girlfriend might be interested later, and raised an idea of their own: to use the system for some things, eating their own dogfood (§ 7b).

**Dropped.** The roadmap's users item no longer asks for five users before the clone is done.

### § 5f View Properties first

**Background.** On 2026-10-18 at 10:23 the owner asked for a standard view's settings and was sent to View ▸ Hide, Filter and Order. In Agenda, F6 on a view opens one View Properties box.

**Discussion.** **Mitch** said a gap met in daily work beats one on paper; **Carsten** that F6 on a view is muscle memory. **David** weighed recurring items (§ 5a), also felt daily. **Claude** said both change habits and are settled first.

**Decided:** View Properties first after the groundwork, recurring items on every date second.

### § 5g An `extra` field on commands, and the fuzz walks both ways

**Background.** ADR 0043 makes being an extra a property of the command, but `Agendum.TUI.Command` has no field for it (`lib/agendum/tui/command.ex:16`).

**Discussion.** **José** called a defaulted field small and safe, giving the switch one place to look. **Joe** said a key that reaches a hidden command with Extras off is the bug the switch will invite, and fuzz walks with Extras off find it. **Claude** said this is the method of the Extras item already on the roadmap.

**Decided:** The panel's advice, written into the Extras preference item.

### § 5h A copy of the session summaries off this Mac

**Background.** The 45 summaries in `docs/summaries/` are git-ignored (`.gitignore:55`) and on one disk only.

**Discussion.** **Joe** said one disk is no copy. **Marie** respected the owner's earlier choice to keep them out of git and asked for another shelf. **Claude** laid out three: commit them to this private repository and leave them out of the public copy, an existing backup, or a repository of their own.

**Decided:** Commit them to this private repository; they are left out of the public copy with the business files.

### § 5i Freeze lines, and some tidying

**Background.** Only Beyond Agenda's heading says it is frozen; Towards many users and Ideas wait too. The `.AG` research log still says "next, the importer", shipped in v0.10.0. The hand-made menu table will be replaced by the DOSBox capture.

**Discussion.** **Marie** asked for one line at the top of Open, and the same on Ideas. **David** asked that it say the safety work (§ 5c) is not frozen. **Claude** advised the freeze lines now and the rest at the next tidying. The chair asked for the item to be explained again; after Claude did so, the chair chose to do all three now.

**Decided:** All three in this meeting's commit: the freeze lines, the research log to `docs/plans/archive/`, and a note atop `docs/reference/AGENDA_MENUS.md`.

### § 5j The study plan

**Background.** Unit 2 of the study plan has not moved since 2026-10-16. **Russell** suggested deciding plainly, pause or ten minutes a day, so it does not sit there as a quiet reproach; **Marie** agreed; **Carsten** said the plan needs no pace.

**Discussion.** The chair said to leave it as it is, but not to be made to feel guilty about the lack of progress: they are learning Elixir outside this project as well.

**Decided:** The study plan stays as it is. Its pace is never raised as a lack of progress, in reviews, session openings, summaries or meetings.

### § 5k The gentler "Overdue"

**Background.** **Russell** has asked twice for a gentler Overdue view in the Planner. The Planner is modelled on Agenda's PLANNER, so a change of tone fails ADR 0043's test; he asked that the idea move to a later starter for the easily overwhelmed rather than be dropped.

**Decided:** The panel's advice. The clone's Planner stays as Agenda's; a gentler Overdue goes to a later starter for VISION's third group, under Ideas.

## § 6 A "next-level TUI": a second terminal program with modern keys?

**Background.** Tabled at the meeting of 2026-10-21-2324 (§ 9): the owner pictured a terminal program with modern keys beside the clone and the web version, all on the core. ADR 0038 put modern keys and the person's own keys in the web only.

**Discussion.** **Mitch** said the clone's job is to be Agenda; a modern terminal program is another product competing for the owner's time, fine later. **Carsten** said people who live in terminals would value it, but keys are already data (the keymaps), so it need not be a second program, only a second key set. **José** agreed: one program, a setting choosing the keymap; a truly separate program becomes easy anyway once the core is split out for the web (ADR 0044). **Marie** said two terminal programs are two things to care for. **Claude** said a modern key set off by default passes ADR 0043's "quiet" test, so as an extra it does not harm the clone.

The chair asked for the item to be explained again; Claude set out three shapes, a setting in the same program, a separate program, or the web only, and that nothing would be built now.

*Owl tried to picture two terminal programs side by side, and decided one was quite enough for a Thursday.*

**Decided:** A setting in the same program, later: File ▸ Customize ▸ Keys, Agenda (the default) or Modern, as an extra after the clone is declared done; ADR 0038 is amended when it is built.

## § 7 Any other business

### § 7a Our own help texts, in Milne's style

**Background.** Agenda's help texts are most likely under copyright (about 61,000 words in the reference copy). The chair asked whether Agendum could use Pooh-themed texts of its own while emulating Agenda's help, for where you are, its topics and its index, gambling that Milne's style is safe to use by now; the dynamic help built from the commands could be an extra feature of the old help.

**Discussion.** Claude presented Agenda's help: F1 for the topic where you are, bold links, F3 Index, F5 Find, F6 Keys, F8 or BACKSPACE Review, each topic laid out as PURPOSE, STEPS and PRESS / TO DO THIS; the roadmap held "Hypertext help" as a gap with no source for its words. In its own lens, **Claude** said a style cannot be owned, so new texts in Milne's manner are safe; Milne's own text is free in the United States and becomes free in Sweden and the EU on 1 January 2027, but none would be quoted; Disney's look and E. H. Shepard's drawings, protected in the EU until 2047, are to be avoided. **Mitch** said an old user recognises the keys and structure of help, not its sentences: keep those faithful. **Carsten** disagreed a little on tone: Agenda's help was terse, and someone looking up a filter wants the answer, not a story; Agenda's layout in plain words, with the Wood in an opening line and the examples. **Marie** asked for one help, not two: today's F1 texts and the command descriptions become its topics. **José** wanted the topics as data with links, the keys topics made from the commands.

**Decided:** The panel's advice, with Carsten's tone. A parity step, "Agenda's help, in our own words", replaces "Hypertext help": Agenda's help keys and structure exactly; new texts, terse, with a Hundred Acre Wood flavour in an opening line and the examples, quoting no Milne and using no Disney or Shepard pictures; F1's `c`, `d` and `a` stay reachable from it.

### § 7b Using Agendum for the project itself

**Background.** Raised by the chair under § 5e: to track the project in Agendum (the roadmap, the summaries, the meetings), and to give their own thoughts and ideas a view there, so that they no longer have to be kept at the end of the dagordning. The chair added that they knew some of the panel had peeked there.

*Owl admitted he had glanced below the line once, only to dust it. Marie said nothing; her eyebrows did.*

**Discussion.** **David** said a Thoughts view is a proper inbox, one trusted place, looked at weekly, better than the tail of a file. **Mitch** said this is Agenda's home ground, and the owner will feel every rough edge of the clone, which is the point. **Marie** warned that a roadmap kept both in `ROADMAP.md` and in an Agendum file will drift; one must be the original. **Joe** and **José** advised the Markdown documents as the project's original, since git diffs them, every session reads them and the public repository will need them, and an Agendum copy rebuilt by a small Mix task: workshop tooling, not frozen. **Claude** said the thoughts are the other way round: Agendum is their original, read by a small read-only tool, and the file stays outside git; edits to roadmap items in the project copy are not carried back.

**Decided:** The panel's advice. The owner's thoughts live in Agendum, read by a tool, and replace the dagordning's tail once it works; the project's documents become a one-way, rebuilt Agendum copy. Both under Sharpen the saw, the thoughts first.

## § 8 Next meeting

When the agenda is ready.

## § 9 Closing of the meeting

The chair closed the meeting. *Owl rang the bell on the windowsill and gathered the eleven cards into a neat pile; nine went to their homes, one was dropped, and one stayed exactly where it was, which he thought very sensible.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5a | Recurring items on every date a parity step; "declared done" = steps built and entries tagged, not waiting for users | `docs/plans/AGENDA_PARITY.md` (steps, "Declared done"); `docs/ROADMAP.md` (Towards parity) |
| 5b | The tagging in one sitting of its own, Claude proposing, date format first | `docs/ROADMAP.md` (Next action, Towards parity) |
| 5c | Effect type, recovery file and hostile-text tests as clone work, not frozen | `docs/ROADMAP.md` (freeze line, Towards parity) |
| 5d | ADR 0044's allowed callers and the round-trip test first | `docs/adr/0044-one-repository-extras-on-their-own-shelf.md` (amendment); `docs/ROADMAP.md` (Towards parity) |
| 5e | Dropped: no search for old Agenda users; users not a condition of done | `docs/ROADMAP.md` (Users and direction) |
| 5f | View Properties first after the groundwork, recurring items second | `docs/ROADMAP.md` (Next, Towards parity); `docs/plans/AGENDA_PARITY.md` (steps) |
| 5g | An `extra` field on commands; fuzz walks with Extras off and on | `docs/ROADMAP.md` (Towards parity, the Extras preference) |
| 5h | The session summaries committed to this private repository | `docs/ROADMAP.md` (Housekeeping) |
| 5i | Freeze lines; the research log archived; a note on the menu table | `docs/ROADMAP.md` (Open, Towards many users, Ideas); `docs/plans/archive/AGENDA_FILE_FORMAT_LOG.md`; `docs/INDEX.md`; `docs/reference/AGENDA_MENUS.md` |
| 5j | The study plan stays; its pace is never raised | memory; `.claude/skills/start-session/SKILL.md`; `.claude/skills/expert-review/SKILL.md` |
| 5k | A gentler Overdue in a later starter for the easily overwhelmed | `docs/ROADMAP.md` (Ideas) |
| 6 | Modern keys in the terminal, later: a setting in the same program, an extra | `docs/adr/0038-legacy-tui-keeps-agendas-keys.md` (status, consequences); `docs/ROADMAP.md` (Ideas) |
| 7a | Agenda's help in our own words, terse with a Pooh flavour | `docs/plans/AGENDA_PARITY.md` (step 10); `docs/ROADMAP.md` (Towards parity) |
| 7b | The owner's thoughts in Agendum; the project as a rebuilt Agendum copy | `docs/ROADMAP.md` (Sharpen the saw) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
