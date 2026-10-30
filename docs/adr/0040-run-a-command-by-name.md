# ADR 0040 — The terminal program runs a command by name (CTRL-X)

**Status:** accepted · 2026-10-16 (meeting 2026-10-16-2323, § 7). Amends ADR 0038.

## Context

ADR 0038 keeps Agenda's keys in the terminal program and puts the command palette, with modern and own keys, in the web version. The owner wants to run a command by its name in the terminal too, with fuzzy matching. F1 then `c` already lists the commands of the place, narrowed by an exact substring of what is typed, and ENTER runs one (`Agendum.TUI.HelpScreen`). Agenda used no CTRL-letter keys; CTRL-X is free in Agendum and works on a Mac.

## Decision

- **CTRL-X opens a small box of its own**, shaped like Agenda's choice lists (not the help screen, which is for reading): an input line, the best matches with their keys, the highlighted command's summary at the bottom. Only commands that can run in the place are shown; ENTER runs, ESC closes.
- **Matching is fuzzy** (initials and letters in order; best match first, recently used first), one pure function over the command data (`Agendum.TUI.Commands`), which F1 `c`'s narrowing uses too, and which the web's palette is to reuse.
- This adds a key and rebinds none: ADR 0038 stands for Agenda's keys. The web keeps its command palette, built on the same commands and matcher.

## Consequences

- One habit change: F1 `c` narrows fuzzily, so it may show more matches, in another order.
- A command that has no key can still be reached in the terminal, the way an agent reaches it by name (ADR 0036).
- The box gets its keymap, F1 text, an entry in `docs/SCREENS.md`, `docs/KEYBOARD.md`, and is listed in `docs/plans/AGENDA_PARITY.md` as an enhancement.
