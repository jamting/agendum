# ADR 0033 — Keys run named commands through keymaps; a count with ALT-digits

**Status:** accepted · 2026-10-15

## Context

Until now each screen read its keys in one long `case`: a key ran code directly. Nothing knew which commands exist, what a key does in a given place, or which keys are free. The F1 help and `docs/KEYBOARD.md` were written by hand and could drift from the code. A second front end needs commands that describe themselves (as Emacs's do), a command list, "describe key", and later key bindings of the person's own.

The owner settled these choices before any code (2026-10-15):

- F1 still opens the help screen at once. In the help screen, `c` lists the commands and `d` describes the next key pressed (Emacs's C-h then a letter).
- ALT-letters (and ESC + letter, the same key once decoded) are bound through keymaps like every other key.
- Key bindings of the person's own are prepared for, not built yet.
- A numeric prefix, as in Emacs, repeats a command: ALT-1 ALT-0 ↓ moves ten rows down. CTRL + digit cannot be used: terminals send nothing for most of those keys, and CTRL-3 sends ESC itself. In Agenda ALT-0 to ALT-9 typed DOS character codes (Working with Macros, p. 1-14), not commands, so taking them is no clash.
- The count applies in views first, and only to commands chosen with care. A repeat that changes nothing stops at once (100 ↓ at the end of the list does not try a hundred times).

## Decision

- **A command is data.** `Agendum.TUI.Command`: an id (an atom, stable, what keymaps and later the preferences name), a name and a one-line summary to show, and whether it takes a count. `Agendum.TUI.Commands` lists them. The code that runs a view command is `ViewKeys.run`.
- **A keymap per place** (`Agendum.TUI.Keymap`) maps a key event to a command id. The view is the first place; others follow a few at a time. Typing a character (a new item, a column entry) is not in the keymap: it is what an unbound printable key does, as Emacs's self-insert. A command whose work depends on where the highlight is (F3, F5, DEL …) is one command that decides for itself.
- **The selection is found, not passed.** A command acts on what is marked (items with F7, text in a note) by reading the state, as Emacs commands read the region; it is not a parameter of every command. A core command (ADR 0020) will carry the ids it acts on explicitly; the TUI fills them in from the marks.
- **The count.** In a view, ALT-digits build a count, shown in the control panel; the next key runs its command with it. A command that takes a count either uses it directly (↓ moves n rows: one build of the view, not n) or is run again up to n times, stopping as soon as a run changes nothing or reports an error. A command that takes no count runs once. ESC drops the count. Counts are capped (999).
- **Order of lookup** (prepared): the person's bindings, then keys a file's macros are attached to (R50), then the built-in keymap. Only the last two exist; ESC, F1 and the help screen's `c` and `d` will not be rebindable.

- **F1 is help about where you are** (owner, 2026-10-15): a text per place (`about/0` in the place's module) and per box (`Box.about/2`, or one made from the box's title and settings' help); `c`, `d` and `a` (all keys, generated from the keymaps) from there. The hand-written key list is gone.

- **What cannot run now is greyed, not hidden** (owner, 2026-10-16; R65a). F1 `c` keeps every command of the place in its place and greys the ones that cannot run now, with the reason on the highlighted one; hiding them would make commands come and go, putting them last would move them. Each place has an explicit `unavailable/1` beside its `run`, rather than trying every command on the state: many commands open a box or ask first, and only fail later, so a trial run would call them available. A test runs each command said not to run and checks that nothing changed, so the checks cannot claim more than is true.

## Consequences

- The keymap is data that tests can check: every bound command exists, every view command is bound or reachable from the menu, and the F1 help can be checked against it.
- `ViewKeys.view_key/2` becomes a lookup; its per-key logic moves into clauses of `run`, one per command.
- ALT-digits are taken in views; on a Mac they need Option as Meta, like the ALT-letters. In boxes and notes they do nothing yet.
- The global keys (CTRL-Z, CTRL-S …) and the keys that stand for others (CTRL-N = INS) are in `Agendum.TUI.Keymap` too, and so are the category and view managers and the note (2026-10-15). An alias can be limited to a place (⌥↑ is CTRL-PGUP in a view only; CTRL-E is F2 except in a note, where it edits). The keys every box shares (F1, F3, ESC) have a keymap (`:box`). Every box declares its own keymap and commands (`keymap/1`, `commands/1` by the box's mode, `run/3` of `Agendum.TUI.Boxes.Box`; a settings box starts from `Box.settings_keymap/1`, a list box uses `Box.list_moves/0`); keys not in it, and every key while the person types in one of its fields (`typing?/2`), go to its `handle/3`. The menu has a keymap too (2026-10-15); its entries are chosen by their first letters, which the help lists as their keys. So do the modes that move something (items, a column, a section, a width, Browse) and searching the view. Typing has keymaps too: `:line` for one line (an item, a name, a field, a prompt; `Typing.LineEdit`) and `:text` for a note (`Typing.TextEdit`); a character is typed. What still reads keys directly: the help screen itself, the splash screen and the developer screen.
