# Running the real Agenda for Claude: DOSBox Staging

**Status:** done, differently (2026-10-14/15). The goal was reached by
another route than the one planned below: DOSBox Staging runs headless
(`SDL_VIDEODRIVER=dummy`) with its REST API, the screen is read as text
from video memory and keys are written into the BIOS keyboard buffer, so
neither `AUTOTYPE` nor `screencapture` is needed. The tool is
`tools/agformat/agenda_driver.py`, its notes
`tools/agformat/DRIVING_AGENDA.md`; CLAUDE.md ("Reference material") says
when to use it. What it cannot show is colour and pixels: for those the
owner's screenshots remain the source. The original plan is kept below
as a record. Written 2026-10-14 from a conversation between the owner and
Claude.

## Why

When the manuals leave a behaviour unclear (what ESC does in a box, how a
long list scrolls, which setting a key moves to), the owner runs Lotus
Agenda 2.0 in DOSBox Staging and takes screenshots
(`docs/reference/screens/`, transcribed in `notes.md`). That works, but
each question costs the owner a round trip.

If Claude could start the real Agenda, press keys in it and look at the
result, it could:

- check Agenda's own behaviour as it builds a feature, instead of guessing
  or asking;
- compare our screens with Agenda's side by side (CLAUDE.md, workflow step
  4) without new screenshots from the owner;
- turn a question into a repeatable scenario: the same keys, the same
  screen, every time.

## Why not a pseudo-terminal

The real terminal of Agendum is tested through a pseudo-terminal (Python
`pty`), because Agendum writes text. DOSBox does not: it draws the DOS
screen in a graphical window (SDL). A pseudo-terminal would show nothing.
So Claude needs a way to send keys to the DOSBox window and a way to see
the window.

## The plan

### Keys: DOSBox Staging's `AUTOTYPE`

DOSBox Staging has an `AUTOTYPE` command that types keys into the program
running in it, after a wait and with a pause between keys, for example:

```
AUTOTYPE -w 3 -p 0.3 f10 v c p
```

Each scenario is a DOSBox config whose `[autoexec]` mounts the Agenda
folder, queues the keys with `AUTOTYPE` and starts Agenda. Every run starts
from the same file and the same keys, so it is repeatable.

**To verify first:** that `AUTOTYPE` exists in the installed version
(`AUTOTYPE -list` should list the key names), that it reaches Agenda (it
queues keys for the next program), and that it covers what Agenda needs:
F1–F10, ALT- and SHIFT- combinations, ESC, ENTER, arrows, INS, DEL. If it
falls short, keys can be sent to the window with macOS's `osascript`
(System Events `key code`), which needs the Accessibility permission.

### Seeing it: macOS `screencapture`

`screencapture -l <window id> -o file.png` saves one window as a PNG (the
window id can be found with a few lines of Swift or Python and
`CGWindowListCopyWindowInfo`, or with a small helper). Claude reads PNGs as
images, as it reads the owner's screenshots now. Screenshots go in `tmp/`
(ignored by git).

DOSBox Staging can also take its own screenshot with a hotkey, but not from
a command, so `screencapture` is simpler for an unattended run.

### A script: `tools/dosbox/`

```
tools/dosbox/
  run.sh           start DOSBox with a scenario, wait, capture, quit
  agenda.conf      the shared settings (window size, no splash, mounts)
  scenarios/*.conf one [autoexec] each: the keys of one question
```

`run.sh SCENARIO SECONDS` would: copy the Agenda file to a scratch folder
(so every run starts from the same data), start DOSBox Staging with
`agenda.conf` and the scenario, wait, capture the window to
`tmp/dosbox/SCENARIO.png`, and quit DOSBox. Several captures in one run
(after each step) would need the keys split over waits.

## What the owner sets up (about 15 minutes)

1. **The Agenda folder:** where Agenda 2.0 and its sample files are
   installed. It stays outside git (Lotus's program), as the screenshots do;
   the script reads its path from an environment variable, e.g.
   `AGENDA_DOS_DIR`.
2. **Screen Recording permission** (System Settings ▸ Privacy & Security)
   for the terminal app Claude Code runs in, so `screencapture` may capture
   another app's window.
3. **The sandbox:** Claude's commands run in a sandbox that may not allow
   starting a graphical app or capturing the screen. Then each run needs the
   owner's approval to go outside it, or a permission rule for
   `tools/dosbox/run.sh` (the `update-config` skill sets that up).
4. **Accessibility permission**, only if `AUTOTYPE` cannot send the keys
   needed and `osascript` is used instead.

## Then

Claude writes the config and the script, checks `AUTOTYPE` and the capture
with one scenario (say, F10 V C P on the Activities view), and records how
to use it in CLAUDE.md (next to "Testing the real terminal"). Screenshots
it takes for a feature are described in `docs/reference/screens/notes.md`
as the owner's are.

If the sandbox or the permissions get in the way, nothing is lost: the
owner's screenshots on request keep working as now.

## Open questions

- Does `AUTOTYPE` in the installed version send ALT-F keys and SHIFT-F
  keys as Agenda expects?
- How long does Agenda take to start in DOSBox (the wait before the keys)?
- One window size for all captures (DOSBox's 720×400 like the owner's
  shots), so they compare alike.
