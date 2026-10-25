# Driving Lotus Agenda remotely (DOSBox Staging)

Practical notes for running the real Agenda 2.0 unattended, to check how it behaves or to make test files for the `.AG` format research (`docs/AGENDA_FILE_FORMAT.md`, log in `docs/plans/archive/AGENDA_FILE_FORMAT_LOG.md`). The driver is `agenda_driver.py` in this directory.

## Setup

- **Always work on a copy** of the install (`~/Dosbox/APPS/AGENDA`), never the original. Copy it to a scratch directory as `<root>/APPS/AGENDA` and set `AGENDA_DOS_ROOT=<root>`; the driver mounts `<root>` as `C:`.
- DOSBox Staging 0.83 runs without a window (`SDL_VIDEODRIVER=dummy`) and exposes emulated memory on `http://127.0.0.1:8765/api/v1/memory` (`[webserver] webserver_enabled=true` in the generated `run.conf`).
- `d.start("AGENDA NAME")` opens or creates `C:\APPS\AGENDA\NAME.AG`. **Names must fit DOS 8.3**: a longer name is truncated by DOS and Agenda silently creates a *new empty file* (it shows the "New File" box). Use short fixed names (`XP`, `SS`) and copy the result to a descriptive name.
- DOSBox keeps running after the Python process that started it exits, so one Agenda session can be driven from many separate Python calls (the driver talks HTTP; only `stop()` needs the process handle; use `pkill -f "DOSBox Staging"` to kill a session started elsewhere).
- Only one DOSBox at a time: they share port 8765.

## Reading the screen

- `screen()` returns 25 lines of text from `B800:0000`. Every line starts with a space column; compare with `.strip()`.
- Line 0 is Agenda's prompt/help line (it says what the current field is for); line 1 is `View: <name>` in a view: **a reliable "no box is open" test**. While a menu is open, lines 0–1 are the menu.
- Attributes tell what is selected. In settings boxes the **label of the current field is drawn with attribute `0x3F`** (bright white on cyan); everything else in the box is `0x31`/`0x30`. Reading the characters with that attribute gives the current field's label, which is how `goto(label)` finds a field without counting ↓ presses.
- In lists (category manager, filter picker) the highlighted row has an attribute different from all other rows in that column; `select(text)` uses this. Skip rows 0–1 and the column-head row: a column head with the same text (e.g. "When") otherwise matches first.
- **`select(text)` can be fooled in a view** (2026-10-23): in a datebook the slot heads are `0x71` and item rows `0x70`, so a lone item row "differs from the others" without being highlighted, and F4 then went to the slot head. In views, check the highlight itself: the highlighted item row has `0x4F` (`attr_at(row, col) == 0x4F`), pressing ↓ until it does; read the result from a saved file (`agdump.py`) rather than the screen when a symbol (√, ♪) is not plain ASCII.

## Typing keys

- Keys go into the BIOS keyboard buffer (`0040:001E–003D`); Agenda reads the BIOS, so F-keys, ALT and CTRL combinations all work. The buffer holds 15 keys; the driver waits for room.
- Call `idle()` (buffer empty and screen stable for 0.3 s) before reading the screen. Keys typed while a box is still opening are **lost**: open a box, `idle()`, then move in it.

## Settings boxes (as Agenda 2.0 does them)

