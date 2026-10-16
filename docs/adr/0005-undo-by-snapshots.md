# ADR 0005 — Undo by database snapshots, recorded automatically

**Status:** accepted · 2026-10-10 (recording a decision made on 2026-10-08)

## Context

Agenda 2.0 had no general undo, but a modern user expects one, and many operations here change several things at once: assigning an item can unassign it from an exclusive sibling, run conditions and follow category links. Writing an inverse for every operation would be large and easy to get wrong. Because the database is an immutable value (ADR 0001), keeping old values is cheap: unchanged parts are shared between versions.

## Decision

- `Agendum.TUI.History` keeps up to 100 snapshots. A snapshot is the previous `Database` plus where the user was (view and cursor).
- Recording is automatic: `Update.handle/2` compares the database before and after every key, and records one step if it changed. One key press is one user action, which is one database change and one undo step.
- A key that does two things the person would undo separately may end a step partway (`State.end_step/1`, added 2026-10-15): History then records the two parts as two steps, still by comparing databases, not by hand. The first replacement in a note uses it, so that the typing before it is not undone with it.
- Undo and redo themselves, loading or starting a file, and the clock (alarms ringing) do not record steps.
- Undo works in views and in the category and view managers, not while typing or inside a box that is about one particular item.

## Consequences

- Every new feature gets undo for free, as long as one user action is one database change. CLAUDE.md says so, and that is the rule to keep: never record history by hand.
- Long edits inside one screen, such as a whole note editing session, are one undo step, because the note is saved when it closes (Search/Replace in a note saves it at each replacement, so those are steps of their own).
- Undo lives in the TUI, not in `Agendum.Core`. A web front end (planned) must keep its own history, or this module moves to the core first. The snapshot approach itself carries over unchanged.
- Memory use is bounded by the 100-step limit and by structural sharing.
