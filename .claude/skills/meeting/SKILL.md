---
name: meeting
description: Hold a panel meeting in Owl's house on the owner's own agenda (a classic Swedish dagordning in docs/meetings/dagordning.md, where the owner collects thoughts over time). The experts the agenda calls for (from the panel of expert-review: José, Joe, Carsten, Mitch, David, Russell, Marie and Claude) discuss each item with the owner, who decides; decisions go into the roadmap, plans and ADRs, and the worded agenda and the minutes (protokoll) are published in docs/meetings/YYYY-MM-DD/. Use when the owner calls a meeting, asks to go through the dagordning, or types /meeting.
---

# Panel meeting

The owner collects thoughts in `docs/meetings/dagordning.md` whenever they come, as roughly as they like. Calling a meeting turns them into decisions: the panel discusses each item, the **owner decides**, the decisions are written into the documents they belong in, and the meeting leaves two files behind: the agenda, worded properly, and the minutes.

This is not a review: nothing is scored, and the panel speaks only to the items on the agenda. It is also not a work session: **no code changes** during the meeting. A decision to build something becomes a roadmap item, built later in the usual way (CLAUDE.md, "Workflow for a feature").

## The people and the place

- **The panel and the setting** are those of the `expert-review` skill: read its sections "The panel" and "The setting" (`.claude/skills/expert-review/SKILL.md`) and follow them, including the rules on spelling, on spice (stage notes outside the substance) and on never quoting the real people (minutes report what was said).
- **Who attends depends on the agenda** ("Who attends" in `expert-review`): only the lenses whose subjects are on it, chosen in step 1. Owl and Claude are always there. A meeting on documents, scope or what to keep calls Little Marie-Who-Folds; one on keys and screens may need only Mitch, Carsten and David.
- **The owner chairs the meeting** and makes every decision. The panel advises and may disagree; it never votes. Owl hosts (it is his house) and keeps order, kindly; he does not decide.
- **Claude is the secretary**, and also sits on the panel with its own lens; it keeps the two roles apart in the minutes.

## The files

```
docs/meetings/
  TEMPLATE.md              the empty agenda (do not fill in)
  dagordning.md            the next meeting's agenda, where the owner writes
  YYYY-MM-DD/
    dagordning.md          the agenda as adopted, worded properly
    protokoll.md           the minutes
```

A second meeting on the same day gets `YYYY-MM-DD-2/`.

## 1. Prepare

1. Read `docs/meetings/dagordning.md`. Everything below the `---` line at its end is off topic: the owner's thoughts being prepared for a later meeting. Do not word, discuss, decide or minute them, and do not prepare them in step 3; they are not part of the agenda. If it has no items under "Items to discuss", say so and stop (offer to hold the meeting anyway if the owner has something to raise now; add it to the agenda first).
2. Read the newest `docs/meetings/*/protokoll.md`, if there is one: its decisions are followed up under § 4 (done, partly, not yet, dropped, with the commit or the roadmap line).
3. For each item, read what it touches before the meeting: the files and plans it names, the roadmap lines, `docs/VISION.md`, the ADRs, the relevant code, the newest review in `docs/reviews/`. A view given at the meeting needs evidence (`path:line`, a document) as in a review. Where an item asks how Agenda did something, check it (the reference texts, or Agenda run headless, as CLAUDE.md describes).
4. **Word the agenda.** Give each item a short heading that says what is to be decided or discussed, number it from § 5, and write its background in two to five plain sentences, keeping all of the owner's meaning: nothing dropped, nothing added that they did not raise. Their own questions stay as questions. Several notes on one subject may become one item; one note on two subjects becomes two. Correct spelling and grammar. English, as `docs/` is, unless the owner asks for Swedish.
5. **Choose who attends**: for each item, the lenses with something distinct to say; the meeting's attendance is their union. Usually three to five, rarely all.
6. Show the worded agenda in the terminal (headings and one line each), and who is invited, for § 3, adoption: the owner may reorder, add, strike or merge items, and invite or excuse an expert.

## 2. Hold the meeting

Go through it in order, one item at a time, in the conversation; do not run ahead to the next item before the owner has decided this one.

