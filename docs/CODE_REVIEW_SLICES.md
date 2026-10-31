# Reviewing the whole code base in slices

How Agendum's code, all of it, gets a deep review from Claude Code's cloud review (`/code-review ultra`), although that review only looks at changes, and only at changes of a limited size. Decided with the owner on 2026-10-26, before the public repository (ROADMAP, In order: a general code review).

## The problem

- `/code-review ultra` reviews **a diff**: the current branch against a base (the default branch, or a branch, tag or commit named after it: `/code-review ultra review/a-base`). It cannot review a path.
- A diff may hold at most **8,000 changed lines and 500 changed files** by default; the values can change, and a refusal names the ones in effect (Claude Code's docs, "Find bugs with ultrareview", read 2026-10-26).
- Pro and Max plans get **three free runs**, once; after that a run costs usage credits (typically $5 to $25). The dialog before a run starts says how many free ones are left.
- `lib/` held **54,838 lines** on 2026-10-26: seven slices at the most, so three free runs cover under half of it.

## The idea: a slice is a diff that adds an area

For each slice, two local branches are made from a commit (`main`):

- `review/NAME-base`: that commit with the slice's files **removed**;
- `review/NAME`: on top of it, the same files **added back**, unchanged.

On `review/NAME`, `/code-review ultra review/NAME-base` then sees exactly the slice's files as new code: a whole area reviewed as if it had just been written, with the rest of the program there for context. Nothing is pushed: the branches live only on this Mac, and are deleted after.

The work happens in a git worktree of its own, `../agendum-review`, so the main checkout never changes branch while the owner works in it.

## The slices

Chosen by where a bug costs most, not where there is most code: losing or corrupting a file first, then the rules everything goes through, then the extras (every extra usable before the public repository, the owner, 2026-10-26).

| Slice | What | Lines | Files |
| --- | --- | --- | --- |
| a | **The file and the shell**: `Store` (saving, loading, encryption, the upgrade of old files), `CLI`, `Preferences`, `App` (the main loop, effects, crash recovery), `State`, `Update` and `Update.Results`, `History` (undo), `DebugLog`, `JSONFile`, the `.AG` import, `FileDefaults` | 7,076 | 16 |
| b | **The core's rules**: `Agendum.Core`, `Assign`, `Command`, `Database`, `Invariants`, `Links`, text matching and conditions, range filters, the reasons, the facade's areas | 7,583 | 24 |
| c | **The extras**: feeds, calendars, the blog and its site, Markdown, Zettel ids, their facade, their boxes and the shell's fetching and publishing | 5,485 | 26 |

What the three do not cover, about 35,000 lines: the boxes (`tui/boxes/`, 10,863), drawing (`tui/render/`), the view model and columns, dates and their languages, the help, the starters. These can have the local review per folder (`/code-review lib/agendum/tui/boxes`), which costs no ultra run, or a later round of slices.

The lists are in `tools/review/slice.sh`, the one place they are kept; `--list` prints each slice's size from the files as they are now.

## How to run one

```sh
tools/review/slice.sh --list      # the slices and their sizes now
tools/review/slice.sh a           # build slice a from main: the worktree on review/a
```

Then, in the Claude Code session, with its working folder in `../agendum-review` (Claude moves the session there), the owner types:

```
/code-review ultra review/a-base
```

Only the owner can start it; the dialog shows the free runs left before anything is used. The review runs in the cloud and reports back to the session; its findings are checked against the code and fixed in the main checkout, one release for each slice's fixes, as for any review.

When all slices are done:

```sh
tools/review/slice.sh --clean     # delete the review/* branches and the worktree
```

## The rest, reviewed locally

The three free runs covered about 20,000 of 55,000 lines. The rest is reviewed with the local review, which costs no ultra run: `/code-review high <paths>` in this checkout, run in the background, its findings checked against the code and fixed as one release a group, each with its test (`test/agendum/review_<group>_test.exs`), as the cloud slices were. The local review sees the paths as they are, not a diff, so no branches are needed. Each group is about 7,000 lines, a size a review reads well.

| Group | What | About | Order, and why |
| --- | --- | --- | --- |
| d | **Dates and views in the core**: `DateParser`, the date languages, `DateFormat`, `DateRule`, `Recurrence`, `Datebook`, `Browse`, `Context`, `InputFormat`, `View`, `ViewModel`, `ViewColumns`, `NumberFormat`, and the core's other modules outside slice b | 10,000 lines | first: rules the person relies on every day (when an item is due, what a view shows) |
| e | **The keys**: `tui/update/` (but `results.ex`, in slice a), `Keymap`, `Commands`, `Menu`, `Macros`, `Layout`, `Places`, `tui/typing/`, `tui/moves/` | 8,000 lines | second: every key goes through it; undo and one-change-a-key live here |
| f | **The boxes, A to M**: `tui/boxes/` from `abandon_box` to `macro_props` | 5,500 lines | third |
| g | **The boxes, N to Z**: `tui/boxes/` from `new_file_box` to `what_to_copy_box` | 5,400 lines | fourth |
| h | **Drawing and the rest**: `tui/render/`, `tui/category_screens/`, `tui/terminal/`, `tui/help/`, the splash, the developer screen, `starters/`, `mix/` | 7,000 lines | last: a drawing bug shows at once, and is seen in use |

The group lists are in `tools/review/slice.sh` too (2026-10-30): `--list` prints every group's size, `--files d` a group's paths for the review. The sizes above were the plan's estimates; measured on 2026-10-30 they were d 5,000, e 7,800, f 6,500, g 4,600 and h 10,700 lines (h may be split in two).

## Record

The series is complete: every slice, a to h, was reviewed by 2026-10-31, and what was left of their findings is on the roadmap (Fixes and polish).

| Slice | Run | Findings | Fixed in |
| --- | --- | --- | --- |
| a | 2026-10-26, free run 1 of 3 | 10: a read for one file filed into another; a failing log write crashing past the recovery file; a damaged `.AG` file reading without bound; JSON trash ids not checked; a long description breaking an encrypted header; passwords in the crash dump and in batched input; userinfo past the address redaction; working-day repeats not noted; a backup asked for a new file | v0.68.2 (`test/agendum/review_slice_a_test.exs`) |
| b | 2026-10-26, free run 2 of 3 | 10: actions left naming a discarded category; a template of a Show Circular view unopenable; a template keeping what its subscriptions read; unindexed text lost on a recurring item's next occurrence; a mismatched set action crashing; F4 Done and a cleared date not rerunning conditions (Agenda reruns them, User's Guide 18-5/6); a category typed into a column settled without the clock; items marked circular before their conditions ran (Agenda: only those that keep moving, 20-21); four commands past the ingested lock; a text match's mark left without its link | v0.68.3 (`test/agendum/review_slice_b_test.exs`) |
| c | 2026-10-26, free run 3 of 3 | 10: Markdown looping for ever on a `#hashtag` line; INTERVAL=0 crashing at every start; an upload stalling the program; a Latin-1 calendar unreadable; Publish swapping posts or drafts for a namesake; a failed SFTP upload never retried; Zettel links inside addresses and code; a legacy calendar's category of the person's moved and locked; entries filed through a category link never fading; undated entries never fading | v0.68.4 (`test/agendum/review_slice_c_test.exs`) |
| d | 2026-10-30, local (`/code-review high`, 6 minutes) | 10: a repeat of 0 accepted, then crashing or hanging the views; a long s (ſ) in a weekday crashing the date reader; an added or removed item also listed as changed; more than 15 decimals (from a file) crashing a numeric column; a huge number of working days freezing the reader; a two-byte currency symbol turning scientific too early; and four left open on the roadmap (a fiscal quarter's year, linking columns of different formats, search and sort speed) | v0.72.6 (`test/agendum/review_slice_d_test.exs`) |
| e | 2026-10-30, local (`/code-review high`, 7 minutes) | 10: an empty prompt answer dropped (a number not refused, an unindexed text not taken out); APPEND taking the word out of MAIN's note; a When date that discards its item crashing; GETITMS discarding the open note's item, losing its text; an emptied item text refused after its line closed; OVR lost after Replace and Clear; a search match left highlighted after ALT-D, ALT-T and TAB; and three left open on the roadmap (a refused command moving the screen on, not reproduced; building the view model several times a key; APPEND's and MAKEITM's rules in the TUI) | v0.72.7 (`test/agendum/review_slice_e_test.exs`) |
| f | 2026-10-31, local (a background agent, 6 minutes) | 8: Abandon crashing with a view made since the save; Item Column Properties crashing when Link turns it Manually; the clock's changes undone by ESC in a box; Column Add leaving its new head after ESC; a choice's own letter refused; the Copy box not scrolling; Item Properties' key line pushed out; the action box's help naming the wrong key | v0.72.8 (`test/agendum/review_slice_f_test.exs`) |
| g | 2026-10-31, local (a background agent, 5 minutes) | 7: View Properties crashing with every section removed; the Date Filter box crashing on a digit; Section statistics counting the wrong section; a New File password's first key logged, and its spaces trimmed; → jumping to a section out of sight; a choice's own letter refused (as f's) | v0.72.8 (`test/agendum/review_slice_g_test.exs`) |
| h | 2026-10-31, local (two background agents, one a half, 11 minutes) | 15: a file holding invalid UTF-8 crashing the screen; the Linux console's F-keys and unknown sequences typed as text; a CR LF in a name a column too wide; calculations shifted with Number items; a tall row scrolled to its end; the password box too wide for 40 columns; the profile crashing after a discarding action; unindexed Advanced settings crashing; a category moved under a date or numeric one; an empty documents import; a Planner sample losing a category; a hook without its x bit; and wide characters (contained, left open); the fuzz walks found a 16th meanwhile, an undo step left by a box cancelled after a macro run, a rename to a sibling's name (Agenda's own) and a 12-column screen (unreachable) | v0.73.1 (`test/agendum/review_slice_h_test.exs`) |
