# Starter files: ideas

**Status:** ideas, not a plan yet (meeting 2026-10-28-0048, §§ 5–8); the GTD starter is built (R60a, v0.76.0, 2026-11-02); the Journal and To-do lists starters are decided (meeting 2026-11-02-1043, §§ 5–7; ROADMAP, Towards parity). Nothing else here is decided for building except the date filter's "or not assigned" (ROADMAP, Beyond Agenda). The order of work and the open questions at the end are for a later meeting.

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

## Open questions

For a later meeting (the chair, 2026-10-28):

1. **Which to build first.** No order yet (§ 5).
2. ~~**The merges** (§ 7)~~ Decided (meeting 2026-11-02-1043): to-do lists and project management are one starter, **To-do lists**, opening on the lists, with a Projects view (Due, an example of prerequisites); the dream, mood and training trackers are one **Journal** starter of collections, each cut to its core columns, with a **Gym** collection added (Sets, Reps, Weight, Volume typed by hand) and, after the meeting, a **Health** collection (headaches, colds and such: Symptoms by words, Severity 1–5).
3. **Expenses alone**, or only in the Planner?
4. **How a person gets a starter.** Today a starter is copied from the repository (`starters/planner.agendum`, README); a person with only the binary has none. Built into the binary, offered when making a new file, or a command-line flag?
5. **Agenda's other three starters** (Account Manager, People Manager, Information Sifter; Starter Applications chapters 2–4): rebuilt from code as the Planner was, without the macros Agendum cannot run? Their `.AG` files are test fixtures only (`test/fixtures/ag/`).
6. **A chart** for the trackers: a later idea, a new kind of view.