- **§ 1 Opening, § 2 Elections, § 3 Adoption of the agenda**: a few lines; the owner is chair, Claude secretary, two panel members approve the minutes. Most of the setting lives here.
- **§ 4 The previous minutes**: the follow-up of earlier decisions, as a table. Nothing to decide unless something is stuck.
- **Each item (§ 5 onwards)**:
  1. Claude presents it: the worded background and what the evidence says, in a few lines.
  2. The panel speaks: the two to four attending lenses with something distinct to say, each in a few sentences with evidence; say where they disagree. Not every lens on every item.
  3. The panel's advice, if it has one, as one sentence.
  4. **The owner decides.** When the choices are clear, ask with `AskUserQuestion` (two to four options, the panel's advice first, marked "(Recommended)"); otherwise ask in plain text and wait. The owner may discuss before deciding: answer, and record the gist.
  5. Record the outcome as one of:
     - **Decided**: what was decided, in one or two sentences.
     - **Tabled** (bordlagt): to the next meeting; it is carried over to the next agenda with what was said.
     - **Referred**: to be investigated first (a plan document, an experiment in Agenda, a measurement), with where it goes.
     - **Noted** (lades till handlingarna): discussed, nothing to decide.
  - A decision that changes what a key or behaviour does for someone already using Agendum: list those habit changes before the owner decides (CLAUDE.md, workflow step 0).
- **Any other business**: ask whether the owner has anything more; new items get the same treatment, or are tabled to the next agenda.
- **Next meeting**: when, if the owner says; otherwise "when the agenda has enough items".
- **Closing**.

## 3. Write the decisions where they belong

After the closing, before the minutes, put every decision in its home, each citing the meeting (`meeting 2026-10-20, § 6`):

- **Work to do**: a roadmap item in its area (`docs/ROADMAP.md`; tools and ways of working under "Sharpen the saw"); keep the **Next:** line true if the order of work changed.
- **A plan's question answered, or a new plan**: the plan document in `docs/plans/` (its status line too); a new plan gets a row in `docs/INDEX.md`.
- **A lasting decision** (how something is built, a principle): an ADR in `docs/adr/` with the next number, if the owner agrees it is one; listed where ADRs are listed (`docs/ARCHITECTURE.md`).
- **Direction**: `docs/VISION.md`.
- **How Claude should work**: a memory.

`docs/INDEX.md`, "Where a change is written down", says what else a kind of change touches. Nothing under `lib/` or `test/`.

## 4. Write the agenda and the minutes

`docs/meetings/YYYY-MM-DD/dagordning.md`: the agenda as adopted (after § 3), with the worded backgrounds; the owner's own notes are no longer needed beside it, since nothing of their meaning was dropped.

`docs/meetings/YYYY-MM-DD/protokoll.md`:

```markdown
# Minutes of the panel meeting, YYYY-MM-DD

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); <the experts invited, e.g. Old Mitch Lilypad,
Little Marie-Who-Folds>, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** <two panel members>
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `<hash>`

<a short italic paragraph: the setting as the meeting starts, and the
note that the panel's voices are lenses in the spirit of the named
people, written by Claude, not their words; made with the `meeting`
skill>

## § 1 Opening of the meeting
## § 2 Election of a chair, a secretary and two approvers
## § 3 Adoption of the agenda
## § 4 The previous minutes        (table: Decision | Status | Evidence)
## § 5 <item heading>
**Background.** <the worded background>
**Discussion.** <what each lens said, reported: "**Joe** observed
that …"; what the owner said, likewise; where they disagreed>
**Decided** / **Tabled** / **Referred** / **Noted:** <the outcome>
## § 6 …
## § N Any other business
## § N+1 Next meeting
## § N+2 Closing of the meeting

## Decisions and where they are recorded
| § | Decision | Recorded in |    (roadmap area, plan, ADR, memory; "—" for noted)

*Minutes kept by Claude. Approved by <the two approvers>.*
```

The owner's words are reported as faithfully as the panel's ("The chair said that …"). Plain language, short sentences, correct spelling (read the file once for spelling alone, as in `expert-review`). Stage notes in italics, one or two per item at most, never inside a background, a decision or the table.

## 5. Start the next agenda

Replace `docs/meetings/dagordning.md` with `docs/meetings/TEMPLATE.md`, and put every **tabled** item back under "Items to discuss", with a line saying it was tabled at this meeting (and why, in a few words), and the next meeting's date as "Wished date" if one was set. Copy everything below the `---` line over unchanged: the owner moves an item up when they want it discussed.

## 6. Commit and report

- `mix test test/agendum/docs_index_test.exs` if a document was added under `docs/` or `docs/plans/`; nothing under `lib/` or `test/` changed, so `mix check` is not needed.
- One commit, with explicit paths (never `git add docs`): the meeting's folder, the reset agenda, and every document a decision was written into. "Panel meeting YYYY-MM-DD", the decisions listed in the body.
- In the terminal: the decisions, each with where it was recorded; what was tabled or referred; the path to the minutes.
