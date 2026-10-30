# Minutes of the panel meeting, 2026-10-26-2234

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Great-Uncle Joe, José Who Brews, Old Mitch Lilypad, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Great-Uncle Joe, Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `b59a3a3`

*A wet evening. Owl has lit the fire and set out more chairs than usual; Joe and José sit by the window, Mitch at the table with a Feeds box drawn on a napkin, and Marie has already straightened the honey jars. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting. There were no thoughts under Next meeting in the project file; the chair raised the item in the session.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs, Claude is secretary, and Great-Uncle Joe and Little Marie-Who-Folds approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as proposed.

## § 4 The previous minutes

| Decision (2026-10-26-5) | Status | Evidence |
| --- | --- | --- |
| § 5 What an extra keeps for itself; fingerprints in the snapshots | Done | ADR 0048, `a663ef2` (v0.66.0) |
| § 6 Ingested categories | Done | `f53f316`, `222e1d6`, `22778dd` (v0.67.0–v0.68.1) |

Nothing is stuck.

## § 5 Is there a pattern, and is the freeze its cause?

**Background.** The owner sees a pattern: the code review's findings, the recent publish crash (v0.69.1), and the settings boxes for feeds and publishing not living up to the standard of the rest of the program. Could the freeze during the Agenda parity work have left the extras fragile, compared with the core functionality and the TUI?

**Discussion.** **Claude** presented the evidence. The extras were built in two days (2026-10-16/17, `feed_sync.ex`, `publish.ex`, the boxes in `lib/agendum/tui/extras/`), before the `feature` checklist (meeting 2026-10-22-2337, § 5); during the freeze (10-21 to 10-26) they had two commits, then eight on 10-26 alone. Each review slice was capped at ten findings, so the counts say nothing, but slice C's were the ones a user meets at once: Markdown looping for ever, `INTERVAL=0` crashing at every start, an upload stalling the program (`docs/CODE_REVIEW_SLICES.md`, Record); slice B found real errors in the core's rules too. The v0.69.1 crash was in `App`, introduced by a review fix (`abf02ef`), where no pure test and no fuzz walk reaches; the fuzz walks start from the demo file with the extras off (ROADMAP, Sharpen the saw).

**Joe** observed that the extras are the only part that talks to the world, and that the Elm-style net (pure `Update`, fuzz walks, invariants after every key) stops at `App`: the bugs gathered where the net does not reach, a missing net more than a frozen one. **José** said the clone's boxes were built or converted under the checklist, with `Template` layouts, DOSBox checks and the fuzz walks crossing them, while `tui/extras/` predates it and the walks never open it. **Mitch** said the clone had a model to copy in Agenda and the extras had none, so nobody set their bar: a design gap more than a code gap. **Marie** said one part of the house was tidied room by room while another was closed off; the closed rooms did not decay but were never tidied, then were rearranged in a hurry. **Claude**, as a panel member, said the freeze explains the timing, not the cause.

The chair asked to clarify first, and gave an example: in the extras' settings a category to publish cannot be chosen with a picker, only typed. Claude checked it: the clone's boxes pick a category from a list (Datebook Settings, "SPACE picks one", `lib/agendum/tui/boxes/datebook_settings.ex:29-32`), as Agenda does, while Publish's Posts and Drafts are typed, and a typo makes a new category under MAIN (`lib/agendum/tui/extras/publish_box.ex:38-39`). **Mitch** called it the design gap in its plainest form; **Marie**, the one room where the chairs do not match. **Claude** sharpened the diagnosis to two lags with one cause.

**Noted:** the pattern is real, as two lags with one cause. The extras were built before the clone's bar was raised and missed its catch-up: (1) in robustness, at the shell's edge where the tests do not reach (the crash, the hangs); (2) in conventions, where their boxes do not follow the patterns the clone's boxes learned from Agenda. The freeze only meant that nobody lifted them.

## § 6 What feels weak in the Feeds and Publish boxes?

**Background.** The owner names what feels below the standard of the clone's boxes, and the panel compares the extras' boxes with the conventions the clone's boxes follow.

