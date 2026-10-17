# Plan: the note editor as Agenda's (2026-10-15)

**Status:** researched in Agenda 2.0 (2026-10-15); the six habit changes settled by the owner (2026-10-17); steps 1 to 6 done (R64a–R64f, 2026-10-17); v0.15.0 waits for the owner to try it; open: GETITMS's discard question, and whether to build step 7 at all (needs an ADR) (ROADMAP, The note editor).

Agenda's note editor (F5) is a screen of its own: its own control panel, its own key bar and its own F10 menu. Agendum's note editor has the text editing, marking and Search/Replace, but keeps the view's control panel and has no menu. This plan maps what Agenda's editor does, sets printing and typesetting out of scope, and lists the steps for the rest: some new, some only a connection to a feature Agendum already has.

The macro editor (F2 in the macro manager) is the same editor in Agenda, and in Agendum (`{:macro, id}` notes), so every step below applies to it too unless it says otherwise.

## What Agenda does (the evidence)

Checked in the real Agenda 2.0 (headless, on a copy of PLANNER, 2026-10-15), and in its F1 help ("Note Editor", "Notes: Accelerator Keys", "Discard Note/Macro Changes Box", "Note/Macro File Not Found Box"):

| What | Agenda | Source |
| --- | --- | --- |
| Control panel, line 1 | `Note for:   <item text>` on the left; `Line    1 INS EDIT` on the right: the line the cursor is on, INS or OVR, EDIT | tried |
| Control panel, line 2 | `Note file:  C:\APPS\AGENDA\IN.TXT` when an external file is attached; `Font: Generic 10.0 pitch  Attr: Normal` on the right | tried |
| Key bar | F1 Help, F2 Paste, F3 Copy, F4 Cut, F5 Return, F6 Marker, F7 Mark, F10 Menu | tried |
| F10 menu | File (Attach, Detach, Erase), Print (Final, Preview, Layout, Setup, Named), Import, Export, Clear, Return, Quit | tried |
| Import | A box: File name (F3 lists files) and "Strip carriage returns: No"; the file's text goes in at the cursor, the cursor after it | tried |
| Export | A box: File name (F3 lists, INS creates); writes the note as a text file (CR LF line ends) | tried |
| Clear | A question "Clear all text from the note?  Yes"; Yes empties the note | tried |
| Return / Quit | Return = F5 (save and back); Quit = ALT-Q (save and quit Agenda) | tried |
| File Attach | A box: File name; the note is then kept in that text file (the file's text replaces what is shown; edits are written to the file); line 2 shows "Note file:" | tried |
| File Detach | "Detach the existing note file?  No"; Yes keeps the note in the Agenda file again | tried, help |
| File Erase | Erases the attached file from the disk | menu help |
| A missing attached file | "Note file was not found. Create a file?" Yes creates it; No does not open the note | help |
| ESC | With changes: "Discard changes?  No". No (ENTER) leaves and saves; Yes leaves and restores the note as it was when opened. File commands (Attach, Import …) are not undone either way | tried, help |
| INS | Switches Insert and Overwrite (INS / OVR in the control panel) | tried |
| TAB | Spaces to the next tab stop; File Properties ▸ Tab size (5 in PLANNER) | tried, help |
| ENTER, ALT-M | A new line | help |
| CTRL-BACKSPACE, ALT-W | Delete the previous / the next word | help |
| CTRL-ENTER | Delete from the cursor to the end of the line | help |
| PGUP, PGDN | Up / down a page | help |
| CTRL-← CTRL-→ | A word left / right | help |
| CTRL-HOME, CTRL-END | The start / end of the note | help |
| F7, F3, F4, F2, ALT-F4 | Mark, copy, cut, paste, delete | help |
| ALT-F2 MAKECAT, ALT-F7 MAKEITM | A category from the word or marked text; an item from the text (removed from the note) | help |
| ALT-F8 GETITMS | Copies the marked items (and their notes) into the note; "There are no marked items in the file." when none | tried, help |
| ALT-F9 APPEND | Moves text from the note to the end of the item's text (category's name); a box "Append to item: Word" (Word, Line, All text, or the marked text); ESC instead of F5 afterwards keeps the text in the note | tried, help |
| ALT-F6, ALT-S | Search / replace; repeat | help |
| ALT-F1 COMPOSE | Types a character not on the keyboard (a compose sequence) | help |
| ALT-D, ALT-T | Today's date / the time at the cursor | help |
| ALT-N, ALT-P | The next / previous item's or category's note ("and optionally save your changes") | help |
| ALT-C | The calendar | help |
| ALT-Z | Runs the current macro | help |
| ALT-K, ALT-Q | Key map; quit | help |
| F6 MARKER | A box: printer, orientation, the current attribute and font; Attribute (Bold, Italic, Underscore …, Strikethrough, Small caps), Font, Special (Page number, Path name, Printer code, Time, View name) for the marked text or at the cursor | tried |

