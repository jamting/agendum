# Keyboard guide

Agenda's original keys assume a PC keyboard with F-keys, INS and an ALT
key. Each command also has a key that works on a Mac laptop keyboard in
any terminal. ⌘ (Command) shortcuts can be added through your terminal's
settings, as described in the second half of this guide.

## Keys that work everywhere

| Command                                                                                         | Agenda key                    | Mac-friendly alternative                                              |
| ----------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------- |
| New item / column entry / category / view                                                       | INS                           | **CTRL-N**                                                            |
| Edit (item, section head, column entry, category)                                               | F2                            | **CTRL-E**                                                            |
| Mark done                                                                                       | F4                            | **CTRL-K**                                                            |
| Discard                                                                                         | ALT-F4                        | **CTRL-D**                                                            |
| Set the When date                                                                               | ALT-F2                        | ESC then `@`, or menu Item ▸ When                                     |
| Next / previous completion while typing a column entry                                          | F8 / F7                       | ALT-N / ALT-P (ESC then `n` / `p`)                                    |
| New category instead of the completion                                                          | F5 or INS                     | **CTRL-N**                                                            |
| Collapse / expand a family or section (twice: all)                                              | ALT-− / ALT-=                 | ESC then `-` / `=` (Option-− / Option-= also work)                    |
| Unmark all items                                                                                | ALT-F7                        | ESC then `&`, or menu Item ▸ Unmark                                   |
| Jump to the next marked item                                                                    | ALT-J                         | ESC then `j` (Option-j)                                               |
| Assign the item or marked items to a category (MakeAssign)                                      | ALT-M                         | ESC then `m` (Option-m), or menu Item ▸ Categorize                    |
| Go to a section (GO TO, in a view); sort a family (category manager); sort views (view manager) | ALT-F5                        | ESC then `%`                                                          |
| Next / previous view (in a view)                                                                | ALT-N / ALT-P                 | ESC then `n` / `p`                                                    |
| Show / hide empty sections (in a view)                                                          | ALT-V                         | ESC then `v`                                                          |
| Insert an item (in a view)                                                                      | ALT-I                         | ESC then `i`, or INS / **CTRL-N**                                     |
| Save / retrieve a file (in a view)                                                              | ALT-W / ALT-G                 | ESC then `w` / `g`, or **CTRL-S** / **CTRL-O**                        |
| Quit                                                                                            | ALT-Q                         | ESC then `q`, or **CTRL-Q**                                           |
| Show / hide the function key map                                                                | ALT-K                         | ESC then `k`                                                          |
| Search this view; then next / previous match                                                    | ALT-F6; ALT-N / ALT-P         | ESC then `^`; ESC then `n` / `p`                                      |
| In a note: search / replace; find the next occurrence (after a single replacement: replace it)  | ALT-F6; ALT-S                 | ESC then `^`; ESC then `s`                                            |
| In a note: insert today's date / the time                                                       | ALT-D / ALT-T                 | ESC then `d` / `t`                                                    |
| In a note: the next / previous item's (or category's) note                                      | ALT-N / ALT-P                 | ESC then `n` / `p`                                                    |
| Back to the previous view (LAST VW)                                                             | ALT-F8                        | ESC then `*`, or menu View ▸ Last                                     |
| Set or cancel an alarm (Item Alarm)                                                             | ALT-A                         | ESC then `a`, or menu Item ▸ Alarm                                    |
| Pop-up calendar: pick a date (in a date column) / look one up (anywhere in a view)              | F3 / ALT-C                    | ESC then `3` / ESC then `c`                                           |
| In the calendar: a day, a week; the first / last day of the month                               | ← → ↑ ↓; HOME / END           | fn-← / fn-→ for HOME / END                                            |
| In the calendar: a month back / ahead; a year back / ahead                                      | PGUP / PGDN; CTRL-← / CTRL-→  | fn-↑ / fn-↓; `<` / `>`                                                |
| In the calendar: set the date; a time (F6); go to a typed date; cancel                          | ENTER; F6; type it; ESC       | ESC then `6` for F6                                                   |
| Make the item depend on the marked items, or clear its dependencies                             | ALT-O                         | ESC then `o`                                                          |
| Execute all conditions and actions on all items / those of the highlighted category             | ALT-X / ALT-E                 | ESC then `x` / `e`, or menu Category ▸ Execute                        |
| Category manager: add a sibling below / above                                                   | ALT-D (or ALT-I, INS) / ALT-U | ESC then `d` / `u`, or **CTRL-N**                                     |
| Category manager: add a child / a new family after the parent                                   | ALT-R / ALT-L                 | ESC then `r` / `l`                                                    |
| Remove from section / column                                                                    | DEL                           | fn-⌫ (forward delete)                                                 |
| Undo / redo                                                                                     | —                             | **CTRL-Z** / **CTRL-Y** (also in the menu)                            |
| Save / open / print to file / quit                                                              | menu                          | **CTRL-S** / **CTRL-O** / **CTRL-P** / **CTRL-Q** (CTRL-C also quits) |
| Previous / next section                                                                         | CTRL-PGUP / CTRL-PGDN         | ⌥↑ / ⌥↓ (in a view)                                                   |
| Any function key Fn                                                                             | F1…F10                        | ESC then the digit (ESC 0 = F10)                                      |
| ALT-F1…ALT-F10                                                                                  |                               | ESC then the shifted digit (`!` … `)`)                                |
| Menu                                                                                            | F10                           | `/`                                                                   |

