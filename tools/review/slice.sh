#!/usr/bin/env bash
# Builds a code-review slice (docs/CODE_REVIEW_SLICES.md): two local
# branches from a commit, so that `/code-review ultra review/NAME-base`, run
# on review/NAME, sees exactly the slice's files as new code.
#
#   review/NAME-base   the commit with the slice's files removed
#   review/NAME        on top of it, the files added back, unchanged
#
# Works in a worktree of its own (../agendum-review), so the main checkout
# is never switched. Nothing is pushed.
#
#   tools/review/slice.sh a               # build slice a from main
#   tools/review/slice.sh a v0.68.1       # from a tag or commit
#   tools/review/slice.sh --list          # the slices and their sizes
#   tools/review/slice.sh --clean         # remove every review/* branch and the worktree
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
WORKTREE="$(dirname "$ROOT")/agendum-review"

# The slices: where a bug costs most, each under ultra's limits (8,000
# changed lines, 500 files, by default; the refusal names the ones in effect).
slice_files() {
  case "$1" in
    a) # the file and the shell: saving, loading, encryption, JSON, .AG import,
       # preferences, the main loop, the session state, undo, the debug log
      echo lib/agendum/store.ex lib/agendum/cli.ex lib/agendum/preferences.ex \
        lib/agendum/preferences/*.ex lib/agendum/tui/app.ex lib/agendum/tui/state.ex \
        lib/agendum/tui/update.ex lib/agendum/tui/update/results.ex lib/agendum/tui/history.ex \
        lib/agendum/tui/debug_log.ex lib/agendum/core/json_file.ex lib/agendum/core/ag_file.ex \
        lib/agendum/core/ag_file/*.ex lib/agendum/core/file_defaults.ex ;;
    b) # the core's rules: assignment, the commands, the database, invariants,
       # links, text matching, the facade
      echo lib/agendum/core.ex lib/agendum/core/assign.ex lib/agendum/core/command.ex \
        lib/agendum/core/database.ex lib/agendum/core/invariants.ex lib/agendum/core/links.ex \
        lib/agendum/core/text_match.ex lib/agendum/core/text_condition.ex \
        lib/agendum/core/range_filter.ex lib/agendum/core/reasons.ex lib/agendum/core/facade/*.ex ;;
    c) # the extras: feeds, calendars, blog, Zettels, their boxes and fetching
      echo lib/agendum/core/extras lib/agendum/core/facade/extras lib/agendum/tui/extras \
        lib/agendum/extras ;;
    *) echo "unknown slice: $1 (a, b or c)" >&2; exit 1 ;;
  esac
}

size() {
  # shellcheck disable=SC2046
  echo "$(find $(cd "$ROOT" && slice_files "$1") -name '*.ex' 2>/dev/null | (cd "$ROOT" && xargs cat) | wc -l | tr -d ' ') lines"
}

case "${1:-}" in
  --list)
    cd "$ROOT"
    for s in a b c; do
      # shellcheck disable=SC2046
      files=$(find $(slice_files "$s") -name '*.ex' | wc -l | tr -d ' ')
      # shellcheck disable=SC2046
      lines=$(find $(slice_files "$s") -name '*.ex' | xargs cat | wc -l | tr -d ' ')
      echo "slice $s: $lines lines, $files files"
    done
    exit 0 ;;
  --clean)
    cd "$ROOT"
    git worktree remove --force "$WORKTREE" 2>/dev/null || true
    git branch --list 'review/*' | sed 's/^[* +]*//' | xargs -r git branch -D
    exit 0 ;;
  "") echo "usage: $0 SLICE [FROM] | --list | --clean" >&2; exit 1 ;;
esac

name="$1"
from="${2:-main}"
cd "$ROOT"
files=$(slice_files "$name")

# the worktree, on the base branch made from FROM
if [ ! -d "$WORKTREE" ]; then
  git worktree add --quiet --detach "$WORKTREE" "$from"
fi
cd "$WORKTREE"
git switch --quiet --force-create "review/$name-base" "$from"
# shellcheck disable=SC2086
git rm --quiet -r $files
git commit --quiet --no-verify -m "Review base $name: the slice's files removed (local only, docs/CODE_REVIEW_SLICES.md)"

# the review branch: the same files added back, unchanged
git switch --quiet --force-create "review/$name"
# shellcheck disable=SC2086
git checkout "$from" -- $files
git commit --quiet --no-verify -m "Review slice $name: the files added back (local only, docs/CODE_REVIEW_SLICES.md)"

echo "slice $name: $(git diff --shortstat "review/$name-base" "review/$name")"
echo "in $WORKTREE on review/$name; run: /code-review ultra review/$name-base"
