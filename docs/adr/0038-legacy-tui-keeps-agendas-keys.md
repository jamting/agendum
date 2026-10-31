# ADR 0038 — The terminal program keeps Agenda's keys; modern and own keys belong to the web

**Status:** accepted · 2026-10-16 · amended by ADR 0040 (run a command by name in the terminal) · amended 2026-10-31: modern keys and command names in the terminal, as an extra

## Context

The roadmap had customizable key bindings for the terminal program: the person's own bindings, kept in the preferences, set in File ▸ Customize ▸ Keys (ADR 0033 prepared the lookup order for it). A web version is planned with a modern interface (ADR 0020), for people who never used Agenda (`docs/VISION.md`), and the core's commands (R66, ADR 0036) serve both.

## Decision

The owner, 2026-10-16:

- **The terminal program is the legacy interface.** It keeps Agenda's keys as they are (ADR 0007), faithful to the original, without bindings of the person's own.
- **Modern keys and customization belong to the web's modern interface**, with the command palette, built on the same commands and the same command descriptions.

## Consequences

- The roadmap item for own key bindings moves from the terminal program to the web work. ADR 0033's lookup order (the person's bindings first) stays prepared but unused in the terminal.
- New keys in the terminal program still follow KEYBOARD.md's rules and Agenda's keys; a key Agenda did not have is chosen with care, as before.
- **Later, a modern key set in the terminal too** (meeting 2026-10-22-2130, § 6): not a second program but a setting in the same one, File ▸ Customize ▸ Keys: Agenda (the default, the clone) or Modern, swapping the keymaps (ADR 0033); same screens, same file. It waits until the truthful clone is declared done, as an extra behind the Extras switch (ADR 0043), and this ADR is amended when it is built. The person's own bindings stay with the web.

## Amendment: modern keys in the terminal, as an extra (2026-10-31)

The owner, 2026-10-31: the modern key set is an extra of the terminal program, and with it today's command names (Open not Retrieve, Delete not Discard, CTRL-O/S/Z/F/N …). ADR 0050 already lists a modern terminal program as public.

- **A setting, not a second program:** Utilities ▸ Customize ▸ Keys, Agenda (the default) or Modern, behind the Extras switch (ADR 0043); same screens, same file.
- **A second keymap and the menu's names**, made as the key bars are (ADR 0045) and kept apart from Agenda's; the function keys stay required (ADR 0032).
- **The fuzz walks run under both keymaps**, so the second does not rot.
- **The person's own bindings** stay with the web, as decided above.

It is on the roadmap (The extras, second in their order).
