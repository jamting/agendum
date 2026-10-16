# ADR 0018 — The look follows screenshots of the real Agenda

**Status:** accepted · 2026-10-11

## Context

The TUI was first drawn from the manuals alone, which describe what is on the screen but hardly how it looks. The result, white on blue with thin line-drawn boxes, worked but did not feel like Agenda. The owner runs Agenda 2.0 in DOSBox Staging and took screenshots of the main screens (the view, menus, boxes, the category manager, help, notes, questions). They are kept locally in `docs/reference/screens/` and not in git: they are Lotus's screens. What we learn from them is written into the SPEC (R40) and the code.

## Decision

- The default theme (`classic`) imitates Agenda 2.0 on a colour VGA screen, as seen in the screenshots: black text on grey, blue section heads, column heads and entries, white-on-red highlights, a blue title bar and control panel, cyan boxes in a solid blue frame with the title centred and a black shadow, the screen behind a box greyed out, a cyan category manager and yellow-on-blue help. The earlier look stays as the `blue` theme.
- Exact colours where the terminal allows: a theme style is a pair of the 16 VGA colours, sent as 24-bit colour when `COLORTERM` says the terminal takes it, and as the nearest of the 16 ANSI colours otherwise.
- The aim is the general look and feel, not pixel fidelity. Where the original's way does not suit a terminal or the owner prefers otherwise, we differ on purpose and say so in the SPEC: the highlighted line is tinted across the screen instead of Agenda's » pointer.
- Screens are compared side by side: `tools/screenshots/` draws our TUI's screens as PNGs on the same 9×16 cell grid as a VGA text screen (720×400 for 80×25).
- The key bar stays one line, with fuller labels than Agenda's 8-character slots, since today's terminals are wider than 80 columns (owner's choice).
- The two top lines are Agenda's control panel: the file, indicators and time, then the view (or the manager shown); the menu, prompts, questions and messages take them over.
- Boxes opened from boxes are offset (one line down, two columns right) and the titles of the boxes beneath are dimmed, so the active one is clear (our choice; Agenda drew them over each other).
- When a box does not fit the screen, follow Agenda's own nesting before inventing scrolling: File Properties holds "Global date settings ..." and "Auto-assign settings ...", and Global Date Settings holds "Display format ..." and "Input format ...", as in Agenda 2.0.
- Every theme has the same parts (control panel, highlighted line, box titles and dimmed titles, faded background) in its own colours; a test checks that none of them is lost in a theme.
- The rest of the look (symbols, box layouts, editing lines, the ALT key bar, startup, hypertext help) follows in small steps listed in the roadmap ("Look and feel").

## Consequences

- People who liked the blue look choose `blue` in File ▸ Customize.
- Styles are symbolic, so the boxes and screens did not change shape: the frame is drawn with line characters in the same colour as its background, which shows as a solid band in `classic` and as lines in `blue` and `mono`.
- On terminals with only 16 colours, the shades depend on the terminal's palette; the tint of the highlighted line becomes bright white there.
