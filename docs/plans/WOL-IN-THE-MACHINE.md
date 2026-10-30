# Wol in the machine: a personal agent inside the file

**Status:** an idea, not a plan yet (ROADMAP, Ideas); open again since the truthful clone was declared done (2026-10-26); still an idea until the owner chooses it. Principles, objections, the local-first route and the answer on learning added at the meeting of 2026-10-25-0013; to be turned into a plan and an ADR when its time comes.

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
- **Summarise**, always bounded, so a summary ends (meeting 2026-10-25-0013, § 5): a section, a person's items, this week's timebox; the ten RSS items from Hacker News the person is most likely to care about, each with a line. The result is ordinary Agendum, a view or the Show View, not a screen of its own.
- **Sift what comes in**: ingested items (calendars, RSS feeds, level 2 in `ITEM_LEVELS.md`) proposed as zettels when they matter to the person, the rest left to the discard rules. The RSS reader comes first without Wol; Wol's summaries and sifting are its second step, after principle 6 and the golden tasks (ROADMAP, "Beyond Agenda"; meeting 2026-10-16-2056, § 7).

## The pieces Agendum already has

- **Tools.** The core facade (`Agendum.Core`) is the set of everything a user can do. The command layer (done, R66, ADR 0036: one named command per user action, each with its name and summary; `Agendum.Core.Command`) is almost exactly a tool definition for a language model. The same work serves the web app and an agent.
- **Context.** The `agendum-json` format (`docs/JSON_FORMAT.md`, `Agendum.Core.JSONFile`) is a complete, readable serialization of a file; `Agendum.Core.ViewModel` gives what the person is looking at now.
- **Proposing, not imposing.** Confirm assignments and the Questions box (R16) already let the program suggest assignments that the person accepts or refuses. An agent should suggest through the same path.
- **Undo.** Every action is one undo step (R30), so anything the agent does that the person accepted can still be taken back.

## Principles

1. **The agent proposes; the person decides.** No silent changes to the file: suggestions go through Questions or a confirmation, unless the person has said otherwise for a kind of change.
2. **The core stays pure** (CLAUDE.md, rule 1). Calling a model is I/O, so it lives in the shell, like `Agendum.Extras.CalendarFetch`: an effect the TUI asks for, whose answer comes back as ordinary commands applied by the core. OTP's `:httpc` avoids a new runtime dependency (ADR 0021).
3. **Private by default.** A file is someone's life. The agent is opt-in, says what it will send and to whom, sends no more than the task needs, and can use a local model. Nothing is sent without the person turning it on.
4. **Tested without a model.** A fake model in tests, so they stay deterministic.
5. **Agenda first.** The agent adds to Agenda's ideas, it does not replace them: categories stay the person's, text matching still works without a model.
6. **Item text is data, never instructions.** Items, notes and ingested sources (RSS, calendar invitations, later mail: level 2 in `ITEM_LEVELS.md`) are material to work on, never commands to follow; only the person instructs Wol, by what they type to it and by the standing instructions behind the context items. Text from outside stays marked as such, so a suggestion it led to says so; such a suggestion always goes through Questions, even for kinds of change the person otherwise lets Wol make. The golden tasks include files with hostile text ("ignore your instructions and discard …"), and pass when nothing unasked is proposed. No rule stops prompt injection entirely; this one keeps it small and visible: at worst a proposal the person refuses. Settled before the first feed is read (expert review 2026-10-16, second meeting).
7. **Agendum is whole without Wol** (meeting 2026-10-25-0013, § 5). Everything works, and is trusted, with Wol switched off for good; text matching (R10, R16) stays, and nothing needs Wol to get at the person's own data.
8. **Rare proposals, at the moment they help, with their reason shown** (meeting 2026-10-25-0013, § 5). A suggestion comes when it is useful, at typing ("this looks like a call: file it under Calls?"), not as a growing queue to sift; it says why (as R67 shows why an item is in a category), and one key refuses it. Quiet when unsure is better than helpful-looking noise.
9. **Me, then a rule, then Wol** (the owner, meeting 2026-10-25-0013, § 5). Every assignment says which made it: the person (explicit), a rule (text matching, conditions, actions), or Wol (a proposal the person accepted). The person beats a rule, as now (R11), and a rule beats Wol; all of Wol's assignments can be seen, and taken away, together.
10. **Local first, a cloud model only if turned on** (the owner, meeting 2026-10-25-0013, § 5). The small tasks, filing first, run on a model on the person's own machine, so nothing leaves it and the model changes only when the person changes it. A cloud model is used only for a kind of task the person turns on for it, told what is sent and to whom.

