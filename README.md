# Wol's Agendum

**Wol's Agendum** (Agendum for short) is a clone of **Lotus Agenda**, the 1988
DOS personal information manager, written in Elixir with a terminal UI that
looks and feels like the original. Wol is how Owl spells his name in A. A.
Milne's books about the Hundred Acre Wood, and the program's manual is Owl
teaching Rabbit to use it; an *agendum* is one thing to be done.

New to Lotus Agenda? [`docs/AGENDA_HISTORY.md`](docs/AGENDA_HISTORY.md) explains
why people loved the original and what made it unique.

You type free-form items. Agendum files them into categories: the one you
typed them under, and any whose names appear in the text. Views show the
same items arranged in different ways, and you change the data directly
in the views.

```
 File: ~/work.agendum                                   READY  2026-10-08 09:00
 View: Activities
 Calls                                               When       Priority Contact
 • Set up meeting at Terracotta Corp to discuss                 Medium
   CopyCat before the end of the month.
 • Don't forget to call Anna Lasky with the info…               High     Anna Lasky
 • Check with Abigail Scheer on meeting times.                  Medium   Abigail Scheer
 F1 Help F2 Edit F3 Choices F4 Done F5 Note F6 Props F7 Mark F8 VwMgr F9 CatMgr F10 Menu
```

## Running

Requires Elixir ≥ 1.20 on OTP ≥ 28 (for the built-in raw terminal mode).

```sh
mix deps.get
mix run -e 'Agenda.CLI.main(["--demo"])'       # sample data from the Agenda patent
mix escript.build && ./agendum ~/work.agendum   # standalone binary
./agendum --mono ~/work.agendum                 # monochrome (also: --theme mono, or NO_COLOR=1); --theme blue: white on blue
./agendum --lang=swedish --fallback=english f   # read dates typed in Swedish (and English)
./agendum --number-order=dmy --date-separator=. f  # type dates as 12.11.26 for this session
# File ▸ Customize saves your theme, date languages and input format in ~/.config/agendum/preferences
```

## Quick tour

The full user guide, with a worked example, is [`docs/guide/index.html`](docs/guide/index.html)
(open it in a browser).


- **Type** under a section to add an item. It is assigned to that section's
  category, and automatically to any category it mentions.
- Dates in the text count: "Call Bob next Friday" gets a When date. **ALT-F2**
  (or Item ▸ When) sets one explicitly.
- **→ / TAB** moves into columns. Type a name to assign (new names create
  subcategories) or a date (`tomorrow`, `friday`, `2026-12-24`) in the When column.
- **F9** opens the category manager: type to add, F7/F8 promote/demote, F6
  properties (mutually exclusive children, short names, category links).
- **ALT-D / ALT-R** add sections and columns. **F8** manages views.
  **F10** or **/** opens the menu.
- **CTRL-Z / CTRL-Y** undo and redo. **CTRL-S** saves, **CTRL-Q** quits.
- On a Mac: **CTRL-N** replaces INS (new item/category), **CTRL-E** = F2 edit,
  and **ESC then a digit** replaces a function key (ESC 9 = F9, ESC 0 = F10).
  To use ⌘N, ⌘Z, ⌘S and so on, map them in your terminal; see
  [`docs/KEYBOARD.md`](docs/KEYBOARD.md).
- **F1** lists every key.

## Development

The code is a pure functional core with an imperative shell. See
[`CLAUDE.md`](CLAUDE.md) for conventions, [`docs/SPEC.md`](docs/SPEC.md) for
behaviour, [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for structure,
[`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) and
[`docs/DATA_ACCESS.md`](docs/DATA_ACCESS.md) for the data layer, and
[`docs/ROADMAP.md`](docs/ROADMAP.md) for what's next.

```sh
mix check   # format + warnings-as-errors + tests
```
