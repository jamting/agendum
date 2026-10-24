# Keyboard guide

Agenda's original keys assume a PC keyboard with F-keys, INS and an ALT key. Function keys are required, as in Agenda (ADR 0032): on a Mac, use fn with them or make them standard function keys (below). For INS, HOME, END and the most used commands there are CTRL alternatives that work on a Mac laptop keyboard in any terminal; "—" below means the Agenda key is the only one. ⌘ (Command) shortcuts can be added through your terminal's settings, as described in the second half of this guide.

## Keys that work everywhere

| Command                                                                                         | Agenda key                    | Mac-friendly alternative                                              |
| ----------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------- |
| New item / column entry / category / view                                                       | INS                           | **CTRL-N**                                                            |
| Edit (item, section head, column entry, category)                                               | F2                            | **CTRL-E**                                                            |
| Mark done                                                                                       | F4                            | **CTRL-K**                                                            |
| On a column head (→ / TAB on a section head): remove the column; replace the head; its properties; rename it; move it (← →, ENTER) | DEL; F3; F6; F2; ALT-F10 | fn-⌫; —; **CTRL-E**; menu View ▸ Column ▸ Move |
| On a section head: Section Properties; in it: remove a column from the section; move it; add one; the head's category properties | F6; DEL; ALT-↑ / ALT-↓; INS; F6 on Section head | —; fn-⌫; ⌥↑ / ⌥↓; **CTRL-N** |
| On a section head: move the section up or down in the view (↑ ↓, ENTER keeps, ESC puts back) | ALT-F10 | menu View ▸ Section ▸ Move |
| In the view manager: the highlighted view's View Properties (R78) | F6 | — |
| In View Properties' Sections (R78): add a section below the highlighted one (or type its name); pick its category instead; remove it; its Section Properties; pick it up and carry it (↑ ↓, ENTER or ESC puts it down, as Agenda's); move it a place at once (ours) | INS; F3; DEL; F6; ALT-F10; ALT-↑ / ALT-↓ | **CTRL-N**; —; fn-⌫; —; ⌥ with F10; ⌥↑ / ⌥↓ |
| Copy the item (or the marked items) to another section of the view as well: the Copy box | ALT-F9 | — |
| Yank back the item DEL last removed from a section: into the current section, below the highlighted item | ALT-Y | ⌥y |
| Hop to the highlighted item's next occurrence: further down this view, else in the next view that shows it (ALT-F8 goes back) | ALT-H | ⌥h |
| Discard                                                                                         | ALT-F4                        | **CTRL-D**                                                            |
| Set the When date                                                                               | ALT-F2                        | —                                                    |
| Next / previous completion while typing a column entry                                          | F8 / F7                       | ALT-N / ALT-P (⌥n / ⌥p)                                    |
| New category instead of the completion                                                          | F5 or INS                     | **CTRL-N**                                                            |
| Collapse / expand a family or section (twice: all)                                              | ALT-− / ALT-=                 | ⌥− / ⌥=                    |
| Unmark all items                                                                                | ALT-F7                        | —                                                    |
| Jump to the next marked item                                                                    | ALT-J                         | ⌥j                                               |
| Assign the item or marked items to a category (MakeAssign)                                      | ALT-M                         | ⌥m, or menu Item ▸ Categorize                    |
| Go to a section (GO TO, in a view); sort a family (category manager); sort views (view manager) | ALT-F5                        | —                                                          |
| Highlight a view by typing the start of its name (view manager)                                 | letters                       | —                                                                     |
| List the views by recently used, or your order (view manager; an extra, R77)                     | F5                            | —                                                                     |
| Next / previous view (in a view)                                                                | ALT-N / ALT-P                 | ⌥n / ⌥p                                                    |
| Show / hide empty sections (in a view)                                                          | ALT-V                         | ⌥v                                                          |
| Insert an item (in a view)                                                                      | ALT-I                         | ⌥i, or INS / **CTRL-N**                                     |
| Save / retrieve a file (in a view)                                                              | ALT-W / ALT-G                 | ⌥w / ⌥g, or **CTRL-S** / **CTRL-O**                        |
| Quit                                                                                            | ALT-Q                         | ⌥q, or **CTRL-Q**                                           |
| The key bar in turn: the ALT, CTRL and SHIFT keys, hidden, the plain keys (hidden kept for next time) | ALT-K                         | ⌥k                                                          |
| Search this view; then next / previous match                                                    | ALT-F6; ALT-N / ALT-P         | —; ⌥n / ⌥p                                      |
| In a note: search / replace; find the next occurrence (after a single replacement: replace it)  | ALT-F6; ALT-S                 | —; ⌥s                                            |
| In a note: move by the rows shown (long lines wrap, R64); start / end of the row, again: of the line| ↑ ↓; HOME / END               | CTRL-A / CTRL-E                                                       |
| In a note: insert today's date / the time                                                       | ALT-D / ALT-T                 | ⌥d / ⌥t                                                    |
| In a note: the next / previous item's (or category's) note                                      | ALT-N / ALT-P                 | ⌥n / ⌥p                                                    |
| In a note: save and go back; go back asking "Discard changes?" when it changed (R64d)           | F5; ESC                       | —                                                          |
| In a note: a word left / right (on to the line above or below); delete the word before / after (R64e) | CTRL-← / CTRL-→; CTRL-BACKSPACE / ALT-W | ⌥← / ⌥→; ⌥⌫ or CTRL-W / ⌥w                |
| In a note: delete to the end of the line; a new line (R64e)                                      | CTRL-ENTER; ALT-M             | **CTRL-K** (terminals send CTRL-ENTER as ENTER); ⌥m        |
| In a note: insert or type over (INS / OVR); spaces to the next tab stop (File Properties ▸ Tab size; R64e) | INS; TAB             | **CTRL-N**; TAB                                            |
| In a note: move text onto the item's text (APPEND); copy the marked items in (GETITMS); type a date from the calendar (R64f) | ALT-F9; ALT-F8; ALT-C | ⌥ with F9, F8; ⌥c                           |
| In a note: a page of rows up / down; the start / end of the note (R64e)                          | PGUP / PGDN; CTRL-HOME / CTRL-END | fn-↑ / fn-↓; ALT-< / ALT-> (⌥< / ⌥>)                    |
| In a note: make the marked text (or the word, line or all text) into a new item (it leaves the note; MAKEITM) / the marked text or the word into a new category under a parent you pick (MAKECAT) | ALT-F7 / ALT-F2 | — |
| In a note: mark text (then move the cursor; again to unmark); copy / cut the marked text, or a word, line or all text; delete it (not kept); paste what was last copied or cut | F7; F3 / F4; ALT-F4; F2 | — |
| Back to the previous view (LAST VW)                                                             | ALT-F8                        | —                                                    |
| Set or cancel an alarm (Item Alarm)                                                             | ALT-A                         | ⌥a, or menu Item ▸ Alarm                                    |
| Macros: the macro manager; in Learn mode, stop recording / run the last macro again             | ALT-F3 / ALT-Z                | — / ⌥z                                           |
| In the macro manager: new macro; learn its keystrokes; run it                                   | INS; F7; ENTER                | **CTRL-N** or type its name; —                             |
| In the macro manager: edit the keystrokes; properties (attach to a key, where it runs); delete; sort; move | F2; F6; DEL; ALT-F5; ALT-↑ / ALT-↓ | —; fn-⌫; —; ⌥↑ / ⌥↓                       |
| Pop-up calendar: pick a date (in a date column) / look one up (anywhere in a view)              | F3 / ALT-C                    | — / ⌥c                                           |
| In a Star column: star or unstar; in a Yes/No column: yes or no (R56)                           | SPACE; Y / N                  | —                                                                     |
| In a Category note column: type the line; edit it; empty it (R56)                               | type; F2; DEL                 | CTRL-E for F2; fn-⌫ for DEL                                           |
| In the calendar: a day, a week; the first / last day of the month                               | ← → ↑ ↓; HOME / END           | fn-← / fn-→ for HOME / END                                            |
| In the calendar: a month back / ahead; a year back / ahead                                      | PGUP / PGDN; CTRL-← / CTRL-→  | fn-↑ / fn-↓; `<` / `>`                                                |
| In the calendar: set the date; a time (F6); go to a typed date; cancel                          | ENTER; F6; type it; ESC       | the same                                                              |
| In a prompt for a file name: pick it from a list (Select File box: ENTER opens, typing narrows, F7 dates, ESC back) | F3                            | —                                                          |
| Browse a datebook view: previous / next period; go to a date; keep; go back                     | ALT-B: ← →; ALT-F5; ENTER; ESC | ⌥b; `<` / `>`; —                                 |
| Browse a date filter (standard view): a day; a week; a month; a year                            | ALT-B: ← →; CTRL-← →; PGUP/PGDN; CTRL-PGUP/PGDN | ⌥b; ↑ ↓ for a week; ⌥↑ / ⌥↓ for a year                      |
| Column width (View ▸ Column ▸ Width): narrower / wider; a width; fit to contents; keep; go back | ← →; type it; SHIFT-?; ENTER; ESC               | `?` (no SHIFT needed); opened from menu View ▸ Column ▸ Width         |
| Make the item depend on the marked items, or clear its dependencies                             | ALT-O                         | ⌥o                                                          |
| Execute all conditions and actions on all items / those of the highlighted category             | ALT-X / ALT-E                 | ⌥x / ⌥e, or menu Utilities ▸ Execute                        |
| Give the item, or the marked items, a Zettel id (ours, R73; an extra, R77)                     | —                             | **CTRL-T**, or menu Item ▸ Zettel ▸ Attach                 |
| Follow the item's Zettel links / show the items linking to it (ours, R73b; an extra, R77)      | —                             | **CTRL-G** / **CTRL-R**, or Item ▸ Zettel ▸ Follow / Linked |
| In a note: type a link to each marked item, `[[bonalaku]]` (ours, R73b; an extra, R77)          | —                             | **CTRL-L**                                                  |
| Open the item's web link in the browser: a feed entry's article (ours, R75; an extra, R77)     | —                             | **CTRL-V**, or menu Item ▸ Open link                       |
| Category manager: the category above / below                                                   | ↑ or BACKSPACE / ↓ or ENTER    | ↑ or ⌫ / ↓ or ENTER                   |
| Category manager: add a sibling below / above                                                   | ALT-D (or ALT-I, INS) / ALT-U | ⌥d / ⌥u, or **CTRL-N**                                     |
| Category manager: add a child / a new family after the parent                                   | ALT-R / ALT-L                 | ⌥r / ⌥l                                                    |
| Remove from section / column                                                                    | DEL                           | fn-⌫ (forward delete)                                                 |
| Undo / redo                                                                                     | —                             | **CTRL-Z** / **CTRL-Y** (also in the menu)                            |
| Run a command by its name: type part of it or its initials, ENTER runs it (ours, R65d)          | —                             | **CTRL-X** (also in a note)                                           |
| Save / open / print to file / quit                                                              | menu                          | **CTRL-S** / **CTRL-O** / **CTRL-P** / **CTRL-Q** (CTRL-C also quits) |
| Previous / next section                                                                         | CTRL-PGUP / CTRL-PGDN         | ⌥↑ / ⌥↓ (in a view)                                                   |
| A count for the next command in a view (R65): ALT-1 ALT-0 ↓ moves ten rows down. Counts work with ↑ ↓ PGUP PGDN ← → TAB, previous / next section, ALT-J, ALT-H, ALT-N / ALT-P; other commands run once; ESC drops the count | ALT-0 … ALT-9 (ours) | ⌥0 … ⌥9 (Option as Meta) |
| Menu (in a note: the note's own menu, Import, Export, Clear, Return, Quit; R64b; in the category manager its own, Category, Return, Quit; R81) | F10 | `/` (not in a note, where it is typed)                                |
| Help about where you are; then `c` the command list (typing narrows it, ENTER runs one, ← → page through the highlighted command's text in the pane), `d` describe the next key pressed, `a` all keys (R65) | F1; then `c` / `d` / `a` | ⌘/ mapped to F1 |
| In the menu: back up a level; in a box, prompt or question opened from it: back to the menu       | ESC (BACKSPACE in the menu)   | ESC; ⌫                                                                 |
| In a box: move between settings (→ ← along a row, on to the next or previous; ↓ ↑ keep to the side); first / last setting | ↑ ↓ ← →, TAB / SHIFT-TAB; HOME / END | fn-← / fn-→ for HOME / END                                            |
| In a box: change or open a setting; type a number (width, decimal places, line); edit a text field; pick from a list; done; cancel the box's changes | SPACE; digits; F2; F3; ENTER; ESC | SPACE; digits; **CTRL-E**; —; ENTER; ESC                 |
| In a box, on a setting with choices: the next choice starting with a letter; list the choices | the letter; F3 | the letter; —                                              |
| A Yes/No question: answer at once; switch the answer shown; accept it; cancel                   | Y / N; SPACE; ENTER; ESC      | Y / N; SPACE; ENTER; ESC                                              |

While typing text (on one line; in a note, the first two rows and CTRL-D; the keymaps `:line` and `:text`, R65):

| Key                                         | Action                                |
| ------------------------------------------- | ------------------------------------- |
| CTRL-A / CTRL-E (HOME / END)                | Start / end of line                   |
| CTRL-B / CTRL-F (← / →)                     | A character left / right              |
| ⌥← / ⌥→ (ALT-← / ALT-→, ALT-B / ALT-F)      | Word left / right                     |
| CTRL-K                                      | Delete to the end of the line         |
| CTRL-W or ⌥⌫ (ALT-BACKSPACE)                | Delete the previous word              |
| CTRL-U                                      | Clear the line                        |
| BACKSPACE                                   | Delete the character before the cursor |
| CTRL-D                                      | Delete the character under the cursor |

The F1 help lists every key from the keymaps (F1 then `a`); a test checks that every key in them with a name (F-, ALT-, CTRL- and SHIFT-keys, ENTER, BACKSPACE, PGUP …) is in this guide.

ALT is ⌥ (Option) on a Mac: ALT-D (add section) is ⌥D, ALT-← is ⌥←. These keys need "Use Option as Meta key" (Terminal.app: Settings ▸ Profiles ▸ Keyboard) or "Esc+" for the left Option key (iTerm2: Settings ▸ Profiles ▸ Keys); the terminal then sends ESC and the key together, which Agendum reads as ALT. Without it, a few still work in Terminal.app with a US keyboard layout: Agendum recognises the characters Option produces for ⌥D, ⌥R, ⌥L, ⌥T, ⌥W, ⌥J, ⌥M, ⌥− and ⌥= (`∂`, `®`, `¬` …). Pressing ESC and then the letter by hand does not work: a lone ESC is ESC (it cancels), and the letter then counts on its own (ADR 0032).

CTRL-F keys (for macros, `{CtlF4}`): macOS keeps several for its own shortcuts (System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Keyboard navigation, and Mission Control), so only some reach the terminal; which ones depends on the setup (on one Mac with iTerm2, only CTRL-F4, F9 and F10). The key tester (ALT-?) shows whether a key gets through.

Function keys: on a Mac, hold **fn** to send F1…F12, or enable "Use F1, F2, etc. keys as standard function keys" in System Settings ▸ Keyboard. ALT-F1… ALT-F10 are ⌥ with the function key; Terminal.app needs "Use Option as Meta key" for them.

## ⌘ shortcuts

**macOS terminals never pass ⌘ keys to the programs running in them.** ⌘N, ⌘Z, ⌘S and ⌘Q belong to the terminal itself (new window, undo, …). To use them in Agendum, tell your terminal to send Agendum's CTRL key instead:

| ⌘ shortcut | Command               | Send                      |
| ---------- | --------------------- | ------------------------- |
| ⌘N         | New                   | `\x0e` (CTRL-N)           |
| ⌘Z         | Undo                  | `\x1a` (CTRL-Z)           |
| ⇧⌘Z        | Redo                  | `\x19` (CTRL-Y)           |
| ⌘S         | Save                  | `\x13` (CTRL-S)           |
| ⌘O         | Open                  | `\x0f` (CTRL-O)           |
| ⌘P         | Print to file         | `\x10` (CTRL-P)           |
| ⌘I         | Properties (Get Info) | `\x1b[17~` (F6)           |
| ⌘⌫         | Discard               | `\x04` (CTRL-D)           |
| ⌘↑ / ⌘↓    | First / last line     | `\x1b[1;5H` / `\x1b[1;5F` |
| ⌘/         | Help                  | `\x1bOP` (F1)             |

> ⚠️ **Scope these mappings to Agendum.** Terminal key mappings usually apply to every tab. In an ordinary shell, CTRL-Z suspends the running program and CTRL-S can freeze output. So put the mappings in a separate profile or configuration used only to run Agendum, as shown below. ⌘Q is left out on purpose: quitting the terminal by accident is worse than typing CTRL-Q.

The snippets below follow each terminal's documented configuration syntax, but they have not been tested here. Please report any that need adjusting.

### iTerm2

Create a profile just for Agendum (Settings ▸ Profiles ▸ +), set its _Command_ to the `agendum` binary, then add each shortcut under Profiles ▸ Keys ▸ Key Mappings ▸ + with the action **Send Hex Code**:

| Shortcut | Hex code    |
| -------- | ----------- |
| ⌘N       | `0x0e`      |
| ⌘Z       | `0x1a`      |
| ⇧⌘Z      | `0x19`      |
| ⌘S       | `0x13`      |
| ⌘O       | `0x0f`      |
| ⌘P       | `0x10`      |
| ⌘I       | `0x1b 0x5b 0x31 0x37 0x7e` |
| ⌘⌫       | `0x04`      |

Open Agendum with that profile (Profiles ▸ Agendum). If a ⌘ shortcut still triggers the iTerm2 menu item, remove or change the menu shortcut in System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ App Shortcuts.

### kitty

Save as `~/.config/kitty/agendum.conf` and run `kitty --config ~/.config/kitty/kitty.conf --config ~/.config/kitty/agendum.conf agendum`:

```conf
map cmd+n       send_text all \x0e
map cmd+z       send_text all \x1a
map cmd+shift+z send_text all \x19
map cmd+s       send_text all \x13
map cmd+o       send_text all \x0f
map cmd+p       send_text all \x10
map cmd+i       send_text all \x1b[17~
map cmd+backspace send_text all \x04
map cmd+up      send_text all \x1b[1;5H
map cmd+down    send_text all \x1b[1;5F
```

### Ghostty

Save as `~/.config/ghostty/agendum` and start a separate Ghostty instance with `open -na Ghostty --args --config-file=$HOME/.config/ghostty/agendum -e agendum`:

```conf
keybind = cmd+n=text:\x0e
keybind = cmd+z=text:\x1a
keybind = cmd+shift+z=text:\x19
keybind = cmd+s=text:\x13
keybind = cmd+o=text:\x0f
keybind = cmd+p=text:\x10
keybind = cmd+i=text:\x1b[17~
keybind = cmd+backspace=text:\x04
keybind = cmd+up=text:\x1b[1;5H
keybind = cmd+down=text:\x1b[1;5F
```

### WezTerm

Add a separate config (e.g. `~/.config/wezterm/agendum.lua`) and run `wezterm --config-file ~/.config/wezterm/agendum.lua start -- agendum`:

```lua
local wezterm = require 'wezterm'
local send = wezterm.action.SendString
return {
  keys = {
    { key = 'n', mods = 'CMD', action = send '\x0e' },
    { key = 'z', mods = 'CMD', action = send '\x1a' },
    { key = 'z', mods = 'CMD|SHIFT', action = send '\x19' },
    { key = 's', mods = 'CMD', action = send '\x13' },
    { key = 'o', mods = 'CMD', action = send '\x0f' },
    { key = 'p', mods = 'CMD', action = send '\x10' },
    { key = 'i', mods = 'CMD', action = send '\x1b[17~' },
    { key = 'Backspace', mods = 'CMD', action = send '\x04' },
  },
}
```

### Terminal.app

Terminal.app cannot remap ⌘ shortcuts, so use the CTRL keys in the first table (CTRL-N, CTRL-Z, CTRL-S, …).

## How it works

Raw terminal mode would normally let the tty driver swallow some of these keys: CTRL-S/Q (flow control), CTRL-C/Z (signals), CTRL-O/V (discard, literal-next). `Agendum.TUI.Terminal` turns those features off with `stty` while Agendum runs and restores them on exit, so every CTRL key reaches Agendum.

## Developer tools (hidden)

ALT-? (⌥? with Option as Meta) opens the developer screen from anywhere except while typing: the last key as Agendum decoded it, the mode stack, cursor, undo depth, session (time, languages, input format, theme, preferences, terminal size), file counts and versions. Every key but ESC is only shown, not acted on, so it doubles as a key tester: press a key and see whether your terminal sends what you expect (CTRL-E shows `{:ctrl, "e"}`, not the F2 it stands for elsewhere). ↑↓ PGUP PGDN scroll; ESC returns. It is not in the menus or the F1 help (`Agendum.TUI.DevTools`).
