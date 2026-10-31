# ADR 0043 — A truthful clone: what may differ from Agenda, and extras hidden behind one switch

**Status:** accepted · 2026-10-21 (meeting 2026-10-21-2324, § 6 and § 7). Amends ADR 0006.

## Context

ADR 0006 made Agendum faithful to Agenda 2.0 "with marked extensions", accepted one by one. The two lists in `docs/plans/AGENDA_PARITY.md` grew to 20 accepted enhancements and 11 accepted modifications with no common test, so undo sits beside the micro-blog, the feeds and the Zettel ids. The owner decided (meeting 2026-10-21-2324, § 5) to make a truthful clone of Lotus Agenda first: alike in function, look and feel, with the same keys made to work on modern computers, and only a few modernisations. Those who love Agenda would notice a faithful clone, and might be put off by a mixed one. The owner uses some of the extras daily (the blog, the feeds), and their data is in the owner's files.

## Decision

**The test.** A difference from Agenda 2.0 stays in the clone only for one of three reasons:

1. **The machine.** A modern computer forces it: Mac keyboards without INS, HOME or END, what terminals send, no PC speaker, today's files and characters.
2. **The person's work.** It protects the person's work: undo and redo, asking before changes are lost, the guard against a file changed on disk.
3. **Quiet.** An Agenda user who never asks for it never meets it: it changes nothing on Agenda's screens, takes no Agenda key and adds no entry to Agenda's own menus.

Anything else is hidden in the clone (below), or changed back to Agenda's way.

**Hide, do not remove.** A feature that fails the test is an *extra*. Its commands carry that as a property of the command (ADR 0033); one preference, **Extras**, off by default, hides every extra from the menus, the keymaps, F1 and CTRL-X, in one place rather than in checks spread through `Agendum.TUI.Update`. The code stays, and so do the stored fields (`next_zettel`, `feeds`, `blog`): a file saved with Extras off keeps them unchanged, so no format version or migration is needed. The switch is a preference, not a file setting (ADR 0008): it is how a person wants the program, not part of their data.

## Consequences

- Each entry on AGENDA_PARITY.md's two lists gets a tag, *machine*, *work* or *quiet*, or is marked to be hidden (an extra) or changed back. The owner confirms each tag before anything is built; each change back that alters a habit (the date format's ISO default, the always-shown mode word, entries added to Agenda's menus, the view manager's ► and F5) is a roadmap item of its own, settled with the owner first.
- The owner turns Extras on once to keep the blog, the feeds and the Zettel commands.
- The round-trip tests check that a file saved with Extras off keeps the extras' fields.
- The accepted differences have one home, the tags, which the comparison with Agenda's captured menus reads (meeting 2026-10-21-2324, § 8).
- `--clinic` passes as quiet (it is reached only by a command-line flag).
- Where the extras' code lives is ADR 0044.

## Amendment: the switch as built (2026-10-23)

Settled with the owner before it was built (R77, v0.18.0): the switch is a row of its own, **Extras**, in File ▸ Customize, beside Sound. With it off, the file's data show as they are (a Zettel id column still shows its ids; only the commands are hidden); feeds and calendars are not read on schedule, so nothing reaches the network unasked; and alarms that came due while the file was closed ring as Agenda's do, without the "While you were away" box, although Utilities ▸ Show Alarm is not built yet. The commands carry the tag (`extra` on `Agendum.TUI.Command`), the menu's extras entries are named by their actions, and one gate in `Agendum.TUI.Update` leaves an extra's key unbound.

## Amendment: an Extra, or Beyond Agenda (2026-10-31)

The owner, 2026-10-31, settling where new work beyond the clone goes:

- **An extra** adds to Agenda's way and can be switched off without leaving a hole: with the switch off, the clone's screens, menus and keys are Agenda's (the note preview column on the right is the example).
- **Beyond Agenda** is a change to how the program works at its heart, which cannot be a switch (doing what the person means, fewer commands, commands that depend on the context).
- **The switch stays** one quiet setting in Utilities ▸ Customize, and nothing of the extras shows while it is off; a test that renders every menu, key bar, F1 topic and box with it off checks this (`docs/ROADMAP.md`, The extras).
- **The extras get a menu of their own**, F10 E, there only while they are on, so the clone's menus stay Agenda's either way (`docs/ROADMAP.md`, The extras).
- **A starter file** is content of the clone, made of its features; one that needs features outside the clone may be an extra.
