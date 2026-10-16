---
name: tidy-docs
description: Bring Agendum's documents (README, CONTRIBUTING, CLAUDE.md, docs/, docs/plans/) up to date with the code and keep them streamlined - stale facts fixed, duplicates replaced by references, the indexes (docs/INDEX.md, SPEC's rule index) complete, the roadmap with open work first, a status line on every plan. Use when the owner asks to tidy, streamline, refactor or bring the docs up to date, or to make them easier for an LLM to read. Not for the user guide or the manual (update-guide, update-manual).
---

# Tidy the documents

Two goals, done as **two commits** so the owner can revert either one:

1. **Up to date:** every document says what the code does today.
2. **Streamlined:** easy to find things in, for people and for an LLM reading it cold. Each fact has one home; other places link to it.

Ground rules:

- **Nothing is lost.** Move, merge or shorten; never drop a fact. Letting go of a document or a fact that is no longer needed is the owner's decision, usually on Little Marie-Who-Folds's advice in a review or a meeting; here, only propose it. When something is said twice, keep it in the document it belongs to (see `docs/INDEX.md`) and put a reference in the other.
- **Within reason.** Don't rewrite for style; fix what is wrong, hard to find or repeated.
- **Stable names.** Code, tests and skills cite file names, `SPEC §5`, `§6` and rule numbers (`R42`): keep them. Rename a file only when the gain is clear, and then fix every reference (`grep -rn` over `lib test docs tools .claude CLAUDE.md README.md CONTRIBUTING.md mix.exs`).
- **ADRs are records** of past decisions: don't rewrite them. A later change gets "superseded in part by ADR NNNN", as ADR 0007 has.
- **Leave alone** what is about to change or is generated: the guide and the manual (their own skills), `docs/manual/index.html`, and anything the owner says is being reworked (ask if unsure; e.g. KEYBOARD.md's structure while the commands-for-keys work is under way).
- Names follow CLAUDE.md: **Agendum** is ours, **Agenda** the original; the binary is `agendum`.

## 1. Read before changing

```sh
last=$(git log -1 --format=%H -- docs/INDEX.md)   # the last tidy touched the index
git log --oneline "$last"..HEAD -- docs README.md CONTRIBUTING.md CLAUDE.md
wc -l README.md CONTRIBUTING.md CLAUDE.md docs/*.md docs/plans/*.md | sort -n
```

Read `docs/INDEX.md`, then the headings of every document (`grep -n '^#' FILE`), and in full the ones that changed or look suspect: README, CONTRIBUTING, ARCHITECTURE, ROADMAP, the plans' openings.

## 2. Up to date (first commit)

Run the drift checks; each hit is a lead, not a verdict:

```sh
python3 .claude/skills/tidy-docs/check_docs.py
```

It reports links, paths and modules that don't exist, `name/arity` with no such function, modules ARCHITECTURE.md doesn't list, core struct fields DATA_MODEL/JSON_FORMAT don't name, whether DATA_MODEL's format-version table has the current version, and every "planned / not done / not yet" claim. Check each claim against the code (`grep -rn` in `lib/`) and the roadmap's Done section; known false leads: `Agendum.Core.Facade.Area` (ADR 0023's placeholder), `press`/`screen`/`utc_today` (test helpers and the clock rule), `tools/dosbox/` (a plan kept as a record), `Agendum.TUI.KeysPropertyTest` (defined in `keys_test.exs`), `ov` (from "Nov/12/90" in SPEC), `docs/reviews/YYYY-MM-DD.md` (the expert-review skill's naming pattern).

Then look for what the script cannot see:

- **Recent decisions not carried through.** For each ADR and each user-visible change since the last tidy (step 1's log), grep the old behaviour across the documents (e.g. ADR 0032 removed ESC + digit: `grep -rni 'ESC.\{0,12\}digit'`).
- **Roadmap vs. code:** open items already built (tick and move them), plans whose status changed (DOSBOX_STAGING was done another way).
- **Status tables** that freeze a date (AGENDA_HISTORY's, a plan's Progress): bring them up to date and say when.
- **ARCHITECTURE.md:** a row for every module the script names; know-how that only lives in a finished plan (e.g. how to add a box) moves here.

Commit: "Docs brought up to date with the code", the body listing what was stale.

## 3. Streamlined (second commit)

Keep these in place, and repair them when they drift:

| Structure | Rule |
| --- | --- |
| `docs/INDEX.md` | Every document in `docs/` and `docs/plans/` with what it is for; "Where a change is written down" (a test checks the list is complete) |
| `docs/ROADMAP.md` | `## Open` first: a **Next:** line saying what comes next, then "Sharpen the saw" (tools, checks, ways of working), then by area (`###`); then `## Done` by milestone. One open item per piece of work: if a plan's steps are listed, nest them under one item and fold repeats into it |
| `docs/SPEC.md` | The rule index at the top: every rule, its title and its `## N.` section (a test checks); long paragraphs split under `###` headings without changing the wording |
| `docs/plans/*.md` | A `**Status:**` line right under the title: what is done, what is next, where it is tracked |
| Tables over walls | A long list run into one paragraph (a version history, a set of conventions) becomes a table or a list |
| Paths | In `docs/INDEX.md` and other ex_doc pages, link only to Markdown files `mix docs` publishes (`docs/*.md`, `docs/plans/`, `docs/adr/`, README, CONTRIBUTING, CLAUDE); write other files as repo-relative code paths (`` `docs/guide/index.html` ``), or ex_doc warns and the link breaks |

When moving many lines (the roadmap), do it with a script that takes each line by its text and asserts it was placed exactly once; then compare the counts of `- [x]` and `- [ ]` before and after, and explain any difference (a merged duplicate).

If the structure changes (a new index, a new roadmap layout), update the instructions that describe it: CLAUDE.md (workflow step 4), the `end-session` skill, and `docs/INDEX.md`'s "Where a change is written down".

## 4. Check and commit

```sh
mix check                       # includes the docs tests (names, SCREENS, the indexes)
mix docs 2>&1 | grep -A2 -i warn   # no link warnings
git status --short              # stage only what you changed: docs/reference/ holds the owner's untracked files
```

Commit: "Docs streamlined: …", the body listing each structural change. Then summarise for the owner: the two commits, what was stale, what moved where, what was deliberately left alone and why. The owner reviews the commits and reverts what they don't like.
