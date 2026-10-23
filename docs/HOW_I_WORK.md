# How I work on Agendum

The owner's way of working on Wol's Agendum with Claude: the habits, the rituals and the tools set up for them, in one place, so that a smart way of working is not forgotten once it is made. The second half is about what could work better.

**Start every session with `/start-session`**, end it with `/end-session`. The first reads where the last one stopped and offers one thing to do; the second writes down what must not be lost.

**Keep this up to date:** a new skill, ritual, tool or standing rule gets a line here (`docs/INDEX.md`, "Where a change is written down"; the `end-session` skill checks it).

## At a glance

| I want to…                                     | Say or type                              | What happens                                                            |
| ---------------------------------------------- | ---------------------------------------- | ----------------------------------------------------------------------- |
| begin a session, or ask "where were we?"      | `/start-session`                         | where the last session stopped, what to try, three things to choose from |
| build the next thing                           | "next", a roadmap item, or `/feature`    | the `feature` skill: habit changes first, then test-first, step by step |
| park a thought for later                       | an item in Thoughts in my project file (Agendum) | nothing, until a meeting                                                |
| put a thought on the next meeting's agenda     | assign it to Next meeting (under Thoughts) | `/meeting` brings it up; afterwards I mark it done (F4)                 |
| discuss my parked thoughts with the panel      | `/meeting`                               | a panel meeting on my agenda; I decide; minutes and roadmap updated     |
| know how the project is doing                  | `/expert-review`                         | dated review minutes with scores and ranked recommendations             |
| understand code I did not write by hand        | `/study-plan`                            | the panel picks a part; learning comments; questions I tick off         |
| get help on a study question                   | "help with 2.3.1"                        | an explanation pointing at the code; I tick it myself ("tick 2.3.1")    |
| have code explained inside the code            | "add learning comments to lib/…"         | comments on Elixir idioms and domain logic, no code changes             |
| make the docs true and tidy again              | `/tidy-docs`                             | two commits: up to date, then streamlined                               |
| update the user guide or the manual            | `/update-guide`, `/update-manual`        | the guide (Piglet) or the manual (Owl and Rabbit) caught up             |
| several of these at once                       | "do X, Y and Z in parallel"              | one agent per job, each in its own git worktree, merged afterwards      |
| stop for the day                               | `/end-session`                           | records written, a summary with next steps, saved in `docs/summaries/`  |
| hand over a list and go to bed                 | "do these overnight"                     | Claude works until done or blocked, then versions and ends the session  |

## The loop for a feature

The full steps are the `feature` skill (`.claude/skills/feature/SKILL.md`, meeting 2026-10-22-3, § 5); in short:

1. **Habits first.** Before any code, Claude lists every key or behaviour the change would alter for someone already using Agendum. I settle them. A habit change found halfway is the most expensive kind.
2. **As Agenda did.** The behaviour is checked in the manuals (`docs/reference/*_djvu.txt`), the Lotus Q&A, the F1 help, the `.AG` file format, and by running the real Agenda 2.0 headless in DOSBox (`tools/agformat/agenda_driver.py`). Results come as an evidence table: question, Agenda's answer, source.
3. **Test first**, core first, then the TUI.
4. **The gate.** `mix check` (format, warnings, Credo, Dialyzer, tests). After a large TUI change, the long fuzz run: `FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs`. A gate fixed after one green run may be flaky: run it several times.
5. **Docs with the change:** the rule in `docs/SPEC.md`, the roadmap ticked, `KEYBOARD.md` and `SCREENS.md` when keys or screens change; the guide and the manual only when I ask.
6. **Commit without asking** once the checks pass, one feature per commit (my standing rule since 2026-10-14). I review the commits afterwards and ask to amend or revert.
7. **Version.** A major feature or a change to the file format bumps the minor version in `mix.exs`, gets a `CHANGELOG.md` entry and a `vX.Y.Z` tag once the long fuzz run passes. Never 1.0.0 unless I say so.
8. **Try it myself** before the next change builds on it, when it changes a habit.

## The skills

All in `.claude/skills/`, each started with `/name` or by asking for it in words.

