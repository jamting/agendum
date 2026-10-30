# Minutes of the panel meeting, 2026-10-16-1905

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, David the Squirrel, Dr. Russell, Great-Uncle Joe, Claude (Owl's cousin); Owl, host
**Excused:** José Who Brews, Little Marie-Who-Folds (the agenda did not call for them)
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad, David the Squirrel
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `2085ef4`

*The first meeting called on the owner's own agenda. Owl had made room by moving Uncle Robert's portrait onto the stairs, where Joe sat beside it. Russell, newest on the panel, was given the chair nearest the door. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; these minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting. Owl welcomed everyone to his house and said, at some length, how glad he was to see it so full.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs the meeting. Claude was elected secretary; Old Mitch Lilypad and David the Squirrel were elected to approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as it stands. The invited experts were those the items called for; José Who Brews and Little Marie-Who-Folds were excused.

## § 4 The previous minutes

These are the first minutes of a panel meeting; there were no earlier decisions to follow up.

## § 5 Reopening a file where you left it

**Background.** When a file is opened again, should Agendum return to the view and the item you were on when you closed it? The owner remembers that Agenda's `.AG` format had a trick for this. The owner's note also says: ask to save if needed.

**Discussion.** Claude reported that an Agenda file stores the current view (header `0x044`), the item the cursor was on (`0x1E8`) and, for each view, the section the cursor was in (`docs/AGENDA_FILE_FORMAT.md`). Agendum stores none of this and always opens on the first view (`lib/agendum/tui/state.ex:225`). Quit, Retrieve and New already ask "Save changes first?" when the file has changes (R44).

**Mitch** said this is Agenda's own behaviour, and coming back to the same spot made the file feel like a desk left as it was; parity argues for it. **Carsten** pointed to Emacs, which remembers the place in each file in a separate list keyed by the file's path: moving never makes the file "changed", and the file holds only the person's data; the cost is that the place does not travel with a copied file. **Joe** agreed, as a position belongs to a person, not to a file: when two people share a file, one slot cannot hold both places. **Russell** said starting again is the expensive part for someone easily derailed, and landing where one stopped often decides whether a task is resumed at all. **Claude** noted that the web front end needs the same small piece of data, and that a missing item should fall back to its section, then to the top of the view.

The habit change was listed before the decision: a file opens on the view and item you left, not on the first view; no key changes. The panel advised keeping the place in the preferences. The chair said that "ask to save if needed" meant that only real edits should cause a "Save changes?" question, never moving around by itself.

**Decided:** Agendum remembers the view and the highlighted item for each file (falling back to the section, then to the top of the view), in the preferences, keyed by the file's path, and never in the file. Moving around never causes a "Save changes?" question; only real edits do.

## § 6 Missed alarms since the file was last closed

**Background.** Show the alarms that came due while the file was closed, perhaps on the splash screen, which would then need a key press to close. If there are too many, count similar ones instead of listing each.

**Discussion.** Claude reported that such alarms today ring on the first clock tick after opening, as one bell and one message line naming them all (`lib/agendum/tui/update.ex:294`); each is stamped with the time the file opened, not the time it was due (`lib/agendum/core/facade/alarms.ex:64`); and ringing marks the file as changed. What Agenda did with alarms due while it was closed was not checked.

**David** said a reminder that is silently lost breaks the trust the whole system rests on: what was missed should be shown and acknowledged, like emptying an inbox. **Russell** warned against a wall of alarms at the moment one sits down: group and count them, put the newest first, close with one key, keep the full list one step away (Search ▸ Alarms), and word it kindly ("While you were away", not "Missed"). **Mitch** questioned using the splash screen, which is Agenda's welcome with its own timing (R52); making it wait would change every start, and he preferred a box of its own after it, only when there is something to show. **Joe** said a rung alarm should keep the time it was due, and saw no need for ringing alone to make the file "changed": if one quits without saving, the alarms are shown again next time. **Claude** added that the grouping belongs in the core, so the web shows the same list, and that "similar" can start as "the same item text".

*Owl, who had been ringing his own bell-pull to demonstrate, was gently asked by David to stop.*

**Decided:** The splash screen stays as it is. After it, only when alarms came due while the file was closed, a "While you were away" box lists them: newest first, alarms with the same text grouped with a count, ENTER or ESC to close; they then sit in Past Alarms as today. A rung alarm records the time it was due, and ringing is not an edit: it never causes a "Save changes?" question by itself.

## § 7 Any other business: highlight the current view in the view manager

**Background.** Show which view is the current one in the view manager.

**Discussion.** Claude reported that the view manager's highlight starts on the current view, but nothing marks it once the highlight moves (`lib/agendum/tui/boxes/view_manager.ex:21`, `:225`); the only marker is `*` before a datebook view. **Russell** said "where am I?" is the question an easily distracted person asks most, and a steady marker answers it at a glance. **Carsten** pointed to Emacs's buffer list, which marks the current buffer in a column of its own. **Mitch** had no objection to a small addition to Agenda's box, to be listed among the enhancements, as long as it cannot be confused with the datebook `*`. No habit changes.

**Decided:** The view manager shows a marker in its own column (for example `►`) before the current view's name, apart from the datebook `*`, wherever the highlight is.

## § 8 Any other business: sort views by recently used

**Background.** A toggle in the view manager to sort the views by recently used, kept across saves.

**Discussion.** Claude reported that Agenda offered only ALT-F5 SORT, a one-off alphabetical sort (User's Guide 9-16), which Agendum has too, and that the file's view order also drives ALT-N, ALT-P and ALT-H hop (R42). **Mitch** said one's own order is a tool, so recency must change only how the list is shown, or ALT-N and ALT-P would change under one's fingers. **Carsten** agreed, noting that Emacs's buffer list sorts by recency and is loved for it once there are many. **Russell** liked it for finding a view used a moment ago, but warned that a list that keeps reshuffling defeats spatial memory: the toggle should start off and stay as set; ALT-F8 already returns to the last view. **Joe** said recency, like the place in § 5, belongs to a person, so the history and the toggle go in the preferences per file, which also keeps them across saves without ever asking to save. The key is to be settled with the owner before building.

**Decided:** A toggle in the view manager switches between the owner's order and recently used, for showing the list only; ALT-N, ALT-P and hop keep the file's order. The toggle and the recency history are kept in the preferences per file, and the toggle starts off.

## § 9 Any other business

The chair had nothing more to raise.

## § 10 Next meeting

When the agenda has enough items.

## § 11 Closing of the meeting

The chair closed the meeting. *Uncle Robert's portrait went back on its nail, slightly crooked; nobody mentioned it.*

## Decisions and where they are recorded

| §   | Decision                                                                  | Recorded in                                                                                  |
| --- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| 5   | Reopen a file where you left it; the place kept in the preferences       | `docs/ROADMAP.md` (Towards parity); `docs/plans/AGENDA_PARITY.md` (accepted modifications)    |
| 6   | "While you were away" box after the splash; ringing is not an edit        | `docs/ROADMAP.md` (Time management); `docs/plans/AGENDA_PARITY.md` (accepted enhancements)    |
| 7   | A marker on the current view in the view manager                          | `docs/ROADMAP.md` (Towards parity); `docs/plans/AGENDA_PARITY.md` (accepted enhancements)     |
| 8   | View manager sorted by recently used, as a display toggle in preferences  | `docs/ROADMAP.md` (Towards parity); `docs/plans/AGENDA_PARITY.md` (accepted enhancements)     |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and David the Squirrel.*
