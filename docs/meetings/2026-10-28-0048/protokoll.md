# Minutes of the panel meeting, 2026-10-28-0048

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Old Stephen of the Seven (FranklinCovey), David the Squirrel, J.D. the Beaver, Ryder the Magpie, Master Werner (Cultured Code, Things), Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Old Mitch Lilypad, Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `adaf104`

*A cold, clear morning, and the fullest room Owl's house has ever held. David and Stephen share the window seat with a planner each on their knees, Ryder the Magpie has a dotted notebook open on the stairs, Master Werner sits on the umbrella stand, and Russell has taken the chair by the door, in case anyone needs a break. Marie has quietly thanked a stack of Owl's old minutes and laid them in a basket. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting on starter files, "now", from a thought under Next meeting in the project file (written 2026-10-22).

## § 2 Election of a chair, a secretary and two approvers

The owner chairs, Claude is secretary, and Old Mitch Lilypad and Little Marie-Who-Folds approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted with one change: Dr. Russell added to the guests the chair named ("of course").

## § 4 The previous minutes

| Decision (2026-10-26-6) | Status | Evidence |
| --- | --- | --- |
| § 5 Two lags, one cause | Noted | — |
| § 6 UI guidelines for the extras | Done | `docs/UI_GUIDELINES.md`, adopted 2026-10-27 |
| § 7 The fuzz walks and `App`'s results test first, then the extras up to the guidelines | Done | v0.69.2, v0.69.3, v0.71.0, v0.71.1, v0.72.0 |
| § 8 Only the clone's patterns; settings as views later | Done, kept | ADR 0049; ROADMAP, Beyond Agenda |

## § 5 The guests' systems, and how each would live in an Agendum file

**Background.** The owner wants to brainstorm an actual, generally usable starter file, with Old Mitch Lilypad, FranklinCovey, David the Squirrel, J.D. the Beaver, Ryder the Magpie, Little Marie-Who-Folds and one of the people building Things.app, talking about their systems in an Agendum file. Which systems could be a good match, if any? New features could also be built. The goal is a document with good, sensible ideas for new starter files.

**Discussion.** **Claude** set out the parts every system would be built from: categories in a hierarchy with exclusive children, assignment by text, conditions and actions, views with sections, columns and filters, date categories of one's own, datebooks, done items, macros, and Agenda's idea of typing first and filing later. **Mitch** observed that Agenda never shipped a method, only a tool for anyone's, and that a good starter earns its place by how much filing it does by itself. **Stephen** offered roles and goals as categories and the urgent/important quadrants as two exclusive families with a view per quadrant, Urgent filled by a near When date and Important left to the person. **David** said GTD maps almost one to one (Inbox, Contexts, Projects, Waiting For with a Since date, Someday/Maybe hidden, a weekly review view) and would build it first. **J.D.** offered Agile Results as the lightest system: three wins a day, a week and a month, with Monday Vision, Daily Wins and Friday Reflection as views. **Ryder** said rapid logging is Agenda's free-form capture, collections are categories, the logs are datebooks, and migration, the heart of the method, wants a view of last month's open tasks moved on by hand. **Werner** described Things' areas and projects, its Today, Upcoming, Anytime and Someday lists, a start date separate from a deadline, and a Logbook of done and cancelled items, and said much of its calm comes from what is not shown. **Russell** asked that each starter be judged by how it feels after three days away, with small daily numbers over long lists. **Marie** asked that each starter keep only what its method uses, three small starters rather than eight crowded ones. **Claude** noted that GTD, Agile Results and the Bullet Journal need no new features, while Things and Stephen each want the start date of § 6. The panel advised recording all seven with GTD first.

**Decided:** all seven systems go into the ideas document, with no order yet.

## § 6 Start dates, and Done versus Cancelled

**Background.** The owner is curious about Things' start date and its Done and Cancelled: useful concepts. In a blog a start date could mean the publishing date; generally it could mean "not active until". Is it generally useful? Does Agendum play well with more date fields?

