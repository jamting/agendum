# Minutes of the panel meeting, 2026-10-28-2214

**Place:** Owl's house, the Hundred Acre Wood
**Present:** Mattias (chair); Little Marie-Who-Folds (tidiness), Old Mitch Lilypad (Lotus Agenda), Dr. Russell (ADHD); Claude (Owl's cousin); Owl, host
**Apologies:** José Who Brews, Great-Uncle Joe, Carsten Stargazer, David the Squirrel
**Secretary:** Claude · **Approvers:** Little Marie-Who-Folds, Dr. Russell
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `7796fba`

*The sixth meeting of the day. The new README lay on the table with its first real picture, and Owl had printed the guide, the manual and a blog post side by side and pinned them to the portrait of Uncle Robert, who did not seem to mind. The panel's voices are lenses in the spirit of the people behind the pseudonyms (`.claude/skills/expert-review/SKILL.md`), written by Claude, not their words; the meeting was held with the `meeting` skill.*

## § 1 Opening of the meeting

Owl rang the bell-pull for the sixth time that day and opened the meeting.

## § 2 Election of a chair, a secretary and two approvers of the minutes

Mattias was chair and Claude secretary. Little Marie-Who-Folds and Dr. Russell were chosen to approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as shown. The owner's project file had no thoughts under Next meeting; the items are the ones the chair raised in the session.

## § 4 The previous minutes

| Decision (meeting 2026-10-28-1911) | Status | Evidence |
| --- | --- | --- |
| §§ 5–8, 12: the five fixes to the copy | Done | `ee9d3b1` |
| § 8: the captured texts kept | Done; the chair kept all 1,558 messages, the question goes to the lawyer | `9280a1e` |
| § 9: the lawyer before the first outside pull request | Not yet | `docs/ROADMAP.md`, Housekeeping |
| §§ 10–11: the rename, no sync | Waiting for moving day | `plans/GITHUB.md` § 7 |
| § 13: the README's screenshot | Done | `7796fba` |
| § 13: the guide and manual in the blog's stylesheet | Refined at this meeting (§ 5) | — |
| § 14: Find your way | Done | `7796fba` |

## § 5 How the guide and the manual should look

**Background.** The practical meeting decided to style the guide and the manual in the blog's stylesheet (meeting 2026-10-28-1911, § 13). Screenshots taken for the meeting showed the guide and manual already have a design of their own: a contents sidebar, Owl's and Rabbit's speech bubbles, the Wood drawings and screens in Agenda's colours (`docs/guide/guide.css`, `docs/manual/manual.css`). The blog uses The Proportional Web (`lib/agendum/core/extras/site_assets/style.css`): Alegreya and Courier Prime, small capitals, a baseline grid, one narrow column, no sidebar.

**Discussion.** **Marie** said each part of the guide has a job (the sidebar finds things, the bubbles tell Owl from Rabbit, the screens show Agenda's colours), and that throwing them away to match the blog would be tidying by force; a shared base of fonts and colours gives the family one home. **Russell** said the guide reads well for a tired person: short paragraphs, generous line height, the contents always in view; a single column without a sidebar means more scrolling and more to hold in mind. **Mitch** said Lotus's manuals were roomy, with a picture of the screen on almost every page, which the guide already does, and that the public face should look like one family: blog, guide, manual and later the site. **Claude** said nobody had yet seen Alegreya at the guide's body size beside the VGA screens, so a sample page should settle it first.

The chair then said what they want: only the typographic elements of The Proportional Web, for its vertical rhythm and vintage look; perhaps its aside elements; the manual using the browser's width adaptively; a sidebar that shows where the reader is in the document; and the manual remembering where the reader left off. **Russell** asked that "adaptive" not mean very long lines, which tire the eye: the text column keeps a readable width and the extra width goes to the sidebar, the margin notes and the screens. **Claude** said the reader's place can be kept in the browser's own storage, which works for a page opened as a local file, and that the page opens at the top when storage is blocked.

*Marie quietly moved the biscuit tin into the margin, as an aside.*

**Decided:** the guide and the manual take The Proportional Web's typography (its fonts, vertical rhythm and vintage look) and its asides as margin notes, and keep their own parts (sidebar, bubbles, drawings, screens). The manual uses the browser's width adaptively, its sidebar shows where the reader is, and it remembers where the reader left off. One sample page first, for the chair to look at.

## § 6 Airier documents

**Background.** The chair finds dense paragraphs hard to read. Measured for the meeting: the README, `AGENDA_HISTORY.md` and the summaries average 22–29 words a paragraph; SPEC's rule entries average 184, with 115 over 80 words and the longest 1,048; the roadmap has 19 items over 80 words; VISION, KEYBOARD and ARCHITECTURE two or three each.

**Discussion.** **Russell** said a thousand-word paragraph is a wall, and that people easily overwhelmed give up on walls; short paragraphs of one idea and lists for conditions help most where the rules are hardest. **Marie** advised a habit rather than a rewrite spree: airy writing for new text, SPEC and the roadmap restructured once, the short documents left alone. **Mitch** said SPEC will be public as the evidence of a truthful clone, read by people who knew Agenda, so it is worth doing before publishing. **Claude** said SPEC is about 32,000 words in 174 rule entries, an L-sized job, best done in slices with a check that every rule keeps its number, its status mark and its "(checked in Agenda)" or "Our choice", the meaning unchanged.

**Decided:** airy writing becomes a habit for all new text, documents and replies alike (CLAUDE.md, Conventions). SPEC and the roadmap are restructured once, in slices, meaning unchanged; both before the public repository, SPEC first.

## § 7 A Wood-themed README picture

**Background.** The README's picture shows Agenda's own sample calls (Terracotta Corp, Anna Lasky). The chair may swap it for one with more of the Wood in it: Rabbit's file from the manual, Piglet's party from the guide or the splash with Wol.

**Discussion.** **Mitch** said the first picture tells strangers what kind of project this is: a Wood file shows the character, Agenda's sample shows the faithfulness, and either works. **Marie** said it is a one-line roadmap item, not work for tonight. The chair wanted strangers to meet the Wood first.

**Decided:** a Wood-themed README picture before the public repository; the screen is the chair's choice when it is made.

## § 8 Any other business

None.

## § 9 Next meeting

When the agenda has enough items.

## § 10 Closing of the meeting

Owl thanked the panel, unpinned the printouts from Uncle Robert and closed the meeting.

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The Proportional Web's typography and asides for the guide and manual; an adaptive manual that shows and remembers the reader's place; a sample page first | `docs/ROADMAP.md` (In order 1, Housekeeping), `ROADMAP_DONE.md` |
| 6 | Airy writing as a habit; SPEC, then the roadmap, restructured before publishing | `CLAUDE.md` (Conventions), `docs/ROADMAP.md` (In order 1, Housekeeping), memory |
| 7 | A Wood-themed README picture before publishing | `docs/ROADMAP.md` (In order 1, Housekeeping) |

*Minutes kept by Claude. Approved by Little Marie-Who-Folds and Dr. Russell.*
