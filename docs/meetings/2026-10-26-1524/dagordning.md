# Agenda (dagordning) for the panel meeting, 2026-10-26-1524

**Called by:** the owner **Place:** Owl's house, the Hundred Acre Wood **Wished date:** 2026-10-26, the roadmap's In order 1 (a meeting on the expert review of 2026-10-26)

## § 1 Opening of the meeting
## § 2 Election of a chair, a secretary and two approvers of the minutes
## § 3 Adoption of the agenda
## § 4 The previous minutes: decisions followed up

## Items to discuss

The review's resolutions (`docs/reviews/2026-10-26.md`, § 18), with the owner's two additions: the review's points of disagreement (§ 17) and "SPEC is becoming a diary" (§ 15). Where they overlap a resolution, they are discussed with it.

### § 5 The faded feed entries keep only their ids

In the owner's file, 13,184 of 14,423 feed entry snapshots have faded or been discarded, yet each keeps its title, note and link: 12.7 MB of the file's 17.0 MB, and the reason a save takes about half a second. Should they keep only their id (and publish date)? Should the compression level change too? And, from the panel's disagreement, do ingested items belong in the person's file at all?

### § 6 The clone's safety before going public

Three items are open: a recovery file on a crash, hostile-text tests for `.AG` files and feeds, and Erlang's logger, which can print over the screen. Should they come before the public repository, and in what order?

### § 7 No private addresses in the debug log

The debug log writes feed and calendar fetches with their full addresses, private tokens included, and keeps only five sessions. How should fetches be logged, and how many sessions kept?

### § 8 Keep the long fuzz run's output

A long fuzz failure on 2026-10-26 could not be repeated because its output, with the seed, was lost. Where should the output be kept: locally, in CI, or both?

### § 9 A tidy pass and a dry run before going public

Stale texts remain (VISION's freeze paragraph, AGENDA_PARITY's "three differences"), and going public rewrites the history with `git filter-repo`. Should a `tidy-docs` pass and a dry run on a copy come first?

### § 10 The pace

Ninety commits on 2026-10-25 and fourteen versions on 2026-10-26. Should there be a few days of use with nothing new built, and should the session summaries say whether the owner tried each version?

### § 11 `Update`'s shell answers

`lib/agendum/tui/update.ex` is 987 lines, about half of them the shell's answers. Should they move to a module of their own, now, later or never?

### § 12 The sort box's three Credo suppressions

The Sort box builds its eight setting names with `String.to_atom/1` and silences Credo three times, twice without a reason. Should the names be written out instead?

### § 13 SPEC is becoming a diary

SPEC grew from 135 KB to 185 KB in five days; its longest rule is one line of 6,169 characters, and many rules tell when and how they were checked or chosen. Should SPEC keep only the rule, the rule with its story, or a middle way, and when should it be slimmed?

### § 14 What comes after the public repository

The panel disagreed: looking for users, a read-only headless command with golden tasks, the GTD starter, or the gentler starter for the easily overwhelmed. Which, and when is it decided?

### § 15 The order of the work decided here

## Any other business
## Next meeting
## Closing of the meeting
