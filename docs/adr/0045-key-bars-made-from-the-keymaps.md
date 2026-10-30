# ADR 0045 — Every key bar is made from the keymaps

**Status:** accepted · 2026-10-24 (meeting 2026-10-24-2057, § 5)

## Context

Agenda's key bar has ten fixed slots, one per function key (R80), and holding ALT, CTRL or SHIFT shows the ALT-F, CTRL-F and SHIFT-F keys of the place in the same slots (checked in Agenda 2.0, PLANNER, 2026-10-24, by setting the BIOS shift flags). Agendum is to show those bars too, reached with ALT-K (meeting 2026-10-24-2057, § 5). That is five bars in each of five places. Until now each bar was a hand-written list in `Agendum.TUI.Render.KeyBar`, apart from the keymaps (`Agendum.TUI.Keymap`) that decide what a key does, so a bar could say one thing while the key did another. The F1 help is already made from the keymaps and the commands (R65).

## Decision

- **Every key bar is made from the place's keymap**: a slot shows the short label of the command its key is bound to there, or the name of a macro attached to the key (R50); a key bound to nothing leaves its slot empty.
- **Each command gets a short label**, at most seven characters, Agenda's where Agenda has one (`Last Vw`, `UnmkAll`), beside its name and summary in `Agendum.TUI.Commands`. The bar keeps no texts of its own.
- **A bar is fixed per place**: not greyed or emptied when a command cannot run at the moment (the F1 help's `c` says that, R65a), so the slots never change under the person's eyes; only attached macros change a label.
- **A test compares the bars with Agenda's**, captured in DOSBox, as the menu test does for the menus (`test/agendum/tui/agenda_menus_test.exs`); each difference is tagged by ADR 0043's test.

## Consequences

- One table answers "what does this key do here" for the bar, the F1 help, the web front end and an agent; key bindings customised later (ADR 0038) show up on the bar, and in the menu if it ever names keys, without more work.
- The hand-written lists in `KeyBar` go; the hint lines of boxes and moves stay until the texts step compares them with Agenda (AGENDA_PARITY § The steps).

## Amended 2026-10-25: boxes and the menu

Boxes and the menu have Agenda's slots too (checked in Agenda 2.0, PLANNER: 35 boxes captured with `tools/agformat/capture_boxes.py`; the owner's choice). In a box **a bar is fixed per field, not per place**: Agenda's changes on a few fields (Item Properties' Assigned to adds F4 Values; View Properties' Sections drops F8 Default), and the owner chose to follow it. A slot is the command the box's keymap binds the key to, with a short label (`c:Agendum.TUI.Boxes.Box.labels/1`, or the shared ones in `Box.slot/4`), or one of the keys every box shares (F1 Help; F3 Choices and F8 Default in a box of settings); a box names the keys that do nothing on the highlighted field (`c:Agendum.TUI.Boxes.Box.idle_keys/2`). The hint line stays only while a field is typed in, until the Editing step. `test/agendum/tui/agenda_boxes_test.exs` compares the slots with Agenda's; the keys Agenda names but ours lack (F2 Edit in most boxes, F6 Props, F8 Default in a few) are tagged *not built*.
- Keys Agenda had but Agendum lacks (ALT-F1 Compose, ALT-F9 Copy) show empty slots: honest, though less like Agenda, until they are built.
