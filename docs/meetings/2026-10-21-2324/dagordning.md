# Agenda (dagordning) for the panel meeting, 2026-10-21-2324

**Called by:** the owner · **Place:** Owl's house, the Hundred Acre Wood · **Minutes:** [protokoll.md](protokoll.md)

## § 1 Opening of the meeting

The owner has prepared coffee and kanelbullar, though one bulle short.

## § 2 Election of a chair, a secretary and two approvers of the minutes

## § 3 Adoption of the agenda

## § 4 The previous minutes: decisions followed up

## § 5 A truthful clone of Lotus Agenda first: a change of strategy

The owner proposes to make a truthful clone of Lotus Agenda first, and to reorder the roadmap after it. The modernisation, the web version, many users and the agent stay in the plan, but come after the clone. The reasons: a truthful clone would draw the attention of those who love Agenda, while an unholy mix of things might turn them away; the program could be really useful, and free as in freedom; and it would be a good thing on the owner's résumé. The owner asks: what does the panel think of this plan?

## § 6 What "truthful" allows: a rule of thumb for modernisations and additions

Truthful means very alike both in function and in look and feel; only a few modernisations, such as undo and redo, which ones exactly still to be determined; and the same keyboard commands, made to work better on modern computers. The strategy of accepted additions and omissions stays (`docs/plans/AGENDA_PARITY.md`), but some of them may need to be reconsidered. The owner asks: which features should the clone keep? Let us make a principle, or a rule of thumb.

## § 7 Features to remove or hide for truthfulness

Some features already built may have to be removed, or hidden, to keep the clone truthful.

## § 8 Agenda in DOSBox as the reference for texts and menus

The owner's idea: use Agenda 2.0, run in DOSBox, as the reference for adjusting Agendum's texts and menus automatically towards more truthfulness. The headless driver (`tools/agformat/agenda_driver.py`) can already type keys and read Agenda's screen as text; Agenda's menus were walked with it once and written down by hand (`docs/reference/AGENDA_MENUS.md`).

## § 9 How the clone and the rest are split technically

How is this solved technically: a branch in git, or a new project? The core will most likely be shared. Perhaps the core and the terminal program could be one "thing", and a "next-level TUI" and the web version other "things", importing the core from the first.

## § 10 A clean, public history worth showing

Can a new git repository be made, carrying over the changes that are actually relevant to this scope? The owner would like a clean git history that is reasonable to show to people who might want to hire them.

## Any other business

## Next meeting

## Closing of the meeting
