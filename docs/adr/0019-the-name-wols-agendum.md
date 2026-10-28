# ADR 0019 — The name: Wol's Agendum

**Status:** accepted · 2026-10-11

## Context

The program had no name of its own: it was "Agenda", like the Lotus program it clones. That made every sentence ambiguous (does "Agenda files the item" describe the original or us?) and the program's files, command and settings looked like Lotus's. The owner chose a name: **Wol's Agendum**. Wol is how Owl spells his name in A. A. Milne's books, and Owl already teaches Rabbit in the manual; an *agendum* is one thing to be done.

## Decision

- **Wol's Agendum** in titles, headings and the splash screen; **Agendum** where a short name reads better (menus, help, running text). **Agenda** means the original Lotus Agenda, everywhere.
- What users see uses the new name: the command `agendum`, its help, menu texts, the F1 help, developer tools, messages, default file names, and the User-Agent of calendar downloads.
- Names stored on disk change, and the old ones keep working:
  - files are `.agendum`; a name typed without an extension also finds a `.agenda` file from before, and the tag inside a saved file stays `:agenda`, so every file ever saved still loads;
  - preferences are in `~/.config/agendum/preferences` (or under `$XDG_CONFIG_HOME`); without that file, the old `~/.config/agenda/preferences` is read, and the next save writes the new one;
  - the JSON format is `"agendum-json"`; `"agenda-json"` is read too.
- Made-up UIDs for calendar events without one keep their `agenda-` prefix: changing it would mirror every such event a second time.
- The code keeps its `Agenda` names for now (the Mix app `:agenda`, the `Agenda.*` modules, `lib/agendum`, `test/agendum`): users never see them, and renaming them touches every file. It is on the roadmap (Housekeeping), as one mechanical commit of its own.

## Consequences

- Text can say "as Agenda does" and "Agendum does it differently" without ambiguity; CLAUDE.md states the convention.
- Until the code is renamed, module names (`Agendum.Core`) and the product name differ; that is expected.
- ADR 0008 (the preferences path) and ADR 0010 (the JSON format name) are amended by this record.

## Update, 2026-10-14: the code renamed

The code now matches: the Mix app is `:agendum`, the modules `Agendum.*`, in `lib/agendum` and `test/agendum`, in one mechanical commit. Two things stay as they were, so every file ever saved still loads:

- the tag inside a file stays `:agenda` (it is data, not a module name);
- a file keeps the struct names it was saved with, so `Agendum.Store` turns `Agenda.*` struct names into `Agendum.*` on load. Before decoding, it makes the old names from its own modules' names, so `:safe` decoding (which refuses unknown atoms) still works. A file saved by a program from before the rename loads in the renamed one; a file saved by the renamed program cannot be opened by an older one.

The repository folder (`Lotus Agenda`) is renamed by the owner, and the small TUI modules are still to be grouped in subfolders (Roadmap).


## Update, 2026-10-28: the name kept, and how it is said

Weighed against **Owl's Agendum** at the meeting of 2026-10-28-4 (§ 5) and kept: "Wol" is distinctive and found exactly in a search, where "Owl" is crowded; it is Milne's own spelling; and the planned agent is called Wol, inside the program named after him (`docs/plans/WOL-IN-THE-MACHINE.md`). The long name is never stored in a person's file, only in text the program writes.

- **How it is said:** "wolz a-JEN-dum". *Wol* rhymes with "doll" (British /wɒl/; American close to "wall", /wɑːl/); *Agendum* has a soft g and the stress on the middle syllable, as in "agenda" (/əˈdʒɛndəm/).
- **The story told once** where the name first meets a reader (the About help, the README, later the site): "Wol is how Owl spells his name", so it is not taken for a typo.
