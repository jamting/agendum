# Vision

Where Wol's Agendum is going, in one place. The steps are in [`ROADMAP.md`](ROADMAP.md); the decisions behind them in `docs/adr/`.

## Who Agendum is for

Agendum is for curious people who think in loose notes and want them put in order without filing each one by hand: people with an open mind, glad to try something new, or something old (Agenda's way of thinking, on the BEAM). It is built for them in this order:

1. **Its owner, first.** Agendum is a learning project and a place to try out ideas about what makes a tool satisfying to use. Its owner uses it daily, and more as it grows, so what feels wrong in daily use comes first. Its own uses show what this group asks for: a blog published from the file, feeds to read, and trackers (moods, dreams, training) (meeting 2026-10-16-2056, § 5).
2. **Agenda's old users and people who love keyboard tools.** Old users should find the Agenda they knew, and bring their `.AG` files. Users of Org-mode, Emacs or plain-text lists should find Agenda's idea new, and the terminal no hurdle. Parity with Agenda serves both groups, which is why it comes before most of "Beyond Agenda".
3. **Later, people who are not nerds, on the web.** This is a guess, to be tested with real people: someone with many loose threads (a consultant, a teacher, a small-business owner, a project lead) who juggles people, promises and dates. They have tried task apps and given up on their forms, and use a notes app that never sorts anything. They want to write a sentence and find it in the right place later, on any device, without learning a program first. For them Agenda's power must stay, and its strangeness must not be the first thing they meet (the modern key set, the web front end). For them, Agendum could one day become a service.

   Within this group, a possible user group of its own: people with ADHD, and anyone who is easily overwhelmed by life. For them, writing a thought down at once, without first deciding where it belongs, and finding it filed later is not a convenience but the difference between keeping a thread and losing it. Also a guess to be tested; what it asks of Agendum is still to be planned.

   Candidate users to test, from a brainstorm (meeting 2026-10-16-2056, § 5), and to choose the five real users from: people who juggle people and promises, as Agenda's own users did (consultants, lawyers, journalists, researchers, managers); writers who collect quotes and sources; Org-mode and Emacs users and the personal-knowledge crowd (Zettelkasten, Obsidian, Logseq); GTD practitioners who do a weekly review; students, and caregivers who juggle a family's appointments; adults with ADHD, and people coming back after burnout, who need a tool that does not scold; privacy-minded people who want a language model over their own data, on their own machine; developers who want a scriptable personal database.

Each step is weighed against this order. Work for the third group must keep Agendum good for the first two: the TUI stays, as one front end among others.

**First, a truthful clone of Lotus Agenda** (the owner, meeting 2026-10-21-2324, § 5): **declared done on 2026-10-26** (v0.62.0; meeting 2026-10-26-1108, § 7). It stays truthful: a new difference from Agenda passes ADR 0043's test or is an extra behind the Extras switch. Until it was declared done against the steps of [`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md), parity came before everything else, the owner's own wishes included, and "Beyond Agenda" got bug fixes only; that freeze has ended (ROADMAP). Truthful means alike in function, look and feel, with the same keys made to work on modern computers, and only the few differences ADR 0043's test allows (the machine forces them, they protect the person's work, or they are quiet); the extras that fail it stay in the program, hidden behind one switch, off by default. The reasons: those who love Agenda would notice a faithful clone and be put off by a mixed one; a finished, faithful program is useful in itself and shows the owner's work. The dream below is unchanged and comes after: the modern interface, the web, many users and the agent. Before the meeting of 2026-10-21-2324, a "Beyond Agenda" item could go ahead of parity if it served the first two groups now, as the micro-blog and the RSS reader did.

## 1. Agenda's idea, faithfully

Lotus Agenda let people type thoughts in first and organise them later: free-text items, filed automatically into categories by what they say, seen through many editable views ([`AGENDA_HISTORY.md`](AGENDA_HISTORY.md)). Agendum is a clone of Agenda 2.0 as close as makes sense, with a list of accepted enhancements and modifications ([`plans/AGENDA_PARITY.md`](plans/AGENDA_PARITY.md), ADR 0006), on a pure functional core with a terminal UI (ADR 0001).

## 2. A personal knowledge system with a model inside

Beyond Agenda, Agendum becomes the place where a person's own notes meet the information that flows past them, with a language model that understands both. Items come on three levels ([`plans/ITEM_LEVELS.md`](plans/ITEM_LEVELS.md)):

1. **Zettels**, the items the person cares for, with Zettelkasten IDs and links between them;
2. **ingested items** from calendars, RSS feeds and other sources, which become zettels when they are interesting enough and are otherwise discarded by rules;
3. **context items** that the model (Wol, [`plans/WOL-IN-THE-MACHINE.md`](plans/WOL-IN-THE-MACHINE.md)) makes to understand what the information means: the person can look at them, and steers them by instruction rather than by editing.

The volumes can be large, so the working file stays a compact, fast Erlang-term file; JSON is for people, to exchange and inspect, with the levels to include chosen at export, as Agenda's structured files are (ADR 0034).

## 3. Many users, on the web

*[A page here was soaked in the creek. — Rabbit]*

A second front end may come on the same core (CLAUDE.md rule 6). The command layer, one named command per user action applied by the core, is done (R66, ADR 0036): the web, a modern key set, the person's own keys (in the web's modern interface, ADR 0038) and the agent all build on it (ROADMAP). A service adds to the local program; it never takes a local feature away, and the file stays the person's (meeting 2026-10-28-0908, § 8).
