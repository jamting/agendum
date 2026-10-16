---
name: expert-review
description: Produce a dated, in-depth review of Agendum by a panel of five lenses - José Who Brews (Elixir), Great-Uncle Joe (Erlang/OTP), Carsten Stargazer (Org-mode), Old Mitch Lilypad (Lotus Agenda) and David the Squirrel (GTD) - covering architecture, code quality, helpfulness to users, business value, vision and methods, with scores, findings backed by evidence, ranked recommendations and the trend since the last review. Saved as docs/reviews/YYYY-MM-DD.md. Use when the owner asks for an expert review, a panel review, a project health report, or types /expert-review.
---

# Expert panel review

A periodic, outside look at the whole project: is it built well, does it
help the people it is for, is it worth something, and is the way it is
being made sound? The answer is a dated report in `docs/reviews/`, so that
reviews can be compared over time. Do not change code here; the report
recommends, the owner decides.

## The panel

Write as five lenses, each with its own concerns. They are *perspectives
in the spirit of* these people, drawn from their public work; never invent
quotes and attribute them to the real person. Say so once at the top of
the report.

| Lens                     | Looks at                                                                                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **José Who Brews** (Elixir)  | Idiomatic Elixir, module boundaries, data modelling with structs and types, Dialyzer and specs, tests and tooling, compile-time guarantees, what a future LiveView needs |
| **Great-Uncle Joe** (Erlang/OTP) | Simplicity, "make it work, make it beautiful, make it fast", pure functions and messages, failure and recovery, the on-disk format, processes for the web, measurement |
| **Carsten Stargazer** (Org-mode) | The person's data: plain text, longevity, interchange, keyboard flow, capture, agenda views, extensibility, power users' habits, what a long-lived personal tool needs |
| **Old Mitch Lilypad** (Lotus Agenda) | Faithfulness to Agenda's *idea* (free-form capture, automatic filing, editable views), the learning curve that limited it, product vision, who it is for, market     |
| **David the Squirrel** (GTD)    | Does it work as a trusted system: capture, clarify, organize, reflect (weekly review), engage; next actions, contexts, projects, waiting-for; reliability and trust     |

## 1. Gather the evidence

Read before judging; every finding in the report needs a pointer
(`path:line`, a document, a command's output). Collect into the scratchpad,
not the repo.

**Mission and plans**: `README.md`, `CLAUDE.md`, `docs/INDEX.md`,
`docs/AGENDA_HISTORY.md`, `docs/ROADMAP.md` (open first), every plan's
status line in `docs/plans/`, the newest ADRs, `CHANGELOG.md`.

**Architecture**: `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`,
`docs/DATA_ACCESS.md`, `test/agendum/architecture_test.exs`. Then read code,
not only documents: `lib/agendum/core.ex`, `core/database.ex`,
`core/assign.ex`, a facade area, `tui/update.ex`, `tui/state.ex`,
`tui/app.ex`, `store.ex`, and whatever the largest or most changed modules
are this time.

**Numbers** (put them in the report's table, so the next review can show
the trend):

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
(time mix check) 2>&1 | tail -5                             # the gate: result and time
```

Run `mix check` for real (in the background) and report what it said; do
not assume it passes. Optionally time a large file (the roadmap's
"Sharpen the saw" items) if performance is a finding.

**The previous review**: read the newest file in `docs/reviews/`. Each
of its recommendations is followed up: done, partly, not yet, or dropped
(with the commit or the reason).

## 2. Judge

For each area, find strengths *and* risks; a review with only praise or
only faults is not useful. Prefer a few deep findings with evidence over
many shallow ones. Check claims before writing them (read the code a
document describes). Where the lenses disagree, say so: the tension is
often the most useful part.

Score each area 1–5 (5 = exemplary for a project of this size and age),
with one line of why:

Architecture · Code quality · Tests and verification · Documentation ·
Helpfulness to users · Vision · Methods · Business value

## 3. Write the report

`docs/reviews/YYYY-MM-DD.md` (today's date; if one exists for today, add
`-2`). Never overwrite an earlier review. Structure, the same every time
so reviews compare:

```markdown
# Expert panel review, YYYY-MM-DD

<one paragraph: what was reviewed (commit hash, version), the panel, and
that the voices are lenses in the spirit of the named people, not their words>

## Summary
<five to eight sentences: the verdict, the biggest strength, the biggest risk,
the one thing to do next>

## Scorecard
| Area | Score | Trend | Why |       (trend: ↑ ↓ → or "first" on the first review)

## The project in numbers
| Measure | Now | Last review |

## Follow-up of the last review
| Recommendation | Status | Evidence |   (left out on the first review)

## Architecture            (José, Joe)
## Code quality            (José)
## Tests and verification  (José, Joe)
## Helpfulness to users    (David, Carsten, Mitch)
## Business value          (Mitch, Carsten)
## Vision                  (Mitch, David)
## Methods                 (all)
## Where the panel disagrees

## Recommendations
<numbered, most valuable first, each: what, why, how big (S/M/L), lens>
```

Within each section, use the lens names as short attributions ("**Joe:**
…") where a view is distinctly theirs. Keep plain language (the owner's
style in `docs/`): short sentences, no marketing words. Link to code as
`path:line`.

## 4. Record and report

- Add a row for the review to the "Reviews" table in `docs/INDEX.md` if
  it is not there already (one row for the folder is enough).
- Commit the report alone (`git add docs/reviews/<file> docs/INDEX.md`;
  never `git add docs`): "Expert panel review, YYYY-MM-DD". Nothing under
  `lib/` or `test/` changes, so `mix check` is not needed for the commit.
- In the terminal, give the summary, the scorecard and the top three
  recommendations, with the path to the report. Offer, in one line, to
  turn recommendations into roadmap items; do not add them unasked.
