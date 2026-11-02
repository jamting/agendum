# Minutes of the panel meeting, 2026-11-02-1043

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad (Lotus Agenda), David the Squirrel (GTD), Dr. Russell (ADHD), Little Marie-Who-Folds (tidiness), Ryder the Magpie (Bullet Journal, guest), Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds and Dr. Russell
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `8a0caf9`

*A short meeting, called in the middle of a working morning, the GTD starter barely out of its box. Owl opened it from the top of the stairs, as there was no room left in the room, and Ryder arrived last with a notebook and a ribbon and took the windowsill. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; made with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs, Claude is secretary, and Little Marie-Who-Folds and Dr. Russell approve the minutes.

## § 3 Adoption of the agenda

There were no thoughts under Next meeting in the owner's project file; the chair raised the item in the session (`docs/plans/STARTERS.md`, open question 2), and the secretary worded it as two. The agenda was adopted as it stood.

## § 4 The previous minutes

| Decision (meeting 2026-10-30-2020) | Status | Evidence |
| --- | --- | --- |
| § 5 A hand-written front page; the recording from our own renderer | Done | the site at `jamting.github.io/agendum/` |
| § 6 The guide and the manual updated first | Done | `docs/guide/`, `docs/manual/` |
| § 7 Releases on every tag and the Homebrew tap | Done | the release workflow, `jamting/homebrew-agendum` |
| § 8 The docs start page, `llms.txt`, the devlog | Done | `/devlog/` |
| §§ 9–10 Back to front; the address | Done | `docs/ROADMAP_DONE.md` |

## § 5 To-do lists and project management: one starter or two?

**Background.** Little Marie-Who-Folds suggested merging them (meeting 2026-10-28-0048, § 7; `docs/plans/STARTERS.md`, open question 2). Both are lists of items with Done, and project management adds Agenda's prerequisites. Since then the GTD starter has a Projects family and view, and the Planner already has one (`lib/agendum/starters/planner/views.ex`), so a third home for projects may overlap.

**Discussion.** **Marie** observed that projects now live in two starters already and a third would make three homes for one idea; she would keep To-do lists as the small, plain starter with one Projects view. **Mitch** said the one thing a project starter could teach that nothing else does is prerequisites, which few Agenda users found, and it deserves a small home. **David** said a GTD user already has projects, so this starter is for people who want no method and should stay small, lists first. **Russell** asked that it open on one list with one line to type, nothing else on screen. **Claude** noted that it needs no new feature. The panel advised one starter, To-do lists, with a Projects view.

**Decided:** one starter, **To-do lists**: it opens on the lists with one line to type, done items hidden; a second view, Projects, has a section per project, a Due column and an example of prerequisites. No separate project-management starter. *Marie folded the "Project management" sketch in three and gave it to Owl for the umbrella stand; Owl thanked it.*

## § 6 The dream, mood and training trackers: one Journal starter, or three?

**Background.** Ryder the Magpie saw them as collections of one Bullet Journal-style starter (the same open question). Each is a dated item with numeric columns and a view by week or month. The principles ask for small starters that keep only what their method uses, and for a Today view with one line to type.

**Discussion.** **Ryder** said a journal is one book with collections, not three books, and an Index view is the Bullet Journal's own table of contents. **Russell** was wary that three trackers are three things to keep up; one file must open on Today with one line, and a missed day or an unused collection must show nothing. **Marie** found one Journal tidier than three files with the same skeleton, but asked that each collection be cut to its core columns, dropping Weight from Training and Places from Dreams. **Mitch** called it the best showcase of numeric columns and section statistics, with People and Feelings filled by text matching. **Claude** noted that numbers are not read out of text, so a line typed in Today is filed into its collection by words ("ran", "dream", "mood") and the number is typed in its column. The panel advised one Journal.

**Decided:** one **Journal** starter: Dreams (Vividness, People, Feelings), Mood (Mood, Sleep, Exercise) and Training (Distance, Minutes, Sport) as collections, each with its own view; it opens on Today with one line to type; an Index view lists the collections; words file a line into its collection; a missed day shows nothing. *Ryder tied his ribbon round the three sketches; Eeyore, passing below, said it was a nice ribbon.*

## § 7 Any other business: a gym tracker

**Background.** The chair asked for a simple gym tracker with the total number of sets and reps, and weight. The Journal's Training collection holds runs and swims; lifting needs other columns. A numeric column can show Count, Total, Average, Minimum or Maximum under each section, and Agenda has no formulas, so sets × reps × weight cannot be computed.

**Discussion.** **Marie** placed it in the Journal as a fourth collection, Gym. **Mitch** said Sets and Reps want a weekly Total, but a total of the weights typed means little, so Weight wants its Maximum or a volume typed by hand. **Russell** liked the visible weekly number, and asked that a week without the gym show nothing rather than a zero. **Ryder** suggested one item per exercise, filed from Today by words such as bench, squat and deadlift. **Claude** suggested an Exercise family filled by those words, so a view by exercise shows progress over the weeks. The panel advised a Gym collection with Weight's Maximum; the chair chose a Volume column as well.

**Decided:** a **Gym** collection in the Journal: one item per exercise, an Exercise family filled by words; Sets and Reps (the exercise's reps in all) with a weekly Total, Weight with its Maximum, and Volume typed by hand (3 × 10 × 40 = 1200) with a weekly Total. The order of work: the Journal first, then To-do lists, then the starter for the easily overwhelmed. *A dumbbell made of a honey pot and a stick was found on the stairs afterwards; Pooh said it was for Thursdays.*

## § 8 Next meeting

When the agenda has enough items; the starters' other open questions (how a person gets a starter, expenses, Agenda's other three starters, a chart) are ready for it.

## § 9 Closing of the meeting

The chair closed the meeting with thanks. *Owl's closing speech grew longer as it went, and Marie gently handed him his hat.*

## Addition after the meeting: a health tracker

**Background.** After the closing, the chair asked that the Journal also hold a simple health tracker for headaches, colds and such, and that it be added to these minutes.

**Decided by the chair** (not discussed by the panel; the secretary's sketch, to be settled when the Journal is built): a **Health** collection in the Journal: one item per complaint, filed from Today by words (headache, migraine, cold, cough, fever …) into a Symptoms family (Headache, Cold, Fever, Stomach, Other; not exclusive, as a cold can bring a headache); a numeric Severity 1–5 with its Average and the Count of entries under each month; medicine and notes in the item's note. Like the other collections, a month without complaints shows nothing.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | One To-do lists starter with a Projects view; no project-management starter | `docs/ROADMAP.md` (Towards parity, In order 2), `docs/plans/STARTERS.md` (open question 2) |
| 6 | One Journal starter of collections, cut to their core columns, opening on Today | `docs/ROADMAP.md` (Towards parity, In order 1), `docs/plans/STARTERS.md` |
| 7 | A Gym collection in the Journal, with Sets, Reps, Weight and a typed Volume; the Journal first | `docs/ROADMAP.md` (In order 1–3), `docs/plans/STARTERS.md` |
| Addition | A Health collection in the Journal: Symptoms by words, Severity 1–5, a monthly Count and Average | `docs/ROADMAP.md` (Towards parity), `docs/plans/STARTERS.md` |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Dr. Russell.*
