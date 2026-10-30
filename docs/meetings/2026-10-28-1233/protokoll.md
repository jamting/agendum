# Minutes of the panel meeting, 2026-10-28-1233

**Place:** Owl's house, the Hundred Acre Wood
**Present:** Mattias (chair); Old Mitch Lilypad (Lotus Agenda), Little Marie-Who-Folds (tidiness), Dr. Russell (ADHD and overwhelm); Joel and Jeff, the Chipmunk Brothers (guests: launching an online business); Claude (Owl's cousin); Owl, host
**Apologies:** José Who Brews, Great-Uncle Joe, Carsten Stargazer, David the Squirrel
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Old Mitch Lilypad
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `4413101`

*The fourth meeting of the day, and the shortest. Owl, whose name was the subject, had promised to stay neutral, and sat very straight on his perch with his eyes closed so as not to influence anyone; he opened one of them only twice. The panel's voices are lenses in the spirit of the people behind the pseudonyms (`.claude/skills/expert-review/SKILL.md`), written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting, called by the chair on a question raised in the session; there were no thoughts under Next meeting in the chair's project file.

## § 2 Election of a chair, a secretary and two approvers

Mattias chairs; Claude keeps the minutes; Marie and Mitch approve them.

## § 3 Adoption of the agenda

The agenda was adopted as worded.

## § 4 The previous minutes

| Decision (2026-10-28-3) | Status | Evidence |
| --- | --- | --- |
| § 5 The FSL and BSL facts corrected | Done | `docs/plans/GITHUB.md` § 7 |
| §§ 6–8 AGPL-3.0-only, CC BY 4.0, a CLA | Recorded | ADR 0051, `4413101` |
| § 9 Confirmed after a lawyer's check | Not yet (before the practical meeting) | `docs/plans/GITHUB.md` § 7, step 7; `docs/ROADMAP.md` |

## § 5 The long name: Wol's Agendum or Owl's Agendum?

**Background.** ADR 0019 (2026-10-11) named the program Wol's Agendum: Wol is how Owl spells his name in Milne's books, and an agendum is one thing to be done. The short name, Agendum, is not in question. The chair asked whether the project should be called Wol's Agendum or Owl's Agendum, and which is better, before it goes public.

**Discussion.** Claude reported that the long name appears 61 times in 36 tracked files, 15 of them under `lib/` and `test/`, and is never stored in a person's file, only in text the program writes (comments, the User-Agent, the blog's generator tag, the debug log's build line); a rename would be one mechanical commit with three tests changed and nothing to migrate. The planned agent is called Wol, "inside the program named after him" (`docs/plans/WOL-IN-THE-MACHINE.md`).

**Mitch** said a product name should be distinctive rather than self-explaining, and that "Wol" is a small secret shared with the reader. **Russell** noted that a name that looks like a typo makes a small stumble on first meeting, especially for someone who reads quickly or has dyslexia, mended by telling the story once where the name first appears. **Joel and Jeff** said "Owl" is crowded with apps and standards, and that a name that cannot be found cannot be recommended; they had not checked domains, which would carry "Agendum" anyway. **Marie** said one name should be kept for the program and the agent. **Claude** (its own lens) said a unique string, once written in the README, `llms.txt` and the site, is found exactly by search engines and LLMs, while "Owl's Agendum" would blur into the common words; and that Wol is Milne's own spelling.

The panel advised keeping Wol's Agendum, with one line telling its story.

Before deciding, the chair, a native Swedish speaker, asked whether the name is hard to pronounce, and how it is said. Claude answered that it is one short syllable with no unusual sounds: *Wol* rhymes with "doll" (British /wɒl/; American close to "wall"), near Swedish "våll" with an English w; *Wol's* is "wolz"; *Agendum* is "a-JEN-dum" in English (/əˈdʒɛndəm/), with a soft g and the stress on the middle syllable, as in "agenda", where Swedish speakers tend to a Latin hard g. The only cost is the first "is that a typo?", not the sound, and a name spelled as it sounds is easy to write down after hearing it.

**Decided:** keep **Wol's Agendum**; ADR 0019 stands. One line tells the story, "Wol is how Owl spells his name", where the name first meets a reader: the About help, the README, later the site.

## § 6 Any other business

The chair asked for the pronunciation to be written down. **Decided:** "wolz a-JEN-dum", with the phonetics, in ADR 0019's update of 2026-10-28, and beside the story line in the About help, the README and the site (one roadmap item).

## § 7 Next meeting

The practical meeting on the dry run's results (In order 3).

## § 8 Closing of the meeting

*Owl opened both eyes, thanked the panel for keeping his spelling, and closed the meeting.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | Keep Wol's Agendum; tell its story once where the name first appears | ADR 0019 (update 2026-10-28), `docs/ROADMAP.md` (Housekeeping) |
| 6 | The pronunciation written down: "wolz a-JEN-dum" | ADR 0019 (update 2026-10-28), `docs/ROADMAP.md` (Housekeeping) |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Old Mitch Lilypad.*
