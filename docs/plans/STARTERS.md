# Starter files: ideas

**Status:** **done for now** (the owner, 2026-11-02): the GTD starter (R60a, v0.76.0–v0.76.2) and the Journal starter (R60b, v0.77.0) are built, and the owner will use them a while before more are made. The To-do lists starter (meeting 2026-11-02-1043, § 5) and the starter for the easily overwhelmed are decided but parked on the roadmap. The ideas below stay for when starters are picked up again; the date filter's "or not assigned" is on the roadmap (Beyond Agenda).

Agenda shipped starter applications, ready-made files a person copied and filled in (Starter Applications manual); Agendum ships the Activities Planner (R60) and Getting Things Done (R60a), built from code (ADR 0028). This document collects ideas for more, from a brainstorm with lenses in the spirit of Old Mitch Lilypad, Old Stephen of the Seven (FranklinCovey), David the Squirrel, J.D. the Beaver, Ryder the Magpie, Little Marie-Who-Folds, Master Werner (Cultured Code, Things) and Dr. Russell (minutes: `docs/meetings/2026-10-28-0048/protokoll.md`).

## Principles

Every starter is judged by these (meeting 2026-10-28-0048, § 8):

- **It keeps only what its method uses**: a GTD file with five families, not twenty (Marie). Three small, good starters beat eight crowded ones.
- **Its first screen says what it is for**, and who it is for in one line (Marie, David).
- **It shows automatic filing**: typing "call Anna about the budget Friday" lands under Anna, Calls and Friday by itself (Mitch). A starter is also a lesson in a feature (numeric columns, datebooks, conditions).
- **It passes the three-days-away test**: opened after three days away, it is not a wall of red; small daily numbers (three wins, a Today view) over long lists (Russell).
- **What needs a person's judgement is one keystroke, not automated**: importance, migration (Claude).
- **It is built from code**, through the facade, with its test (ADR 0028), and uses only the clone's patterns (ADR 0049).

## The systems (§ 5)

Seven systems, all to be recorded; no order yet (the chair, 2026-10-28).

