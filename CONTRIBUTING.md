# Contributing to Wol's Agendum

Thank you for helping. This guide gets you from a fresh machine to a
first change.

Agendum is not open source (see the README's Licence section). Before your
first contribution, the owner will agree with you the terms it comes under,
*[A page here was soaked in the creek. — Rabbit]*
([`docs/plans/GITHUB.md`](docs/plans/GITHUB.md), section 7). The rules for the code itself are in [`CLAUDE.md`](CLAUDE.md):
it is written for Claude, the AI assistant that has written much of the
code with the owner, and it applies to people just the same.

## 1. Set up

You need **Erlang/OTP 28 or later** (the terminal layer uses OTP 28's raw
mode, ADR 0002) and **Elixir 1.20**.

With Homebrew on a Mac:

```sh
brew install erlang elixir
elixir --version     # Elixir 1.20.x (compiled with Erlang/OTP 28 or later)
```

Or with a version manager ([mise](https://mise.jdx.dev) or asdf), which
lets you keep several versions side by side:

```sh
mise use erlang@28 elixir@1.20.4-otp-28    # mise and asdf name Elixir builds by OTP version
```

Then, in the project folder:

```sh
mix deps.get
mix check            # the quality gate: format, warnings, Credo, Dialyzer, tests
```

The first `mix check` builds Dialyzer's tables and takes a few minutes;
after that it takes about a minute. If it passes, you are set up.

## 2. Run it

```sh
mix run -e 'Agendum.CLI.main(["--demo"])'     # sample data, in your terminal
mix escript.build && ./agendum my.agendum      # the standalone program
AGENDUM_LOG=1 ./agendum my.agendum             # with a debug log of the session
```

It needs a real terminal (not an editor's output pane). F1 lists every
key. On a Mac without INS or easy function keys, CTRL-N is INS and ESC
then a digit is a function key (ESC 6 = F6); see
[`docs/KEYBOARD.md`](docs/KEYBOARD.md).

`mix docs --open` shows the API documentation, the design documents, the
user guide and the manual in your browser.

## 3. Find your way

| Where | What |
| --- | --- |
| [`docs/SPEC.md`](docs/SPEC.md) | What Agendum does, as numbered rules (R1, R2 …), each with its source in Agenda's manuals |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | How the code is laid out, module by module, and the list of decisions |
| `docs/adr/` | Why: one Architecture Decision Record per lasting decision |
| [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md), [`docs/DATA_ACCESS.md`](docs/DATA_ACCESS.md) | The data and how it is read and changed |
| [`docs/SCREENS.md`](docs/SCREENS.md) | Every screen and box of the terminal UI |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | What is done and what is next: a good place to pick something |
| [`docs/AGENDA_HISTORY.md`](docs/AGENDA_HISTORY.md) | Why people loved Lotus Agenda, and what matters most to keep |
| `docs/reference/` | Agenda's manuals as text, its help file and the Lotus support Q&A: grep them to check how the original behaved |

The code in brief:

- `lib/agendum/core/` is a **pure functional core**: no I/O, no clock, no
  processes. Everything a front end needs goes through the facade,
  `Agendum.Core`.
- `lib/agendum/tui/` is the **terminal UI**, Elm style:
  `Agendum.TUI.Update.handle(state, key)` returns the new state and effects,
  `Agendum.TUI.Render.render(state)` returns the screen. Only a few modules
  touch the outside world (the terminal, files, preferences).
- A web front end on the same core is planned
  ([`docs/plans/MULTIUSER.md`](docs/plans/MULTIUSER.md)), so the logic of a user action
  belongs in the core, not in the UI.

`test/agendum/architecture_test.exs` checks the most important of these
rules; [`CLAUDE.md`](CLAUDE.md) lists them all.

## 4. Make a change

The workflow, in short (in full in [`CLAUDE.md`](CLAUDE.md), "Workflow for
a feature"):

1. **Say what changes for the person using it.** If the change alters a
   key or a habit (what ENTER does, which key changes a value), agree on
   that first.
2. **Find the behaviour** in Agenda's manuals (`docs/reference/*_djvu.txt`)
   and add or update its rule in `docs/SPEC.md`. Where we differ from
   Agenda on purpose, the rule says "Our choice".
3. **Write a failing test**: core rules in `test/agendum/core/`, UI
   behaviour in `test/agendum/tui/` (press keys with
   `Agendum.TUIHelpers.press/2`, look at `screen/1`).
4. **Implement it**, core first, then the UI.
5. **Run `mix check`** until it passes, with no warnings. Fix what Credo
   and Dialyzer report rather than silencing them.
6. **Update the docs** the change touches: tick the roadmap item, and
   `docs/SCREENS.md`, the F1 help (`Agendum.TUI.Render.Help`) and
   `docs/KEYBOARD.md` if screens or keys changed. A lasting decision gets
   an ADR. (The user guide and the manual are updated now and then, not
   with every change.)

One feature per commit. Commit messages say what changed for the person
using Agendum, in a short first line, with the rule number when there is
one: `Category Properties in two columns, as Agenda's (screenshot 74)`.

## 5. Conventions worth knowing early

- **Names:** the program is **Wol's Agendum** (titles) or **Agendum**
  (running text); **Agenda** means the original Lotus Agenda. The code
  is `Agendum` too, `Agendum.*` modules in `lib/agendum` (ADR 0019).
- **Every key needs a Mac-friendly alternative:** a CTRL key or ESC then a
  key, documented in `docs/KEYBOARD.md` and the F1 help.
- **Dates** are read by language packs (`Agendum.Core.DateLanguage.*`);
  core functions that read dates take the clock as an argument.
- **No new runtime dependencies** unless they meet ADR 0021 (pure
  Elixir/Erlang, keeps the single-file program).
- **Undo is automatic:** one key that changes the file is one undo step;
  never record history by hand.
- **Boxes** are drawn from layouts written as they look on screen
  (`Agendum.TUI.Boxes.Template`); their keys follow Agenda's (ADRs 0030, 0031).

## 6. Questions and bugs

For a bug, say what you pressed and what happened, and attach the debug
log if you have one (`AGENDUM_LOG=1`; the logs are in
`~/.local/state/agendum/logs`). Screenshots of the original Agenda 2.0
running in DOSBox are very welcome when its behaviour is in question.