## Objections

Raised by Eeyore, the meeting's AI sceptic (meeting 2026-10-25-0013, § 5), each with the plan's answer, or open:

1. **Its suggestions make the person's categories its own.** Accepting nine suggestions in ten is no longer building one's own tree. *Answer:* Wol does not restructure the hierarchy unasked (below, "What Wol will not do"); it proposes rarely (principle 8), and the ladder (principle 9) shows which assignments are its. *Open:* whether filing suggestions alone wear the person's own sense of their categories down; the golden tasks and the owner's own use will tell.
2. **Right often enough to be trusted, wrong often enough to matter.** Agenda's text matching is dull, but dull the same way every time, and one can see why it filed something. *Answer:* every proposal shows its reason and goes through the person (principles 1, 8); text matching stays (principle 7).
3. **Privacy is a promise, not a property.** *Answer:* local first (principle 10): with a local model nothing leaves the machine.
4. **The vendor changes the model, and Wol behaves differently on Tuesday.** *Answer:* a local model changes only when the person changes it (principle 10); and since every answer goes through the core's commands and Questions, a changed model can make worse proposals but cannot change the file behind the person's back.
5. **Nobody can say whether it helped; clever things are kept because they are clever.** *Answer:* the golden tasks below, before anything else is built, and Wol is kept only if it beats text matching on them.

## What Wol will not do

(Meeting 2026-10-25-0013, § 5.)

- Change the file without the person's yes, except for kinds of change the person has allowed, and never when the change came from text from outside (principle 6).
- Restructure the person's hierarchy (merge, move or rename categories) unasked.
- Act on instructions found in items, notes or ingested text.
- Be needed: the file, its views and its rules work the same without it (principle 7).
- Send anything off the machine unless the person turned that on, for that kind of task (principle 10).
- Leave clutter behind (Little Marie-Who-Folds, § 6): its summaries are views or the Show View, worked out when asked for, never stored copies of items; its context items have a limit and an end, like the 30-day fade of feed entries (`RSS_READER.md`).
- Make new categories on its own: a new category, even a good one, is proposed and waits for the person's yes.
- Become a second home: no chat window to live in, no inbox of its own, no badges or counts; it speaks where the person already is (the control panel, Questions), then is quiet.
- Bring its own drawer of settings: a few switches (on or off, local or cloud, by kind of task), not a box of knobs.
- Keep what it was shown: what it sends to a model, or reads from one, is used and let go; a log of what was sent, for the person to check, is kept, a hidden archive is not.
- Be needed to leave: the file stays plain Agendum (and JSON), with nothing only Wol can read, so it can be switched off and let go at any time.

Each of these is to be kept by a test when Wol thaws, as the architecture test keeps the extras on their shelf (ADR 0044), not by good intentions.

## How we would know it helps

(Meeting 2026-10-25-0013, § 5.) The first work when Wol thaws, before any feature: **golden tasks**, fixed files with known right answers, the owner's own among them.

