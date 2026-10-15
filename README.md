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
mix run -e 'Agendum.CLI.main(["--demo"])'       # sample data from the Agenda patent
mix run -e 'Agendum.CLI.main(["--rabbit"])'     # Rabbit's file from the manual
mix escript.build && ./agendum ~/work.agendum   # standalone binary
mix docs --open                                 # API and design docs, guide and manual, in the browser
./agendum --mono ~/work.agendum                 # monochrome (also: --theme mono, or NO_COLOR=1)
./agendum --theme zenburn ~/work.agendum        # themes: classic (Agenda's colours, the default), mono,
                                                #   modus-operandi, modus-vivendi, alabaster, zenburn, ayu, borland
./agendum --lang=swedish --fallback=english f   # read dates typed in Swedish (and English)
./agendum --number-order=dmy --date-separator=. f  # type dates as 12.11.26 for this session
# File ▸ Customize saves your theme, date languages and input format in ~/.config/agendum/preferences
```

To start from Agenda's Activities Planner (tasks, people, projects,
priorities, expenses, sixteen views and a few macros, no items), copy the
starter file and open the copy:

```sh
cp starters/planner.agendum ~/planner.agendum && ./agendum ~/planner.agendum
```

## Quick tour

The [user guide](docs/guide/index.html) is the short version, with a worked
example; the [manual](docs/manual/index.html) is the long one, as Owl explains
it to Rabbit. Open them in a browser; `mix docs` also puts them beside the API
documentation.


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
- Function keys are required, as in Agenda: on a Mac, hold **fn** with them
  or make them standard function keys (System Settings ▸ Keyboard).
  **CTRL-N** replaces INS (new item/category), **CTRL-E** = F2 edit, and ESC
  then a letter = ALT and that letter. To use ⌘N, ⌘Z, ⌘S and so on, map them
  in your terminal; see [`docs/KEYBOARD.md`](docs/KEYBOARD.md).
- **F1** lists every key.

## Development

The code is a pure functional core with an imperative shell. See
[`CLAUDE.md`](CLAUDE.md) for conventions, [`docs/SPEC.md`](docs/SPEC.md) for
behaviour, [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for structure,
[`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) and
[`docs/DATA_ACCESS.md`](docs/DATA_ACCESS.md) for the data layer, and
[`docs/ROADMAP.md`](docs/ROADMAP.md) for what's next.

```sh
mix check   # the quality gate: format, warnings as errors, Credo, Dialyzer, tests
mix agendum.starters             # rebuild starters/planner.agendum (a test checks it is current)
mix agendum.starters --samples   # a copy full of sample data, for testing: tmp/planner-samples.agendum
```

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) takes you from a fresh machine to a
first change: installing Erlang and Elixir, running the checks, finding
your way in the code and the documents, and the workflow for a change.
The plan for putting the project on GitHub, with checks on every push and
the documentation on GitHub Pages, is in [`docs/plans/GITHUB.md`](docs/plans/GITHUB.md).

## Licence

Wol's Agendum is not open source: the code is private, and all rights are
reserved by the owner. Whether it will be made public, or offered in a
*[A page here was soaked in the creek. — Rabbit]*
section 7).
