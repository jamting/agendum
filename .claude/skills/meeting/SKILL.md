---
name: meeting
description: Hold a panel meeting in Owl's house on the owner's own agenda (the thoughts they put under Next meeting in their Agendum project file, read with mix agendum.thoughts; a classic Swedish dagordning). The experts the agenda calls for (from the panel of expert-review: José, Joe, Carsten, Mitch, David, Russell, Marie and Claude) discuss each item with the owner, who decides; decisions go into the roadmap, plans and ADRs, and the worded agenda and the minutes (protokoll) are published in docs/meetings/YYYY-MM-DD-HHMM/. Use when the owner calls a meeting, asks to go through their thoughts with the panel, or types /meeting.
---

# Panel meeting

The owner collects thoughts in their own Agendum project file whenever they come, as roughly as they like (meeting 2026-10-22-2130, § 7b): a Thoughts category whose child Next meeting holds what they want brought up, read with `mix agendum.thoughts` (the file's path is in `$AGENDUM_PROJECT_FILE`). The Markdown file `docs/meetings/dagordning.md` they used before is retired (meeting 2026-10-22-2309, § 3). Calling a meeting turns them into decisions: the panel discusses each item, the **owner decides**, the decisions are written into the documents they belong in, and the meeting leaves two files behind: the agenda, worded properly, and the minutes.

This is not a review: nothing is scored, and the panel speaks only to the items on the agenda. It is also not a work session: **no code changes** during the meeting. A decision to build something becomes a roadmap item, built later in the usual way (the `feature` skill).

## The people and the place

- **The panel and the setting** are those of the `expert-review` skill: read its sections "The panel" and "The setting" (`.claude/skills/expert-review/SKILL.md`) and follow them, including the rules on spelling, on spice (stage notes outside the substance) and on never quoting the real people (minutes report what was said).
- **Who attends depends on the agenda** ("Who attends" in `expert-review`): only the lenses whose subjects are on it, chosen in step 1. Owl and Claude are always there. A meeting on documents, scope or what to keep calls Little Marie-Who-Folds; one on keys and screens may need only Mitch, Carsten and David.
- **The owner chairs the meeting** and makes every decision. The panel advises and may disagree; it never votes. Owl hosts (it is his house) and keeps order, kindly; he does not decide.
- **Claude is the secretary**, and also sits on the panel with its own lens; it keeps the two roles apart in the minutes.
- **Private passages** follow `expert-review`'s rule of that name: this repository is public, so an item or a part of one that is private is written into the Wolery's `docs/meetings/YYYY-MM-DD-HHMM/private.md` (the Wolery's path is in `CLAUDE.local.md`), and the public agenda and minutes show the creek line in its place.

## The files

```
docs/meetings/
  TEMPLATE.md              the form for a meeting's worded agenda (copy it, do not fill it in)
  YYYY-MM-DD-HHMM/
    dagordning.md          the agenda as adopted, worded properly
    protokoll.md           the minutes
```

The folder is named by the date and time the meeting opens, from `date '+%Y-%m-%d-%H%M'` (like the session summaries): `docs/meetings/2026-10-28-0908/`. A meeting is referred to by that name, "meeting 2026-10-28-0908, § 5".

## 1. Prepare

1. Run `mix agendum.thoughts --next-meeting`: each thought it lists (with its note) is an item to discuss. The other thoughts in the file are off topic, being prepared for a later meeting: do not word, discuss, decide or minute them, so the task is run without `--next-meeting` only if the owner asks. If `AGENDUM_PROJECT_FILE` is not set or the file cannot be read, the task says so: ask the owner. If there are no thoughts for the meeting, say so and stop (offer to hold the meeting anyway if the owner has something to raise now; add it to the agenda first).
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
  - A decision that changes what a key or behaviour does for someone already using Agendum: list those habit changes before the owner decides (the `feature` skill, step 1).
- **Any other business**: ask whether the owner has anything more; new items get the same treatment, or are tabled to the next agenda.
- **Next meeting**: when, if the owner says; otherwise "when the agenda has enough items".
- **Closing**.

## 3. Write the decisions where they belong

After the closing, before the minutes, put every decision in its home, each citing the meeting (`meeting 2026-10-20, § 6`):

- **Work to do**: a roadmap item in its area (`docs/ROADMAP.md`; tools and ways of working under "Sharpen the saw"), or for parity work an item in `docs/plans/AGENDA_PARITY.md` § The steps, in its place in the order; keep the roadmap's **In order** list true if the order of work changed.
- **A plan's question answered, or a new plan**: the plan document in `docs/plans/` (its status line too); a new plan gets a row in `docs/INDEX.md`.
- **A lasting decision** (how something is built, a principle): an ADR in `docs/adr/` with the next number, if the owner agrees it is one; listed where ADRs are listed (`docs/ARCHITECTURE.md`).
- **Direction**: `docs/VISION.md`.
- **A private decision**: the Wolery's private plans, never a public document; the public table of decisions shows the creek line in its row.
- **How Claude should work**: a memory.

`docs/INDEX.md`, "Where a change is written down", says what else a kind of change touches. Nothing under `lib/` or `test/`.

## 4. Write the agenda and the minutes

`docs/meetings/YYYY-MM-DD-HHMM/dagordning.md`, made from `docs/meetings/TEMPLATE.md`: the agenda as adopted (after § 3), with the worded backgrounds; the owner's own notes are no longer needed beside it, since nothing of their meaning was dropped.

`docs/meetings/YYYY-MM-DD-HHMM/protokoll.md`:

```markdown
# Minutes of the panel meeting, YYYY-MM-DD-HHMM

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

## 5. The thoughts after the meeting

The task only reads the project file, so the owner changes it in Agendum: a thought the meeting decided, noted or referred is marked done (F4); a **tabled** one is left under Next meeting, not done, so it comes up again at the next meeting (the minutes say why it was tabled). List both in the report (step 6).

## 6. Commit and report

- `mix test test/agendum/docs_index_test.exs` if a document was added under `docs/` or `docs/plans/`; nothing under `lib/` or `test/` changed, so `mix check` is not needed.
- One commit, with explicit paths (never `git add docs`): the meeting's folder and every document a decision was written into. "Panel meeting YYYY-MM-DD-HHMM", the decisions listed in the body (the private ones only as "one private item").
- If there were private passages: one commit in the Wolery (`git -C <the Wolery>`) with its `private.md` and the private plans changed, the same message with the private decisions listed, then a push there.
- In the terminal: the thoughts the meeting handled, for the owner to mark done (F4) in Agendum, and those tabled, to leave under Next meeting; the decisions, each with where it was recorded; what was tabled or referred; the path to the minutes.
