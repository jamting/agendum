# Minutes of the panel meeting, 2026-10-21-2324

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host. David the Squirrel and Dr. Russell were excused, as nothing on the agenda concerned working as a trusted system or the easily overwhelmed.
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad, Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `6cdf033`

*A crisp autumn afternoon. The owner arrived with coffee and a bag of kanelbullar, and the room in the beech tree smelled of cardamom before anyone had sat down. The bell still lives on the windowsill beside the teacups, as agreed at the last meeting. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and thanked the chair for the coffee and the kanelbullar. The chair had noted that there was one bulle too few. *Owl counted them twice and arrived at a different number each time; Pooh, sitting on the stairs, looked out of the window with great interest.*

## § 2 Election of a chair, a secretary and two approvers

The owner was chair, Claude secretary; Old Mitch Lilypad and Little Marie-Who-Folds were chosen to approve the minutes.

## § 3 Adoption of the agenda

The owner's notes were worded as five items (§ 5–7, § 9–10). The chair added an item before adoption: Agenda in DOSBox as the reference for texts and menus (§ 8). The owner's notes below the agenda's line were left for a later meeting. The agenda was adopted with the addition.

## § 4 The previous minutes

| Decision (meeting 2026-10-16-1905, third) | Status | Evidence |
| --- | --- | --- |
| § 5 Quadsyl-24 is the Zettel id, brought into the core | Done, approved by the owner, v0.11.0 | `770f525`, ADR 0039 |
| § 6 A stored id with its own counter; "Attach Zettel id" | Done, v0.11.0 | `10cd608`, R73 |
| § 7 CTRL-X runs a command by name, fuzzy matching shared with F1 `c` | Done, approved by the owner, v0.14.0 | `8768e43`, R65d, ADR 0040 |

Nothing was stuck.

## § 5 A truthful clone of Lotus Agenda first: a change of strategy

**Background.** The owner proposed to make a truthful clone of Lotus Agenda first and to reorder the roadmap after it, keeping the modernisation, the web version, many users and the agent in the plan for later. The reasons given: a truthful clone would draw those who love Agenda, while a mix might turn them away; the program could be really useful, and free; and it would be a good thing on the owner's résumé.

**Discussion.** Claude presented the evidence: the vision ranked the owner's own wishes first and let them go ahead of parity (`docs/VISION.md`), and four of the last six versions (v0.11 to v0.14: Zettel ids, the blog, the feeds, CTRL-X) were additions beyond Agenda; parity was estimated at about 80%, with nine finite steps left (`docs/plans/AGENDA_PARITY.md`).

**Mitch** supported the plan: a faithful Agenda that opens one's old `.AG` files (R72, already built) is a story that can be told in one sentence, and Agenda's admirers are few, loyal and exact; they forgive a missing feature that is announced, not a strange one. He added that the clone serves the old users, not the newcomers: Agenda's learning curve comes with it, so the later work is still needed for them. **Carsten** agreed: people with long-held habits trust a tool that lists honestly how it differs. **Marie** said a finished thing sparks joy; a clone gives the 52 open roadmap boxes a finish line, and everything else a shelf for later. **Joe** recalled his rule, make it work first: one finished, faithful program is worth more than many good beginnings. **Claude** agreed, with two cautions: the vision's order is reversed for a while, which must be written down or later sessions will keep pulling extras forward; and the owner uses the blog and the feeds daily, so a freeze must not break them (§ 7). It asked for a definition of done: the parity steps, and the two lists of differences each tagged on purpose.

No habit of a present user changes with this item alone.

**Decided:** The panel's advice. A truthful clone first: `VISION.md` says so; "Beyond Agenda" is frozen to bug fixes until the clone is declared done against the parity steps.

## § 6 What "truthful" allows: a rule of thumb for modernisations and additions

**Background.** Truthful means very alike in function, look and feel; only a few modernisations, such as undo and redo; the same keys, made to work better on modern computers. The accepted additions and omissions stay the strategy, but some may need to be reconsidered. The owner asked which features the clone should keep, by what principle.

**Discussion.** Claude reported that the two lists hold 20 accepted enhancements and 11 accepted modifications, each accepted on its own, with no common test (`docs/plans/AGENDA_PARITY.md`, ADR 0006).

**Mitch** proposed a three-part test an old user would accept: a difference stays if the modern machine forces it, if it protects the person's work, or if it is quiet, so that an Agenda user who never asks for it never meets it. **Carsten** stressed the third part, as muscle memory is what an old user tests first, and named a visible case: the date format defaults to ISO 8601, where a truthful clone would default to Agenda's MM/DD/YY with ISO one setting away; a change for the owner's own files. **Claude** tried the test on cases: CTRL keys for INS, HOME and END and the sounds through the audio player pass as the machine; undo and the save questions as the person's work; F1 `c`, `d` and `a`, CTRL-X, the ALT-digit count and JSON beside STF as quiet. The always-shown mode word, the entries added to Agenda's menus, the view manager's ► and F5, and the descriptive key bar on a wide screen fail it. **Marie** asked for one test short enough to remember, and a tag on every entry, confirmed by the owner.