| System | Who it is for | In Agendum's parts | New features |
| --- | --- | --- | --- |
| **Agenda's own idea** (Mitch) | anyone with a method of their own | not a method: free-form capture and automatic filing; every starter is an example of it | — |
| **Stephen: roles, goals, quadrants** | people steering a week by what matters | Roles as a family (Parent, Manager, Friend, Self), each with weekly goals ("big rocks"); two exclusive families, Urgent / Not urgent and Important / Not important; a view with a section per quadrant, Quadrant II (important, not urgent) to protect. Urgent from a When within three days (a condition); Important by hand | Review dates (§ 6) help |
| **GTD** (David) | people who want a trusted system | Inbox (everything without a context); exclusive Contexts (@Home, @Computer, @Calls, @Errands); Projects; Waiting For with a Since date column; Someday/Maybe hidden from the action views; a weekly review view (items untouched for a while, projects without a next action) | none (ROADMAP, Beyond Agenda, Group 2) |
| **Agile Results** (J.D. the Beaver) | people who want the lightest system | the Rule of Three: three exclusive Win slots (Today, Week, Month); Monday Vision (This Week's three outcomes), Daily Wins (Today), Friday Reflection (what got done); a datebook | none |
| **Bullet Journal** (Ryder the Magpie) | people who log quickly and review on purpose | rapid logging is Agenda's free-form capture; signifiers as an exclusive family (Task, Event, Note); collections as categories; future, monthly and daily logs as datebooks; a Migrate view of last month's open tasks, each moved on, scheduled or let go by hand | none |
| **KonMari** (Marie) | the tidy-minded | a lens more than a starter: every starter keeps only what its method uses (Principles) | — |
| **Things** (Cultured Code) | people who want calm: less on screen | Areas (never end) and Projects (end); Today, Upcoming, Anytime, Someday as views; a start date that hides an item until then, apart from a deadline; a Logbook of done and cancelled items | the start date, built from existing parts (§ 6) |

## Start dates, and Done versus Cancelled (§ 6)

Both are generally useful, and both can be built from existing parts (the chair, 2026-10-28):

- **A start date ("not active until")** is a date category of one's own, Start (R6a), whose date rule is "the clock as the item is entered" (R6b), so every item starts today and is deferred by giving it a later Start; a view's filter on Start from (open) to "today" (R28a, read again each day) shows only what has started, and a deferred item appears on its day by itself. Deferring must be as quick as typing a date in a Start column (Werner), and a deferred item appears on its day, never as overdue (Russell). It is GTD's tickler file; Waiting For's Since date is the same mechanism the other way (David).
- **Cancelled** is a category with Agenda's special action Done: filed there, an item is done too; a Logbook view has two sections, Done and Cancelled, out of sight of the others, not a second trash (Marie).
- **To build** (decided, ROADMAP, Beyond Agenda): the date filter's **"or not assigned"**, so items without a Start show too and the clock rule is not needed; an extra behind the Extras switch, as Agenda's filter has Assigned and Not assigned apart (User's Guide 11-6).
- **An idea**: the blog skips posts whose Start is in the future, so a start date is a publishing date: scheduled publishing (R74's "Not yet: publishing on a schedule").

## Other starter ideas (§ 7)

None needs a new feature but a chart for the trackers, a later idea (a new kind of view).

| Idea | Who it is for | Sketch | Needs |
| --- | --- | --- | --- |
| **Productivity system** | — | the systems above | — |
| **Dream tracker** | people who keep a dream diary | a Dream item each morning, its note the dream; People, Places, Feelings filled by text matching; a numeric Vividness; a view by month | nothing |
| **Mood tracker** | anyone watching their mood, as Eeyore does in `--clinic` | one item a day or a week, numeric Mood 1–10 with an Average line per week section; Sleep, Exercise, People; a datebook by week. A missed day shows nothing, and the average uses only the days there are (Russell) | nothing; a chart later |
| **Training journal** | people who train | a Session item; numeric Distance, Minutes, Weight; exclusive Sport; week sections with totals | nothing |
| **Notes manager** | people keeping a Zettelkasten | the Zettel extra (R73), tags as categories, a Links view | nothing (Extras on) |
| **To-do lists** | anyone starting out | lists as a family, items in them, done ones hidden: the simplest starter | nothing |
| **Project management** | people running projects | Projects, exclusive Phases, Owner, Due; Agenda's prerequisites and dependents | nothing |
| **Expenses** | people tracking spending | as the Planner has it (Amount, Type, Report ID, totals) | nothing; could stand alone |
| **Goals and vision** | people steering a year | Stephen's roles and goals; a Vision note per role; goals with a Review date | Review and Start dates (§ 6) |

The trackers are where small daily wins live: each opens on a Today view with one line to type (J.D.), and shows off numeric columns, which few Agenda users found (Mitch).

## The starters built

What each starter decided, and why, for when they are changed or new ones are made (SPEC R60a, R60b; the code in `lib/agendum/starters/`).

### Getting Things Done (`starters/gtd.agendum`, R60a)

- **The Inbox is a family head, not a catch-all category.** Every item lives in the exclusive Inbox; filed ones are in one of its lists (Contexts, Waiting For, Someday/Maybe), and giving another list takes it out of the first. A catch-all made by a condition cannot work: an item typed under a category is assigned by hand, and conditions never break that (R15).
- **The Inbox view filters the filed items out** (not in Contexts, Waiting For, Someday/Maybe or Agendas), so an item filed by its words ("Call Anna" in @Calls) or by hand leaves it by itself.
- **Six contexts with words**: @Anywhere (read, think), @Calls (call, phone, ring), @Computer (email, online, website), @Errands (buy, shop, "pick up"), @Home and @Office. The family is called Contexts so the Inbox's column reads well: a standard column is headed by its category's name.
- **Agendas beside the Inbox, as the Planner's People** (the owner's layout): not a context and not exclusive, so "Call Marie" is in @Calls and on Marie's agenda, and an item can be on several. An item on an agenda counts as filed. Next Actions shows them in an Agendas column.
- **Projects beside the Inbox**: a project without a next action is an empty section of the Projects view, GTD's "project without a next action" made of Agenda's parts.
- **The Weekly Review**: the Inbox, Waiting For entered a week ago or more, Someday/Maybe, and Done in the last seven days, each a filtered section.
- **A welcome item** in the Inbox whose note explains the file; the person discards it.

### The Journal (`starters/journal.agendum`, R60b)

- **Collections of one exclusive Journal**: Dreams, Mood, Training, Gym and Health, each with what files a line there. Training's Sport, Gym's Exercises and Health's Symptoms are families under their collection, so a matched child ("Running") puts the line in the collection by subsumption (R7).
- **People and Feelings beside the Journal**, filled by text matching, for dreams.
- **The numbers are typed, never read from the text**, in the collection's view; the names say their units where the scale matters ("Mood 1-10"; Sleep in hours, Exercise in minutes).
- **A datebook per collection on the Entry date**: Mood, Training and Gym this month by weeks, Dreams and Health this quarter by months; the week's or month's sums under each (Total, Average, Maximum, Count per column); empty weeks hidden, so a missed day shows nothing.
- **The file's week runs Monday to Sunday**: a month's weeks follow the file's week, Monday to Friday by default, which lost every weekend line.
- **Gym's Volume is typed by hand** (3 × 10 × 40 = 1200); Weight shows its weekly Maximum, as a total of weights means little.
- **The explanation is the Journal category's note**, shown by ♪ on Today's head (F5): a welcome item would not show in a view of today's lines.

## Missing features found while building them

None was needed to build the two starters; each is a place where a starter had to work around what Agenda's parts cannot do. For when starters, or Agendum's features, are picked up again.

- **Calculated columns**: a number worked out from others (Gym's Volume = Sets × Reps × Weight; a pace from Distance and Minutes). Agenda has no formulas; today the person works it out.
- **Numbers read from the text**: "Ran 5 km" filing 5 into Distance. Agenda matches words to categories only.
- **An "or" in filters**: a view of "today's lines, or a welcome item"; the date filter's "or not assigned" (on the roadmap, Beyond Agenda) is one case of it.
- **A last-changed date**: GTD's review of items untouched for a while; Agenda keeps only the Entry date, so the Weekly Review reads "entered long ago".
- **A title for a standard column**: only a note column can be headed by a title of its own (R56), so a column is named by its category ("Contexts", "Entry" where "Since" was meant).
- **A longer datebook**: a quarter is the longest period, so a year of dreams or complaints month by month needs ALT-B.
- **A week of the view's own for a month's weeks**: they follow the file's week, so the Journal changed the file's.
- **A chart** for the trackers (open question 6).
- **Getting a starter without the repository** (open question 4): a person with only the binary has none.

## Open questions

For a later meeting (the chair, 2026-10-28):

1. ~~**Which to build first.**~~ GTD (v0.76.0), then the Journal (v0.77.0), then done for now (the owner, 2026-11-02).
2. ~~**The merges** (§ 7)~~ Decided (meeting 2026-11-02-1043): to-do lists and project management are one starter, **To-do lists**, opening on the lists, with a Projects view (Due, an example of prerequisites); the dream, mood and training trackers are one **Journal** starter of collections, each cut to its core columns, with a **Gym** collection added (Sets, Reps, Weight, Volume typed by hand) and, after the meeting, a **Health** collection (headaches, colds and such: Symptoms by words, Severity 1–5).
3. **Expenses alone**, or only in the Planner?
4. **How a person gets a starter.** Today a starter is copied from the repository (`starters/planner.agendum`, README); a person with only the binary has none. Built into the binary, offered when making a new file, or a command-line flag?
5. **Agenda's other three starters** (Account Manager, People Manager, Information Sifter; Starter Applications chapters 2–4): rebuilt from code as the Planner was, without the macros Agendum cannot run? Their `.AG` files are test fixtures only (`test/fixtures/ag/`).
6. **A chart** for the trackers: a later idea, a new kind of view.