**Discussion.** **Claude** listed the gaps against the clone's conventions: Publish's Posts and Drafts typed, not picked; the Feeds and Calendars boxes changing a feed's settings by letter keys (F how often, K days kept) and one-line prompts, with no properties box per feed (`lib/agendum/tui/extras/feeds_box.ex:1-17`); OPML import and export, and Publish's Folder, taking typed paths where Agenda's file commands list files (`select_file.ex`); and no DOSBox model, so no SPEC rule for how these boxes look. **Mitch** said the Feeds box acts like a little program of its own; Agenda's habit is a list of things with a properties box each. **Marie** asked that it not grow into a redesign: existing parts, no new features. **José** said the parts exist, so it is wiring, and each box gains the tests the others have.

The chair said a think-through of the extras is needed and asked whether UI guidelines could be formulated; and, throwing it out there, that the settings for News and Calendar could be retrofitted into a view of their own. **Mitch** found the view the most Agenda-like thought on the table: a list of things as items seen through a view gets sorting, sections, columns and the item keys for free, but a column edit must change the subscription. **Joe** pointed to ADR 0048: one source of truth, so a view must be a window onto the typed structs, never a second copy. **Marie** wanted the guidelines first, the view judged against them. **José** said guidelines are worth keeping only if a test checks some of them, as the menu test checks first letters. **Claude** proposed drawing them from the clone's boxes and Agenda's manual (User's Guide 2-17, Appendix A), each rule "(as Agenda)" or "Our choice", with the view as an open question in the document.

**Referred:** UI guidelines in `docs/UI_GUIDELINES.md`, drawn from the clone's patterns and Agenda's manual, each rule marked as SPEC's are, the checkable ones by tests; the gap table goes in it. (The view question was first to be its open question; § 8 moved it to Beyond Agenda.)

## § 7 What to do about it, and where in the order

**Background.** What work would bring the extras up to the standard, and whether it comes before the public repository.

**Discussion.** **Claude** noted that the robustness lag already has roadmap items (In order 1, 2 and 7: parser property tests, hostile files, fuzz walks in a richer file and out of order), the last of them after the public repository, and that the owner wants every extra usable before it (2026-10-26). **Joe** asked to move the fuzz walks up beside 1 and 2, and for a test that sends each kind of background result (`:ok`, `{:ok, _}`, `{:error, _}`, a crash) through `App`, where v0.69.1 slipped through. **Marie** asked that no new extras be built until the existing ones meet the guidelines, Wol staying on its shelf. **Mitch** wanted the guidelines and the rework before the public repository: old users opening the Extras will judge the program by its weakest box. **José** kept it small: only parts that exist, a handful of feature commits.

**Decided:** the order 1 parser property tests, 2 hostile files, 3 the richer and out-of-order fuzz walks with `App`'s results test (moved up), 4 the UI guidelines, 5 the extras brought up to them, one feature commit per gap; then the docs meeting, the tidy pass, the dry run and the public repository as before. No new extras until step 5 is done.

## § 8 Any other business

The chair said that settings as views might be best for Beyond Agenda: while the work is "a truthful clone with robust extras", the extras stick to the existing patterns, so as not to confuse old users.

**Decided:** the guidelines and the rework use only the clone's existing patterns; settings as views (the feeds and calendars as a view of their own) is a later Beyond Agenda item, a window onto the typed structs (ADR 0048), no longer a question the guidelines must settle.

## § 9 Next meeting

When the agenda has enough items.

## § 10 Closing of the meeting

The chair closed the meeting. *Mitch folded the napkin into his pocket.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | Two lags, one cause: built before the bar was raised, missed the catch-up | — (noted; the reason in `docs/ROADMAP.md`, In order) |
| 6 | UI guidelines for the extras, with the gaps found | `docs/ROADMAP.md` (Housekeeping) |
| 7 | The new order; `App`'s results test; the extras up to the guidelines; no new extras until then | `docs/ROADMAP.md` (In order, Sharpen the saw, Beyond Agenda); memory |
| 8 | Only existing patterns; settings as views later | ADR 0049, `docs/ARCHITECTURE.md` (ADRs); `docs/ROADMAP.md` (Housekeeping, Beyond Agenda); memory |

*Minutes kept by Claude. Approved by Great-Uncle Joe and Little Marie-Who-Folds.*