The habit changes the test may bring were listed: the date format's default, the READY word, some menu entries. None happens now; each becomes its own roadmap item, settled first.

**Decided:** The panel's advice. A difference stays only if the machine forces it, it protects the person's work, or it is quiet; ADR 0043, amending ADR 0006. **Referred:** the tagging of the 31 entries, to a pass over `AGENDA_PARITY.md` that the owner confirms entry by entry.

## § 7 Features to remove or hide for truthfulness

**Background.** Some features already built may have to be removed, or hidden, to keep the clone truthful.

**Discussion.** Claude reported where the extras that fail the test live: pure core modules of about 3,500 of 45,500 lines (the blog, the site, Markdown, feeds, Zettel ids), menu entries (`lib/agendum/tui/menu.ex:52-59`) and three stored fields (`next_zettel`, `feeds`, `blog`, `lib/agendum/core/database.ex:29,42,47`); the owner uses the blog and the feeds.

**Joe** advised hiding: removing a stored field takes a format version and a migration, and the owner's files hold those fields; a file saved with the extras hidden must keep them, which the round-trip tests can check. **José** observed that the commands are already data (ADR 0033), so being an extra can be a property of a command, and the menus, keymaps, F1 and CTRL-X can filter on it in one place, with no checks spread through `Update`. **Marie** accepted hiding if it is one switch in one home, and asked that the hidden features stay listed, as they still have to be cared for. **Mitch** wanted the clone to start with the extras off, so that someone coming from Agenda meets Agenda. **Claude** said the switch belongs in the preferences, since it is how a person wants the program, not part of their data (ADR 0008), and that `--clinic` passes as quiet.

The habit change: the blog, the feeds and the Zettel commands disappear until the owner turns Extras on once.

**Decided:** The panel's advice. Hide, do not remove: commands are tagged as extras, and one preference, Extras, off by default, hides them from the menus, keys, F1 and CTRL-X; the code and the stored fields stay, and files round-trip unchanged (ADR 0043).

## § 8 Agenda in DOSBox as the reference for texts and menus

**Background.** The chair's idea: use Agenda 2.0 run in DOSBox as the reference for adjusting Agendum's texts and menus automatically towards more truthfulness. The headless driver can already type keys and read the screen as text; Agenda's menus were walked with it once and written down by hand.

**Discussion.** Claude reported that the view's F10 menu was walked level by level on 2026-10-15 and written into `docs/reference/AGENDA_MENUS.md` by hand, the note editor's walked by hand and the category manager's taken from the User's Guide unchecked, and that nothing compares that file with Agendum's `Menu.tree/0`.

**Claude** said, in its own lens, that this is a golden reference taken from the original, best split in two: a capture tool, run by hand, that writes what Agenda shows to a committed JSON file, and a test that compares Agendum with that file without DOSBox, since CI cannot run DOSBox and Agenda's program cannot be committed. Automatic should mean the differences are found automatically, not that code is rewritten automatically. It added a caution for § 10: Agenda's help texts are Lotus's text; menu words are likely fine in public, long help lines may not be. **José** wanted the accepted differences to have one source, the tags of § 6, which the test reads. **Joe** advised starting small and measuring: the menus first, then the labels in boxes, then the key bar and messages. **Mitch** said menu words and help lines are what an old user recognises first: cheap faithfulness. **Marie** asked that the captured file replace or generate the hand-made table, so there are not two copies.

No habit changes, beyond menu wording the comparison will later correct.

*Marie held up the hand-made menu table, thanked it for its service, and put it on the windowsill beside the bell, to be retired once the captured file arrives.*

**Decided:** The panel's advice. Build it, menus first: a capture tool writes a committed JSON reference of Agenda's menus, a test compares Agendum's menus with it, and accepted differences come from the § 6 tags; then boxes, the key bar and messages.

## § 9 How the clone and the rest are split technically

**Background.** The owner asked whether this is solved with a git branch or a new project; the core will most likely be shared. Perhaps the core and the terminal program could be one "thing", and a "next-level TUI" and the web version other "things" importing the core from the first.

**Discussion.** Claude reported that Agendum is one Mix application, one repository and one single-file escript (ADR 0021), that the core is already a layer of its own guarded by the architecture test, that no earlier decision names an umbrella or a library, and that § 7 had already made the clone and the extras one program behind a switch.

