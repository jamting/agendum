# Minutes of the panel meeting, 2026-10-28-1911

**Place:** Owl's house, the Hundred Acre Wood
**Present:** Mattias (chair); Old Mitch Lilypad (Lotus Agenda), José Who Brews (Elixir), Little Marie-Who-Folds (tidiness); Joel and Jeff, the Chipmunk Brothers (guests: launching an online business); Claude (Owl's cousin); Owl, host
**Apologies:** Great-Uncle Joe, Carsten Stargazer, David the Squirrel, Dr. Russell
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Old Mitch Lilypad
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `9c88fec`

*The fifth meeting of the day, held late, by lamplight. The dry run's report lay on the table, folded open at "Verdict: clean", and the Chipmunk Brothers shared a saucer. The panel's voices are lenses in the spirit of the people behind the pseudonyms (`.claude/skills/expert-review/SKILL.md`), written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the practical meeting on the dry run, called by the chair (In order 2 on the roadmap). There were no thoughts under Next meeting; the items came from the roadmap and the report.

## § 2 Election of a chair, a secretary and two approvers

Mattias chairs; Claude keeps the minutes; Marie and Mitch approve them.

## § 3 Adoption of the agenda

The agenda was adopted, with one item added by the chair: the last names spotted in the public copy (§ 12). Go or no-go moved to § 13.

## § 4 The previous minutes

| Decision (2026-10-28-4) | Status | Evidence |
| --- | --- | --- |
| § 5 Keep Wol's Agendum; tell its story once | Not yet | `docs/ROADMAP.md`, Housekeeping |
| § 6 The pronunciation written down | Done in ADR 0019; not yet in the About help | ADR 0019, `docs/ROADMAP.md` |

## § 5 What the copy still says about many users

**Background.** The plan for many users is private and absent from the copy; the fact that a second front end may come is public (meeting 2026-10-28-0908, § 6). About twenty public lines still link to the private plan (CONTRIBUTING:55, SPEC R66, ADRs 0033–0038, comments in `tui/state.ex` and `tui/keymap.ex`), which become dead links in the copy.

**Discussion.** **José** observed that the code comments explain why the state is split and why actions are commands, and that ADRs 0033 and 0036 are the public home of that reason. **Marie** asked for the fix at the source, in the workshop, so both repositories say the same. **Joel** said a planned web version gives nothing away, while a dead link looks like something hidden.

**Decided:** reworded in the workshop in one tidy commit before the next dry run: the fact kept, the link dropped, ADRs 0033 and 0036 cited where they explain the code.

## § 6 Five commit messages that mention the business

**Background.** Five commit messages in the copy name what is kept private. The copy script can reword a message (`MESSAGE_REWRITES`, empty so far), in the owner's words; the hashes are new in the copy anyway.

*[A page here was soaked in the creek. — Rabbit]*

**Decided:** all five reworded: Claude drafts new body lines, each subject kept, and the owner approves the wording before the next run.

## § 7 Lotus's four starter files in the test fixtures

**Background.** ACCOUNT, INFOSIFT, PEOPLE and PLANNER in `test/fixtures/ag/` (about 600 KB with their JSON dumps) are Lotus's starter applications; DATES, RICH and UX are our own, made in DOSBox. The reader, the importer and the parser property tests read the four; INFOSIFT seeds the fuzzed `.AG` files.

**Discussion.** **Mitch** said they are Lotus's work, and keeping them would be inconsistent with the manuals and the help having left the copy. **José** proposed taking them out of the copy's history and running their tests only where the files exist, as the test of the owner's own Planner already does, so the workshop keeps the full check. **Marie** said own replacements only if a test is seen to miss something. **Claude** proposed RICH as the fuzz seed in the copy.

**Decided:** out of the copy's history, their tests run only where the files exist, RICH seeds the fuzz in the copy; own replacements made in DOSBox only if a gap shows.

## § 8 `docs/reference/README.md` in the copy

**Background.** The copy keeps the reference README, the patent and the texts captured from Agenda run headless (menus with help lines, boxes, key bars, messages), which the parity tests compare with. The README describes six texts the copy lacks, and the captured help lines are Lotus's sentences (`plans/GITHUB.md` § 7, step 6).

**Discussion.** **Mitch** said menu words and short prompts are the interface a compatible program may describe; long help paragraphs are Lotus's writing. **Marie** asked that the README list what the reader finds, with one line on what is not included. **José** wanted the parity tests public, as the evidence of a truthful clone, with the longest captured help lines looked at. **Joel** said a lawyer could be asked this too.

**Decided:** the README marked so the copy lists only what it has, with one line that Lotus's manuals (archive.org) and the other third-party texts are not included; the captured texts stay, and the next dry run lists the longest help lines for the chair to look over.

## § 9 A lawyer before publishing?

**Background.** ADR 0051 confirms the licence after a lawyer's check; the chair put it off on 2026-10-28, and the copy has the licence, the CLA and its bot. A version published under the AGPL stays so; loosening later is easy, tightening is not.

*[A page here was soaked in the creek. — Rabbit]*

**Decided:** publishing does not wait for the lawyer; a lawyer reads the CLA and the dual-licensing question before the first outside pull request is merged, and until then the README says contributions open later.

## § 10 The workshop's new name on GitHub

**Background.** This repository is renamed so that the public one can take `jamting/agendum`; the private name is seen only by the owner, and the repository may later become the private one of § 11.

**Discussion.** **Marie** proposed `agendum-workshop`, the word the documents already use; **Joel** noted a name for a later role could come with a cheap rename; **José** advised against `agendum-private`, which sounds like a fork. The chair asked for more suggestions with a Wood twist. Claude offered four places from Milne: the Wolery, the house Owl named in his own spelling in *The House at Pooh Corner*; the Chestnuts, his first house, where the panel meets; Galleons Lap, the enchanted place at the top of the Forest; and the Six Pine Trees, where the Heffalump trap was planned.

**Decided:** `jamting/agendum-wolery`: Wol's Agendum, made in the Wolery.

*Owl opened one eye and looked pleased.*

## § 11 No sync after the first publish: confirm it

**Background.** The chair's preferred way (`plans/GITHUB.md` § 7): the public repository becomes the main one for the core and the terminal program; the Wolery keeps the private documents. The alternatives were a one-way sync script, or the private repository as a fork that merges the public one.

*[A page here was soaked in the creek. — Rabbit]*

**Decided:** confirmed: no sync after the first publish.

## § 12 Last names in the public repository

**Background.** The chair had spotted real surnames in the copy and begun replacing them by hand (a stash in the copy), noting that they can stand as `_Surname` or `Surname_`, inside Markdown's italics.

**Discussion.** Claude reported 44 real surnames left in the copy, all in the four reviews added back at the end, all in italics: the stage notes and the credits after each recommendation; commit messages and the older history were clean. The cause: the script and its leak test match names with `\b`, and `_` is a word character, so a name inside `_…_` has no word boundary. The copy is rebuilt at each run, so hand edits there are lost (one had also dropped a word). **José** proposed letter-only boundaries in both places and a Markdown case in the script's own check. **Marie** said fix the rule, not the 44 lines. **Mitch** said Agenda's designer, named in the reviews as the panel's lens, is mapped like the others; the real name stays only in the history documents. **Claude** (its own lens) asked that the business-word and marker searches be checked for the same trap.

**Decided:** the script fixed (letter-only boundaries in the redaction and the leak test, a `_Surname_` case in its check, the other searches checked); the chair's stash goes with the next run, which must show 0 surnames.

## § 13 Go or no-go

**Background.** The dry run at `8faf444` was clean and `mix check` passed in the copy (2,670 tests); the copy is six commits behind, and §§ 5–8 and 12 add fixes.

**Discussion.** **José** said the gate is the evidence: a fresh run reporting clean. **Marie** said the owner reads the report and a few of the reviews in the copy before anything is pushed. **Joel** said a go keeps the momentum, while the last look before the one step that cannot be undone stays the owner's. **Mitch** wanted the name's story in the README before strangers read it. The chair added conditions: the README looked at again, with a real screenshot instead of the text dump of the screen; the guide and the manual in the blog extra's stylesheet; everything made to look nice, all before the public repository.

**Decided:** go, on conditions: the fixes of §§ 5–8 and 12; the README's screenshot and the name's story; the guide and manual in the blog's stylesheet; a fresh dry run reporting clean, read and approved by the chair; then the rename (§ 10) and the public repository.

*Jeff nodded: one screenshot says more than a page of text.*

## § 14 Any other business

The chair asked for links in the README to the documents, the meetings and the rest, so they are easy to find. **Marie** called the README the hall of the house; **Claude** said the same list helps an agent or a search engine find the right page, beside `llms.txt` later; **Mitch** said the meetings and reviews are the project's unusual story and deserve a line saying what they are.

**Decided:** a Find your way section in the README, one line each for the guide, the manual, `docs/INDEX.md`, SPEC, the roadmap, the ADRs, the meetings and the reviews; before the public repository.

## § 15 Next meeting

When the agenda has enough items.

## § 16 Closing of the meeting

*Owl thanked the panel, put out the lamp and, looking round his house, said he had not known it would one day have a repository named after it.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The many-users lines reworded at the source | `docs/ROADMAP.md` (Housekeeping), `plans/GITHUB.md` § 7 |
| 6 | The five commit messages reworded, the owner's wording | `docs/ROADMAP.md` (Housekeeping), `plans/GITHUB.md` § 7 |
| 7 | Lotus's four starters out of the copy, tests skip without them | `docs/ROADMAP.md` (Housekeeping), `plans/GITHUB.md` § 7 |
| 8 | The reference README marked; captured texts kept, longest help lines listed | `docs/ROADMAP.md` (Housekeeping), `plans/GITHUB.md` § 7 |
| 9 | The lawyer before the first outside pull request | ADR 0051, `plans/GITHUB.md` § 7 step 7, `docs/ROADMAP.md` (Housekeeping) |
| 10 | The workshop becomes `jamting/agendum-wolery` | `plans/GITHUB.md` § 7 step 8, `docs/ROADMAP.md` (In order 2), memory |
| 11 | No sync after the first publish | `plans/GITHUB.md` § 7 |
| 12 | Surname matching fixed for Markdown formatting | `docs/ROADMAP.md` (Housekeeping) |
| 13 | Go on conditions; the README's screenshot; the guide and manual in the blog's stylesheet | `docs/ROADMAP.md` (In order 1, Housekeeping), `ROADMAP_DONE.md`, memory |
| 14 | A Find your way section in the README | `docs/ROADMAP.md` (Housekeeping) |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Old Mitch Lilypad.*