While typing text:

| Key                          | Action                                |
| ---------------------------- | ------------------------------------- |
| CTRL-A / CTRL-E (HOME / END) | Start / end of line                   |
| ⌥← / ⌥→ (ALT-B / ALT-F)      | Word left / right                     |
| CTRL-K                       | Delete to the end of the line         |
| CTRL-W or ⌥⌫                 | Delete the previous word              |
| CTRL-U                       | Clear the line                        |
| CTRL-D                       | Delete the character under the cursor |

Keys that need the ⌥ (Option) key, such as ALT-D (add section) or ⌥←, need
"Use Option as Meta key" (Terminal.app: Settings ▸ Profiles ▸ Keyboard) or
"Esc+" for the left Option key (iTerm2: Settings ▸ Profiles ▸ Keys). Without
it, ALT-D, ALT-R and ALT-L still work in Terminal.app (Agenda recognises the
`∂`, `®` and `¬` characters that Option produces), and ESC followed by the
letter always works.

Function keys: on a Mac, hold **fn** to send F1…F12, or enable "Use F1, F2,
etc. keys as standard function keys" in System Settings ▸ Keyboard.

## ⌘ shortcuts

**macOS terminals never pass ⌘ keys to the programs running in them.** ⌘N,
⌘Z, ⌘S and ⌘Q belong to the terminal itself (new window, undo, …). To use
them in Agenda, tell your terminal to send Agenda's CTRL key instead:

| ⌘ shortcut | Command               | Send                      |
| ---------- | --------------------- | ------------------------- |
| ⌘N         | New                   | `\x0e` (CTRL-N)           |
| ⌘Z         | Undo                  | `\x1a` (CTRL-Z)           |
| ⇧⌘Z        | Redo                  | `\x19` (CTRL-Y)           |
| ⌘S         | Save                  | `\x13` (CTRL-S)           |
| ⌘O         | Open                  | `\x0f` (CTRL-O)           |
| ⌘P         | Print to file         | `\x10` (CTRL-P)           |
| ⌘I         | Properties (Get Info) | `\x1b6` (ESC 6 = F6)      |
| ⌘⌫         | Discard               | `\x04` (CTRL-D)           |
| ⌘↑ / ⌘↓    | First / last line     | `\x1b[1;5H` / `\x1b[1;5F` |
| ⌘/         | Help                  | `\x1b1` (ESC 1 = F1)      |

