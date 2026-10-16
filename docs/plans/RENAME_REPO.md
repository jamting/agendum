# Renaming the repository folder

**Status:** to do by the owner (Roadmap, Housekeeping). Written 2026-10-14.

The code is called Agendum now (ADR 0019), but the folder is still `~/Code/Lotus Agenda`. Renaming it is a plain `mv`, with one catch: **Claude Code keeps its memory of this project in a folder named after the project's path**, so after the rename it would start without it.

## What depends on the folder's path

| What                                                                                          | Where                                                                                                                                                     | What to do                                                 |
| --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Claude Code's memory of the project, and the history of past sessions (for `claude --resume`) | `~/.claude/projects/-Users-mattiasjamting-Code-Lotus-Agenda/` (the path with `/` and spaces turned into `-`): `memory/` and one `.jsonl` file per session | Move it to the name of the new path (step 4)               |
| Agendum's "last file used"                                                                    | `~/.config/agendum/preferences`, `last_file = /Users/mattiasjamting/Code/Lotus Agenda/…`                                                                  | Edit the path, or just open a file from the new place once |
| Compiled files and Dialyzer's tables                                                          | `_build/` (they record absolute paths)                                                                                                                    | Delete `_build/` and rebuild (step 5)                      |
| Your editor's recent projects (Zed)                                                           | the editor                                                                                                                                                | Open the new folder                                        |

Nothing else needs changing: git does not care where the folder is (its remotes and history stay), `.claude/skills/` and `CLAUDE.md` live inside the repository and move with it, and the memory files themselves name no paths.

## Steps

The example renames it to `~/Code/agendum`; any name works.

1. **Finish and close.** Commit everything (`git status` clean). Quit every Claude Code session in the folder, the editor, and any running Agendum (`./agendum`).

2. **Move the folder.**

   ```sh
   mv ~/Code/"Lotus Agenda" ~/Code/agendum
   ```

3. **Find the name Claude Code gives the new path.** Start it once in the new folder and quit at once, then look:

   ```sh
   cd ~/Code/agendum && claude      # then /exit
   ls ~/.claude/projects/ | grep -i agendum
   ```

   Expected: `-Users-mattiasjamting-Code-agendum`. (Starting it once makes the folder, so you see the exact name rather than guess it.)

4. **Move the memory and the session history into it.**

   ```sh
   OLD=~/.claude/projects/-Users-mattiasjamting-Code-Lotus-Agenda
   NEW=~/.claude/projects/-Users-mattiasjamting-Code-agendum   # the name from step 3
   cp -R "$OLD"/. "$NEW"/          # copy first; delete OLD only after step 6
   ```

   `memory/` holds `MEMORY.md` and one file per memory; the `.jsonl` files are the past sessions, which `claude --resume` lists.

5. **Rebuild.**

   ```sh
   cd ~/Code/agendum
   rm -rf _build
   mix deps.get && mix check
   mix escript.build               # if you use ./agendum
   ```

6. **Check that Claude remembers.** Start `claude` in the new folder and ask it what it remembers about the project (or run `/memory`): it should know the workflow (commit on its own once the checks pass), the DOSBox screenshots, the debug log and so on. `claude --resume` should list today's sessions.

7. **Tidy up.** When step 6 is fine, delete the old folder:

   ```sh
   rm -rf ~/.claude/projects/-Users-mattiasjamting-Code-Lotus-Agenda
   ```

   And in `~/.config/agendum/preferences`, change `last_file` to the new path (or open a file from the new place once).

## If something goes wrong

- Claude starts without its memory: the folder name in step 4 does not match the one Claude Code made (step 3). Copy `memory/` again into the folder that `ls ~/.claude/projects/` shows for the new path.
- `mix check` fails with paths from the old folder: `_build/` was not deleted, or a running editor's language server (`.elixir_ls/`) rebuilt it with old paths; delete `_build/` and `.elixir_ls/` and run it again.
- Undo: move the folder back (`mv ~/Code/agendum ~/Code/"Lotus Agenda"`); the old `~/.claude/projects/` folder is still there until step 7.
