# Minutes of the panel meeting, 2026-10-23-1333

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, David the Squirrel, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** David the Squirrel and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `fab275c`

*A short meeting with one card on the table. Owl, who had now hosted four meetings in two days, had begun keeping a datebook of them himself, and left it open on the sideboard as if by accident. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; the minutes were made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs; Claude is secretary; David the Squirrel and Little Marie-Who-Folds approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as proposed, with one item from the owner's Agendum project file (§ 5). Old Mitch Lilypad, Carsten Stargazer, David the Squirrel and Little Marie-Who-Folds were invited.

## § 4 The previous minutes

| Decision (meeting 2026-10-22-2130, third) | Status | Evidence |
| --- | --- | --- |
| § 5 A `/feature` skill; tests for F1 texts and KEYBOARD.md | Done | `bc39775` |
| § 6 Read-only feed entries referred to the item levels | Recorded | `docs/plans/ITEM_LEVELS.md` |
| § 7 F3 at the OPML prompts now; OPML through File ▸ Transfer ▸ Import when the extras thaw | Done; the second part waits | `57e9a17` (v0.16.2) |

Nothing was stuck.

## § 5 Imported documents in a datebook, by the date they were written

**Background.** The owner wants to see the imported documents (meetings, ADRs, session summaries) laid out in a datebook by the date each was written. The import already stores that date as the item's Entry date and leaves When empty on purpose, so documents do not fill the calendar. The owner's two datebooks, Kalender and Kalling, are on When, so the documents never show there. To discuss: how the documents should be shown by date, whether the import should make such a view, and whether documents should ever get a When date.

**Evidence.** The import gives each document its date as Entry (the meeting folder's, the summary's file name, the ADR's status line) and clears the When date a title would give it (`lib/agendum/thoughts.ex:183-194`). Kalender (a month) and Kalling (a week) in the owner's file both have When as their date category. A datebook's date category can be any date category: "the date category that Agenda uses to filter items in the view. The default is When" (User's Guide 10-6); Agendum's Datebook settings box offers Entry as well. So a datebook on Entry over Disposable already shows the documents, made by hand.

**Discussion.** **Mitch** said this is Agenda's design doing what it was for: dates are categories and a datebook is a view over any one of them, so a datebook of when things were written beside one of when things happen needs nothing new in the program.

**Carsten** compared Org-mode's two kinds of timestamp: an active one shows in the agenda, an inactive one (when a note was made) does not unless asked for. Entry plays the inactive part and When the active one, and he advised keeping the two apart: documents off When, seen through a view of their own.

**David** said the calendar is for what must happen on a day; a minute from last week is reference, not a commitment. Giving documents a When date would make the owner's calendar less trustworthy. A datebook of its own keeps reference findable by time without diluting it.

**Marie** asked whether the view would be used often or once. If it is part of how the owner works, the import should make it, as it makes the Documents view, so it survives and need not be rebuilt; she would not let it grow into a view per kind of document.

**Claude** noted that the import already makes the Documents view only when it is missing (`lib/agendum/thoughts.ex:230-237`), so a datebook would follow the same pattern, with a test, and that the import is a tool of the project (Sharpen the saw), not an Agendum extra, so the freeze does not apply. Unverified: whether Agenda's own picker offered Entry; the guide says any date category, and Entry is one.

*Owl, at the word "datebook", fetched his own from the sideboard: every entry dated the day he wrote it, which he took as proof of Carsten's point.*

The panel's advice: keep documents off When; the import makes a datebook on Entry over Disposable (a month, a slot per day) when the file has none, as it does the Documents view.

The chair agreed, with one condition: RSS items must be kept out of that datebook. Claude explained that feed entries also have an Entry date (their publish date) but live under Feeds, and the Disposable kinds are made without name matching, so the Section head keeps them out; a test will show it.

**Decided:** The panel's advice, with the chair's condition. `mix agendum.thoughts --import-docs` also makes a datebook view on Entry, its Section Disposable, a Month with a slot per day, when the file has none; When stays empty. RSS items stay out of it, shown by a test with a feed entry of the same day. No habit of anyone using Agendum changes: the view is new, and Kalender and Kalling are untouched.

## § 6 Any other business

None.

## § 7 Next meeting

When there are thoughts under Next meeting.

## § 8 Closing of the meeting

The chair closed the meeting. *Owl wrote the meeting into his datebook, under today's date, and closed it with some satisfaction.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The import makes a datebook on Entry over Disposable (Month, daily slots) when missing; When stays empty; RSS items kept out, with a test | `docs/ROADMAP.md` (Sharpen the saw) |

*Minutes kept by Claude. Approved by David the Squirrel and Little Marie-Who-Folds.*
