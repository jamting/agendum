# Wol's Agendum

**Wol's Agendum** (Agendum for short) is a clone of **Lotus Agenda**, the 1988 DOS personal information manager, written in Elixir with a terminal UI that looks and feels like the original. Wol is how Owl spells his name in A. A. Milne's books about the Hundred Acre Wood, and the program's manual is Owl teaching Rabbit to use it; an *agendum* is one thing to be done.

New to Lotus Agenda? [`docs/AGENDA_HISTORY.md`](docs/AGENDA_HISTORY.md) explains why people loved the original and what made it unique; where Agendum is going is in [`docs/VISION.md`](docs/VISION.md).

You type free-form items. Agendum files them into categories: the one you typed them under, and any whose names appear in the text. Views show the same items arranged in different ways, and you change the data directly in the views.

```
 File: ~/work.agendum                                          2026-10-08 09:00
 View: Activities
 Calls                                               When       Priority Contact
 • Set up meeting at Terracotta Corp to discuss                 Medium
   CopyCat before the end of the month.
 • Don't forget to call Anna Lasky with the info…               High     Anna Lasky
 • Check with Abigail Scheer on meeting times.                  Medium   Abigail Scheer
  F1   │  F2   │  F3   │  F4   │  F5   │  F6   │  F7   │  F8   │  F9   │  F10
 Help  │ Edit  │Choices│ Done  │ Note  │ Props │ Mark  │Vw Mgr │Cat Mgr│ Menu
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
# Utilities ▸ Customize saves your theme, date languages and input format in ~/.config/agendum/preferences
```

To start from Agenda's Activities Planner (tasks, people, projects, priorities, expenses, sixteen views and a few macros, no items), copy the starter file and open the copy:

```sh
cp starters/planner.agendum ~/planner.agendum && ./agendum ~/planner.agendum
```

## Quick tour

The [user guide](docs/guide/index.html) is the short version, with a worked example; the [manual](docs/manual/index.html) is the long one, as Owl explains it to Rabbit. Open them in a browser; `mix docs` also puts them beside the API documentation.

- **Type** under a section to add an item. It is assigned to that section's category, and automatically to any category it mentions.
- Dates in the text count: "Call Bob next Friday" gets a When date. **ALT-F2** sets one explicitly.
- **→ / TAB** moves into columns. Type a name to assign (new names create subcategories) or a date (`tomorrow`, `friday`, `2026-12-24`) in the When column.
- **F9** opens the category manager: type to add, F7/F8 promote/demote, F6 properties (mutually exclusive children, short names, category links).
- **ALT-D / ALT-R** add sections and columns. **F8** manages views (F6 there: a view's properties, as View ▸ Properties). **F10** or **/** opens the menu.
- **CTRL-Z / CTRL-Y** undo and redo. **CTRL-S** saves, **CTRL-Q** quits.
- Function keys are required, as in Agenda: on a Mac, hold **fn** with them or make them standard function keys (System Settings ▸ Keyboard). **CTRL-N** replaces INS (new item/category), **CTRL-E** = F2 edit, and ALT is ⌥ (Option) with "Use Option as Meta key" on. To use ⌘N, ⌘Z, ⌘S and so on, map them in your terminal; see [`docs/KEYBOARD.md`](docs/KEYBOARD.md).
- **F1** is help about where you are, as Agenda's: links in bold (arrows and ENTER), **F3** the index, **F5** Find, **F8** back; **F6** Keys lists every key and leads to the commands you can run there (greyed when they cannot, with the reason) and to describing a key.

## Development

The code is a pure functional core with an imperative shell. See [`CLAUDE.md`](CLAUDE.md) for conventions, [`docs/SPEC.md`](docs/SPEC.md) for behaviour, [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for structure, [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) and [`docs/DATA_ACCESS.md`](docs/DATA_ACCESS.md) for the data layer, and [`docs/ROADMAP.md`](docs/ROADMAP.md) for what's next.

```sh
mix check   # the quality gate: format, warnings as errors, Credo, Dialyzer, tests
mix agendum.starters             # rebuild starters/planner.agendum (a test checks it is current)
mix agendum.starters --samples   # a copy full of sample data, for testing: tmp/planner-samples.agendum
```

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) takes you from a fresh machine to a first change: installing Erlang and Elixir, running the checks, finding your way in the code and the documents, and the workflow for a change. The code is in a private GitHub repository, with the checks run on every push and the long fuzz run every night; the documentation on GitHub Pages is still to come ([`docs/plans/GITHUB.md`](docs/plans/GITHUB.md)).

## Licence

*[A page here was soaked in the creek. — Rabbit]*

The blog's design and fonts, which Agendum writes into a published site, are other people's work under their own licences: [The Proportional Web](https://owickstrom.github.io/the-proportional-web/) by Oskar Wickström (MIT, `lib/agendum/core/extras/site_assets/the-proportional-web-LICENSE.md`) and the fonts Alegreya, Alegreya SC and Courier Prime (SIL Open Font License, `site_assets/OFL.txt`).
