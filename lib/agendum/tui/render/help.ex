defmodule Agendum.TUI.Render.Help do
  @moduledoc """
  The F1 help screen. Pure.
  """

  @help """
   AGENDUM KEYS   (↑↓ PGUP PGDN scroll · c commands · d describe a key · other keys return)

   In a view                         Mac / no-INS alternative
     Type          Add an item, or an entry in the highlighted column
     INS           New item / extra column entry   CTRL-N
     F2            Edit item, section head, entry  CTRL-E
     F3            Choices: column box / item's profile / calendar
                   (in a date column: ←→↑↓ PGUP PGDN, CTRL-←→ or < > a year,
                   F6 a time, type a date to go there, ENTER sets it)
     F4            Mark item done                  CTRL-K
     F5            Note of the item, or of the category highlighted
     F6            Item / section properties
     F7            Mark item (on a section: all)  ALT-F7 unmark all, ALT-J next
     F8 / F9       View manager / category manager
     F10 or /      Menu (ESC backs up a level; ESC in a box
                   it opened goes back to it)
     In a box      Arrows/TAB move; SPACE changes, F2 edits,
                   F3 picks, type a number; ENTER done, ESC cancels
     DEL           Remove from section or column   fn-⌫
     ALT-F4        Discard item                    CTRL-D
     ALT-M         Assign to a category (MakeAssign)   ESC m
     With marked items, F4 DEL ALT-F2 ALT-F4 ALT-F9 ALT-F10 ALT-M F3 ask:
                   marked items (M) or the current item (C)
     ALT-F2        Set the When date (or menu Item When)
     ALT-F10       Move item to another section (on a section
                   head: move the section, ↑ ↓, ENTER)
     ALT-F9        Copy item to another section
     ALT-Y         Yank back the item DEL removed  ESC y
     ALT-H         Hop to item's next occurrence   ESC h
     ALT-− / ALT-= Collapse / expand section (twice: all)
     ALT-F5        Go to a section (GO TO)
     ALT-N / ALT-P Next / previous view              ESC n / ESC p
     ALT-V         Show / hide empty sections        ESC v
     ALT-I         Insert an item (like INS)         ESC i
     ALT-W / ALT-G Save / retrieve a file            ESC w / ESC g
     ALT-F6        Search (then ALT-N / ALT-P, F7 mark)
     ALT-F8        Back to the previous view
     ALT-A         Set or cancel an alarm            ESC a
     ALT-C         Show the calendar (to look up a date)  ESC c
     ALT-F3        Macros: the macro manager; in Learn mode, stop
                   recording (F7 in the manager learns, ENTER runs, F2
                   edits, F6 properties: attach to a key)
     ALT-Z         Run the last macro again              ESC z
     ALT-B         Browse a datebook view (← → a period) or a date filter
                   (← → a day, ↑↓ a week, PGUP/PGDN a month, CTRL-PGUP/PGDN
                   a year); ALT-F5 a date, ENTER keeps, ESC goes back   ESC b
     ALT-O         Depend on the marked items (&); with none marked,
                   clear the item's dependencies     ESC o
     ALT-X / ALT-E Execute all conditions and actions / the section's
                   category's, on all items (Category ▸ Execute)
     ALT-D / ALT-U Add section below / above
     ALT-R / ALT-L Add column right / left
     ←→ TAB        Move between item and columns (on a section head:
                   its column heads; DEL removes the column, F3
                   replaces the head, F6 its properties, F2 renames,
                   ALT-F10 moves it: ← →, ENTER)
     In a column   Type a name: the first match shows; ENTER accepts,
                   F8/ALT-N and F7/ALT-P cycle, INS/^N makes it a new one
     Numeric column Type a number; F2 edits, DEL removes it; the format and
                   totals are in View ▸ Column ▸ Properties
     Star column   SPACE stars or unstars; Yes/No column: Y or N
     Note column   Type that line of the category's note; F2 edits it
     CTRL-PGUP/DN  Previous / next section         ⌥↑ / ⌥↓
     ALT-1…ALT-9   A count for the next move: ALT-1 ALT-0 ↓ goes ten rows
                   down (also PGUP PGDN ←→, sections, ALT-J ALT-H ALT-N
                   ALT-P); ESC drops it

   Everywhere
     F3 in a prompt for a file name: pick it from a list of files
     CTRL-Z / CTRL-Y   Undo / redo
     CTRL-S            Save              CTRL-O   Open (retrieve) a file
     CTRL-P            Print to file     CTRL-Q   Quit (also ALT-Q)
     ALT-K             Show / hide the function key map (kept)

   In the category manager (F9)
     Type / INS    Add a category below            CTRL-N, ALT-D, ALT-I
     ALT-U         Add a category above            ESC u
     ALT-R / ALT-L Add a child / a new family after the parent
     F2            Rename                          CTRL-E
     F7 / F8       Promote / demote
     ALT-↑ ALT-↓   Reorder among siblings          ⌥↑ / ⌥↓
     ALT-− / ALT-= Collapse / expand family (twice: all)   ESC - / ESC =
     ALT-F10       Move under another parent
     DEL           Discard category                CTRL-D
     F6            Properties (exclusive, short name, links)
     ESC / F9      Return to the view

   In the view manager (F8)
     Type          Highlight the next view starting with the letters
     ENTER         Show the highlighted view
     INS           Add a view                      CTRL-N
     F2            Rename                          CTRL-E
     DEL           Discard view (items are kept)   CTRL-D
     ALT-F5        Sort the views by name
     ALT-↑ ALT-↓   Reorder                         ⌥↑ / ⌥↓
     ESC / F8      Return to the view

   In a note (F5)
     F7            Mark text (then move the cursor; F7 again unmarks)
     F3 / F4       Copy / cut the marked text (else: word, line, all)
     ALT-F4        Delete the marked text (not kept)
     F2            Paste the text last copied or cut
     ALT-F6        Search / replace text
     ALT-S         Find the next occurrence         ESC s
                   (after a single replacement: replace it)
     ALT-D / ALT-T Insert today's date / the time   ESC d / ESC t
     ALT-N / ALT-P Save; next / previous item's note
     ALT-F7        Make the marked text (or word / line /
                   all) an item (MAKEITM; it leaves the note)
     ALT-F2        Make the marked text or the word a
                   category (MAKECAT)
     ESC / F5      Save the note and return
     ↑↓            Move by the rows shown (long lines wrap)
     HOME / END    Start / end of the row; again: of the line

   While typing
     ←→ HOME END   Move          CTRL-A / CTRL-E   Start / end of line
     ⌥← ⌥→         Word left / right
     CTRL-K        Delete to end  CTRL-W / ⌥⌫      Delete word   CTRL-U  Clear

   On a Mac, hold fn for F1..F10 (or make them standard function keys in
   System Settings ▸ Keyboard); ALT-Fn is ⌥ + Fn (Option as Meta).
   ⌘ shortcuts (⌘N, ⌘Z, ⌘S ...) work once your terminal maps them to the
   CTRL keys above; see docs/KEYBOARD.md.

   Items are assigned to the section they are typed in, and automatically to
   any category whose name (or short name) appears in their text. The first
   date in the text ("call Bob next Friday") becomes the When date. Typing a
   name in a column assigns the item to that subcategory, creating it if new.
  """

  @doc "How many lines the help has."
  def line_count, do: @help |> String.split("\n") |> length()

  @doc "The F1 help text."
  def text, do: @help

  @doc "The help's lines."
  def lines, do: @help |> String.split("\n") |> Enum.map(&[{:normal, &1}])
end
