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

## Record

| Slice | Run | Findings | Fixed in |
| --- | --- | --- | --- |
| a | 2026-10-26, free run 1 of 3 | 10: a read for one file filed into another; a failing log write crashing past the recovery file; a damaged `.AG` file reading without bound; JSON trash ids not checked; a long description breaking an encrypted header; passwords in the crash dump and in batched input; userinfo past the address redaction; working-day repeats not noted; a backup asked for a new file | v0.68.2 (`test/agendum/review_slice_a_test.exs`) |
| b | | | |
| c | | | |
