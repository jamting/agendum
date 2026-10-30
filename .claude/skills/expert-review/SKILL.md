---
name: expert-review
description: Produce a dated, in-depth review of Agendum as the minutes of a panel meeting in Owl's house, with eight lenses - José Who Brews (Elixir), Great-Uncle Joe (Erlang/OTP), Carsten Stargazer (Org-mode), Old Mitch Lilypad (Lotus Agenda), David the Squirrel (GTD), Dr. Russell (ADHD and overwhelm), Little Marie-Who-Folds (tidiness and scope) and Claude (an owl from Anthropic, Owl's cousin, on readiness for agents) - covering architecture, code quality, helpfulness to users, business value, vision, methods, tidiness and scope, and agent readiness, with scores, findings backed by evidence, ranked recommendations and the trend since the last review. Saved as docs/reviews/YYYY-MM-DD.md. Use when the owner asks for an expert review, a panel review, a project health report, or types /expert-review.
---

# Expert panel review

A periodic, outside look at the whole project: is it built well, does it help the people it is for, is it worth something, is the way it is being made sound, is it kept tidy without hoarding, and is it ready for agents to work in it? The answer is a dated report in `docs/reviews/`, so that reviews can be compared over time. Do not change code here; the report recommends, the owner decides.

The report is written as **the minutes of a meeting** of the panel, held in Owl's house in the Hundred Acre Wood. The substance is a serious review (the first one, `docs/reviews/2026-10-16.md`, is the model for depth and evidence); the setting is the spice. Findings first, tea second.

## The panel

Eight lenses, each with its own concerns. The seven people are *perspectives in the spirit of* their public work; never invent quotes and attribute them to a real person. The minutes help here: they report what was said ("José noted that …"), they do not quote. Say once, in the opening paragraph, that the voices are lenses written by Claude, not their words.

| Lens                     | Looks at                                                                                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **José Who Brews** (Elixir)  | Idiomatic Elixir, module boundaries, data modelling with structs and types, Dialyzer and specs, tests and tooling, compile-time guarantees, what a future LiveView needs |
| **Great-Uncle Joe** (Erlang/OTP) | Simplicity, "make it work, make it beautiful, make it fast", pure functions and messages, failure and recovery, the on-disk format, processes for the web, measurement |
| **Carsten Stargazer** (Org-mode) | The person's data: plain text, longevity, interchange, keyboard flow, capture, agenda views, extensibility, power users' habits, what a long-lived personal tool needs |
| **Old Mitch Lilypad** (Lotus Agenda) | Faithfulness to Agenda's *idea* (free-form capture, automatic filing, editable views), the learning curve that limited it, product vision, who it is for, market     |
| **David the Squirrel** (GTD)    | Does it work as a trusted system: capture, clarify, organize, reflect (weekly review), engage; next actions, contexts, projects, waiting-for; reliability and trust     |
| **Dr. Russell** (ADHD) | Does it help people with ADHD, and anyone easily overwhelmed by life (`docs/VISION.md`): help at the point of performance (the reminder, the next step, shown where and when it is needed), information kept outside the head instead of in working memory, time made visible (dates, durations, what is overdue), friction at capture (a thought written down before it is lost), how much is on screen at once, recovering after days away without shame or a wall of red, small steps and quick feedback |
| **Little Marie-Who-Folds** (tidiness) | Is everything in its place, and does each thing still serve the project: code and documents with one clear home each, duplicates, stale plans, dead code and unused functions, folders that grow without being read (reviews, summaries, logs); scope creep (roadmap items that pile up without serving `docs/VISION.md`); and keeping less: stored fields, data and files the program or the project will never need, in Agendum's own files as much as in the repo |
| **Claude** (an owl from Anthropic) | Readiness for agents: user actions as named commands an agent can call (tools), headless entry points (CLI, JSON in and out), stable schemas, explainable results ("filed under Kanga because …"), proposals before changes and one-step undo of an agent's batch, permissions and scope, a human and an agent editing the same file, how much of a file fits in a model's context (ADR 0034, the item levels), item text as data and never as instructions (prompt injection), documents an LLM can read (CLAUDE.md, `docs/INDEX.md`), and whether agent behaviour can be tested (golden tasks, evals) |

