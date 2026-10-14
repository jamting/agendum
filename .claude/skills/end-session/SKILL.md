---
name: end-session
description: Close a working session on Agendum - review what was done (commits, uncommitted changes, open threads), record what is worth remembering (memory, docs/ROADMAP.md, plan documents), and give the owner a summary of the session's work with a cheerful compliment and recommended next steps. Use when the owner says they are ending the session, asks for a session summary or wrap-up, or types /end-session.
---

# End the session

The owner runs this at the end of a working session. It has three parts:
look back, write down what must not be lost, then report. Do not start new
work here. Small fixes to records (roadmap ticks, a plan's progress) are
fine; code changes are not.

## 1. Look at what was done

The session's work is what this conversation did, and the commits it made.

```sh
git status --short                      # anything not committed?
git log --oneline --since="12 hours ago" # today's commits (widen if the session was longer)
git diff --stat HEAD                    # size of uncommitted work, if any
```

Go through the conversation as well: what the owner asked for, what was
decided and why, what was tried and dropped, and what was left half done.
For each piece, note whether it is **done** (committed, `mix check`
passing), **paused** (and where it stops), or **only talked about**.

If there are uncommitted changes, say so; do not commit them unasked
unless they are finished and `mix check` passes (the owner's standing
rule: commit on your own once the checks pass).

Check what `CLAUDE.md` asks after a change and whether it happened:
`mix check`, the long fuzz run after a large TUI change
(`FUZZ_RUNS=3000 mix test test/agendum/tui/fuzz_test.exs`), a smoke test of
the real terminal after key or drawing changes, ROADMAP ticks, `SCREENS.md`
and the F1 help. List anything skipped; do not hide it.

## 2. Record what to remember

Write things down where the next session will find them. Prefer the repo
for anything about the project, and memory for how the owner works:

- **docs/ROADMAP.md**: tick what was finished; add bugs or ideas found on
  the way (with enough detail to act on later).
- **Plan documents** (e.g. `docs/REFACTORING.md`): update a "Progress"
  section for work that is paused: what is done, what is left, how to
  continue.
- **ADRs** (`docs/adr/`): a lasting decision made this session that has
  none yet.
- **Memory** (the memory directory in the system prompt): the owner's
  preferences and feedback learned this session, decisions not visible
  in the code, and a pointer to paused work ("resume from …"). Follow the
  memory rules: one fact per file, update rather than duplicate, link
  related memories, add a line to `MEMORY.md`, and remove memories that
  this session made wrong (e.g. paused work that is now finished).

Commit repo changes made here in one commit ("Session notes: …"), after
`mix check` if anything under `lib/` or `test/` was touched (normally
nothing is).

## 3. Report to the owner

Write the summary in the terminal (not a file), in this order:

1. **A cheerful compliment** about the day's work, one or two sentences,
   specific to what was actually achieved (name the thing, the number of
   commits or boxes, the bug squashed). Warm and a little playful is good;
   a light Hundred Acre Wood touch fits the project. Never invent
   achievements.
2. **What was done**: grouped by piece of work, each with its outcome and
   the commits (short hashes). Changes the owner will notice when using
   Agendum come first, then the inner work.
3. **Not done or skipped**: paused work and where it stops, checks that
   were not run, open questions for the owner. Plainly, no hedging.
4. **Remembered**: what was written to memory, the roadmap or plan
   documents in step 2, in one line each.
5. **Recommended next steps**: two to five, most valuable first, each one
   line with why. Prefer finishing paused work and closing skipped checks
   before new features. If something needs the owner (trying a habit
   change in the real terminal, a decision), say so.

Keep it short enough to read in a minute: headings and bullets, no
paragraphs of narration.
