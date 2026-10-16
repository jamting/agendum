# ADR 0027 — A debug log of each session

**Status:** accepted · 2026-10-13

## Context

A crash in the terminal UI leaves only Elixir's report behind. It says where the program failed, but not which keys led there, which box was open or what the file held. The developer screen (ESC ?) shows the state but is gone once the program has crashed. Bugs found while using the program are therefore hard to reproduce, by the owner or by Claude.

## Decision

- `Agendum.TUI.DebugLog` writes a log of each session when the `AGENDUM_LOG` environment variable is set: `1` (or any word) to `$XDG_STATE_HOME/agendum/logs`, default `~/.local/state/agendum/logs` (logs are state, not configuration); a path to that folder. Unset, empty or `0` is off, and nothing is written.
- One file a session, named by its start time. Starting a session deletes all but the newest four, so five are kept.
- It logs the program (version, the git commit it was built from and dev or prod build), Elixir, OTP, OS, terminal and arguments; every input as raw bytes and decoded keys, with the boxes open; the keys a macro plays; the effects `App` runs and how long each took (text written to a file counted, not copied; a calendar read too); new messages and errors; terminal resizes; the file in use with its size and, on disk, its bytes, time and a fingerprint (at the start, and when another is opened or saved under a new name); answers to keys that took 100 ms or more, from the key's arrival to the screen drawn (split into waiting, update and draw; added 2026-10-15 to find lag felt in use), with the view on screen (its sections and filters) and the garbage collections and memory during the answer; and a crash: the stack trace and the state as `DevTools.lines/2` shows it, with the mode stack. After a crash the CLI prints the log's path.
- Each line is written to disk before the next key (no delayed write), so a crash cannot lose the lines before it. The open file is a registered process, so the pure code is untouched and `App` does not carry it around.
- Logging never stops the program: a log that cannot be opened is left off.

## Consequences

- What is typed (item text, notes) is in the log. It stays on this computer, it is off by default, and only five sessions are kept.
- `DebugLog` is a new module of the imperative shell, with `App` and `CLI` its only callers.
- Not a preference: it is for debugging on one computer, not a setting of the program, so it lives in the environment, not in File ▸ Customize.
- A lag is found by replaying the log's keys on the same file: the commit says which code ran and the fingerprint whether the copy is the file the session began with (added 2026-10-15, after the first lag found this way took a replay to learn which view was open).
