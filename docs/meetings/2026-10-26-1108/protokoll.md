# Minutes of the panel meeting, 2026-10-26-1108

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Little Marie-Who-Folds, David the Squirrel, Dr. Russell, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `47a9a94`

*The same day, later. The lamp was lit again, and Owl had put out a celebratory jar of honey, already half eaten, he said, by a visitor. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting, noting that it was the second of the day and that he was getting quite good at them.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude keeps the minutes; Old Mitch Lilypad and Little Marie-Who-Folds approve them.

## § 3 Adoption of the agenda

No thoughts were waiting under Next meeting; the agenda was the owner's request, in three items. It was adopted as it stood. Before the meeting, Claude checked Agenda's key bar during moves in Agenda 2.0: empty slots while an item moves, F1 Help alone for a column's width.

## § 4 The previous minutes

| Decision (2026-10-26) | Status | Evidence |
| --- | --- | --- |
| Topics for every box, menu, place and key chart; written how-to topics | Done | v0.56.0 to v0.61.0, `docs/plans/HELP.md` |
| Agenda's help keys; F6 Keys leads to the command list and describe key | Done | v0.56.0 |
| Text files compiled in, three checks, ADR 0047 | Done | ADR 0047, `test/agendum/tui/help_topics_test.exs` |
| Frame, tone sample, batches; done when the checklist is empty | Done | `HELP.md`, step 4 ticked |
| (after the meeting) Agenda's keyword index and Find boxes | Done | v0.56.0, v0.57.0 |

## § 5 Confirm the tags on "Beyond Agenda: accepted enhancements"

**Background.** ADR 0043's test keeps a difference from Agenda only for the machine, the person's work, or when it is quiet; anything else is an extra, hidden while the Extras preference is off. The owner tagged the entries on 2026-10-22; the definition of done asks for each tag to be confirmed. Two entries' texts describe a state that has passed.

**Discussion.** Claude went through the nineteen entries in plain words. **Mitch** said that with Extras off an Agenda user sees Agenda's screens, and nothing takes an Agenda key or menu entry, so the tags hold. **Marie** asked that the two stale texts be fixed as part of confirming, the command help now being behind F6 Keys and Show Alarm built, and observed that the day's trash, Find and help work brought Agendum towards Agenda, adding nothing to the list. **Russell** advised confirming them in one go. **Claude**, in its own lens, had checked every extra against its command's extra tag: none untagged.

**Decided:** every tag confirmed as it stands; the two stale texts updated.

## § 6 Confirm the tags on "Done differently: accepted modifications"

**Background.** The same for what Agenda had that Agendum does another way. Of the three entries marked "change back", two are done; the key bar while moving is still a line of hints where Agenda keeps its ten slots.

**Discussion.** **Mitch** found the tags sound and wanted the moves' bar changed back: it is what an Agenda user sees during a common action. **Russell** noted that the hints help someone who forgets how to end a move, which Agenda's empty bar does not, but that F1 covers it and the clone's rule is Agenda's way. **Marie** asked that the finished change backs leave the list, so it holds only what is different now. **David** asked for a clear decision on whether the bar blocks done, rather than leaving it vague. **Claude**, in its own lens, sized it as small and named the habit change: the hint line during moves goes; F1 still explains the keys.

**Decided:** every tag confirmed; the category lists and Write → MakeCopy off the list as done; the key bar in moves changed back to Agenda's (its ten slots, F1 Help where Agenda shows it, no hint line) as the last step before declaring done.

## § 7 Declare the truthful clone done?

**Background.** Every required step is built. Declaring done sets off what the meeting of 2026-10-25-2252 (§ 7) decided: the public repository, the freezes lifted (Beyond Agenda, Ideas, Towards many users), the optional steps back on the roadmap in their areas.

**Discussion.** **David** advised declaring it done on a condition: the moment the moves' bar is built, so the finish line is concrete and the next actions can be planned. **Russell** said a long push deserves a clear moment of finishing. **Mitch** said what is left of Agenda (printing, networks, the macro language) is out of scope by decision, not neglect. **Marie** asked that on the day, the parity plan become a record, How close say all of the scope, and the roadmap's In order list show what comes next. **Claude**, in its own lens, noted that the "Our choices" within SPEC's rules are not on the two lists and the definition does not ask for them. The chair was asked about the version number, as 1.0.0 is the owner's call alone.

**Decided:** the truthful clone is declared done the moment the key bar in moves is built and tagged, without another meeting; the public repository, the freezes lifted and the optional steps then follow as decided on 2026-10-25. The version stays below 1.0.0 (v0.62.0); 1.0.0 is kept for later.

## § 8 Any other business: the Wood touches in the help

**Background.** The chair asked for a new document listing the Hundred Acre Wood touches in the help texts.

**Discussion.** **Marie** proposed one small document, a row per touch: the topic, the words, who appears, so the touches stay spread out and are easy to find and change. **Russell** said a list shows the balance: no topic overloaded, no character so frequent that it grates. **Claude**, in its own lens, proposed the tone rules at its top (no Milne quoted, Owl never self-centred: one such joke was cut that day) and a check that fails when a listed line is no longer in its topic, as the help's other checks do.

**Decided:** `docs/HELP_WOOD.md`, the tone rules at the top and a row per touch, listed in `docs/INDEX.md`, kept true by a check built with the key bar in moves.

## § 9 Next meeting

When the agenda has enough items.

## § 10 Closing of the meeting

Owl closed the meeting, satisfied that he appears in the Wood list a respectable number of times.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The accepted enhancements' tags confirmed; two stale texts updated | `docs/plans/AGENDA_PARITY.md` (Beyond Agenda) |
| 6 | The accepted modifications' tags confirmed; two finished change backs off the list; the key bar in moves changed back | `docs/plans/AGENDA_PARITY.md` (Done differently; The steps) |
| 7 | Declared done the moment the key bar in moves is built and tagged; the version stays below 1.0.0 | `docs/plans/AGENDA_PARITY.md` (Declared done), `docs/ROADMAP.md` (In order) |
| 8 | `docs/HELP_WOOD.md` with its tone rules, and a check keeping it true | `docs/HELP_WOOD.md`, `docs/INDEX.md`, `docs/ROADMAP.md` (In order; Sharpen the saw) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
