# ADR 0022 — Themes, not custom colours

**Status:** accepted · 2026-10-12

## Context

Agenda 2.0's Utilities Customize had Color: Mono, Color, Plasma, or
Custom, with a Custom Colors box that set a colour for each of about 25
screen elements (view background, item text, column entries, section
heads, box borders and titles, highlight, menu, key map, help…), plus drop
shadows, box animation and wide borders (Setting Up Agenda 1-28 to 1-31).
It was on our roadmap under More preferences.

We have three themes instead (R40): `classic` (Agenda 2.0's colours, from
screenshots, ADR 0018), `blue` and `mono`. Each theme defines every style
the screen uses, and a test checks that. Agenda's Custom Colors existed
partly because DOS screens differed so much (MDA, CGA, EGA, plasma); a
terminal today has its own colour settings, and its own themes.

## Decision

- We keep to themes. There is no Custom Colors box and no per-element
  colours in the preferences.
- A new look is a new theme in `Agenda.TUI.Theme`, defining every style,
  so it is designed and tested as a whole.
- Drop shadows, box animation and wide borders are not settings: boxes
  have shadows in the themes that draw them, and do not animate.

## Consequences

- The Customize box stays short, and the preferences file stays simple.
- A combination of colours that makes text unreadable cannot happen by
  accident; each theme is checked as a whole.
- Someone wanting other colours chooses another theme, adds one to the
  code, or changes their terminal's palette (the `classic` theme uses the
  terminal's 16 colours unless the terminal shows 24-bit colour).
- R40 and the roadmap say custom colours are not planned, pointing here.
