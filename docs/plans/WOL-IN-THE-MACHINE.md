# Wol in the machine: a personal agent inside the file

**Status:** an idea, not a plan yet (ROADMAP, Ideas); to be turned into a plan and an ADR when its time comes.

(Name of file is a reference to Ghost in the Machine)

Written down on 2026-10-13 from a conversation between the owner and Claude.

**The idea.** A language model agent that lives inside a person's Agendum file: it reads their items, categories and views, and helps them file, find and plan, the way an assistant who knows the file well would. Wol, the owl who knows the Hundred Acre Wood, inside the program named after him.

## Why Agendum is a good home for an agent

Most apps make an agent guess what matters to a person. An Agendum file says it, in the person's own words:

- **Items are free text**, exactly what a language model reads best.
- **Categories are the person's own ontology.** Someone who builds People ▸ Kanga, Roo or Priority ▸ High has written down how they see their world. That structure is explicit, named and theirs.
- **Assignments** link the free text to that structure; subsumption (R4) adds what follows from the hierarchy.
- **Views are saved questions**: "what is due this week, by person?". Their sections, columns, filters and sorting say what the person wants to see together.
- **Conditions and actions** (R15, R15b) are rules the person has already stated; **dates** (When, Done, date categories) put items in time; **notes** hold the detail.

And Agenda was reaching for this from the start: its designers' 1990 CACM article describes text matching and automatic assignment as a step towards a program that understands what is typed into it (see `docs/reference/` and `docs/AGENDA_HISTORY.md`). A language model is the natural successor of the string matching in R15 and R16.

## What it could do

- **File new items** better than word matching: "Ask Owl about the cake" goes to People ▸ Owl and Party, even with no word in common.
- **Suggest categories**, or a cleaner hierarchy when the tree has grown untidy (duplicates, a family that should be exclusive).
- **Answer questions with a view or a filter**, not only with text: "what am I waiting for before the party?" becomes a view the person can keep.
- **Turn a long note into items** (as Agenda's ALT-F7 made items from note text), each filed.
- **Write conditions in plain words**: "anything about the garden that is not done" becomes a condition or a filter.
- **Summarise**: a section, a person's items, the week ahead.
- **Sift what comes in**: ingested items (calendars, RSS feeds, level 2 in `ITEM_LEVELS.md`) proposed as zettels when they matter to the person, the rest left to the discard rules.

## The pieces Agendum already has

- **Tools.** The core facade (`Agendum.Core`) is the set of everything a user can do. The command layer (done, R66, ADR 0036: one named command per user action, each with its name and summary; `Agendum.Core.Command`) is almost exactly a tool definition for a language model. The same work serves the web app and an agent.
- **Context.** The `agendum-json` format (`docs/JSON_FORMAT.md`, `Agendum.Core.JSONFile`) is a complete, readable serialization of a file; `Agendum.Core.ViewModel` gives what the person is looking at now.
- **Proposing, not imposing.** Confirm assignments and the Questions box (R16) already let the program suggest assignments that the person accepts or refuses. An agent should suggest through the same path.
- **Undo.** Every action is one undo step (R30), so anything the agent does that the person accepted can still be taken back.

## Principles

1. **The agent proposes; the person decides.** No silent changes to the file: suggestions go through Questions or a confirmation, unless the person has said otherwise for a kind of change.
2. **The core stays pure** (CLAUDE.md, rule 1). Calling a model is I/O, so it lives in the shell, like `Agendum.CalendarFetch`: an effect the TUI asks for, whose answer comes back as ordinary commands applied by the core. OTP's `:httpc` avoids a new runtime dependency (ADR 0021).
3. **Private by default.** A file is someone's life. The agent is opt-in, says what it will send and to whom, sends no more than the task needs, and can use a local model. Nothing is sent without the person turning it on.
4. **Tested without a model.** A fake model in tests, so they stay deterministic.
5. **Agenda first.** The agent adds to Agenda's ideas, it does not replace them: categories stay the person's, text matching still works without a model.
6. **Item text is data, never instructions.** Items, notes and ingested sources (RSS, calendar invitations, later mail: level 2 in `ITEM_LEVELS.md`) are material to work on, never commands to follow; only the person instructs Wol, by what they type to it and by the standing instructions behind the context items. Text from outside stays marked as such, so a suggestion it led to says so; such a suggestion always goes through Questions, even for kinds of change the person otherwise lets Wol make. The golden tasks include files with hostile text ("ignore your instructions and discard …"), and pass when nothing unasked is proposed. No rule stops prompt injection entirely; this one keeps it small and visible: at worst a proposal the person refuses. Settled before the first feed is read (expert review 2026-10-16, second meeting).

## Open questions

- Which model or models, and a local one (privacy, cost, working offline)?
- How much of the file to send: all of it, the view, or what a search finds first?
- Does the agent remember between sessions, and where? The owner's answer (2026-10-16): in **context items**, the third level of items (`ITEM_LEVELS.md`), which it makes to understand what the information means; the person can inspect them but not edit them, and changes them by telling the agent to behave differently.
*[A page here was soaked in the creek. — Rabbit]*
- The first small step. A good candidate: smarter filing of a new item, shown as Questions (R16), with nothing else changed.

## Where it fits

The command layer, which gives the agent its tools, is done (2026-10-16); before that, an experiment on the JSON export could show what a model makes of a real file.
