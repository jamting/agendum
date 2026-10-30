# ADR 0047: Help topics as text files and generated pages

**Status:** accepted (meeting 2026-10-26-0829, § 7)

## Context

Agendum's help is to be Lotus Agenda's: a topic for where you are, bold links, an index, a search, key charts and a way back (meeting 2026-10-26-0829, §§ 5–6; `docs/plans/archive/HELP.md`). Its texts are our own (meeting 2026-10-22-2130, § 7a). Much of it is already in the program: each box's help line per field, each menu entry's description, each command's summary and longer text (`Agendum.TUI.CommandDocs`), each place's F1 text and the keymaps. The rest, 40 to 60 how-to and concept topics, has to be written. The program is one file with nothing beside it (ADR 0021).

## Decision

- **Generated topics** for every box, menu, place and key chart are made from the program itself while it runs, never written twice.
- **Hand-written topics** are plain-text files in the repository, one per topic, in Agenda's layout: a title, then PURPOSE, STEPS, NOTE and SEE ALSO as needed; a link is the title of another topic in `**bold**`. They are compiled into the program (`@external_resource`), so no runtime files.
- Every topic, of either kind, is data: a title, its lines and its links, so the TUI draws it and a later front end or an agent can serve it.
- **Checks** (tests) keep the help from rotting: every box, menu and place has a topic; every link leads to a topic that exists; every key a topic names is bound there.

## Consequences

- One help: today's F1 pages become its topics (`c`, `d` and `a` are reached through F6 Keys).
- A new box or menu entry has its topic at once; a new feature with a task to explain needs its hand-written topic, which the checklist in `docs/plans/archive/HELP.md` tracks.
- The texts are English; another language would need translated files and a choice of language, not decided here.