**Pseudonyms** (meeting 2026-10-28-0908, § 10): in every new text the people behind the lenses go by Wood names, so a keen reader can tell who is meant from the background but the names are not searchable. On first mention in a document the full pseudonym with the lens in brackets ("Carsten Stargazer (Org-mode)"); after that the first name ("Carsten noted …"). The names vary in form as in the Wood (a title, a habit, a "Who" name), and the short form is still the first name ("Great-Uncle Joe" is Joe, "Little Marie-Who-Folds" is Marie); the names were chosen anew by the owner on 2026-10-30, and two quotes of the first proposal ("Joe the Polar Bear") stay in the minutes of 2026-10-28-0908. The owner is called Mattias. Guests get a pseudonym before their first meeting. Every text in this public repository uses the pseudonyms only (ADR 0050): the table pairing them with the real people is private, in the Wolery (the owner's private repository; its path is in `CLAUDE.local.md`): its copy of this skill and its `tools/public/names.py`. A new guest's pair is added there, never here.

**Claude** is the model writing the report, so it is the one lens that may speak for itself, in the first person where it fits. In the story it is an owl: a cousin of Owl's (Wol, whose name the program carries), from a branch of the family that went into language. Owl is proud of the relation and not entirely sure how it works. Claude's lens is not a mascot: it judges, with evidence, how far the project is from the agent in `docs/plans/WOL-IN-THE-MACHINE.md` and the web plan, and it may disagree with the others.

**Little Marie-Who-Folds** looks at the project as a home to be tidied, by category rather than by folder (all plans together, all summaries together), and asks of each thing whether it still serves. Two rules keep her lens fair. She **respects vision that sparks joy**: an ambitious idea in `docs/VISION.md` or a plan the owner cares about is not clutter; she asks only that it has its place (a plan with a status line, a "later" area on the roadmap) instead of leaking into today's work. And she **advises, never discards**: letting go of a document, a field or a feature is the owner's decision, and what the owner has already decided to keep (the complete session summaries, the untracked reference files in `docs/reference/`) is not raised again. Her advice on keeping less names what to drop, why it will not be needed, and what it costs to keep (reading time for people and LLMs, file size, format upgrades).

### Who attends

Not every expert attends every meeting; it depends on the subject. **Owl** (host) and **Claude** (secretary, and its own lens) are always there. A **review** covers every area, so the whole panel is invited, but a lens with nothing new to say in an area keeps quiet there. A **meeting** (`meeting` skill) or a **study plan** (`study-plan` skill) calls only the lenses whose subjects are on the table: José and Joe for code and architecture, Carsten for data and habits, Mitch for Agenda and the product, David for working as a trusted system, Russell for people with ADHD or easily overwhelmed, Marie for documents, organisation, scope and what to keep. The minutes list who was present and, where it helps, who sent apologies.

## The setting

- **Owl's house**, high in a beech tree: a small room with a door knocker and a bell-pull, a chair or two, and portraits of relations (Uncle Robert among them). Owl, the host, chairs the meeting, kindly and a little long-winded; he is not a narcissist (the owner's rule, see `lib/agendum/starters/clinic.ex`). He is not a panel member and does not score.
- **Tightly squeezed.** Up to nine in a room built for one owl: knees against the table, someone on the stairs, Mitch's papers on the floor. Little Marie-Who-Folds has views on Owl's house (the portraits, the stacks of papers, the umbrella stand); she is gentle about it, and Owl, though fond of every item, is slowly persuaded to thank one or two and let them go. Tea gets spilt on each other, a finding is underlined with a teaspoon, a biscuit tin goes round. Other Hundred Acre Wood animals may put a head through the door (Pooh about honey, Rabbit with a list), briefly.
- **How much spice.** Stage notes in italics, one or two per section at most, never inside a finding's evidence, a score, a number or a recommendation. The opening, the any-other-business item and the closing may carry more. Find new incidents each time; read the last minutes so the running gags develop rather than repeat. Funny, warm, no innuendo, no mocking the real people.
- **Spelling.** Owl is famous for spelling badly; these minutes are not. Every word is spelled correctly, including in jokes about Owl's spelling, which describe it rather than reproduce it. Names: José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad, David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Wol, Hundred Acre Wood, Agendum, Lotus Agenda.

## Private passages

This repository is public (moving day, 2026-10-30; ADR 0050). What is private never goes into it: the owner's own plans beyond the open program (what the creek lines stand for; the list is in `CLAUDE.local.md`'s Rules and the Wolery's ADR 0050), and the real names behind the pseudonyms.

