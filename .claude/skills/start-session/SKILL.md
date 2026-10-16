---
name: start-session
description: Open a working session on Agendum - read where the last session stopped (the newest summary in docs/summaries/, its next steps and "what you'll notice"), the roadmap's Next line, the study plan's progress, paused work in memory and anything uncommitted, then offer the owner a short list of the most useful things to do now and wait for a choice. Use when the owner says they are starting a session, asks "where were we" or "what should I do now", or types /start-session.
---

# Start the session

The owner runs this at the start of a working session. Sessions end with a ritual (`end-session`); this is its mirror: pick up the thread, choose one thing, begin. **Do not start any work here**: read, then offer, then wait for the owner's choice. The whole report must read in half a minute.

## 1. Read where things stand

Quietly, without narrating each step:

```sh
ls docs/summaries | tail -1                      # the newest summary
git status --short                               # anything not committed?
git log --oneline -5                             # the last commits
git log -1 --format=%cr                          # how long since the last commit
git remote -v                                    # is there a backup off this Mac?
```

- **The newest summary** in `docs/summaries/`: its "Recommended next steps", its "Not done or skipped", and its "What you'll notice when using Agendum" (things the owner has not tried yet).
- **`docs/ROADMAP.md`**: the **Next:** line, and any open bug.
- **`docs/study/STUDY_PLAN.md`**: the current unit, ticked / total, and the first unticked question.
- **Memory**: paused work ("resume from …") and decisions waiting for the owner.
- **The newest review** (`docs/reviews/`) only for resolutions the newest summary says are still waiting for a decision.
- **Uncommitted changes**: say what they are, except `docs/meetings/dagordning.md`, which is the owner's running notes and is never mentioned (memory: ignore dagordning).

Check whether the summary's facts still hold (a step may have been done since, in a commit after it); don't offer what is already done.

## 2. Offer

In the terminal, in this order, short:

1. **Where we stopped**: one or two lines (the last session's main outcome and date, how long ago).
2. **Try first** (only when there is something): the changes from the last session the owner has not tried in the real program, as a short list of keys to press. Five minutes in the program before new work keeps understanding level with the code (`docs/HOW_I_WORK.md`, "The loop for a feature", step 8).
3. **Choose one**: at most three options, most valuable first, each one line with why and a rough size (S, M, L). Prefer, in this order: a risk to the owner's data or work (a known data-losing bug, no backup); paused or half-done work; a decision the owner owes (a habit change to settle, review resolutions to sort); the roadmap's **Next:**. One of the three may be a study question ("help with 2.1.1"), as a small dose before building.
4. **Warnings**, if any, one line each: uncommitted work that is not the dagordning, a failing or skipped check from last time, no git remote.

End with a plain question: which one? Then stop, and wait for the answer.

## 3. When the owner chooses

Go on with the normal workflow for that kind of work (CLAUDE.md, "Workflow for a feature", or the skill it names: `study-plan`, `meeting` …). If the owner chooses something not on the list, that is fine: the list is an offer, not a plan.

Nothing is written or committed by this skill.
