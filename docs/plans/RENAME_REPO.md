# Moving the repository folder

**Status:** prepared 2026-10-23, to do by the owner (Roadmap, Housekeeping): from `~/Code/Lotus Agenda` to `~/ailab/agendum`, with the owner's `~/ailab/mv-to-ailab` (its `--name` option added 2026-10-23). Written 2026-10-14.

The code is called Agendum (ADR 0019), but the folder still has the old name and sits outside `~/ailab`, where the owner's other projects are. Moving it is a plain `mv`, with one catch: **Claude Code keys its memory of a project, its session history and the folder's trust settings by the folder's path**, so after a bare `mv` it would start without them. `mv-to-ailab` moves those too.

## What depends on the folder's path

| What | Where | Done by |
| --- | --- | --- |
| Claude Code's memory of the project, and the past sessions (`claude --resume`) | `~/.claude/projects/-Users-mattiasjamting-Code-Lotus-Agenda/` (the path with every `/` and space turned into `-`) | `mv-to-ailab` renames it to `-Users-mattiasjamting-ailab-agendum` |
| The folder's trust and per-project settings | `~/.claude.json`, under `projects` | `mv-to-ailab` re-keys it (and backs the file up first) |
| Compiled files and Dialyzer's tables | `_build/` (they record absolute paths) | delete and rebuild (step 3) |
| Your editor's recent projects (Zed) | the editor | open the new folder |
| Agendum's preferences | `~/.config/agendum/preferences` | nothing: `last_file` already points into `~/ailab`; `place` lines for old test files are harmless and age out |

Nothing else needs changing: git does not care where the folder is (its remote and history stay), `.claude/skills/` and `CLAUDE.md` live inside the repository and move with it, and the memory files name no paths of the folder. A dry run (2026-10-23) found the old path written only in this plan and in `_build/` and `tmp/`, which are rebuilt.

## Steps

1. **Finish and close.** Commit everything (`git status` clean). Quit every Claude Code session, Zed, and any running Agendum. A running Claude Code may write `~/.claude.json` back over the re-keyed one.

2. **Move it**, from a plain terminal outside the folder. A dry run first shows the plan and changes nothing:

   ```sh
   cd ~
   ~/ailab/mv-to-ailab "Code/Lotus Agenda" --name agendum --dry-run
   ~/ailab/mv-to-ailab "Code/Lotus Agenda" --name agendum
   ```

3. **Rebuild.**

   ```sh
   cd ~/ailab/agendum
   rm -rf _build tmp
   mix deps.get && mix check
   mix escript.build               # if you use ./agendum
   ```

4. **Check that Claude remembers.** Start `claude` in `~/ailab/agendum` and ask what it remembers about the project (or run `/memory`): it should know the workflow (commit on its own once the checks pass), the Extras switch, the next step (View Properties). `claude --resume` should list today's sessions. Open the folder in Zed.

## If something goes wrong

- Claude starts without its memory: `ls ~/.claude/projects/ | grep agendum` shows the folder Claude Code made for the new path; if `mv-to-ailab` skipped the rename because that folder already existed (it says so), copy `memory/` and the `.jsonl` files from `-Users-mattiasjamting-Code-Lotus-Agenda` into it.
- `mix check` fails with paths from the old folder: `_build/` was not deleted, or Zed's language server (`.elixir_ls/`) rebuilt it with old paths; delete `_build/` and `.elixir_ls/` and run it again.
- Undo: `mv ~/ailab/agendum ~/Code/"Lotus Agenda"`, rename `~/.claude/projects/-Users-mattiasjamting-ailab-agendum` back, and restore `~/.claude.json` from the `.claude.json.bak-…` copy `mv-to-ailab` made.
