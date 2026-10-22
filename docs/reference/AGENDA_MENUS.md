# Lotus Agenda 2.0's menus

**To be replaced:** this table was made by hand. The DOSBox capture tool (ROADMAP, "Towards parity", meeting 2026-10-21, § 8) will write Agenda's menus to a committed JSON reference that replaces or generates it; until then, do not extend it (meeting 2026-10-22, § 5i).

For reference: the F10 menus of the real Agenda 2.0, as it shows them. The
view's menu was walked level by level in Agenda 2.0 run headless in
DOSBox Staging (`tools/agformat/agenda_driver.py`, on a copy of the
PLANNER starter file, 2026-10-15). Only entries whose help line names a
submenu were opened, so no command ran. Each command's text is the help
line Agenda shows when it is highlighted, as written there (keys in
square brackets are its accelerator keys).

The note editor's menu was walked by hand in the same session; the
category manager's comes from the User's Guide, Appendix A, and was not
checked in the program. How Agendum's menus compare:
[`docs/plans/AGENDA_PARITY.md`](../plans/AGENDA_PARITY.md) and
[`docs/plans/NOTE_EDITOR.md`](../plans/NOTE_EDITOR.md).

A menu entry is chosen by its first letter or with ← → and ENTER; ESC
goes back one level.

## The view's menu (F10 in a view)

`File · Item · Category · View · Print · Utilities · System · Quit`

- **File**
  - **Retrieve**: Switch to another file (old or new), saving current file [ALT-G].
  - **Save**: Save the current file to disk [ALT-W].
  - **Abandon**: Discard current changes to the file.
  - **Properties**: Set properties for the current file.
  - **Transfer**
    - **Import**: Import a structured file into the current file.
    - **Export**: Export the current file to a structured file.
    - **Template**: Copy the current file structure.
  - **Maintenance**
    - **MakeCopy**: Make a copy of the current file with another name.
    - **Erase**: Discard an Agenda file from disk.
    - **Compress**: Remove unused space from current file.
    - **Reservation**: Get or release the reservation for the current file.
- **Item**
  - **Properties**: Set properties for the current item [F6].
  - **MakeAssign**: Assign the current item to a category [ALT-M].
  - **Discard**: Discard the current item from the file [ALT-F4].
  - **Undisc**: Recover item(s) from the trash [ALT-Y].
  - **BrkAssign**: Remove the assignment for the current item [DEL].
  - **Reposition**: Reposition the current item within this section.
  - **Alarm**: Set an alarm for the current item [ALT-A].
- **Category**
  - **Properties**: Set properties for the current category [F6].
  - **Add**: Add a new category.
  - **Discard**: Discard the current category from the file [ALT-F4].
- **View**
  - **Properties**: Set properties for the current view [F6].
  - **Add**: Add a new view.
  - **Browse**: Press left or right arrow key to look through other dates [ALT-B].
  - **Discard**: Discard the current view from the file.
  - **Column**
    - **Properties**: Set properties for the current column [F6].
    - **Add**: Add a new column [ALT-R, ALT-L].
    - **Remove**: Remove the current column from the view [DEL].
    - **Move**: Reposition the current column within this section.
    - **Width**: Set the width of the current column.
  - **Section**
    - **Properties**: Set properties for the current section [F6].
    - **Add**: Add a new section [ALT-D, ALT-U].
    - **Remove**: Remove the current section from the view [DEL].
    - **Move**: Reposition the current section.
- **Print**
  - **Final**: Print all or part of your file.
  - **Preview**: Preview all or part of your file.
  - **Layout**: Set margins, attributes, spacing, paper size, and other options.
  - **Setup**: Select printers and set up global font list.
  - **Named**
    - **Retrieve**: Retrieve print settings from Named print set file.
    - **Save**: Save current print settings to Named print set file.
    - **Erase**: Erase a Named print set file.
    - **Attach**: Attach a Named print set file to the current view.
    - **Detach**: Detach a Named print set file from the current view.
- **Utilities**
  - **Customize**: Customize your screen display and work environment.
  - **Execute**: Evaluate conditions/actions [ALT-X].
  - **Show**
    - **Match**: Show all items containing a specific word or phrase.
    - **Prereqs**: Show all items on which current item depends.
    - **Depends**: Show all items that depend on the current item.
    - **ItemsDone**: Show all Done items.
    - **Circular**: Show all items caught in circular references.
    - **Alarm**: Show all items with pending and triggered alarms.
    - **Sched**: Show items for a specific date.
    - **Every**: Show every item in the file.
  - **Questions**: Confirm suggested assignments.
  - **Trash**: Clear all discarded items from the trash.
  - **Launch**: Run a program without quitting Agenda.
- **System**: Exit to DOS.  (Type EXIT to leave DOS and return to Agenda.)
- **Quit**: End this Agenda session [ALT-Q].  Your file is saved automatically.

## The note editor's menu (F10 in a note)

The macro editor has the same menu (Working with Macros; User's Guide,
Appendix A).

`File · Print · Import · Export · Clear · Return · Quit`

- **File**
  - **Attach**: Attach an external file to this note.
  - **Detach**: Remove the attachment to the external file.
  - **Erase**: Erase the file attached to this note from the disk.
- **Print**
  - **Final**, **Preview**, **Layout**, **Setup**: as in the view's Print menu, for the note.
  - **Named**: Retrieve, Save, Erase (named print sets; Appendix A).
- **Import**: Import a text file into the current note.
- **Export**: Export the current note to a text file.
- **Clear**: Delete all text in the current note.
- **Return**: Return to the previous activity [F5].
- **Quit**: End this Agenda session [ALT-Q].  Your file is saved automatically.

What some of them ask (seen in the program):

- Import: a box with File name (F3 lists files) and Strip carriage
  returns (No); the text goes in at the cursor.
- Export: a box with File name (F3 lists files, INS creates one); the
  note is written with CR LF line ends.
- Clear: "Clear all text from the note?  Yes".
- File Attach: a box with File name; the note is then kept in that file,
  and the control panel's second line shows `Note file: <path>`.
- File Detach: "Detach the existing note file?  No".
- Leaving with ESC after a change: "Discard changes?  No" (No saves).

## The category manager's menu (F10 in the category manager)

From the User's Guide, Appendix A (not walked in the program):

`Category · Print · Return · Quit`

- **Category**
  - **Properties**
  - **Add**
  - **Discard**
- **Print**
  - **Final**, **Preview**, **Layout**, **Setup**
  - **Named**: Retrieve, Save, Erase
- **Return**
- **Quit**

## Print preview's menu

From the User's Guide, Appendix A: `Page · Content/Fullpage ·
Reverse/Normal · Quit`, with Page: Next, Previous, GoTo. Printing is out
of scope for Agendum.
