---
name: feature
description: Build one feature or fix of Agendum the agreed way, as a checklist done in the same order every time - the habit changes settled with the owner first, how Agenda did it checked (evidence table), the SPEC rule, a failing test, the core then the TUI, the documents the change touches, mix check and the long fuzz run, a smoke test in the real terminal, the commit, a version when due, and the owner trying a habit change before the next is built on it. Use when the owner asks to build a roadmap item, a feature, a behaviour change or a bug fix in the program, says "next", or types /feature. Not for documents only (tidy-docs), meetings, reviews or the guide and manual.
---

# Build a feature

The steps for building a feature, fix or behaviour change in Agendum, in order (meeting 2026-10-22-2337, § 5). CLAUDE.md keeps the architecture rules and conventions; this is the order of work. A step that does not apply is skipped on purpose, not forgotten: say which in the summary. One feature per commit; small and focused.

Several features in one sitting ("do these in a row"): ask every question for all of them first, in one round, then build them one after another, each through the whole list, so the owner can rest while it is built.

## 1. Habits first

Before any code, list for the owner every key or behaviour the item would change for someone already using Agendum: what ENTER or ESC does, which key changes a value, what a screen shows. Settle them first, in one round of questions (`AskUserQuestion`, with an ASCII picture of the screen as a preview where it helps). A habit change found halfway costs the most: it spreads through the tests. Settled choices that came from a meeting or a plan are not asked again.

## 2. How Agenda did it

Agendum is a truthful clone first (ADR 0043): for anything Agenda had, find how it behaved before deciding how ours does.

- The manuals' text (`docs/reference/*_djvu.txt`), the F1 help (`docs/reference/Agenda 2.0 Help File.html`), the Lotus Q&A (`docs/reference/ag2qanda.txt.html`), the patent.
- Agenda itself, headless (`tools/agformat/agenda_driver.py`, on a copy of the install; `tools/agformat/DRIVING_AGENDA.md`); and what it stores (`agdump.py`, `agdiff.py`, `docs/AGENDA_FILE_FORMAT.md`) for stored versus computed.
- Report it as an evidence table: question, Agenda's answer, source. Ask the owner only for what text cannot show (colours, pixels).
- Where we differ on purpose, `docs/plans/AGENDA_PARITY.md` lists it, tagged by ADR 0043's test.

## 3. The rule

Find or add the behaviour in `docs/SPEC.md` (rules are numbered, e.g. `R7`); where we differ from Agenda on purpose, the rule says "Our choice". A new rule gets a line in the rule index at the top (a test checks).

## 4. A failing test

- Core rules → `test/agendum/core/*_test.exs` (use `Agendum.Fixtures`).
- UI behaviour → `test/agendum/tui/*_test.exs`: drive keys with `Agendum.TUIHelpers.press/2` and assert on `screen/1` text.
- In a box, reach a setting by its label, not by counting ↓ presses: `Agendum.TUIHelpers.to_setting(state, "Also match")`; layouts and keys change, labels rarely do.
- **Four questions** (the code reviews of 2026-10-26: almost all 30 findings were one of these). For each "yes", a test of that case too:
  1. Does it read **input from outside** (a feed, a calendar, an `.AG` or JSON file, Markdown, a typed address)? Then a broken, hostile and huge one, which must give an error, never a crash or a hang; add the file to the hostile collection.
  2. Does it **wait on the network or run in the background**? Then a result that never comes, or comes late, and the program going on meanwhile.
  3. Can the text have an **odd encoding** (Latin-1, control characters, invalid UTF-8)?
  4. Can things happen **in another order** (a result after another file was opened, two at once, a key in between)?

Run it and see it fail for the right reason before writing the code.

## 5. Core first, then the TUI

