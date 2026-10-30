# Minutes of the panel meeting, 2026-10-26-1358

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, José Who Brews, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `9c1b3a0`

*The third meeting of the day. Owl had been at the window since breakfast and opened the door before anyone could knock. Mitch's papers went straight onto the stairs; Little Marie-Who-Folds took the last chair and did not look at the place where the umbrella stand used to be. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words. The minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting, observing that a meeting with only one subject was a rare and restful thing.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude keeps the minutes; Old Mitch Lilypad and Little Marie-Who-Folds approve them.

## § 3 Adoption of the agenda

No thoughts were waiting under Next meeting; the agenda came from the roadmap's first item, which says a meeting settles it first. Before the meeting, Claude checked Update defaults in Agenda 2.0, run headless in DOSBox on a copy of the install:

| What was checked | What Agenda showed |
| --- | --- |
| File Properties ▸ Update defaults, SPACE | A one-line box, "Update new file properties? Yes"; frame "Press ENTER to accept, ESC to cancel"; SPACE turns Yes into No |
| Where the defaults go | Agenda's program settings file, `AGENDA.ENV` (9 bytes changed: Make backup on open, Empty trash, Tab size; then the date settings), written the moment Yes is accepted, not when the file is saved |
| ESC on File Properties afterwards | Does not cancel the box's changes: the Yes has kept them |
| A new file afterwards | Make backup on open Yes, Empty trash "When item is discarded", Tab size 8, Morning 9:00, Beginning of week Tue, date separator "-", 24-hour clock (the title bar's clock too: `10-26-26 13:49`) |
| What a new file does not get | The file description (blank) |
| Not checked | The password, Auto-assign settings and Global protection (the manual says "File Properties settings"); what F8 Default gives afterwards |
| Existing files | Keep their settings (User's Guide 17-50) |

The User's Guide (22-14, 17-50, H-9) says Update defaults also saves the Print Layout settings; printing is out of scope in Agendum (SPEC § 6). The agenda was adopted as it stood.

## § 4 The previous minutes

| Decision (2026-10-26-2) | Status | Evidence |
| --- | --- | --- |
| The accepted enhancements' tags confirmed | Done | `docs/plans/AGENDA_PARITY.md` |
| The accepted modifications' tags confirmed; the key bar in moves changed back | Done | `b28bb59` (R80) |
| Declared done when the key bar in moves is built and tagged | Done | `1bd08b6` (v0.62.0), `a1ec3d1` |
| `docs/HELP_WOOD.md` with its tone rules, and a check | Done | `docs/HELP_WOOD.md` |

## § 5 Update defaults, as Agenda does it

**Background.** Agenda's File Properties box has an Update defaults row: it takes the current file's settings and makes them the starting point for every new file. Agendum does not have it yet; it is one of the last three F10 commands missing (`docs/plans/AGENDA_PARITY.md`). Where should the defaults be kept, which settings do they include, and does the command behave exactly as Agenda's?

**Discussion.** **Mitch** pointed to the DOSBox evidence: a snapshot taken at the Yes, written at once to the program's own settings file and never into the data file, with the box's changes kept even if ESC follows. In Agenda's world that file belonged to the person's own installation, so in Agendum it is the preferences file. He asked that one thing be checked in Agenda before it is built: whether F8 Default in File Properties then gives Agenda's built-in values or the person's defaults. **José** noted that it fits the architecture without strain: the shell reads a "new file defaults" value from the preferences and the core receives it as an argument (`Core.new_file/1`), so the core stays pure and only `Agendum.Preferences` touches the disk; since the file itself does not change, it is not an undo step. **Carsten** liked that the defaults stay plain `key = value` lines that a person can read and edit, and that a person's habits stay with the person. **Marie** asked whether to write the whole snapshot or only the settings that differ from Agenda's built-in values: the difference keeps the preferences short, and a later change to a built-in value still reaches the settings the person never touched. Mitch replied that Agenda wrote everything, but agreed that nothing on screen would differ. **Claude**, for its own lens, observed that in the planned web app each user has their own defaults, which matches one preferences file per person rather than one shared program file.

The panel advised building it as Agenda's, kept in the preferences, writing only what differs from Agenda's built-in values.

**Decided:** Update defaults as Agenda's: the same row and question ("Update new file properties? Yes"), written to the person's preferences the moment it is accepted, and the box's changes kept. It covers the File Properties settings (not the description or the password), the global date settings with the display format, and the auto-assign settings; the preferences keep only the settings that differ from Agenda's built-in values. Existing files are unchanged. What F8 Default gives afterwards is checked in Agenda first. No habit changes: it is a new command.

*Marie thanked Mitch's papers on the stairs and stacked them. Mitch let her.*

## § 6 The owner's own defaults for new files

**Background.** The owner wants their own defaults for new files, such as the date format: a new file shows Agenda's MM/DD/YY (R41), while the owner types dates in Swedish. Is Update defaults enough for this, or should more be done, such as a built-in date format that follows the date language? And which ways of making a file should use the person's defaults?

**Discussion.** **Mitch** recalled that Agenda's built-in format was MM/DD/YY for its European users too, and that its own answer was Update defaults (User's Guide H-9, the tip on display formats); a built-in format that follows the date language would be a difference from Agenda needing ADR 0043's test or the Extras switch, for something a person does once. **Carsten** agreed, provided the help says where to set it, and proposed that only an empty file the person makes uses their defaults: File ▸ Retrieve with a new name, and `agendum new.agendum` on the command line. Starters, samples, the demo and the clinic are finished content with settings of their own; an `.AG` import keeps the file's own format (R72), and a copy keeps its source's. **Marie** asked for one way of doing it, not two, and noted that the Thoughts file made by `mix agendum.thoughts` is a developer's tool that should not read anyone's preferences. **Claude** observed that the same rule carries over to the web: a user's defaults go into the empty files that user makes, and nowhere else.

The panel advised Update defaults as the only way, with the help saying how.

**Decided:** Update defaults is the only way; Agenda's built-in values stay (MM/DD/YY). The person's saved defaults apply to empty files they make themselves (File ▸ Retrieve with a new name, `agendum new.agendum`), not to starters, samples, the demo, the clinic, the Thoughts file, `.AG` imports or copies. The F1 help for Update defaults and Display format says where to set it.

## § 7 Any other business

None.

## § 8 Next meeting

When the agenda has enough items; the meeting on the expert review of 2026-10-26 is next on the roadmap (In order 2).

## § 9 Closing of the meeting

Owl closed the meeting, remarking that it had been short enough for the tea to stay warm, which he believed was a first.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | Update defaults as Agenda's, kept in the preferences, only what differs from the built-in values; F8 Default checked first | `docs/ROADMAP.md` (In order 1; Fixes and polish), `docs/plans/AGENDA_PARITY.md` (File Properties; the F10 menu), ADR 0008 (amended) |
| 6 | Update defaults the only way; defaults only for empty files the person makes; the help says where | `docs/ROADMAP.md` (Fixes and polish), ADR 0008 (amended) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
