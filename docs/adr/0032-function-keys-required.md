# ADR 0032 — Function keys are required: no ESC + digit stand-in

**Status:** accepted · 2026-10-15 (supersedes the F-key aliases of ADR 0007)

## Context

ADR 0007 made every F-key also work as ESC followed by its digit (ESC 3 =
F3, ESC 0 = F10), and every ALT-F-key as ESC followed by the shifted digit
(ESC $ = ALT-F4), for Mac keyboards and terminals where function keys are
awkward.

In practice the aliases did not work when typed. A lone ESC is only told
apart from the start of an escape sequence by a 40 ms timeout
(`@escape_timeout` in `Agendum.TUI.App`), so ESC then `3` typed by hand
arrives as ESC (nothing, or cancel) and then `3` (a new item). They only
worked from a terminal key binding, which can send the real F-key sequence
just as well. The owner, on a Mac, uses the function keys (fn, or "standard
function keys") and found the aliases did nothing.

Function keys are central to how Agenda is used: F2 edit, F3 choices, F5
note, F6 properties, F7 mark, F8 / F9 the managers, F10 the menu, and the
ALT-F commands. A web front end (ADR 0020) will have its own keys, so the
terminal aliases buy it nothing, and the commands refactor is simpler with
one way to type each F-key.

## Decision

- Function keys are required, as in Agenda. `Agendum.TUI.Terminal.Keys`
  decodes F-keys only from the terminal's own sequences (`ESC O P`,
  `ESC [15~` …), ALT-F-keys from the xterm-modified ones (`ESC [21;3~`) or
  ESC before an F-key's sequence (Option as Meta).
- ESC followed by a digit or a shifted digit is ALT and that character
  (`{:alt, "3"}`, `{:alt, "$"}`), which nothing uses.
- Kept, as accepted modifications of Agenda (`docs/plans/AGENDA_PARITY.md`):
  the CTRL keys for INS, HOME, END and common commands (CTRL-N, CTRL-E,
  CTRL-K, CTRL-D, CTRL-S/O/P/Q …), ESC followed by a letter as ALT-letter,
  and the macOS Option characters decoded as ALT keys.
- ⌘ shortcuts in `docs/KEYBOARD.md` that stood for F-keys send the real
  F-key sequences (⌘I = F6 `\x1b[17~`, ⌘/ = F1 `\x1bOP`).

## Consequences

- Commands only on an F-key (F6, ALT-F5 GO TO, ALT-F9 Copy …) have no
  alternative key; some are on the F10 menu. A new command does not need
  one either, unless it is on INS, HOME or END.
- A terminal without usable function keys cannot run Agendum fully.
- The ESC prefix planned in `docs/plans/KITTY.md` (ESC, then a key typed
  by hand) covers ALT-letters only.
