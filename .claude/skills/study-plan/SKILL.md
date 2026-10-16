---
name: study-plan
description: Let the expert panel (José, Joe, Carsten, Mitch, David and Claude, as in expert-review) pick the next part of Agendum's code for the owner to study, give it learning comments first (the learning-comments skill), then write it as a unit in docs/study/STUDY_PLAN.md - a reading order with questions and exercises the owner checks off when fully understood. Also reports progress and helps with unticked questions. Use when the owner asks for a study plan, the next thing to study, help understanding the code, or types /study-plan.
---

# Study plan

The first expert review (`docs/reviews/2026-10-16.md`, Methods) named a
risk: the code grows faster than the owner's understanding of it. This
skill answers it. The panel picks one part of the code worth knowing by
heart, the code gets learning comments, and the owner works through it
with questions and checks them off **only when fully understood**.

The plan lives in one file, `docs/study/STUDY_PLAN.md`, one unit after
the other. It is the owner's record: **never tick a box for the owner**.
Tick one only when the owner says so in the conversation ("tick 3.2").

The owner is an experienced programmer, new to Elixir (see the
`learning-comments` skill and its memory). Pitch everything at that: the
Elixir *why* and the domain *why*, not programming basics.

## 0. Which kind of call

- **"Next unit", or no plan yet** → steps 1 to 5.
- **Progress, or "help with …"** → read the plan; report ticked / total
  per unit; for the question the owner names (or the first unticked
  one), explain in the chat, pointing to `path:line`, and let the owner
  tick it. Don't start a new unit while the current one has unticked
  boxes unless the owner asks: then mark it "paused" in its header.
- **The studied code changed since** → each unit records the commit it
  was written at. `git diff <commit> -- <files>` shows what moved; add a
  short "Since you studied it" note under the unit, and reword any
  question the change made wrong (keep its tick, say so in the note).

## 1. The panel picks the part

Read `docs/study/STUDY_PLAN.md` (what was studied), the newest review in
`docs/reviews/`, `docs/ROADMAP.md` (the **Next:** line) and
`docs/ARCHITECTURE.md`. Then let each lens (as in `expert-review`) name
one candidate in a sentence, and choose one:

- **Central**: code everything else leans on (`Core.Assign`, `Database`,
  `Update.handle/2` and its effects, `Store`), before the edges.
- **Next in line**: code the coming work will change (the roadmap's
  Next). Understanding it first makes the owner a better reviewer of
  that work.
- **Risky**: where a mistake loses data or trust (saving, undo, format
  upgrades, assignment conflicts).
- **Changing fast**: `git log --since=<last unit> --format= --name-only
  lib | sort | uniq -c | sort -rn | head` shows where the owner has seen
  the least of the code stay still.
- **Not yet studied**, and a sensible next step from what was.

A unit is one coherent story, not a folder: "how a typed item gets
filed", "what happens between a key press and the screen", "how a file
is saved and loaded". Two to six files or parts of files, roughly 300 to
900 lines, one to three evenings of reading. Follow a path through the
code rather than whole modules when a module is large.

Present the choice to the owner in a few lines (the candidates, the
pick, why) and go on unless they want another.

## 2. Learning comments first

Run the `learning-comments` skill on exactly the files (or functions) of
the unit, skipping what already has them (`git log --grep="Learning
comments"`). Follow that skill fully: comments only, `mix check`, the
report, and its commit after asking. The study plan is written on top of
the commented code, so its line numbers point at code with comments.

## 3. Write the unit

Read the commented code again whole, plus the SPEC rules and ADRs it
cites. Then append a unit to `docs/study/STUDY_PLAN.md` (create the file
with the header below the first time):

```markdown
# Study plan

The owner's path through Agendum's code. Each unit is chosen by the
expert panel, the code has learning comments, and a box is ticked only
when that point is fully understood: could you explain it to someone
without looking? Made with the `study-plan` skill.

| Unit | Topic | Started | Done | Ticked |
| ---- | ----- | ------- | ---- | ------ |
| 1    | …     | date    |      | 0 / 12 |

---

## Unit N: <the story, e.g. How a typed item gets filed>

**Chosen by the panel, YYYY-MM-DD, at commit `<hash>`.** <two to four
sentences: why this part, with the lenses who argued for it ("José:
the command layer will change this first …")>

**Before you start:** <what to know from earlier units or documents, with
links; how to run the relevant tests: `mix test test/agendum/core/assign_test.exs`>

### N.1 <first stop on the path> — `lib/…/file.ex:12-80`

<one short paragraph: what to look at and in which order>

- [ ] **N.1.1** <a question that shows understanding, e.g. "Why does
  `do_assign/4` compare the item before and after, instead of storing
  what it added?">
- [ ] **N.1.2** <…>

<details><summary>Where to look for the answers</summary>

N.1.1: `lib/…:44` and R7c in `docs/SPEC.md`. N.1.2: …

</details>

### N.2 …

### Try it

- [ ] **N.x.1** <an exercise: predict, then check. "In `iex -S mix`, build
  a database with `Agendum.Fixtures` … and assign … What do you expect?
  Run it.">
- [ ] **N.x.2** <trace one real action through the unit: "Type 'Call
  Anna Friday' in `--demo`; name every function it passes, in order.">
- [ ] **N.x.3** <a change you would make, thought through but not
  committed: "Where would a new kind of condition go, and which tests
  would fail first?">

### The unit is done when

- [ ] **N.done** I can explain <the story> from start to end without
  the code open.
```

Writing the questions:

- **Questions, not chores.** "Read `assign.ex`" is not a check; "Why is
  the clause for an exclusive parent before the general one?" is.
- **Both kinds**: Elixir questions (why `with` here, what the pin does,
  why this is a tail call) and domain questions (what a conflict is,
  why dates are read once, which rule this is).
- **Answerable from the code and its comments.** Hints point to
  `path:line`, SPEC rules and ADRs; never write the full answer, only
  where it is. Check every hint's line number.
- **Some prediction.** At least two exercises where the owner predicts
  an outcome in `iex` or a test before running it.
- Eight to fifteen boxes per unit. Number them so the owner can say
  "help with 2.3".
- Plain language, the owner's style: short sentences, no marketing
  words, no exclamation marks.

## 4. Record

- `docs/INDEX.md`: the "Reviews and study" section names
  `docs/study/STUDY_PLAN.md` with a link; add it if missing.
- Update the table at the top of the plan (the new unit, started today).
- Commit the plan alone, after the learning comments' own commit:
  `git add docs/study/STUDY_PLAN.md docs/INDEX.md` (never `git add
  docs`): "Study plan: unit N, <topic>".

## 5. Report

In the terminal: the panel's candidates and the pick in a few lines, the
files that got learning comments, the unit's stops, how many boxes, and
how to begin ("start with N.1; say 'help with N.1.2' any time"). The
next `expert-review` reads the plan's table as evidence for Methods.
