#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
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
#   tools/review/slice.sh --files d       # a slice's files, one a line
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
    # groups d to h are reviewed locally (`/code-review high <paths>`,
    # docs/CODE_REVIEW_SLICES.md § The rest): `--files GROUP` prints the paths
    d) # dates and views in the core, and its other modules outside slice b
      echo lib/agendum/core/browse.ex lib/agendum/core/category.ex \
        lib/agendum/core/command/changes.ex lib/agendum/core/context.ex \
        lib/agendum/core/date_format.ex lib/agendum/core/date_language.ex \
        lib/agendum/core/date_language lib/agendum/core/date_parser.ex \
        lib/agendum/core/date_rule.ex lib/agendum/core/date_settings.ex \
        lib/agendum/core/datebook.ex lib/agendum/core/input_format.ex lib/agendum/core/item.ex \
        lib/agendum/core/macro.ex lib/agendum/core/month_calendar.ex \
        lib/agendum/core/number_format.ex lib/agendum/core/recurrence.ex \
        lib/agendum/core/search.ex lib/agendum/core/text_search.ex lib/agendum/core/trash.ex \
        lib/agendum/core/view.ex lib/agendum/core/view_columns.ex lib/agendum/core/view_model.ex ;;
    e) # the keys: every key goes through them (update.ex and results.ex are slice a's)
      find lib/agendum/tui/update -name '*.ex' ! -name results.ex | sort | tr '\n' ' '
      echo lib/agendum/tui/keymap.ex lib/agendum/tui/commands.ex lib/agendum/tui/command.ex \
        lib/agendum/tui/menu.ex lib/agendum/tui/macros.ex lib/agendum/tui/macro_keys.ex \
        lib/agendum/tui/layout.ex lib/agendum/tui/places.ex lib/agendum/tui/modes.ex \
        lib/agendum/tui/typing lib/agendum/tui/moves ;;
    f) # the boxes, A to M
      find lib/agendum/tui/boxes -maxdepth 1 -name '[a-m]*.ex' | sort | tr '\n' ' '; echo ;;
    g) # the boxes, N to Z
      find lib/agendum/tui/boxes -maxdepth 1 -name '[n-z]*.ex' | sort | tr '\n' ' '; echo ;;
    h) # drawing and the rest
      echo lib/agendum/tui/render.ex lib/agendum/tui/render lib/agendum/tui/category_screens.ex \
        lib/agendum/tui/category_screens lib/agendum/tui/terminal.ex lib/agendum/tui/terminal \
        lib/agendum/tui/help lib/agendum/tui/help_screen.ex lib/agendum/tui/command_docs.ex \
        lib/agendum/tui/splash.ex lib/agendum/tui/dev_tools.ex lib/agendum/starters \
        lib/mix ;;
    *) echo "unknown slice: $1 (a to h)" >&2; exit 1 ;;
  esac
}

size() {
  # shellcheck disable=SC2046
  echo "$(find $(cd "$ROOT" && slice_files "$1") -name '*.ex' 2>/dev/null | (cd "$ROOT" && xargs cat) | wc -l | tr -d ' ') lines"
}

case "${1:-}" in
  --list)
    cd "$ROOT"
    for s in a b c d e f g h; do
      # shellcheck disable=SC2046
      files=$(find $(slice_files "$s") -name '*.ex' | wc -l | tr -d ' ')
      # shellcheck disable=SC2046
      lines=$(find $(slice_files "$s") -name '*.ex' | xargs cat | wc -l | tr -d ' ')
      echo "slice $s: $lines lines, $files files"
    done
    exit 0 ;;
  --files)
    cd "$ROOT"
    # shellcheck disable=SC2046
    find $(slice_files "${2:?which group}") -name '*.ex' | sort
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
