# Minutes of the panel meeting, 2026-10-24-2057

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, Dr. Russell, Great-Uncle Joe, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Dr. Russell
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `89c2fe7`

*The meeting was called in the middle of a working session, an hour after the key bar had become Agenda's two lines, so the new bar was still warm on the screen Owl had propped against the umbrella stand. Owl rang the bell-pull twice by mistake, and Old Mitch Lilypad's papers slid down the stairs. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting and welcomed the guests, apologising for the draught from the door knocker.

## § 2 Election of a chair, a secretary and two approvers

The owner was elected chair and Claude secretary. Old Mitch Lilypad and Dr. Russell were elected to approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted with one item, raised by the owner during the session (§ 5). Mitch, Carsten, Russell and Joe were invited; Marie and José sent apologies, the item being about keys and screens rather than scope or code.

## § 4 The previous minutes

| Decision | Status | Evidence |
| --- | --- | --- |
| § 5 (2026-10-23) The import makes a datebook of the imported documents | Done by the owner, by hand in the project file; the import does not make it | `31ffc14` |

## § 5 Showing the ALT and CTRL keys, for exploring

**Background.** In Agenda, holding ALT or CTRL showed what those keys do; Agendum has nothing like it. The kitty-protocol plan for real held keys was dropped on 2026-10-16 (`docs/plans/archive/KITTY.md`), and the owner did not like that path. The owner's idea: a single press of CTRL shows the commands for a few seconds; or is there another solution? The owner sees it as a key feature for explorability.

**What Agenda did.** The secretary checked it before the meeting in Agenda 2.0 run headless on a copy of PLANNER, setting the BIOS's shift flags by hand. Holding ALT turns the key bar (not the F10 menu, which stays as it is) into the ALT-F keys of the place: in a view `Compose When Macro Discard Go To Search UnmkAll Last Vw Copy Move`; the note, the category manager and boxes have their own. Holding CTRL or SHIFT shows `CtlF1 … CtlF10` and `ShfF1 … ShfF10` with empty labels, keys left free for macros. The ALT-letters (ALT-M and the rest) are never shown.

**Discussion.** **Joe** began with the hard fact: a normal terminal sends nothing when CTRL or ALT is pressed alone, only when another key comes with it, so a single press of CTRL meets the same wall as holding it; only the kitty keyboard protocol reports a lone modifier, and whether iTerm2, the owner's terminal, supports it is unverified. **Mitch** observed that Agenda's bars only ever showed the ALT-F keys, so Agenda's own exploring was modest; what matters is that the keys are on screen when one wonders what is there, and that does not depend on holding a key. **Carsten** described Emacs's which-key, which lists the keys that can follow a prefix, and proposed ESC in a plain view as such a prefix: it would show the ALT bar, and the next key would count as ALT and that key. **Russell** objected to a hint that disappears after a few seconds: it punishes those who read slowly or are interrupted; it should stay until the next key. **Claude** proposed that the bars be made from the keymaps, as the F1 help is (R65), so that the bar, the help, the web front end and an agent read one table; and noted that keys named in the F10 menu, which Agenda did not have, would be an extra.

*The panel's first advice, the ESC prefix, never reached a vote: the chair stopped the questions to add something.*

The chair said that the SHIFT and CTRL function keys are where macros are attached (SHIFT-F10, for example), so showing those bindings matters even more to someone who uses macros. The chair proposed that ALT-K, which now shows or hides the bar, cycle through five states instead of two: the normal bar, the ALT bar, the CTRL bar, the SHIFT bar, and hidden, gaining the two lines; the last character of the bottom row, blank today, would say which bar is shown (A, C or S).

**Mitch** welcomed it as Agenda's content exactly, slot for slot, reached another way; the letter costs nothing, as Agenda's bar leaves the eightieth column empty, and a CTRL or SHIFT bar is where an attached macro's name shows. **Joe** noted that it is display state only, with no protocol and no timer, so it works in every terminal, and named the groundwork: the CTRL-F keys are not decoded (CTRL-F4 acts as F4, `Agendum.TUI.Terminal.Keys.modify/2`, confirmed in the meeting), and macOS keeps some CTRL-F keys for its keyboard navigation, which the key tester (ALT-?) would show. **Russell** found it better than a timer, as it stays until changed; his worry, a bar saying Discard over F4 while F4 still means Done, is answered by the key names on the bar (`AltF4`) and the letter. **Carsten** pointed out the habit change: hiding the bar takes four presses instead of one. **Claude** advised keeping only shown or hidden for next time, as the Display key map setting does now.

At the chair's request the secretary explained the CTRL-F issue again: Agendum's decoder sees the CTRL bit on a function key but has no CTRL version of one, so a macro cannot be attached to CTRL-F4 and pressing it marks the item done; and some CTRL-F keys may never reach the terminal on a Mac.

The chair then asked for the pros and cons of Claude's point. Claude set them out: bars made from the keymaps cannot drift from what the keys do (a hand-written label had already drifted that afternoon, in the category manager), give the ALT, CTRL and SHIFT bars of every place for free, show attached macros, and serve the help, the web and an agent from one table, and one test can compare them all with bars captured in DOSBox; against that, each command needs a short Agenda label, about a hundred short texts written once, it is more work now, and keys Agenda had but Agendum lacks show empty slots. **Mitch** favoured making them from the keymaps with Agenda's labels as data, as a test then catches every difference from Agenda. **Joe** and **Russell** warned against a bar that changes with what can run at the moment (greyed or emptied labels): Agenda's bar was fixed per place, and slots that flicker as one moves are worse; the F1 help's `c` already says what cannot run. The chair liked Claude's suggestion, adding that it would later let customised key bindings show up in the menu too.

**Decided:**

1. ALT-K cycles five states: the normal bar, the ALT bar (`A` in the last column of the bottom row), the CTRL bar (`C`), the SHIFT bar (`S`), and hidden. The bars are Agenda's, slot for slot, with the names of macros attached to keys. Only shown or hidden is kept for next time, so Agendum starts on the normal bar. In boxes and the menu the letter shows, and the slots wait for the texts step.
2. The groundwork comes first: the CTRL-F keys decoded as their own keys, and which of them a Mac lets through checked in the key tester.
3. Every key bar is made from the keymaps, with a short Agenda label on each command, fixed per place (not greyed by what can run), and a test against bars captured in DOSBox. The chair agreed that this is a lasting decision: ADR 0045.

## § 6 Any other business

None. *Owl passed the biscuit tin once more; it came back empty, and nobody admitted to the last one.*

## § 7 Next meeting

When the agenda has enough items.

## § 8 Closing of the meeting

The chair closed the meeting. *Owl pressed ALT-K four times on the screen by the umbrella stand, watched the bar go A, C, S and away, and said it was very like a weather vane.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5.1 | ALT-K cycles normal, ALT, CTRL, SHIFT, hidden, with A, C or S in the last column; only shown or hidden kept | `docs/plans/AGENDA_PARITY.md` (The steps; the modifications list) |
| 5.2 | CTRL-F keys decoded first; the Mac's CTRL-F keys checked in the key tester | `docs/plans/AGENDA_PARITY.md` (The steps) |
| 5.3 | Every key bar made from the keymaps, with Agenda's short labels, fixed per place, tested against DOSBox | `docs/adr/0045-key-bars-made-from-the-keymaps.md`, `docs/ARCHITECTURE.md` |
| — | The kitty plan superseded | `docs/plans/archive/KITTY.md` (status line) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Dr. Russell.*