- SPACE cycles a choice field (Yes/No, Inside/Outside …); F3 opens the choices list (HOME, ↓ n, ENTER picks the n-th entry).
- A field shown as `...` opens a sub-box with **F3** (ENTER would accept the whole box).
- ↓/↑ move between fields in the left column; fields on the same row to the right (e.g. "Sort n/a's" beside "Order", "Filter" beside "Number items") are reached with →.
- Text fields: F2 enters edit mode; END, then BACKSPACE × n clears; ENTER accepts the field and stays in the box. Typing directly also starts an edit.
- **Category-name fields autocomplete**: the prompt line shows "1 of 1 matching categories. Current choice: …". Typing a name that does not exist **creates that category** when the box is accepted (Agenda's normal behaviour), so a stray keystroke in such a field leaves a new category in the file.
- A box refuses to close while a required field is empty (e.g. "Category note" sorting without a category); ENTER then does nothing visible.
- ESC cancels the box. Never send ESC "to be safe" before checking the screen: it throws the change away.

## Getting the file

- **File Save writes a complete, consistent file without quitting** (`F10 f s`, ENTER on the Save File box). One Agenda session can therefore run many experiments: change, save, copy `NAME.AG`, diff against the previous save. Much faster than restarting DOSBox for each change.
- A file saved in a running session has no trailer and may have extra link pages; `agdump.py` reads it the same way.
- A few words change on every save and are noise in diffs: header `0x5C` (save counter), `0x60`, `0x1EE`, the dates at `0x168`/`0x170`, the header range `0x1F4–0x210` (last values used in boxes), view word w20 bit `0x400` and section word w12 bits `0x10`/`0x8000` (display state).
- Quit (`F10 q`) also saves; DOSBox then exits (the `exit` in `run.conf`), so do not read the screen after it.

## Robust batch runs

- An interrupted script leaves Agenda wherever it was: a box still open, a menu, edit mode. The next script's keys then land in the wrong place (`F10 v p` typed into a category field creates categories `v`, `p`…). **Start every experiment with `home()`**: ESC until line 1 reads `View:`.
- The DOSBox web server occasionally stalls a request; `urlopen` needs a timeout and a retry, or the script hangs forever.
- Run long batches one experiment per process (`timeout 90 python3 …`), appending results to a log, in the background; watch the log rather than the process. Use `python3 -u`: piped output is otherwise buffered and nothing shows until the end.
- Agenda's edit fields: one BACKSPACE costs ~0.7 s through the driver; clear only as many characters as the field holds. Typing into a field without F2 **replaces** its content (simplest for numbers: "Which one: 3"); F2 edits the existing text.
- **Keys are occasionally lost** (the key word and the buffer's tail pointer are written by two separate HTTP requests, racing the BIOS). Check the screen after each step of a key sequence that matters, the way `robust_save()` checks `F10` → menu, `f` → `Retrieve…`, `s` → "Save File" box, ENTER → view, and retries from `home()` otherwise.
- Speed: `idle()` (two equal screen reads 60 ms apart) dominates; a key costs ~0.3–0.7 s. A box setting experiment (open box, change one field, close, save, diff) takes about 8 s.
- `goto(label)` walks ↓ in the left column, then → and ↓ in the right column, stopping when the `0x3F`-attribute label matches. Fields that appear only for some settings ("Which one", "Sequence") show up after the setting that enables them is chosen.

## Beeps

Agenda beeps on errors (an invalid date, an unknown key). The PC speaker is driven through I/O port `0x61` (and the timer at `0x42/0x43`), not memory, so the memory API cannot see a beep. In practice Agenda shows a message on line 0 or a box with the beep, which `screen()` reads. To hear them (done 2026-10-17 for R76), start DOSBox with sound on (`[mixer] nosound=false`, `rate=48000`; `[speaker] pcspeaker=impulse`) and SDL's disk audio driver: `SDL_AUDIODRIVER=disk`, `SDL_DISKAUDIOFILE=out.raw`, and `SDL_DISKAUDIODELAY=10` (without the delay SDL pulls audio as fast as it can and writes gigabytes in seconds). The file is raw 32-bit float stereo at 48 kHz; runs of samples above a threshold are the beeps, their length in samples ÷ 48000 their duration (DOSBox's start shifts them about 4.4 s after the driver's clock). Zero crossings give the pitch roughly; a 20 ms tone of 75 Hz is too short for them.

The tones themselves are constants in A.EXE: its speaker routine is at file offset `0x5C38` (frequency and length in timer ticks of about 3.43 ms, pushed as two words before a far call; `0x1234DC`-style divisor, ports `0x43`/`0x42`/`0x61`), with small wrappers at `0x67B2` (high, 1200 Hz), `0x67C7` (low, 140 Hz), `0x67DC` and `0x67EA` (225 Hz, 30 and 12 ticks), the Learn click at `0x2A298` (75 Hz) and the alarm at `0x25293`. ADR 0042 has the table.

## An experiment, start to finish

```python
# AGENDA_DOS_ROOT=<scratch>/dos, holding a copy of APPS/AGENDA
import shutil, agenda_driver as d
from agdump import AgendaFile
from agdiff import diff

AG = d.AG + "/SS.AG"                      # short DOS name, see above
shutil.copy("base.ag", AG)
d.start("AGENDA SS"); d.idle()

def snap(path):                            # save without quitting, keep a copy
    d.robust_save(); shutil.copy(AG, path); return path

before = snap("e00.ag")
d.home(); d.keys("F10"); d.idle(); d.keys("v"); d.idle(); d.keys("p"); d.idle()
d.setf("Hide done items")                  # SPACE on the field with that label
print([l for l in d.screen() if "Hide done" in l])   # the new value, as a check
d.keys("ENTER"); d.idle()
after = snap("e01.ag")
diff(AgendaFile(open(before, "rb").read()), AgendaFile(open(after, "rb").read()))
#  blk 11 t4: w20:0x400->0x1       <- view block 11, word 20: bit 0x1 = hide done
#  blk 15 t6: w12:0x3->0x13        <- display state (0x400 and 0x10 are noise)
d.home(); d.keys("F10", "q"); d.stop()
```

The second round (2026-10-15) ran about 150 experiments this way, in batches of 5–30 per script, each printing the field's new value and the diff into a log; the format tables were read from those logs.

## Menus and the note editor (2026-10-15)

- **Walking the F10 menu safely.** A highlighted entry's help on line 1 is a comma-separated list of names ("Retrieve, Save, Abandon …") when it opens a submenu, and a sentence when it runs a command. So enter an entry only when its help is such a list, and read each leaf's help by moving onto it with → and nothing else. Start every path from the view (ESC until line 1 says `View:`), then F10 and the letters. The whole view menu was walked this way in about four minutes (`docs/reference/AGENDA_MENUS.md`).
- **`capture_menus.py`** does this walk for the view's, the note editor's and the category manager's menus (the note reached with F5, the manager with F9), checking each level's first entry against the help line before going on, and writes `docs/reference/agenda_menus.json` and the lists in `AGENDA_MENUS.md`. About five minutes; it ends by killing DOSBox, so the copy is never saved. The help line of a submenu sometimes spells its entries out in full ("Prerequisites, Dependents" for Prereqs, Depends): only the first is compared.
- **Holding a key** (2026-10-24): Agenda reads the BIOS shift flags at `0040:0017`, so writing a bit there is a held key to it (ALT `0x08`, CTRL `0x04`, left SHIFT `0x02`; write `0` to let go). That is how the ALT, CTRL and SHIFT key bars were read. **`capture_key_bars.py`** reads the bar's ten slots in a view, a note (F5), the category manager (F9) and the view manager (F8), with nothing held and with each of the three, and writes `docs/reference/agenda_key_bars.json`. About a minute; it kills DOSBox at the end.
- **One experiment per fresh start.** Long chains of keys in the note editor go out of step: an extra ESC leaves the note, and an ESC in a changed note opens "Discard changes? No". Copy the file again and restart Agenda for each experiment (about ten seconds each), and print the screen after every step.
- **Boxes with a file name** (note Import, Export, File Attach) need two ENTERs: the first finishes typing the field, the second the box.
- **ALT-letter keys sent after typed text** were not reliable in the note editor (ALT-C and ALT-N showed other boxes). Pause before them, or check the key in the F1 help instead ("Notes: Accelerator Keys").

## Settings boxes as text (2026-10-25)

- **`capture_boxes.py`** opens each box in its table from PLANNER's People view (menu keys, `goto(label)` + F3 for a box opened from a box, `select(name)` in the category manager) and writes its title, rows and bottom edge to `docs/reference/agenda_boxes.json`. About four minutes for 25 boxes; naming boxes on the command line recaptures only those, merged into the file.
- **Finding the box on top.** A box is found from its bottom edge ("Press ENTER when done…", "Press any key to continue") and followed up its side edges. A box opened from a box can share its edges with the one beneath (Advanced Settings sits one column inside Category Properties' right edge), and Agenda draws a statistics box on the top edge of the box beneath it, its title replacing that box's: the side edge is the `#` with a blank inside it, and the top is the first row of the box's width that is all edge.
- `goto()` does not reach a right-hand field such as File Properties' Auto-assign settings: go to the field beside it and press →.