| Skill               | What it is for                                                                                                                                                                                                 | Writes                                                  |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| `end-session`       | Close a session: what was done, what must not be lost (roadmap, plans, memory), a cheerful summary with learnings and next steps                                                                                | `docs/summaries/YYYY-MM-DD-HHMM.md` (not committed)     |
| `start-session`     | Open a session: reads the last summary, the roadmap's Next, the study plan and anything uncommitted; lists what to try in the program, offers three things to do, and waits for a choice | nothing                                                 |
| `expert-review`     | A dated review written as the minutes of a panel meeting in Owl's house: architecture, code, tests, docs, users, business, vision, methods, tidiness, agent readiness; scores, evidence, ranked recommendations | `docs/reviews/YYYY-MM-DD.md` (`-2`, `-3` the same day)  |
| `feature`           | Build one feature or fix the agreed way: habits first, Agenda's evidence, the rule, a failing test, core then TUI, the documents, the gate and fuzz, the commit, a version, the owner trying it (meeting 2026-10-22-3, § 5) | the code, its tests and documents; a commit |
| `meeting`           | A panel meeting on my own agenda (the thoughts under Next meeting in my project file): the experts the items call for discuss them, I decide, decisions go into the roadmap, plans and ADRs                                                          | `docs/meetings/YYYY-MM-DD/` (agenda and minutes)        |
| `study-plan`        | The panel picks the next part of the code for me to study, gives it learning comments, and writes a unit of questions and exercises; also helps with a question                                                 | `docs/study/STUDY_PLAN.md`                              |
| `learning-comments` | Comments in the code on Elixir idioms (for an experienced programmer new to Elixir) and on the domain logic; comments only                                                                                     | the files I name                                        |
| `tidy-docs`         | The documents brought up to date with the code, then streamlined: one home per fact, indexes complete, open work first, a status on every plan                                                                 | two commits                                             |
| `update-guide`      | The short user guide (Piglet) caught up with new features                                                                                                                                                      | `docs/guide/index.html`                                 |
| `update-manual`     | The long manual (Owl teaching Rabbit) caught up, its screens captured again from the program                                                                                                                   | `docs/manual/`                                          |

### The panel

The same eight lenses serve the review, the meetings and the study plan; who attends follows the subject (Owl, the host, and Claude always). Ask for "the whole board" to have everyone.

| Member            | Lens                                         |
| ----------------- | -------------------------------------------- |
| José Who Brews        | Elixir, code quality                         |
| Great-Uncle Joe     | Erlang/OTP, processes, failure               |
| Carsten Stargazer   | Org-mode, plain text, personal information   |
| Old Mitch Lilypad       | Lotus Agenda itself, its users               |
| David the Squirrel       | GTD, trust in the system                     |
| Dr. Russell | ADHD and people easily overwhelmed          |
| Little Marie-Who-Folds       | Tidiness and scope; advises, never discards  |
| Claude            | An owl from Anthropic, Owl's cousin: readiness for agents |

The panel advises; it never votes. I decide.

## Where things live