> ⚠️ **Scope these mappings to Agenda.** Terminal key mappings usually apply to
> every tab. In an ordinary shell, CTRL-Z suspends the running program and
> CTRL-S can freeze output. So put the mappings in a separate profile or
> configuration used only to run Agenda, as shown below. ⌘Q is left out on
> purpose: quitting the terminal by accident is worse than typing CTRL-Q.

The snippets below follow each terminal's documented configuration syntax,
but they have not been tested here. Please report any that need adjusting.

### iTerm2

Create a profile just for Agenda (Settings ▸ Profiles ▸ +), set its
_Command_ to the `agenda` binary, then add each shortcut under
Profiles ▸ Keys ▸ Key Mappings ▸ + with the action **Send Hex Code**:

| Shortcut | Hex code    |
| -------- | ----------- |
| ⌘N       | `0x0e`      |
| ⌘Z       | `0x1a`      |
| ⇧⌘Z      | `0x19`      |
| ⌘S       | `0x13`      |
| ⌘O       | `0x0f`      |
| ⌘P       | `0x10`      |
| ⌘I       | `0x1b 0x36` |
| ⌘⌫       | `0x04`      |

Open Agenda with that profile (Profiles ▸ Agenda). If a ⌘ shortcut still
triggers the iTerm2 menu item, remove or change the menu shortcut in System
Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ App Shortcuts.

### kitty

Save as `~/.config/kitty/agenda.conf` and run
`kitty --config ~/.config/kitty/kitty.conf --config ~/.config/kitty/agenda.conf agenda`:

```conf
map cmd+n       send_text all \x0e
map cmd+z       send_text all \x1a
map cmd+shift+z send_text all \x19
map cmd+s       send_text all \x13
map cmd+o       send_text all \x0f
map cmd+p       send_text all \x10
map cmd+i       send_text all \x1b6
map cmd+backspace send_text all \x04
map cmd+up      send_text all \x1b[1;5H
map cmd+down    send_text all \x1b[1;5F
```

### Ghostty

Save as `~/.config/ghostty/agenda` and start a separate Ghostty instance
with `open -na Ghostty --args --config-file=$HOME/.config/ghostty/agenda -e agenda`:

```conf
keybind = cmd+n=text:\x0e
keybind = cmd+z=text:\x1a
keybind = cmd+shift+z=text:\x19
keybind = cmd+s=text:\x13
keybind = cmd+o=text:\x0f
keybind = cmd+p=text:\x10
keybind = cmd+i=text:\x1b6
keybind = cmd+backspace=text:\x04
keybind = cmd+up=text:\x1b[1;5H
keybind = cmd+down=text:\x1b[1;5F
```

### WezTerm

Add a separate config (e.g. `~/.config/wezterm/agenda.lua`) and run
`wezterm --config-file ~/.config/wezterm/agenda.lua start -- agenda`:

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
    { key = 'i', mods = 'CMD', action = send '\x1b6' },
    { key = 'Backspace', mods = 'CMD', action = send '\x04' },
  },
}
```

### Terminal.app

Terminal.app cannot remap ⌘ shortcuts, so use the CTRL keys in the first
table (CTRL-N, CTRL-Z, CTRL-S, …).

## How it works

Raw terminal mode would normally let the tty driver swallow some of these
keys: CTRL-S/Q (flow control), CTRL-C/Z (signals), CTRL-O/V (discard,
literal-next). `Agenda.TUI.Terminal` turns those features off with `stty`
while Agenda runs and restores them on exit, so every CTRL key reaches
Agenda.

## Developer tools (hidden)

ESC then `?` (ALT-? where Option sends Meta) opens the developer screen from
anywhere except while typing: the last key as Agenda decoded it, the mode
stack, cursor, undo depth, session (time, languages, input format, theme,
preferences, terminal size), file counts and versions. Every key but ESC is
only shown, not acted on, so it doubles as a key tester: press a key and see
whether your terminal sends what you expect (CTRL-E shows `{:ctrl, "e"}`,
not the F2 it stands for elsewhere). ↑↓ PGUP PGDN scroll; ESC returns. It is
not in the menus or the F1 help (`Agenda.TUI.DevTools`).
