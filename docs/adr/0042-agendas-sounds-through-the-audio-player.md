# ADR 0042 — Agenda's sounds, played through the computer's audio player

**Status:** accepted · 2026-10-17 (the owner's choices: real tones with the terminal bell as fallback, all four kinds of sound, one Sound switch in the preferences). R76.

## Context

Agenda beeps through the PC speaker: a high and a low beep for automatic completion (one match, none), an error beep, a click for each key recorded in Learn mode, and a two-pitch tune for an alarm. Agendum rang the terminal's bell (BEL) for alarms and two "nothing more" cases, and nothing else; a `:bell` asked for by a key once crashed the shell (fixed the same day).

A terminal can make one sound only, the bell, as the terminal chooses it: the high and the low beep cannot be told apart there. Real pitches need the computer's audio. ADR 0021 allows no runtime package and no runtime files beside the single-file escript.

The tones were taken from Agenda itself. Its program (A.EXE) has one speaker routine, called with a frequency and a length in timer ticks; every call pushes constants, so the table is exact: 1200 Hz × 6, 140 Hz × 6, 225 Hz × 30, 225 Hz × 12, 75 Hz × 6, and the alarm's 3 × 520 Hz and 3 × 1040 Hz, 50 ticks each with 33 between. The routine waits on bit 13 of the PC timer's counter, about 3.43 ms a tick. Recordings of Agenda in DOSBox Staging (SDL's disk audio driver, `tools/agformat/DRIVING_AGENDA.md`) confirmed lengths and pitches, and that completion beeps once on reaching one match or none, not for every key.

## Decision

- The tones are data in `Agendum.TUI.Sound` (pure), which also writes each sound as a small WAV file (8-bit mono square wave) in memory.
- Which key makes which sound is decided purely, once per key, by comparing the state before and after it (`Agendum.TUI.Update.Sounds`), as undo is: a `{:sound, name}` effect. No key handler asks for a beep itself, except Learn mode's click where the key is recorded.
- `Agendum.TUI.Speaker` (the shell, impure) writes each WAV once to the system's temporary folder, named by a hash of its bytes, and plays it in the background with `afplay` (macOS), `paplay` or `aplay` (Linux). With no player, or over ssh (`SSH_CONNECTION` set: the sound would play on the far computer), it rings the terminal's bell.
- Every error message beeps. Agenda's shorter error beep (12 ticks) is not used: which of Agenda's refusals used which cannot be mapped onto Agendum's messages.
- Two preferences in File ▸ Customize: Sound (all of it) and Agenda's Beep on auto-completion. Both are the person's, not the file's (ADR 0008).

## Consequences

- No new dependency and nothing shipped beside the escript: the sounds are made from numbers when first played.
- A web front end plays the same tones from `Agendum.TUI.Sound`'s table (Web Audio) or its WAV bytes.
- Keys that show an error message now beep where they were silent; Sound No silences them.
- Windows, and Linux without PulseAudio or ALSA tools, get the terminal bell only.