## What Agendum has, and what is missing

| Agenda | Agendum today | Step |
| --- | --- | --- |
| Note for … Line N INS EDIT | ✅ R64a (INS only until step 5; no clock, as Agenda) | 1 |
| Note file: line | – | 7 |
| Key bar | ✅ R64a: F1 Help, F2 Paste, F3 Copy, F4 Cut, F5 Return, F7 Mark, then ALT-F6, ALT-F7, ALT-F2 (one line, as every key bar of ours; F10 Menu with step 2) | 1 |
| F10 menu | ✅ R64b: Import, Export, Clear, Return, Quit (File: step 7) | 2 |
| Import, Export | ✅ R64c: prompts (F3 lists `.txt`, `.md`) instead of Agenda's boxes; carriage returns always stripped | 3 |
| Clear | ✅ R64b | 2 |
| Return, Quit | ESC / F5; ALT-Q; ✅ on the menu (R64b) | 2 |
| ESC: Discard changes? | ✅ R64d | 4 |
| INS / OVR | ✅ R64e (INS, CTRL-N) | 5 |
| TAB, tab size | ✅ R64e (spaces; Tab size stored, format 37) | 5 |
| ALT-M, CTRL-ENTER, CTRL-BACKSPACE, ALT-W | ✅ R64e (CTRL-K for CTRL-ENTER; ⌥⌫ and CTRL-W for CTRL-BACKSPACE) | 5 |
| PGUP/PGDN, CTRL-←/→, CTRL-HOME/END | ✅ R64e (⌥←/→, ⌥< ⌥> beside them) | 5 |
| F7 F3 F4 F2 ALT-F4 | ✅ R63 | – |
| ALT-F2, ALT-F7 | ✅ R42 | – |
| ALT-F8 GETITMS | ✅ R64f (copies only; no discard question) | 6 |
| ALT-F9 APPEND | ✅ R64f | 6 |
| ALT-F6, ALT-S | ✅ R39 | – |
| ALT-F1 COMPOSE | – (a modern terminal types any character) | 8 |
| ALT-D, ALT-T | ✅ | – |
| ALT-N, ALT-P | ✅ (always saves: the owner's choice) | 4 |
| ALT-C | ✅ R64f | 6 |
| ALT-Z | ✅ (macros run anywhere) | – |
| ALT-K, ALT-Q | ✅ | – |
| Undo inside the editor | – (roadmap item: undo in the note editor) | 9 |
| Word wrap | ✅ ours (R64; Agenda scrolled sideways) | – |

## Out of scope

Printing on paper and typesetting:

- F10 Print (Final, Preview, Layout, Setup, Named).
- F6 MARKER: attributes (bold, italic, underscores, sub- and superscript, strikethrough, small caps), fonts, and its Special codes (page number, path name, printer code, time, view name), which are filled in when printing.
- The control panel's `Font: … Attr: …`.

So the note editor's F6 stays free. If notes get Markdown later (roadmap: Ideas), bold and italic come back as text (`**bold**`), not as Agenda's printer attributes.

## Habit changes to settle first

These change what a key does for someone using Agendum today; settle them with the owner before the step that brings them:

1. **ESC in a note** (step 4). Today ESC saves and leaves. Agenda asks "Discard changes? No": ENTER on No saves and leaves (as today, one key more), Y discards. Options: Agenda's question; or ESC saves as now and discarding is a menu entry (F10 ▸ Return without saving). ADR 0030 made ESC cancel in every settings box, which argues for Agenda's way.
2. **The control panel's first line** (step 1). Today it holds the help text and messages ("Replaced 3 occurrences"). Agenda shows "Note for: … Line N INS EDIT" there and puts messages over it. Where do messages and the NOTE indicator go?
3. **INS** (step 5). Today INS does nothing in a note; Overwrite mode is new. Mac keyboards have no INS: which key switches it?
4. **TAB** (step 5). Today TAB does nothing in a note; it will type spaces.
5. **CTRL-ENTER and ALT-W** (step 5). CTRL-ENTER deletes to the end of the line in Agenda; terminals often send it as plain ENTER. Agendum already uses CTRL-K for that in single-line fields: CTRL-K in notes too, with CTRL-ENTER where the terminal tells them apart?
6. **ALT-N / ALT-P** (step 4). Agenda "optionally saves"; Agendum always saves. Keep it, or ask as ESC does?

**Settled by the owner, 2026-10-17:**

1. ESC asks Agenda's "Discard changes? No" (not when nothing changed).
2. Line 1 is Agenda's header ("Note for: … Line N INS" and the indicator); a message shows over it until the next key.
3. INS and CTRL-N (Agendum's stand-in for INS everywhere) switch INS / OVR.
4. TAB goes to the next tab stop, typing spaces; Tab size a file setting, 5 by default, as Agenda.
5. CTRL-K deletes to the end of the line, and CTRL-ENTER where the terminal tells it from ENTER.
6. ALT-N / ALT-P keep saving without asking.

## Steps

Each is one commit, test first, as CLAUDE.md says.

1. **The note editor's control panel and key bar.** Line 1: `Note for:
   <title>` and, on the right, `Line N` (the line of the text, not the
   wrapped row), `INS`/`OVR` (after step 5) and the indicator. Line 2: `Note file: …` when attached (step 7), else the help line. The key bar as Agenda's (F5 Return, F10 Menu) without F6 Marker. Already a roadmap item ("the note editor's 'Note for: … Line 1 INS EDIT' header"), which this step closes. Draw ours and Agenda's side by side (`tools/screenshots/`).
2. **The F10 menu in a note.** Its own tree in `Agendum.TUI.Menu`: File (Attach, Detach, Erase; after step 7), Import, Export (step 3), Clear (a Yes/No question; one undo step once the note is saved, as the replacements are), Return, Quit; no Print. Unique first letters, as every menu level.
3. **Import and Export.** Import a text file at the cursor (a box: File name with F3 listing files, R51's Select File; Strip carriage returns); Export the note to a text file (F3 lists, a new name creates it). The reading and writing are effects done in `App`, as the file's own import and export are; the text in the note goes through the core (`Core.set_note`). Line ends: LF on writing, CR LF read as LF.
4. **ESC asks "Discard changes?"** (after habit 1 is settled). No (the default) saves and leaves, Yes restores the note as it was opened; not asked when nothing changed. The steps already saved (Search/Replace's replacements, R39) are undone by Yes too, so the note is as it was. ALT-N / ALT-P as settled in habit 6.
5. **Editing keys.** INS / OVR (with a Mac alternative and the indicator), TAB to the next tab stop with File Properties ▸ Tab size (a new stored setting: DATA_MODEL, JSON schema, JSON_FORMAT; default 5 as Agenda; connects to the roadmap item for File Properties' other settings), ALT-M new line, CTRL-BACKSPACE / ⌥⌫ and ALT-W delete a word, CTRL-K (and CTRL-ENTER) delete to the end of the line, CTRL-← / CTRL-→ (⌥← ⌥→) a word, PGUP / PGDN a page of rows, CTRL-HOME / CTRL-END the start and end of the note (Mac: ESC-prefixed alternatives). Reuse `LineEdit`'s word rules in `TextEdit`. KEYBOARD.md and the F1 help.
6. **Connections to features Agendum has.** ALT-F9 APPEND: the Word / Line / All text box (as F3 COPY's), moving the text to the end of the item's text or the category's name, one undo step (a core function, with MAKEITM's); ALT-F8 GETITMS: the marked items' text and notes into the note at the cursor, or "There are no marked items in the file."; ALT-C: the calendar, its date typed at the cursor on ENTER (as ALT-D types today's).
7. **External note files** (File Attach, Detach, Erase). The note is kept in a text file instead of the Agendum file: a new stored field (the file's path on the item, category or macro: DATA_MODEL, JSON schema, JSON_FORMAT), read when the note opens and written when it is saved, by effects in `App`; "Note file was not found. Create a file?" when it is missing; the ♪ symbol as for any note. Needs an ADR: the core stays pure, so the note's text lives outside `db`, and the planned web front end (MULTIUSER.md) cannot reach a person's files, so it shows such notes as attached but not editable. The `.AG` importer (roadmap, Data interchange) reads Agenda's note files (`docs/AGENDA_FILE_FORMAT.md`) and can attach them.
8. **ALT-F1 COMPOSE** (optional). Agenda typed accented and other characters with compose sequences (`a` `'` → á). A terminal types them already; worth doing only for keyboards that lack them. Low priority.
9. **Undo inside the editor.** The roadmap item of the same name; after step 4, which settles how a note's own steps and the file's history meet.

Steps 1, 2, 5 and 6 are independent of each other (6 is keys only); 3 needs 2; 4 needs habit 1 settled; 7 needs 2 and an ADR.