**José** advised against a long-lived branch: every fix twice, and drift within weeks. The owner's picture of separate things is right for later, the core as a Mix project of its own used by the terminal program and a web application, but the time to cut it is when the web version starts and the core has a second user; for now, the extras' modules get a namespace of their own so that the later cut is clean. **Joe** agreed: split when there is a second consumer, and keep one file format, extras' fields included. **Claude** asked that the line be checked, not hoped for: an `:xref` rule in the architecture test that faithful code never calls an extras module directly, only through tagged commands. It noted that a "next-level TUI" with modern keys would change ADR 0038, which put modern keys in the web only, and should be its own question. **Marie** said the `Extras` shelf is the home she asked for in the last review (`docs/reviews/2026-10-17.md`, § 15). **Mitch** said users get one download either way: Agenda, plus what you turn on.

No habit changes.

**Decided:** The panel's advice. One repository and one program, no branch; the extras on a namespace of their own with an architecture test; the core becomes its own Mix project when the web version starts (ADR 0044). **Tabled:** the "next-level TUI", to the next meeting, as it would change ADR 0038.

## § 10 A clean, public history worth showing

**Background.** The owner asked whether a new repository could be made with only the changes relevant to this scope, and wished for a clean git history that is reasonable to show people who might hire them.

**Discussion.** Claude reported: 490 commits, all by the owner, 17 tags, one change per commit with plain messages, each passing the gate; 475 carry a `Co-Authored-By: Claude` line; the documents cite 424 distinct commit hashes. The deciding finding: third-party material (the Lotus manuals' text, Agenda's help file, the Lotus Q&A, Agenda's starter files, the ACM article and an essay) has been in git since the first commit, `23fa863`, so the history cannot be published as it is (`docs/plans/GITHUB.md` § 1 and § 7).

**José** said the history is already worth showing, as small tested steps with plain messages are what a reader looks for; squashing it would throw that away. The reference material forces a rewrite anyway, and `git filter-repo` keeps every commit, message, date and tag, and writes a map from old hashes to new for updating the cited ones. **Joe** advised keeping this repository as the private workshop and making the public one from a copy, once the clone is done. **Marie** said the owner decides what goes into the public house. **Carsten** first read "free as in freedom" as the GPL family. **Claude** said the résumé should present the project truthfully, as directed by the owner and built with an AI, keeping the co-author lines, and that the minutes using real people's names as lenses deserve a reread before going public.

*[A page here was soaked in the creek. — Rabbit]*

*[A page here was soaked in the creek. — Rabbit]*

## § 11 Any other business

The chair had noted beforehand, "as if this is not enough", and had nothing more to raise. *Owl passed the last kanelbulle round; there was still one too few, and Pooh had left the stairs.*

## § 12 Next meeting

When the agenda has enough items.

## § 13 Closing of the meeting

The chair closed the meeting. *Owl rang the bell on the windowsill to mark the closing, and found it sounded better there than it ever had on the bell-pull.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | A truthful clone first; "Beyond Agenda" frozen to bug fixes until the clone is declared done | `docs/VISION.md`; `docs/ROADMAP.md` (Next, Beyond Agenda); `docs/plans/AGENDA_PARITY.md` (status) |
| 6 | The test: the machine, the person's work, or quiet; amends ADR 0006 | `docs/adr/0043-what-may-differ-from-agenda.md`; ADR 0006 (status); `docs/ARCHITECTURE.md` (ADR list); `docs/plans/AGENDA_PARITY.md` |
| 6 | Tagging the 31 entries: referred, the owner confirms each | `docs/ROADMAP.md` (Towards parity, the truthful clone's groundwork) |
| 7 | Hide, not remove: commands tagged as extras, one Extras preference, off by default | `docs/adr/0043-what-may-differ-from-agenda.md`; `docs/ROADMAP.md` (Towards parity) |
| 8 | Agenda in DOSBox as the reference: menus captured, compared by a test | `docs/ROADMAP.md` (Towards parity) |
| 9 | One repository and one program; the extras on their own shelf with an architecture test; the core a Mix project when the web starts | `docs/adr/0044-one-repository-extras-on-their-own-shelf.md`; `docs/ARCHITECTURE.md` (ADR list); `docs/ROADMAP.md` (Towards parity) |
| 9 | The "next-level TUI": tabled | `docs/meetings/dagordning.md` |
| 10 | A public repository made from a copy when the clone is done; open core; licence at publishing, source-available noted | `docs/plans/GITHUB.md` § 7 and status; `docs/ROADMAP.md` (Housekeeping) |
| 10 | Business thoughts kept out of the documents meant for the public | `docs/plans/GITHUB.md` § 7; memory |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