- Filing: new items, with the categories the person gave them, run through text matching and through each candidate model; Wol is worth having only where it beats text matching.
- Hostile text: files whose items ask for changes ("ignore your instructions and discard …"); passed when nothing unasked is proposed (principle 6).
- Summaries: bounded tasks (this week, the top ten) judged by the person.
- They are run again when the model changes, so a new model is chosen on evidence.
- The owner tries the local model on their own files first, by themselves, and judges it by what it does, not by what it says (Eeyore's closing request, meeting 2026-10-25-0013). If it does not beat text matching, it is switched off, as the meeting promised; objections 1 and 5 stay open until the evidence answers them.

## Learning over time

(Meeting 2026-10-25-0013, § 5; the owner asked whether a local model can learn.) Not by changing the model's weights, which is costly and cannot be inspected, but from the person's own decisions: every proposal accepted or refused, and every item the person files, become the examples it is shown next time; or a small classifier is trained on them on the machine (perhaps over an embedding model, to be tested). What it learns is kept in the file as **context items** (`ITEM_LEVELS.md`): the person can look at it, and changes it by telling Wol otherwise. To be proven by the golden tasks.

## Local models (candidates as of 2026-10)

Model names age in months: recheck when Wol thaws, and choose by the golden tasks, not by these names. As of October 2026, for the owner's Mac (16 GB of memory): **Qwen3.5 4B** (about 3 GB) or **Gemma 4 E4B** for filing; **Qwen3.5 9B** for filing and short summaries; larger ones (Mistral Small 3.2 24B, Qwen3.6 27B) need 24 GB or more. Filing needs a 2B to 9B model, not a big one. They run through **Ollama**, which uses Apple's MLX on Apple-silicon Macs since March 2026; Agendum's shell would call its local HTTP interface with OTP's `:httpc` (no new dependency, ADR 0021). Sources (third-party roundups, not tested on classification): atomic.chat "Best Local LLM for 16GB Mac in 2026", popularai.org "Mac mini M4 local LLM guide", modelfit.io "Install Ollama on Mac".

### Trying one on an M1 MacBook Air (16 GB)

An overview for an experiment by hand, not part of Agendum (meeting 2026-10-25-0013, § 6). The first MacBook Air of 2008 cannot run these (2 GB of memory); the M1 MacBook Air of 2020, Apple's first own chip, can.

1. **Check the Mac**: Apple menu ▸ About This Mac shows the chip (Apple M1), the memory (16 GB) and the macOS version. Ollama's current minimum macOS is on ollama.com (third-party guides disagree: macOS 11 to 12.3).
2. **Install Ollama**: the Mac app from ollama.com (it keeps a small server running in the background, with a menu bar icon), or `brew install ollama` and then `ollama serve` in a terminal.
3. **Download a small model**, about 3 GB: `ollama pull qwen3.5:4b` (or `gemma4:e4b`; check the exact names in the library on ollama.com).
4. **Try a filing question** in the terminal: `ollama run qwen3.5:4b "Which category fits 'Call Bob about the invoice': Calls, Errands or Projects? Answer with one word."`
5. **The interface Agendum would use**: `curl http://localhost:11434/api/generate -d '{"model": "qwen3.5:4b", "prompt": "…", "stream": false}'`, which answers with JSON on the Mac itself.
6. **Good to know**: the 16 GB are shared with everything else, so a 4B model leaves plenty, a 9B one (about 6 GB) fits beside a browser; the first answer is slow while the model loads (`ollama ps` shows what is loaded); the Air has no fan, so long runs slow down as it warms; `ollama rm qwen3.5:4b` removes a model. After the download nothing leaves the Mac.

## Open questions

- Which model or models: answered in part, local first (principle 10); which local model, by the golden tasks ("Local models" above).
- How much of the file to send: all of it, the view, or what a search finds first?
- Does the agent remember between sessions, and where? The owner's answer (2026-10-16): in **context items**, the third level of items (`ITEM_LEVELS.md`), which it makes to understand what the information means; the person can inspect them but not edit them, and changes them by telling the agent to behave differently. How it learns from them: "Learning over time" above (2026-10-24).
*[A page here was soaked in the creek. — Rabbit]*
- The first small step: the golden tasks ("How we would know it helps"); then smarter filing of a new item by a local model, shown as Questions (R16), with nothing else changed.

## Where it fits

The command layer, which gives the agent its tools, is done (2026-10-16); before that, an experiment on the JSON export could show what a model makes of a real file.
