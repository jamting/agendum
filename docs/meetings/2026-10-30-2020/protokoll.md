# Minutes of the panel meeting, 2026-10-30-2020

**Place:** Owl's house, the Hundred Acre Wood
**Present:** Mattias (chair); Little Marie-Who-Folds (tidiness), Old Mitch Lilypad (Lotus Agenda), Dr. Russell (ADHD); Joel and Jeff, the Chipmunk Brothers (guests: launching an online business); Claude (Owl's cousin); Owl, host
**Apologies:** José Who Brews, Great-Uncle Joe, Carsten Stargazer, David the Squirrel
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Dr. Russell
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `e06d416`

*The evening of moving day. A new printout hung on Owl's wall: the repository's page on GitHub, public since the morning. The panel's voices are lenses in the spirit of the people behind the pseudonyms (`.claude/skills/expert-review/SKILL.md`), written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting at 20:20.

## § 2 Election of a chair, a secretary and two approvers of the minutes

Mattias was elected chair, Claude secretary, and Little Marie-Who-Folds and Dr. Russell approvers of the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as proposed.

## § 4 The previous minutes

The minutes of meeting 2026-10-28-2214:

| Decision | Status | Evidence |
| --- | --- | --- |
| § 5: The Proportional Web's typography for the guide and the manual | Done | `f6e1652` |
| § 6: airy writing; SPEC and the roadmap restructured | Done | SPEC in four slices (`0b49161` and earlier) |
| § 7: a Wood-themed README picture | Done | `ROADMAP_DONE.md` |

Nothing was stuck.

## § 5 The front page and its four doors

**Background.** Meeting 2026-10-28-0908, § 9, decided on one static page with four doors (Try it, Learn it, Look inside, Follow it) and a short recording. The page does not exist yet. What does it say above the doors, how is it made, and how is the recording made?

**Discussion.** **Jeff** said a stranger decides in a few seconds, so above the doors goes one sentence on what Agendum is and one moving picture, nothing more. **Russell** wanted four doors and nothing else, each with one line saying who it is for, the whole page on one laptop screen. **Mitch** said the recording is the heart of the page: typing a sentence like "Call Kanga about the picnic Friday" and seeing it filed under Kanga and under Friday by itself, under 20 seconds, looping. **Marie** weighed a hand-written `site/index.html` sharing `guide.css` against having Agendum's blog extra generate the page, and preferred the hand-written page: one file, one home, and the blog not bent into a front page. **Claude** compared an animated image made by the program's own renderer (`tools/screenshots`; Agenda's colours, no JavaScript, made again whenever the screen changes) with asciinema (real playback, but a JavaScript player and a plain terminal look) and a still screenshot first.

**Decided:** a hand-written `site/index.html` sharing `guide.css`, on one screen: one sentence, the recording, four one-line doors. The recording is an animated image made with our own renderer.

*Mitch began writing down the picnic sentence.*

## § 6 The guide and the manual as the Learn it door

**Background.** Both were restyled on 2026-10-28, but their text was last brought up to date on 2026-10-26; the extras changed since. Are they updated before the site goes up? Do both go behind the door, which one first, and how does a new reader find the way from guide to manual to the program's help?

**Discussion.** **Claude** counted 44 commits under `lib/` since the last update: Feeds and Calendars as managers, Calendars as their own family, the blog's new design, the Publish box's F8 and ALT-F8, and one clone change (a new category in a family becomes a section of each view showing it, R42). **Jeff** said a stale guide costs more trust than a missing one. **Mitch** said Lotus shipped a Quick Start and a User's Guide, a short tour and then the book, which is what the guide and the manual already are. **Russell** asked that the door say what to read first and how long it takes, as two equal links make the reader choose. **Marie** said updating both is one run of each skill, about an evening's work. **Claude** suggested a "Written for Agendum X.Y" line on each, set by the skills, and noted that the Pages build will publish later updates by itself.

**Decided:** both are brought up to date before the site goes up. The door lists them in order, each with its length: the guide, the manual, then F1 in the program. Each gets a "Written for Agendum X.Y" line, set by the skills.

*Russell drew three small arrows on the printout.*

## § 7 Try it: getting Agendum onto a machine

**Background.** The earlier decision was GitHub Releases and a Homebrew tap. There are no releases yet, the README's way to run Agendum assumes a developer, and the escript needs Erlang/OTP 28. What must the first version of Try it hold?

**Discussion.** **Joel** proposed two small pieces: a workflow that builds the escript on every tag and attaches it to a GitHub Release, and a tap, `jamting/homebrew-agendum`, whose formula depends on `erlang`. **Jeff** said strangers copy one line, not three, and the tap is that line. **Russell** said trying must ask nothing: `--demo` opens a populated file, and uninstalling should be one line the page shows too. **Marie** said without both the door means "become an Elixir developer", a wall; bundled binaries stay for later. **Claude** noted that many Linux distributions ship an Erlang older than 28 while Homebrew also runs on Linux, that Windows is untried with raw mode so the page says "Mac and Linux", and that a release on every tag is safe since tags follow a green `mix check` and the long fuzz run.

**Decided:** the first version holds both: a release on every tag and the tap. The page shows the install line, `--demo` and the uninstall line, and says "Mac and Linux".

*Jeff wrote "brew install" on a biscuit.*

## § 8 Look inside and Follow it

**Background.** What of `mix docs` goes on Pages, with the `llms.txt`; and the devlog: where it lives and when the first posts come.

**Discussion.** **Claude** suggested the door lead to the `mix docs` start page with three begin-here lines (how it is built, what Agenda does, why), an `llms.txt` generated from `docs/INDEX.md` in the build so it cannot go stale, and asked whether the public minutes and reviews belong in the docs build as the story of the work. **Marie** said the minutes are history, not documentation: linked on GitHub, kept out of the build. **Jeff** said a door onto an empty room is worse than none, so the devlog opens with at least one real post. **Joel** advised keeping the devlog on the same site at `/devlog/`, published by the blog extra into a folder in the repository: no server, no password. **Mitch** said the devlog is the home for the story of the Wood and of Agenda's designers, and named milestones to backfill. **Russell** advised milestones without a promised pace, as a blog that falls silent makes its writer feel guilty.

**Decided:** Look inside leads to the `mix docs` start page with three begin-here lines; the minutes and reviews are linked on GitHub, not built in; `llms.txt` is generated in the build. The devlog lives at `/devlog/` on the same site, published from a folder in the repository, and opens with at least one real post; milestones are backfilled after.

*Mitch started a list headed "the first item filed".*

## § 9 The order of work

**Background.** What the first version of the site must have, what comes later, and in which order the pieces are built.

**Discussion.** **Claude** listed six pieces: Releases and the tap, the guide and the manual, the recording, the front page with the Pages workflow, the first devlog post (the chair's) and switching Pages on (the chair's). **Marie** advised building back to front, so no door opens onto an empty room, one commit per piece. **Jeff** said nothing is announced until it works from a clean Mac. **Russell** asked that In order 1 stay one line in the roadmap, the pieces under it. **Claude** proposed a job on a fresh macOS runner that installs from the tap after each release. The chair asked whether the macOS runner costs anything; **Claude** answered that standard GitHub-hosted runners, macOS included, are free for a public repository, while private repositories pay in minutes and larger runners are paid, and that billing is checked in the repository's settings before the job is built.

**Decided:** back to front: Releases and the tap, the guide and the manual, the recording, then the front page and the Pages workflow; the first post written alongside, Pages switched on last. After each release, a job on a fresh macOS runner installs from the tap and runs `agendum --version`. In order 1 stays one line.

## § 10 Any other business

The chair asked whether GitHub Pages can host the site and at what address. **Claude** answered that Pages is free for a public repository and not yet switched on; a project site is served at `jamting.github.io/agendum/`, with the doors under it (`guide/`, `manual/`, `docs/`, `devlog/`, `llms.txt`); a domain of the owner's own needs one DNS record and can be added later, as GitHub redirects the old address; a user site at `jamting.github.io` would need a repository of that name and be a personal site, not Agendum's. As the site lives under `/agendum/`, every link must be relative.

**Decided:** the site lives at `jamting.github.io/agendum/`; a domain of the owner's own may come later. Links are relative, and the Pages workflow checks it.

## § 11 Next meeting

When the agenda has enough items.

## § 12 Closing of the meeting

Owl thanked the panel and closed the meeting. Jeff ate the biscuit.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | A hand-written front page sharing `guide.css`, on one screen; the recording made with our own renderer | `docs/ROADMAP.md` (Housekeeping, the public site, step 3–4) |
| 6 | The guide and the manual updated first; the door in order with lengths; a "Written for Agendum X.Y" line set by the skills | `docs/ROADMAP.md` (Housekeeping, step 2) |
| 7 | Releases on every tag and the Homebrew tap; one install line, `--demo`, uninstall, "Mac and Linux" | `docs/ROADMAP.md` (Housekeeping, step 1) |
| 8 | Look inside: the docs start page, three begin-here lines, minutes linked not built, `llms.txt` generated; the devlog at `/devlog/`, one post at launch | `docs/ROADMAP.md` (Housekeeping, steps 4–5) |
| 9 | Back to front; a fresh-macOS install check after each release; In order 1 stays one line | `docs/ROADMAP.md` (In order 1, Housekeeping) |
| 10 | `jamting.github.io/agendum/`, relative links checked | `docs/ROADMAP.md` (Housekeeping, step 4), `docs/plans/GITHUB.md` § 4 |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Dr. Russell.*