- The logic of a user action goes in the core, behind the facade (`Agendum.Core`, an area module under `lib/agendum/core/facade/`): a web front end will need it too (CLAUDE.md, architecture rules 3 and 6). The TUI only handles keys and drawing.
- A new side effect is a new effect tuple handled in `App`; `Update` and `Render` stay pure.
- Keys are bound in keymaps (`Agendum.TUI.Keymap`, a box's `keymap/1`) with a command (`Agendum.TUI.Commands`, a box's `commands/1`); F1 then `a` and `c` are made from them. A new place or box gets its F1 text (`about/0`, a box's `about/2`; `test/agendum/tui/help_coverage_test.exs` checks).
- A box whose behaviour changes is drawn from a `Agendum.TUI.Boxes.Template` layout in the same change, laid out as Agenda's box is.
- A stored field: `docs/DATA_MODEL.md` (and a format version row), `docs/JSON_FORMAT.md` and `Agendum.Core.JSONFile`, a value in `Agendum.Starters.Golden`, and with a new format version `mix agendum.golden` (commit both files it writes).
- New or changed Elixir gets learning comments where an idiom or the domain is not obvious: the owner is learning Elixir from this code.

## 6. The documents the change touches

Tick each that applies; the ones marked *test* fail `mix check` when forgotten.

- [ ] `docs/ROADMAP.md` (since the clone was declared done, 2026-10-26, parity leftovers live there too; a new difference from Agenda goes on `docs/plans/AGENDA_PARITY.md`'s two lists, tagged by ADR 0043's test): the item ticked and moved to `docs/ROADMAP_DONE.md`, under its milestone or area; the **In order** list at the top of the roadmap kept true
- [ ] `docs/SPEC.md`: the rule, and its line in the rule index (*test*)
- [ ] `docs/SCREENS.md`: a new box or screen (*test*)
- [ ] `docs/KEYBOARD.md`: every named key in a keymap (*test*), and a line for what a new key does
- [ ] F1 texts: a new place or box (*test*); a command's longer text where the summary is not enough (`Agendum.TUI.CommandDocs`)
- [ ] `docs/ARCHITECTURE.md`: a row for a new module
- [ ] `docs/DATA_MODEL.md`, `docs/DATA_ACCESS.md`, `docs/JSON_FORMAT.md`: stored data or queries changed
- [ ] `docs/plans/AGENDA_PARITY.md`: a difference from Agenda added or closed
- [ ] An ADR for a lasting decision, listed in `docs/ARCHITECTURE.md`
- [ ] `docs/INDEX.md`, "Where a change is written down", for anything else

Not the user guide (`docs/guide/index.html`) or the manual (`docs/manual/`): the owner asks for them from time to time (`update-guide`, `update-manual`).

## 7. The gate

- `mix check` until it passes, with no warnings; fix what Credo and Dialyzer report rather than silencing it. A gate fixed after one failing run may be flaky: run it again.
- A change of more than about 300 lines, or one that touches outside input: a local review of the diff (`/code-review high`) in the background while the documents are written, its findings fixed before the commit (it found the ingested families' bugs within minutes, after they were committed, 2026-10-26).
- After a large TUI change, or for a release: the long fuzz run, in the background while the documents are written: `mix agendum.fuzz` (its output kept in `tmp/fuzz/`). Never beside `mix check` or another compile: both use `_build/test`, and a recompile under a running fuzz fails it with modules "not available" (2026-10-23).
- A box or screen with an Agenda screenshot: draw ours as a PNG (`tools/screenshots/`) and compare it side by side, for spacing the text tests cannot see.
- Keys, ESC or drawing changed: smoke-test the real terminal with `tools/smoke/smoke.py` (sandboxed; it waits for the splash screen to go and for each key's effect to settle) and say in the summary what was seen.

## 8. Commit, and a version when due

- Commit on your own once the gate passes, with explicit paths (never `git add docs` or `.`: the owner keeps untracked files in `docs/reference/`). The first line says what changed for the person using Agendum, with the rule number.
- A major feature or a change to the file format bumps the minor version in `mix.exs` (never 1.0.0 unless the owner says), a fix the patch number; an entry in `CHANGELOG.md`; the `vX.Y.Z` tag once the long fuzz run passes on that commit, unless the owner wants to try it first.

## 9. The owner tries it

When the change alters a habit, the owner tries it before the next change is built on it. The summary lists what they will notice and where to look. A change that works but feels weak is approved with a polish item of its own on the roadmap.
