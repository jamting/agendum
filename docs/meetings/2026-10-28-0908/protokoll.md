# Minutes of the panel meeting, 2026-10-28-0908

**Place:** Owl's house, the Hundred Acre Wood
**Present:** Mattias (chair); Old Mitch Lilypad (Lotus Agenda), Little Marie-Who-Folds (tidiness), Carsten Stargazer (Org-mode), José Who Brews (Elixir); Joel and Jeff, the Chipmunk Brothers (guests: launching an online business); Claude (Owl's cousin); Owl, host
**Apologies:** Great-Uncle Joe, David the Squirrel, Dr. Russell
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Old Mitch Lilypad
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `63200e9`

*The second meeting of the day. Two chipmunks came up the beech tree carrying a laptop between them and settled on the bookshelf, where the laptop's fan made the portrait of Uncle Robert sway gently. The basket of thanked minutes from the morning still stands by the door; Owl says he is keeping it for sentimental reasons. The panel's voices are lenses in the spirit of the people behind the pseudonyms (`.claude/skills/expert-review/SKILL.md`), written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

Owl welcomed the guests and opened the meeting on what to make public, In order 1 on the roadmap (meeting 2026-10-26-1524, § 11), with the chair's thought "Public repo" from the project file (written 2026-10-26).

## § 2 Election of a chair, a secretary and two approvers

Mattias chairs; Claude keeps the minutes; Marie and Mitch approve them.

## § 3 Adoption of the agenda

The agenda was adopted as worded.

## § 4 The previous minutes

| Decision (2026-10-28) | Status | Evidence |
| --- | --- | --- |
| Seven systems and nine ideas written up | Done | `docs/plans/STARTERS.md`, `3006ab2` |
| Start dates and Cancelled made from existing parts | Done (written up) | `docs/plans/STARTERS.md` |
| The date filter's "or not assigned" | Not yet | `docs/ROADMAP.md`, Beyond Agenda |

## § 5 One meeting or a series?

**Background.** Going public covers what to hide, how hidden parts look, where public stops, a site, pseudonyms, the history and a licence. The chair asked whether this is one meeting or a series.

**Discussion.** **Marie** advised finishing what can be finished today and keeping what depends on each other together: what to hide, where public stops and the licence are close to one question. **Joel** said the licence and the line between public and private are business decisions that deserve a night's sleep. **José** said the history (§ 11) depends on §§ 6 and 10, since only what has been decided can be filtered out, and needs its own sitting after the dry run. **Claude** proposed today for the principles, a short licence meeting, and a practical meeting on the dry run.

**Decided:** a series. This meeting decides §§ 6–10 and discusses §§ 11–12; a licence meeting follows, then a practical meeting on the dry run.

## § 6 What to keep out of the public documents

*[A page here was soaked in the creek. — Rabbit]*

## § 7 How redactions look

**Background.** The chair suggested making the redactions playful: Tigger bounced Rabbit and his papers into the creek, so some parts of the documentation are unreadable.

**Discussion.** **Jeff** found it charming and honest: readers see that something is held back without feeling deceived, where a silent gap makes careful readers suspicious. **Marie** asked for it light: the story told once, each gap one line. **José** advised doing it mechanically: private passages marked in the workshop with an HTML comment, which the copy script replaces with the creek line, and a test that no marked passage leaks. **Mitch** said whole private files should simply be absent; the story is for gaps inside documents a reader does see. **Claude** added that the markers also tell an agent working in the workshop which passage is private before it writes beside it.

**Decided:** the creek, marked. The story is told once; each gap is one line, *"[A page here was soaked in the creek. — Rabbit]"*; private passages are marked `<!-- private -->` … `<!-- /private -->` in the workshop and replaced by the copy script, with a leak test; private files are absent.

## § 8 Where public stops, so it does not hinder later work

**Background.** Public, in the chair's note: a modernised TUI as an extra, refined and additional extras, and a local client/server model so several terminals can have the same file open, as in Emacs. To come: a server-side core with an LLM, many users, user accounts, a web client and a TUI client. The rule from 2026-10-21, § 10, is open core.

*[A page here was soaked in the creek. — Rabbit]*

*[A page here was soaked in the creek. — Rabbit]*

## § 9 A public site for the project, help and guide

**Background.** A public site for the project, its help and the guide; download links for installers? There is no product page yet; Pages is free for a public repository; the escript needs Erlang on the machine that runs it.

**Discussion.** **Jeff** said the front page decides everything: what it is, one picture, three lines to install, and a download that just runs. **Joel** advised no installers before anyone asks: GitHub Releases and a Homebrew tap, which brings Erlang along, for Mac users first. **José** said a single binary with Erlang bundled (as Burrito makes) is packaging, not a runtime dependency (ADR 0021), but a build step to maintain; later, if asked for. **Marie** wanted three doors on the front page and nothing else: Try it, Learn it, Look inside. **Mitch** wanted a short recording of the classic flow, an item typed and filed, which is what made Agenda famous. **Claude** suggested an `llms.txt`, made from `docs/INDEX.md`.

The chair accepted this and added a devlog: a simple blog in their own words, for authenticity, published with Agendum, probably backfilled to the start of the project with the summaries as a memory aid, and asked whether it is a fourth door. **Jeff** said a person's own voice is what brings readers back, and a devlog written with the program shows it at work. **Marie** accepted a fourth door, Follow it, kept apart from Learn it. **Joel** advised a handful of honest milestone posts rather than one a day. **Claude** noted that the summaries stay private and only jog the memory; the posts are the owner's own words.

**Decided:** one static page with four doors (Try it, Learn it, Look inside, Follow it) and a short recording; the docs on GitHub Pages; GitHub Releases and a Homebrew tap first, bundled binaries later if people ask; an `llms.txt`. The devlog is the owner's own words, published with Agendum's blog extra, backfilled as milestone posts.

*Owl asked whether the devlog might mention his house. The chair said it probably would.*

## § 10 Pseudonyms for the panel, with a Wood touch

**Background.** The chair proposed Wood pseudonyms for the panel's members, as "Joe the Polar Bear": their backgrounds unchanged, so a keen reader can tell who they are, but their identities not searchable. The real names were in 45 tracked files and six commit messages.

**Discussion.** **Marie** asked for one table in one home, used everywhere, and not a new animal each meeting. **José** advised using the pseudonyms in the workshop from now on, so nothing new needs mapping, and mapping the public copy's history, files and commit messages alike, with `git filter-repo --replace-text` and `--replace-message`. **Carsten** asked for the lens in brackets: the subject is what a reader needs. **Claude** said it is also kinder to the real people, whose names are then not attached to words they never said; Claude stays Claude, as it is the one writing. The secretary drafted the names for every lens and guest so far.

**Decided:** the drafted names, in one table in `.claude/skills/expert-review/SKILL.md`; used in the workshop from now on, the existing documents converted in one commit, the public copy's history mapped. The chair added: no overuse of full names, as everyone knows each other; first names in running text, the full pseudonym once, and the chair is called Mattias from now on.

*Owl told the absent Joe that he now had a name, by leaving a note on his chair. The Chipmunk Brothers held a short, satisfied conversation about being chipmunks.*

## § 11 Rewriting the git history: possible, practical, alternatives?

**Background.** The chair asked whether git history can be changed, whether it is practical, what the alternatives are, and asked for a dry run. The plan rewrites a copy with `git filter-repo` and leaves the workshop untouched (`docs/plans/GITHUB.md` § 7); 795 commits, 96 tags, a `.git` of 9 MB; `filter-repo` is not installed yet.

**Discussion.** **José** said it is possible and routine, with one catch: old versions of a file carry no markers, so the business passages inside VISION, the minutes and the reviews cannot be cut version by version; the plan's way stands, those files leave the whole history and come back once, redacted, while whole private files vanish from every commit. **Claude** named the riskiest step: the four hundred or more commit hashes cited in the documents change, and the dry run must check that each exists in the copy, from `filter-repo`'s commit map. **Joel** described the alternative of one squashed commit: simple, but it throws away the best evidence, hundreds of small tested steps with an AI co-author, which is the devlog's story too. **Jeff** described a fresh public start with the history kept privately: simple too, but the citations would point nowhere. **Marie** asked for the dry run as a script, not hand steps, so the same run can be repeated on the day.

**Decided:** the plan stands. The dry run is a re-runnable script in `tools/public/`, checked by `mix check`, a leak test and a check that every cited commit hash exists; the go or no-go is taken at the practical meeting after it.

## § 12 Fully public with the plans, or a licence that holds off unwanted competition?

**Background.** The chair's options were going fully public with the plans, or hindering unwanted competition with licensing. §§ 6 and 8 already keep the service's plans private; what remains is the public part's licence. Earlier the chair said "free" did not mean the GPL (2026-10-21).

*[A page here was soaked in the creek. — Rabbit]*

The chair chose to table it and asked that the GPL and the AGPL be weighed as well.

**Tabled:** to the licence meeting. Before it, the secretary writes a one-page comparison in `docs/plans/GITHUB.md` § 7 of Apache-2.0, GPL-3.0, AGPL-3.0, the FSL, the BSL and PolyForm Noncommercial, and the contributors' terms; a legal check comes before any choice.

## § 13 Any other business

None. The chair asked Marie to set the order of the coming meetings and work, and their places on the roadmap. **Marie** set it: the pseudonyms first, as every later document is touched by them; the licence comparison and its meeting before the dry run, as the licence and the contributors' terms go into the copy; the tidy pass with the SPEC sweep and the private markers in one sweep over the same documents; the dry run after the markers, so its leak test has something to check; the practical meeting; the public repository; the site last, as Pages needs the repository public. The code review's remaining groups and the brainstorming meeting follow, as before.

*Marie thanked the umbrella stand, which Owl has never once used, and it went into the basket by the door. Owl took it out again on the way to the kettle.*

## § 14 Next meeting

The licence meeting, when the comparison is written (In order 2); then the practical meeting, after the dry run (In order 5).

## § 15 Closing of the meeting

Owl thanked the guests, who went down the tree with their laptop, and closed the meeting.

## Addendum, after the closing

**§ 10 amended by the chair.** Mattias asked whether the pseudonyms would not better be put in at the rewrite of the history, all in one sweep. The secretary agreed: `filter-repo --replace-text` maps every file of every commit anyway, so converting the 45 files in the workshop first adds nothing to the public copy. New texts still use the pseudonyms. Two things the meeting had missed: the name list pairs real names with pseudonyms, so it is private (`tools/public/`, and the skill's table marked private); and the dry run's leak test looks for every real name and surname, and a few converted minutes are read to see the sentences still work.

**Amended:** the existing documents keep the real names in the private workshop; the public copy's history is mapped in one sweep, as part of the dry run. In order 1, the separate conversion, is dropped. The chair also asked for § 8 to be recorded as an ADR: ADR 0050, where public stops.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | A series: content today, a licence meeting, a practical meeting | `docs/ROADMAP.md` (In order), `docs/plans/GITHUB.md` § 7 |
| 6 | What is private and what public | `docs/plans/GITHUB.md` § 7 |
| 7 | The creek: story once, one-line gaps, marked passages, a leak test | `docs/plans/GITHUB.md` § 7, `docs/ROADMAP.md` (Housekeeping) |
| 8 | Where public stops; the service adds, never takes away | ADR 0050, `docs/plans/GITHUB.md` § 7, `docs/VISION.md` § 3 |
| 9 | The site with four doors, Releases and a Homebrew tap, `llms.txt`, the devlog | `docs/ROADMAP.md` (Housekeeping) |
| 10 | Wood pseudonyms, first names, the chair called Mattias; amended: mapped in one sweep at the rewrite | `.claude/skills/expert-review/SKILL.md`, `docs/plans/GITHUB.md` § 7, `docs/ROADMAP.md` (Housekeeping, the dry run), memory |
| 11 | The plan stands; the dry run as a script; go or no-go at a practical meeting | `docs/plans/GITHUB.md` § 7, `docs/ROADMAP.md` (Housekeeping) |
| 12 | Tabled; a comparison including GPL and AGPL first | `docs/plans/GITHUB.md` § 7, `docs/ROADMAP.md` (Housekeeping) |
| 13 | Marie's order of work | `docs/ROADMAP.md` (In order) |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Old Mitch Lilypad.*