| What                                   | Where                                                                                          |
| -------------------------------------- | ---------------------------------------------------------------------------------------------- |
| What comes next                        | [`ROADMAP.md`](ROADMAP.md), the **In order** list at the top; the parity work in order: [`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md) § The steps |
| What is done                           | [`ROADMAP_DONE.md`](ROADMAP_DONE.md), by milestone                                             |
| Every document and what it is for      | [`INDEX.md`](INDEX.md)                                                                         |
| Thoughts waiting for a meeting         | Thoughts ▸ Next meeting in my project file (`$AGENDUM_PROJECT_FILE`), read by `mix agendum.thoughts` |
| Reviews, meetings, study               | `docs/reviews/`, `docs/meetings/YYYY-MM-DD/`, `docs/study/STUDY_PLAN.md`                       |
| A record of every session              | `docs/summaries/` (committed since 2026-10-23, private: left out of the public copy; kept complete, alike in shape, to import into Agendum one day with STF) |
| What changed per version               | [`../CHANGELOG.md`](../CHANGELOG.md), and the `vX.Y.Z` tags                                    |
| Why things are as they are             | `docs/adr/`, listed in [`ARCHITECTURE.md`](ARCHITECTURE.md)                                    |
| Finished or dropped plans              | `docs/plans/archive/`                                                                          |
| Claude's memory of how I work          | Claude Code's project memory (outside the repository, moves with the folder: `docs/plans/archive/RENAME_REPO.md`) |

## Tools I can run

| Command                                                | For                                                                     |
| ------------------------------------------------------ | ----------------------------------------------------------------------- |
| `mix setup`                                            | a fresh checkout: dependencies, and the pre-push hook (runs `mix check`) |
| `mix check`                                            | the quality gate                                                        |
| `gh run list` (or the Actions tab on GitHub)           | CI: the same gate on GitHub after every push (`.github/workflows/check.yml`), and the long fuzz run every night (`fuzz.yml`; `gh workflow run fuzz.yml` starts it by hand) |
| `mix run -e 'Agendum.CLI.main(["--demo"])'`            | the program with sample data (`--rabbit`: Rabbit's file; `--clinic`: the Easter egg) |
| `mix escript.build && ./agendum FILE`                  | the real program                                                        |
| `AGENDUM_LOG=1 ./agendum FILE`                         | with a debug log (`~/.local/state/agendum/logs`); give it to Claude on a crash or lag |
| `mix docs --open`                                      | API docs, design documents, guide and manual in the browser             |
| `mix agendum.starters`, `mix agendum.golden`           | rebuild the Planner starter; write the golden file of a new format version |
| `FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs` | the long fuzz run                                                     |
| `mix agendum.thoughts` (`--next-meeting`; `--init PATH` once; `--import-docs`) | my open thoughts from the project file in `$AGENDUM_PROJECT_FILE`, as Markdown; `--init` makes the file; `--import-docs` puts the meetings, ADRs, roadmap and session summaries into it as Disposable items (Agendum closed first; the old file kept as `.bak`) |
| `tools/agformat/agenda_driver.py`, `agdump.py`, `agdiff.py` | drive the real Agenda headless (also record its sounds: SDL's disk audio driver); read and compare `.AG` files (`tools/agformat/DRIVING_AGENDA.md`) |
| `tools/agformat/capture_menus.py` | walks Agenda's F10 menus (view, note, category manager) in DOSBox into `docs/reference/agenda_menus.json` and AGENDA_MENUS.md; the menu test compares Agendum's menus with it, every difference tagged (meeting 2026-10-21, § 8) |
| `tools/smoke/smoke.py KEYS…` | the real program in a pseudo-terminal: send keys, see the screen as text (sandboxed; `--help`) |
| `tools/screenshots/`                                   | draw a screen as a PNG, to compare with Agenda's                        |

## Ways of working that proved themselves

- **Commit on your own once the checks pass**, and summarise after: fewer round trips (2026-10-14).
- **Settle "how does Agenda do X" by experiment** in the real Agenda, reported as an evidence table (2026-10-15).
- **Sharpen the saw before a large refactoring**: the fuzz invariants, the pre-push hook and the golden files came before the command layer, which then went in seven batches with the gate green each time (2026-10-16).
- **Run the gate several times** after fixing a failing one: a flaky warning hid behind one green run (2026-10-16).
- **A meeting turns parked thoughts into decisions**: four items decided and built the same evening (2026-10-16).
- **Jobs in parallel**: the guide, the manual and a review at once, each agent in its own worktree (2026-10-16).
- **Start sessions on purpose** with `/start-session` (adopted 2026-10-16): the mirror of `end-session`.
- **Writing study questions finds bugs**: asking "what happens if this fails?" found a lost-save bug (2026-10-16).
- **All the questions up front, then a break**: the owner answered seven questions on the `.AG` import in two rounds and rested while it was built in three tested commits; nothing had to wait for them (2026-10-16).
- **A meeting sorts a review's advice**: the eleven recommendations of 2026-10-21 decided one by one in one sitting, each into its home or dropped, so the roadmap's **Next action** says one thing again (2026-10-22).
- **Use Agendum for Agendum** (adopted 2026-10-22, meeting § 7b): my thoughts live in a Thoughts view in my own file, and the dagordning file is retired (meeting 2026-10-22-2); the project's documents are to be imported into the same file as Disposable items, deleted and read afresh on each import (ROADMAP, Sharpen the saw).
- **Off this Mac** (adopted 2026-10-22, meeting § 5h): the code is on GitHub since 2026-10-17; the session summaries are committed too, since 2026-10-23.
- **Formatting needs no gate run**: a Claude Code hook (`.claude/settings.json`) runs `mix format` on every `.ex`/`.exs` file Claude writes, so a format failure no longer costs a `mix check` round (2026-10-22). The same file allows `mix test`, `mix check` and `tools/smoke/smoke.py` without a permission prompt.
- **Questions first, then a row of builds**: three items (a bug fix release, the `feature` skill, the document import) settled in one round of four questions, then built and committed one after another while the owner went to bed (2026-10-23).
- **Smoke tests in a sandbox**: a pty test sets `XDG_CONFIG_HOME` to a scratch folder and unsets `AGENDUM_LOG`, after one test wrote into the owner's real preferences (2026-10-16; CLAUDE.md, Testing the real terminal).

## How I could work better

Suggestions, most valuable first. None is decided; take what helps, and move what you adopt into the sections above.

1. **Try each change before the next one.** The review counted 85 commits in one day. The end-session summary lists "what you'll notice"; spending five minutes in the real program on that list before starting new work keeps your understanding level with the code, and catches habit changes early (CLAUDE.md asks for it).
2. **A rhythm for reviews.** Three reviews in one day is a lot of advice to act on. One per version (or after each meeting's decisions ship) gives each review a real change to measure (the review's resolution 11).
