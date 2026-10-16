# Refactoring plan (2026-10-14)

Agendum grew feature by feature. This is a review of where that left unnecessary complexity, in the code and in the tooling around it (Mix commands, skills, scripts, documents), and what to do about it, in order.

**Status (2026-10-16):** steps 1 and 3 done; 2 decided (the hints stay); 4 done with the command layer (R66, ADR 0036) and typed UI modes (ADR 0037); 5 done for now (the plans moved to `docs/plans/`; the documents streamlined, with an index in `docs/INDEX.md`); 6 needs no change. How to add a box is now in `docs/ARCHITECTURE.md` (TUI).

**In short:** the foundations are sound and stay as they are: the pure core (checked by `test/agendum/architecture_test.exs`), the facade over area modules (ADR 0023), `mix check` as the one quality gate (ADR 0012), the ADRs. The one real structural problem is how a settings box is spread over many files. The rest is small.

## 1. Reaching box settings by name; longer fuzz runs ✅

- `CLAUDE.md` asks tests to reach a box's setting by name, but there was no helper: the tests counted ↓ presses (26 places), and so did the manual's capture script (`docs/manual/src/capture_screens.exs`), which broke on 2026-10-14 when the box keys changed (ADR 0031) and Category Properties became two columns. A helper in `Agendum.TUIHelpers` moves the highlight to a named setting, using the box's own field order.
- The fuzz property's longer run (`CLAUDE.md`, step 4) needed a temporary copy of the test with more runs. An environment variable sets the number of runs instead: `FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs`.
- Found on the way: `test/agendum/docs_names_test.exs` still looked for `Agenda.*` modules after the rename (ADR 0019), so it could no longer fail.

## 2. The hints inside boxes: kept

A box's keys are described in three places: the hint line inside the box, the key bar, and the control panel's help for the highlighted setting (`Agendum.TUI.Boxes.FieldHelp`). Two of them were updated when ENTER came to mean done (ADR 0030); the hint lines of Item Properties and Macro Properties were not (ROADMAP, Look and feel).

Decision: the in-box hints stay for now. They may become the start of an in-line help feature, with longer help texts in a separate help box. Step 3 gives each box one list of its keys, so the hint and the key bar can no longer disagree.

## 3. One module per box

A box's code is spread over about eight files. `:macro_props` appears in:

| File                                                                             | What it does for the box                                |
| -------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `lib/agendum/tui/update.ex`                                                      | a `dispatch` clause sends it the keys (47 such clauses) |
| `lib/agendum/tui/render.ex`                                                      | a list of box types                                     |
| `lib/agendum/tui/render/boxes.ex`                                                | draws it (921 lines, none from a layout)                |
| `lib/agendum/tui/render/key_bar.ex`                                              | a `mode_keys` clause for the key bar                    |
| `lib/agendum/tui/render/control_panel.ex`, `lib/agendum/tui/boxes/field_help.ex` | the help for the highlighted setting                    |
| `lib/agendum/tui/boxes/box_cancel.ex`                                            | the list of boxes ESC cancels                           |
| `lib/agendum/tui/boxes/macro_props.ex`                                           | its keys                                                |

Plan: a behaviour, `Agendum.TUI.Boxes.Box`, whose callbacks are everything about one box: its keys (`handle/3`), its drawing (from a `Agendum.TUI.Boxes.Template` layout), one list of its keys and labels (for the key bar and the in-box hint), its field help, and whether ESC cancels its changes. A registry from mode type to module replaces the scattered clauses; the old places fall back to them until every box has moved.

One box per commit, its layout converted to a template in the same commit (the box's look moves closer to Agenda's screenshots where that is easy), `mix check` passing each time. When the last box has moved, `render/boxes.ex`, the `dispatch` clauses and the lists in `render.ex` and `box_cancel.ex` are gone, and the stale-hint bug with them.

### Done (2026-10-14)

All 41 box types have their module, one commit each; the last commit removed the fallbacks. `Agendum.TUI.Update` sends a box its keys and `Agendum.TUI.Render.Boxes` draws its frame through `Box.registry/0`; `FieldHelp`, `BoxCancel` and `BoxChoices` ask the box modules alone. `Render.CategoryBoxes` is gone: the category lists share `CategoryScreens.list_lines/5`, each box with its own marks. A box's bottom edge may depend on its mode (`finish/1`, the picker's).

A box with fixed settings is drawn from a template layout; the lists (pickers, profiles, calendar, macros, files, views) keep their rows' drawing, and so do their hint lines where they say more than the keys (the assignment profile's legend, the picker's per-purpose line).

Adding a box: a module with `use Agendum.TUI.Boxes.Box` and its options (`finish:`, `indicator:`, `cancels:`, `choices:`), the callbacks (`handle/3`, `title/2`, `content/4`, `keys/2`, `help/0`; `field/2`, `width/2`, `finish/1` where needed), and a line in `Box.registry/0`.

On the way: the fuzz property runs as four test modules side by side (the suite took 32 s, now about 12 s), and a bug in F3's list was fixed (ENTER on the choice already set moved the setting two choices on).

## 4. Logic in `Agendum.TUI.Update`: wait for the command layer

(With the command layer, each place also gets a struct for its UI mode; ROADMAP, "Towards many users".)

`Agendum.TUI.Update` still decides things that belong in the core. The command layer planned in ROADMAP ("Towards many users") is the right fix; a separate refactoring now would be done twice.

Done (2026-10-16): every change to a file is a core command (`Agendum.Core.Command`, run by `Agendum.Core.run/3`; R66, ADR 0036), and every mode on the stack a struct (`Agendum.TUI.Modes`, ADR 0037).

## 5. Documents

- Keys are described in five places: `docs/KEYBOARD.md`, the F1 help (`Agendum.TUI.Render.Help`), `docs/SCREENS.md`, the guide and the manual. No test ties them together. The lasting fix is to generate the key tables from self-describing commands (ROADMAP, after the command layer); until then the `update-guide` and `update-manual` skills catch the drift. Since R65 (2026-10-16) the F1 help is made from the keymaps and commands; `docs/KEYBOARD.md`, `docs/SCREENS.md`, the guide and the manual are still written by hand.
- Plans sat among the reference documents: `GITHUB.md`, `DOSBOX_STAGING.md`, `KITTY.md`, `RENAME_REPO.md`, `WOL-IN-THE-MACHINE.md`, `MULTIUSER.md` and this one. ✅ Moved to `docs/plans/` (2026-10-14), a group of their own (Plans) in `mix docs`, so `docs/` is what Agendum is. `RENAME_REPO.md` goes once the folder is renamed.

## 6. Mix commands, skills, tools: no change

One alias for the docs, one for `check`, one Mix task (`mix agendum.starters`), one switch for the debug log (`AGENDUM_LOG`, ADR 0027). The two update skills share their "what changed since" step; acceptable.
