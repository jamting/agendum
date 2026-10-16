# ADR 0007 — Keyboard: Agenda's keys first, with alternatives that always work

**Status:** accepted · 2026-10-10 (recording decisions made on 2026-10-08–10); the F-key aliases (ESC + digit, ESC + shifted digit) superseded by ADR 0032

## Context

Agenda was driven by function keys, ALT combinations, INS, DEL, HOME and END on a PC keyboard. Modern terminals pass some of these unreliably, Mac keyboards lack INS, HOME and END, terminals never pass ⌘ to programs, and the macOS Option key types special characters instead of acting as ALT. Early on we also gave ALT-F5 a meaning of our own (the Sort box) that Agenda had given to GO TO, which we only found out from the Help file's key charts.

## Decision

- Keys follow Agenda's charts ("Agenda Key and Menu Charts" in `docs/reference/Agenda 2.0 Help File.html`). A key of our own must not take a key Agenda used for something else (R42).
- Every command also has a key that works everywhere:
  - ~~every F-key works as ESC followed by its digit, and every ALT-F-key as ESC followed by the shifted digit;~~ (dropped, ADR 0032)
  - every ALT-letter works as ESC followed by the letter;
  - commands that need INS, HOME, END or F-keys get a CTRL alternative (CTRL-N for INS, CTRL-E for F2, …), which terminals can map ⌘ shortcuts onto;
  - macOS Option characters that stand for ALT keys are decoded as such, except letters used in Swedish and other languages (å, ä, ö …), which stay text.
- `Terminal` turns off `ixon`, `isig` and `iexten` so CTRL keys reach the program (ADR 0002).
- Menu commands are chosen by first letter, so each menu level needs unique first letters (`menu_test.exs` checks this); Agenda's command names are preferred.
- New keys are documented in `docs/KEYBOARD.md` and the F1 help.

## Consequences

- Agenda users find their keys where they expect them; Mac users always have a way in.
- Before giving a key a meaning, check the Help file's charts.
- CTRL-I, CTRL-M, CTRL-H and CTRL-[ cannot be used (they are TAB, ENTER, BACKSPACE and ESC).