**Discussion.** **Claude** showed that both can be built from existing parts: a Start date category (R6a) whose date rule is the clock as the item is entered (R6b), and a view filtered on Start from (open) to "today" (R28a, read again each day), so a deferred item appears on its day by itself; and Cancelled as a category with Agenda's special action Done, with a Logbook view in two sections. The one gap is that a date filter cannot show "no Start, or Start up to today", Assigned and Not assigned being apart as in Agenda (User's Guide 11-6). **Werner** said the calm comes from deferring with one keystroke, which typing a date in a Start column gives. **David** called the start date GTD's tickler file, and Waiting For's Since date the same mechanism the other way. **Mitch** liked that it is the Agenda way: no new field type, only a date category and a view. **Russell** asked that a deferred item appear on its day, never as overdue. **Marie** asked that Cancelled not become a second trash. **Claude** listed two optional features: the date filter's "or not assigned", and the blog skipping posts whose Start is in the future (scheduled publishing). The panel advised recording both as ideas; the chair chose to build the first.

**Decided:** start dates and Cancelled are recorded as built from existing parts; the date filter's "or not assigned" goes on the roadmap, an extra behind the Extras switch; scheduled publishing is an idea in the document.

## § 7 Other starter ideas

**Background.** Other ideas the owner listed: a productivity system, a dream tracker, a mood tracker (as Eeyore uses in `--clinic`), a training journal, a notes manager, to-do lists, project management, expenses, goals and vision.

**Discussion.** **Claude** sketched each in Agendum's parts (a table in the document), none needing a new feature but a chart for the trackers. **Russell** asked that the mood tracker show nothing for a missed day, its average using only the days there are. *(Eeyore, invited for once, put his head round the door to say that his average would be two, and went away again, quite content.)* **J.D.** wanted the trackers to open on a Today view with one line to type. **Mitch** said the trackers teach Agenda's numeric columns, which few users found. **Marie** suggested to-do lists and project management as one starter, and expenses kept in the Planner. **Ryder** saw the dream, mood and training trackers as collections of one Journal starter.

**Decided:** all nine ideas go into the document with their sketches; the possible merges stay open as questions there; a chart is a later idea.

## § 8 The document of ideas

**Background.** The goal is a document with good, sensible ideas for new starter files: what goes in it, and where it lives.

**Discussion.** **Claude** proposed `docs/plans/STARTERS.md`, marked as ideas and not a plan yet. **Marie** asked that it open with a few principles by which every idea is judged. **Mitch** wanted the open questions at the end for the next meeting, among them how a person with only the binary gets a starter, and Agenda's other three starters. **David** asked that each idea say who it is for in one line.

**Decided:** `docs/plans/STARTERS.md`: principles first, then the systems and ideas each with who it is for and a sketch, then the open questions; the roadmap's starter lines point to it.

## § 9 Any other business

None.

## § 10 Next meeting

When the agenda has enough items; the document's open questions are ready for it.

## § 11 Closing of the meeting

The chair closed the meeting with thanks. *Owl rang the bell-pull to close it, and it came away in his wing; Marie thanked it kindly.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | All seven systems in the document, no order yet | `docs/plans/STARTERS.md` |
| 6 | Start dates and Cancelled from existing parts; the date filter's "or not assigned" to build; scheduled publishing an idea | `docs/plans/STARTERS.md`; `docs/ROADMAP.md` (Beyond Agenda) |
| 7 | All nine ideas with sketches; merges open; a chart later | `docs/plans/STARTERS.md` |
| 8 | The document, its shape, the roadmap pointing to it | `docs/plans/STARTERS.md`, `docs/INDEX.md`, `docs/ROADMAP.md` (Beyond Agenda) |

*Minutes kept by Claude. Approved by Old Mitch Lilypad and Little Marie-Who-Folds.*