- **Where it goes**: into the Wolery (the owner's private repository; its path is in `CLAUDE.local.md`), in a file beside the public one: `docs/reviews/YYYY-MM-DD-private.md` for a review, `docs/meetings/YYYY-MM-DD-HHMM/private.md` for a meeting. It is written under the same § number and heading, so the two read together.
- **What the public text shows** in its place: the creek line, *[A page here was soaked in the creek. — Rabbit]* (its story is in `docs/INDEX.md`). The one exception is a review's business value, which the public minutes leave out altogether (Judge, below).
- **The commit**: the private file is committed and pushed in the Wolery (`git -C <the Wolery>`), the public text here.
- **Without a `CLAUDE.local.md`** (a contributor's checkout): leave such passages out altogether.

The `meeting` skill follows the same rule.

## 1. Gather the evidence

Read before judging; every finding in the report needs a pointer (`path:line`, a document, a command's output). Collect into the scratchpad, not the repo.

**Mission and plans**: `README.md`, `docs/VISION.md`, `CLAUDE.md`, `docs/INDEX.md`, `docs/AGENDA_HISTORY.md`, `docs/ROADMAP.md` (open first), every plan's status line in `docs/plans/`, the newest ADRs, `CHANGELOG.md`.

**Architecture**: `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `docs/DATA_ACCESS.md`, `test/agendum/architecture_test.exs`. Then read code, not only documents: `lib/agendum/core.ex`, `core/database.ex`, `core/assign.ex`, a facade area, `tui/update.ex`, `tui/state.ex`, `tui/app.ex`, `store.ex`, and whatever the largest or most changed modules are this time.

**Agents** (for Claude's lens): `docs/plans/WOL-IN-THE-MACHINE.md`, ADR 0033 (commands and keymaps), ADR 0034 (format of record), `docs/JSON_FORMAT.md`, `lib/agendum/cli.ex` (what can be done without the TUI), `Agendum.TUI.Commands` and the command layer as far as it has come. Ask: could an agent today do one ordinary user action (add an item, assign it, read a view) without driving keystrokes, and explain what it did?

**Tidiness** (for Marie's lens): `docs/INDEX.md` against what is in `docs/` (orphans, duplicates), plans' status lines (finished or abandoned plans still open), the roadmap's open list (how long, how old, how much of it serves the vision), the growing folders (`docs/reviews/`, `docs/meetings/`, and the Wolery's `docs/summaries/`), public functions no one calls (`mix xref callers`, or a grep), stored fields that nothing reads (`docs/DATA_MODEL.md` against the code).

**Numbers** (put them in the report's table, so the next review can show the trend):

```sh
git log --oneline | wc -l                                   # commits
git log --format=%ad --date=short | sort | uniq -c          # cadence
git log --since="<last review date>" --oneline | wc -l      # since the last review
find lib -name '*.ex' | xargs wc -l | tail -1               # lines of code
find lib/agendum/core lib/agendum/core.ex -name '*.ex' | xargs wc -l | tail -1
find lib/agendum/tui -name '*.ex' | xargs wc -l | tail -1
find test -name '*.exs' | xargs wc -l | tail -1             # lines of tests
find lib -name '*.ex' | xargs wc -l | sort -rn | sed -n 2,11p   # largest modules
grep -rn "credo:disable" lib | wc -l                        # suppressions
grep -rho "Core\.[a-z_]\+(" lib/agendum/tui/update* | wc -l   # core calls left in Update (command layer)
grep -o "R[0-9]\+[a-z]\?" docs/SPEC.md | sort -u | wc -l    # rules in the spec
ls docs/adr | wc -l                                         # ADRs
grep -n "@format_version" lib/agendum/store.ex              # file format version
ls docs docs/plans | wc -l; ls <the Wolery>/docs/summaries | wc -l   # documents, summaries
grep -c '^- \[ \]' docs/ROADMAP.md                          # open roadmap items
(time mix check) 2>&1 | tail -5                             # the gate: result and time
```

Run `mix check` for real (in the background) and report what it said; do not assume it passes. Optionally time a large file (the roadmap's "Sharpen the saw" items) if performance is a finding.

**The owner's study** (Methods): the table at the top of the Wolery's `docs/study/STUDY_PLAN.md`, if it exists (`study-plan` skill): units done and what is next. Never judge its pace or count it as a lack of progress: the owner learns Elixir outside the project too (meeting 2026-10-22-2130, § 5j).

**The previous review**: read the newest file in `docs/reviews/`. Each of its recommendations is followed up: done, partly, not yet, or dropped (with the commit or the reason).

## 2. Judge

For each area, find strengths *and* risks; a review with only praise or only faults is not useful. Prefer a few deep findings with evidence over many shallow ones. Check claims before writing them (read the code a document describes). Where the lenses disagree, say so: the tension is often the most useful part.

Score each area 1–5 (5 = exemplary for a project of this size and age), with one line of why:

Architecture · Code quality · Tests and verification · Documentation · Helpfulness to users · Vision · Methods · Business value · Agent readiness · Tidiness and scope

**Business value is private** (Private passages, above): its score, its trend and its why go only into the Wolery's file, under § 7 Scorecard, and the public scorecard leaves its row out.

**The public minutes do not mention business value at all** (the owner, 2026-10-30: a creek line in every review would soon grow old). § 12 is written only in the Wolery's file; the public minutes have no § 12 heading and no creek line, and go from § 11 to § 13, so the other sections keep the numbers earlier reviews use. Nor does business value come up anywhere else in the public text (the agenda, the verdict, § 19). Reviews before 2026-10-30 keep their creek line unchanged.

(Agent readiness was added after the first review, Tidiness and scope when Little Marie-Who-Folds joined: each one's trend is "first" the first time it is scored.)

## 3. Write the minutes

`docs/reviews/YYYY-MM-DD.md` (today's date; if one exists for today, add `-2`). Never overwrite an earlier review. The structure is a meeting protocol, numbered with §, the same every time so reviews compare. The review's sections map onto the agenda items (the meeting about Agenda adopts an agenda; Owl will want to say so).

```markdown
# Minutes of the expert panel, YYYY-MM-DD

**Place:** Owl's house, the Hundred Acre Wood
**Present:** José Who Brews, Great-Uncle Joe, Carsten Stargazer, Old Mitch Lilypad,
David the Squirrel, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin);
Owl, host
**Chair:** Owl · **Minutes:** Claude · **Approvers:** <two panel members>
**Under review:** commit `<hash>`, version <x.y.z>

<one paragraph, in italics if you like: the setting as the meeting
starts, and the note that the voices are lenses in the spirit of the
named people, written by Claude, not their words; made with the
`expert-review` skill>

## § 1 Opening of the meeting
## § 2 Election of a secretary and two approvers of the minutes
## § 3 Adoption of the agenda
## § 4 The previous minutes        (follow-up table: Recommendation | Status | Evidence; "no previous minutes" on the first)
## § 5 The project in numbers      (table: Measure | Now | Last review)
## § 6 Summary and verdict         (five to eight sentences: the verdict, the biggest strength, the biggest risk, the one thing to do next)
## § 7 Scorecard                   (table: Area | Score | Trend | Why; trend ↑ ↓ → or "first")
## § 8 Architecture                (José, Joe)
## § 9 Code quality                (José)
## § 10 Tests and verification     (José, Joe)
## § 11 Helpfulness to users       (David, Carsten, Mitch, Russell)
                                   (§ 12 Business value: Mitch, Carsten; only in the Wolery's file, left out here)
## § 13 Vision                     (Mitch, David; Marie on scope)
## § 14 Agent readiness            (Claude, with whoever joins in)
## § 15 Tidiness and scope        (Marie, with whoever joins in: what to put in its place, what to let go, scope creep)
## § 16 Methods                    (all)
## § 17 Points of disagreement
## § 18 Resolutions                (the recommendations: "The meeting resolved to recommend"; numbered, most valuable first, each: what, why, how big (S/M/L), lens)
## § 19 Any other business
## § 20 Closing of the meeting

*Minutes kept by Claude. Approved by <the two approvers>.*
```

§ 1–3 and § 19–20 are short (a few lines each) and carry most of the setting. § 4 onwards hold the review, at the depth of the first one.

Within each section, write as minutes: "**Joe** observed that …", "**Claude** said: I …" (only Claude speaks in the first person). Keep plain language (the owner's style in `docs/`): short sentences, no marketing words. Link to code as `path:line`.

Before committing, read the whole file once for spelling alone (no spell checker is installed; `hunspell` has no dictionaries), then once for the rules above: no invented quotes from real people, Owl kind and not vain, stage notes outside the evidence.

## 4. Record and report

- Add a row for the review to the "Reviews" table in `docs/INDEX.md` if it is not there already (one row for the folder is enough).
- Commit the report alone (`git add docs/reviews/<file> docs/INDEX.md`; never `git add docs`): "Expert panel review, YYYY-MM-DD". Commit and push its private file in the Wolery (`git -C <the Wolery> add docs/reviews/<file>-private.md`), with the same message. Nothing under `lib/` or `test/` changes, so `mix check` is not needed for the commit.
- In the terminal, give the summary, the scorecard and the top three recommendations, with the path to the report. Offer, in one line, to turn recommendations into roadmap items; do not add them unasked. When the owner says yes: tools, checks and ways of working go under "Sharpen the saw", the rest in their areas, each citing the review's date; keep the **Next:** line at the top of Open true.
