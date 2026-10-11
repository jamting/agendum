# ADR 0008 — What belongs in the file, and what belongs to the person

**Status:** accepted · 2026-10-10 · the path is now `…/agendum/preferences` (ADR 0019)

## Context

Several settings could live either in the Agenda file or with the person
running the program: colours, the date display format, the language dates
are typed in, the decimal separator. Agenda 2.0 split them: File Properties
(global date settings, conditions, trash) were saved in the file, while
Utilities Customize (colours, key map, confirm mode, decimal and thousands
separators, auto-save) applied to all of a person's files. A file may be
shared between people with different habits.

## Decision

- **In the file**: settings about the information itself, which everyone
  opening the file should see the same way. These are the date display
  format (File Properties, R41), automatic dating, view, section and column
  settings (including number formats, R29), filters and sorting.
- **With the person, never in the file**: settings about how one person
  sees and types. These are the colour theme (R40), the date languages
  (R14c) and, when they come, the other Utilities Customize preferences
  (key map, confirm mode, separators, auto-save).
- Personal settings are given on the command line for now (`--theme`,
  `--mono`, `--lang`, `--fallback`, and NO_COLOR). A preferences file in the
  user's home directory and a Utilities Customize box are planned. They
  will be read by the shell and passed in, never read by the core.
- The core receives personal settings as arguments: `Core.Context` for the
  time and date languages (ADR 0009), and options such as the separators.

**Amended 2026-10-11 (R41b):** the preferences file now exists,
`Agenda.Preferences`: plain `key = value` lines in
`$XDG_CONFIG_HOME/agenda/preferences` (or `~/.config/agenda/preferences`),
read by the CLI at start and written through an App effect when the
person changes a setting. It holds the theme, the date languages and the
Input format (number order, input date separator, input clock, which
Agenda kept in the file); File ▸ Customize sets them, and command-line
flags override them for one session. Only a setting the person changes
is saved, so a flag never ends up in the file. A preferred theme
overrides NO_COLOR, as no-color.org asks of user configuration.

## Consequences

- Opening someone else's file never changes how your screen looks or how
  your typing is read.
- A date filter saved with relative words in one language ("fredag") is read
  with the languages of whoever opens the file. A fallback language covers
  the common mixed case.
- New settings must be placed in one of the two groups, using the rule above.
