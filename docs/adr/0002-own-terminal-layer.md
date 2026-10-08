# ADR 0002 — Our own terminal layer instead of a TUI library

**Status:** accepted · 2026-10-08

## Context
Elixir TUI libraries are few. Ratatouille/ex_termbox depend on native code
and are unmaintained, and newer ones are young. Agenda's screen is simple:
full-width text lines with colours, no widgets that need layout engines.
OTP 28 added a built-in raw terminal mode:
`:shell.start_interactive({:noshell, :raw})`.

## Decision
Use OTP raw mode plus ANSI escape sequences, with no dependencies.
Rendering produces a list of styled lines, and `Screen.frame/2` diffs frames
so only changed lines are rewritten.

## Consequences
- Requires OTP ≥ 28. The project uses Elixir 1.20 / OTP 29.
- We decode keys ourselves (`TUI.Keys`) and must handle terminal
  differences. ESC+digit aliases for function keys cover the hard cases.
- Raw mode leaves `ixon`, `isig` and `iexten` on, so `Terminal` disables
  them with `stty` on the tty device. That way CTRL-S/Q/C/Z/O/V arrive as
  keys, which the CTRL alternatives for Mac keyboards depend on.
- Wide (CJK/emoji) characters are counted as width 1; acceptable for now.
