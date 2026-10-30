# Minutes of the panel meeting, 2026-10-26-0829

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, José Who Brews, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Carsten Stargazer
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `474bc00`

*A grey morning, the trash freshly tagged. Owl had laid his own copy of "How to Use Help" on the table and tapped it now and then; Little Marie-Who-Folds had already stacked the reference printouts into three neat piles. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and welcomed everyone, mentioning twice that he has always been very good at helping.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude keeps the minutes; Old Mitch Lilypad and Carsten Stargazer approve them.

## § 3 Adoption of the agenda

No thoughts were waiting under Next meeting; the agenda was the owner's subject, Agenda's help, in four items. It was adopted as it stood.

## § 4 The previous minutes

| Decision (2026-10-25) | Status | Evidence |
| --- | --- | --- |
| External note files left out on purpose | Done | `AGENDA_PARITY.md`, `NOTE_EDITOR.md` |
| Optional steps do not block "declared done"; nothing else cut; the help required, last | Done (recorded) | `AGENDA_PARITY.md`, Declared done |
| The order: small steps in batches, Search compared, then the help | Batches and Search done; the help is today's subject | v0.51.0–v0.55.0 |

## § 5 How much of Agenda's help to make

**Background.** Agenda's help has 332 topics, about 61,000 words: 159 on boxes, 132 on how to do things and what things mean, 28 on menus and 13 key charts. The meeting of 2026-10-22-2130 (§ 7a) decided Agenda's keys and structure exactly, in our own words. Should Agendum have a topic for everything it has, or fewer?

**Discussion.** Claude presented the split, and what Agendum already holds that could become topics: each box's help line per field, each menu entry's description, the command summaries and longer texts, and each place's F1 text; what is missing is most of the how-to topics. **Mitch** said an old user expects F1 in a box to show that box's topic, and the index to hold what they knew: every box, menu and key chart Agendum has should have one, and the core tasks need how-to topics. **Carsten** said box, menu and key topics can be made from what the program knows, so they never go stale; only the how-to topics need writing, and 40 to 60 cover what people look up. **Russell** asked for fewer, better topics: a person in trouble needs the right answer on the first screen. **Marie** asked for one help, the generated topics replacing today's F1 pages, and no topic for a feature Agendum lacks. **Claude**, in its own lens, said topics as data serve a web page or an agent as well, and generated ones cannot contradict the code.

**Decided:** the panel's advice. A topic for every box, menu, place and key chart Agendum has, made from what the program knows; hand-written how-to topics for every task Agendum supports, with Agenda's list as the checklist and what Agendum lacks left out.

## § 6 The keys inside the help, and what becomes of today's F1 pages

**Background.** Today F1 shows a text about where you are; `c`, `d` and `a` open the command list, describe key and all keys, and any other key goes back. Agenda's help (seen in DOSBox) has the key bar F1 On Help, F3 Index, F5 Find, F6 Keys, F8 Review, F9 Return; links are moved between with the arrows and opened with ENTER, and a letter jumps to a link. The meeting of 2026-10-22-2130 decided `c`, `d` and `a` stay reachable.

**Discussion.** Claude listed the habit changes: any other key no longer leaves help; letters jump to links, so `c`, `d` and `a` cannot stay single letters; ↑ ↓ move between links. **Mitch** said the keys are what an old user's fingers remember: take all of Agenda's. **José** said `a` is Agenda's F6 Keys, made from the keymaps, and its page can link to "Commands you can run here" (`c`, still able to run them) and "Describe a key" (`d`). **Russell** said ESC must always work and F9 Return always show, so no one feels trapped. **Carsten** noted that describe-key is used often and should come first on the F6 page.

**Decided:** the panel's advice. Agenda's keys exactly: links with the arrows and ENTER, letters to links, F3 Index, F5 Find, F6 Keys, F8 or BACKSPACE Review, F9 or ESC to leave, F1 How to Use Help. Today's `a` becomes F6 Keys, whose first links are "Commands you can run here" (`c`) and "Describe a key" (`d`). Any other key no longer leaves help.

## § 7 How the topics are written and kept

**Background.** Generated topics are made while the program runs; the 40 to 60 hand-written ones need a home inside the single-file program (ADR 0021): text files built in, or Elixir code.

**Discussion.** **José** favoured a text file per topic, readable and easy to review in git, compiled in with `@external_resource`, links as `**name**`. **Carsten** asked for one fixed layout, Agenda's PURPOSE, STEPS, NOTE and SEE ALSO, in plain text rather than Markdown. **Marie** asked for checks so the help never rots: every box, menu and place has a topic, every link leads to one, every key a topic names is bound there. **Claude**, in its own lens, said topics as data can be served beyond the TUI, and that a lasting decision on how the help is built deserves an ADR.

**Decided:** the panel's advice. Hand-written topics as plain-text files in Agenda's layout, compiled into the program; generated topics from the boxes, menus, places and keymaps; the three checks as tests; ADR 0047.

## § 8 The order of work, and when the clone counts as done

**Background.** The help is the last required step; when it is done, the clone is declared done (meeting 2026-10-25-2252, § 7). Today's decisions make it bigger than one batch, and the owner has said parity work is getting tiring.

**Discussion.** **Carsten** advised three sample topics for the owner's approval before dozens are written. **Russell** advised small batches, each finished and tagged, so the end stays in sight, with the owner reading only a few topics from each. **Marie** asked for one checklist, Agenda's how-to topics each marked ours, covered or left out, in a short plan document. **Mitch** advised the frame first, since the habit changes are there and the owner can try them early.

**Decided:** the panel's advice. A plan, `docs/plans/HELP.md`, with the checklist; first the frame (the owner tries it, then it is tagged); then three sample topics for the owner's approval of the tone; then the rest in batches by subject, each tagged; the help, and with it the clone, is done when the checklist has nothing open.

## § 9 Any other business

None.

## § 10 Next meeting

When the agenda has enough items.

## § 11 Closing of the meeting

Owl closed the meeting and offered to write the first help topic himself, about Owls. The offer was noted.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | Generated topics for every box, menu, place and key chart; hand-written how-to topics for every task Agendum supports, Agenda's list as the checklist | `docs/plans/HELP.md` (What it covers, checklist) |
| 6 | Agenda's help keys exactly; `a` becomes F6 Keys, linking first to `c` and `d`; any other key no longer leaves help | `docs/plans/HELP.md` (The keys) |
| 7 | Text files in Agenda's layout compiled in; generated topics; three checks; an ADR | ADR 0047, `docs/ARCHITECTURE.md` |
| 8 | Frame, tone sample, batches, done when the checklist is empty | `docs/plans/HELP.md` (The steps), `docs/plans/AGENDA_PARITY.md` (the help step), `docs/ROADMAP.md` (In order), `docs/INDEX.md` |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Carsten Stargazer.*
