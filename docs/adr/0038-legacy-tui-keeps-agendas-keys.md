# ADR 0038 — The terminal program keeps Agenda's keys; modern and own keys belong to the web

**Status:** accepted · 2026-10-16 · amended by ADR 0040 (run a command by name in the terminal)

## Context

The roadmap had customizable key bindings for the terminal program: the person's own bindings, kept in the preferences, set in File ▸ Customize ▸ Keys (`docs/plans/MULTIUSER.md` §6, ADR 0033 prepared the lookup order for it). A web version is planned with a modern interface (ADR 0020), for people who never used Agenda (`docs/VISION.md`), and the core's commands (R66, ADR 0036) serve both.

## Decision

The owner, 2026-10-16:

- **The terminal program is the legacy interface.** It keeps Agenda's keys as they are (ADR 0007), faithful to the original, without bindings of the person's own.
- **Modern keys and customization belong to the web's modern interface**, with the command palette, built on the same commands and the same command descriptions.

## Consequences

- The roadmap item for own key bindings moves from the terminal program to the web work. ADR 0033's lookup order (the person's bindings first) stays prepared but unused in the terminal.
- New keys in the terminal program still follow KEYBOARD.md's rules and Agenda's keys; a key Agenda did not have is chosen with care, as before.
