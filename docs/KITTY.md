# Plan: the ALT and CTRL key bars while the key is held

A plan for the Roadmap item "The ALT and CTRL key bars while the key is held
(kitty keyboard protocol), and after ESC as a prefix". Not started yet.

## What Agenda does

DOSBox shots 4, 5 and 20 (`docs/reference/screens/notes.md`):

- **Holding ALT** turns the bottom bar into the ALT-F keys. In a view:
  `AltF1 Compose, AltF2 When, AltF3 Macro, AltF4 Discard, AltF5 Go To,
  AltF6 Search, AltF7 UnmkAll, AltF8 Last Vw, AltF9 Copy, AltF10 Move`. The
  note editor has its own set (`MakeCat, Delete, MakeItm, GetItms, Append` …).
- **Holding CTRL** shows `CtlF1 … CtlF10` with empty labels; those keys are
  free for macros.
- Letting go of the key brings the normal bar back.

## The hard part: a terminal cannot see a held modifier

A normal terminal sends nothing for ALT or CTRL pressed alone. The only way
to see it is the **kitty keyboard protocol** (progressive enhancement):

| Flag | What it does                                                        | Why we need it                                     |
| ---- | ------------------------------------------------------------------- | -------------------------------------------------- |
| 1    | Disambiguate: ESC arrives as `CSI 27 u`                             | No more 40 ms lone-ESC timeout                     |
| 2    | Report press, repeat and release events                             | To know when the modifier is let go                |
| 4    | Report the shifted key                                              | Shifted letters on any layout                      |
| 8    | Report all keys as escape codes, the modifier keys alone included   | The held ALT / CTRL itself                         |
| 16   | Report the text the key produces                                    | Swedish: `å`, `Ä`, Option-2 = `@` on a Mac         |

So we push all five (`CSI > 31 u`). With flag 8, every key, typed text
included, arrives as `CSI code[:shifted[:base]] ; mods[:event] ; text u`;
characters must be taken from the text field, not rebuilt from the key code.

Supported by kitty, Ghostty, WezTerm (with `enable_kitty_keyboard = true`),
foot and Alacritty; not by Terminal.app. Zed's terminal and iTerm2 are
unclear and need testing. Without the protocol nothing changes, and the ESC
prefix below still works.

## Found while planning

1. **"ESC then 3" only works when the bytes arrive within 40 ms**
   (`@escape_timeout` in `Agendum.TUI.App`), as from a terminal key binding or
   Option-as-Meta. Typed by hand, ESC does nothing in a view and `3` starts
   a new item. `docs/KEYBOARD.md` promises more than the program does; the
   ESC prefix in step 2 makes it true (in a view).
2. **CTRL-F keys are not decoded.** `Keys.modify/2` passes `{:f, 4}`
   through unchanged when the ctrl bit is set, so CTRL-F4 acts as F4. A CTRL
   bar needs `{:ctrl_f, n}`.

## Steps (one commit each, test first)

### 1. CTRL-F keys

- `Agendum.TUI.Keys` decodes CTRL-F1…F10 as `{:ctrl_f, n}`.
- `Agendum.TUI.MacroKeys` reads and writes them as `{CtlF4}`, so a macro can
  be attached to one. Nothing else uses them.
- Tests: `keys_test`, `macro_keys_test`.

### 2. The bars (pure) and the ESC prefix

- `State` gets `held` (`nil | :alt | :ctrl`) and `prefix` (`nil | :esc`).
- `Agendum.TUI.Render.KeyBar.line/1` gets `alt_keys(mode)` and
  `ctrl_keys(mode)`, with Agenda's short labels and our fuller ones when
  they fit.
- Attached macros' names also show on ALT-F and CTRL-F keys
  (`attached_label/2` generalised beyond the plain F keys).
- Modifier events (`{:modifier, :alt | :ctrl, :press | :release}`) only set
  `held`: no undo step, not recorded by macro Learn, nothing interrupted.
- **ESC prefix in a view:** where ESC now does nothing (a plain view, no
  line being typed), ESC arms `prefix: :esc`, shows the ALT bar and a hint
  in the control panel. The next key becomes F-n (digit), ALT-F-n (shifted
  digit) or ALT-letter; ESC again cancels. It is resolved in
  `Update.handle/2` before macro Learn and attached-key lookup, so Learn
  records `{AltF2}`, not ESC plus a key. Everywhere else ESC keeps its
  meaning (cancel, return).
- TUI tests: press `{:modifier, :alt, :press}` and see `AltF4 Discard` on
  `screen/1`; release brings the normal bar back; ESC then `@` opens When;
  Learn ignores modifier events; no undo step is recorded.

### 3. The kitty protocol in the terminal layer

- `Agendum.TUI.Terminal.start/0` asks `CSI ? u` followed by `CSI c`. If the
  `CSI ? flags u` reply comes before the device attributes reply, it pushes
  the flags with `CSI > 31 u`; `stop/0` pops them with `CSI < u`. The reply
  is read in `Agendum.TUI.App`, with a timeout.
- `Agendum.TUI.Keys` decodes `CSI … u`, and `:event` on the legacy `~`,
  `ABCD` and `PQS` forms (the CSI regex must accept `:`).
- Lock bits (caps lock 64, num lock 128) are masked off. Repeat counts as a
  press. Releases of other keys are dropped. Modifier key codes 57441–57449
  (left/right shift, control, alt, super) become modifier events.
- Unit tests with real byte sequences, Swedish ones included. A manual check
  with the devtools screen ("any key: show it") in kitty, Ghostty and Zed.
- ADR: use the kitty keyboard protocol when the terminal has it.

### Docs

`docs/SPEC.md` §5 (with a rule number), `docs/KEYBOARD.md` (fix the "ESC
then" wording, a kitty section), the F1 help, tick the Roadmap box.

## Open decisions (suggested defaults)

1. **The CTRL bar's contents.** Agenda's is empty. Suggested: our CTRL keys
   for the mode (`^N New, ^E Edit, ^K Done, ^D Discard, ^Z Undo, ^S Save` …)
   plus CTRL-F keys attached to macros.
2. **ALT-F keys we do not have yet** (ALT-F1 Compose, ALT-F9 Copy).
   Suggested: leave them out, as the normal bar lists only keys that work;
   the alternative is Agenda's look, the key with an empty label.
3. **The ESC prefix only in a plain view.** Suggested. Wider use would mean
   delaying every ESC to wait for a second key, which makes cancelling slow.
