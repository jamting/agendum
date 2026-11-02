# Minutes of the panel meeting, 2026-11-02-1954

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Carsten Stargazer (Org-mode), Great-Uncle Joe (Erlang/OTP), José Who Brews (Elixir), Little Marie-Who-Folds (tidiness), Dr. Russell (ADHD), Claude (Owl's cousin); Owl, host. Old Mitch Lilypad and David the Squirrel sent apologies, as nothing on the agenda touched Agenda's own behaviour or GTD.
**Secretary:** Claude · **Approvers:** Carsten Stargazer and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `79962810`

*Evening in Owl's house, the same day as the meeting that planned the publisher. Carsten has brought a laptop showing the devlog, scrolled to the bottom, which takes a while. Little Marie-Who-Folds has already folded the agenda into thirds. Great-Uncle Joe sits on the stairs with a cup of tea; José has the code reviews printed, ten findings a page, seven pages. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; made with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs, Claude is secretary, and Carsten Stargazer and Little Marie-Who-Folds approve the minutes.

## § 3 Adoption of the agenda

There were no thoughts under Next meeting; the chair asked for an evaluation of the publishing work. The secretary worded it as nine items. The chair struck the item on the guide and the manual, and added a final one: to formulate a round 2 of the publisher. The agenda was adopted so.

## § 4 The previous minutes

| Decision (meeting 2026-11-02-1255) | Status | Evidence |
| --- | --- | --- |
| §§ 5–12 The note editor, a post's metadata, templates, pages, several feeds, the settings, our own publisher, dogfooding | Done | v0.79.0–v0.85.0; dogfooding narrowed to the headless publish (the owner, 2026-11-02) |
| § 10 The list-and-box pattern for the RSS Feeds and the Calendars | Not yet | `docs/ROADMAP.md`, lane 4; § 10 below |
| § 13 The order of the seven steps | Followed | `docs/plans/archive/PUBLISHER.md` |

## § 5 What went well

**Background.** Seven steps were built in one day, each through the whole checklist: questions first, failing tests, the gate, two fuzz runs, a code review, a smoke test.

**Discussion.** **Carsten** said the design held because it was built in Agenda's own terms: pages are a category, feeds child categories, a title a heading, so nothing new had to be learned. **Joe** praised the byte-for-byte checks of the templates against a saved site, which proved the new machinery changed nothing until used. **José** noted that the architecture tests caught real slips while the work went on: a database field changed by hand in the TUI, an extra reached directly, a door not listed. **Marie** noted that each step closed its own documents. **Claude** noted that `agendum --publish` is the first headless entry point that writes. **Dr. Russell** credited the chair's calm choices: a menu only with pages, "Updated" left to the template, old templates replaced only while untouched.

*Owl suggested the minutes record "seven steps" in gold letters; Marie suggested ordinary ones.*

**Noted.**

## § 6 Omission: images in posts

**Background.** The site's `assets/` folder goes out with the pages, but a post cannot show an image from it: the Markdown reader takes an image only by a whole web address (`lib/agendum/core/extras/markdown.ex:219`).

**Discussion.** **Carsten** said `![me](assets/me.jpg)` is the first thing a writer tries: let the reader take a path inside the site and write it relative to each page. **Joe** asked that only a safe path to an asset that exists be accepted, a missing one said at publishing, not left as a broken image. **José** noted that the site builder already has the list of assets. **Dr. Russell** added that the preview can name a missing image.

**Decided:** `![alt](assets/…)` works in posts and pages, its address made right for each page; an image naming an asset that is not there stops publishing and says which.

## § 7 Improvement: the index holds every post in full

**Background.** The index and each feed's index show every post in full, and the feeds carry every post, so all of them grow with every post.

**Discussion.** **Joe** said a few hundred posts make the index megabytes, rewritten and uploaded at each publish, and a feed reader wants only the latest. **Carsten** compared the newest posts in full plus an archive by month, whose links never move, with numbered pages, whose addresses shift as posts are added. **Marie** asked for two settings at most. **Dr. Russell** found an archive by month kinder to read than endless scrolling.

**Decided:** the index, each feed's index and the feeds carry the newest N posts (a Site setting, 20 by default); `archive.html`, and a feed's own, lists every post's title and date by month.

## § 8 Improvement: future posts need a manual publish

**Background.** A post with a When still to come waits until the person publishes on or after its day; Agendum has no scheduler, and `agendum --publish FILE` now exists.

**Discussion.** **Joe** advised no scheduler inside Agendum: the system's launchd or cron can run `agendum --publish FILE` each morning, and Agendum's part is to be safe unattended. **Claude** asked for clear exit codes, 0 for published or nothing to do, 1 for an error. **Carsten** said Org users do the same with cron. **Dr. Russell** asked for a ready-made example in the documents. **Marie**: document it, do not build it.

**Decided, as optional:** no scheduler inside Agendum; `agendum --publish FILE --quiet` prints nothing when nothing changed and exits 0 or 1, and the documents show a launchd and a cron example. The chair marked it optional.

## § 9 Tidiness: R74 is one rule of about 2,900 words

**Background.** The micro-blog's rule in SPEC grew with each step, to about 2,900 words; SPEC's style asks for short paragraphs and the rule, not its story.

**Discussion.** **Marie** said a rule a reader cannot hold in mind is a wall, and proposed sub-rules as R64 has: R74 the blog and publishing, R74a Site and Upload, R74b addresses and a post's metadata, R74c templates and assets, R74d pages and the menu, R74e feeds, R74f publishing without the screen. **José** noted the tests citing R74 need not change. **Claude** added that smaller rules are easier for an agent to read one at a time.

**Decided:** R74 is split into R74 to R74f with its meaning unchanged, a documents-only step, first in round 2.

## § 10 Left over: the list-and-box pattern for the RSS Feeds and the Calendars

**Background.** The last meeting (§ 10) decided that the Feeds list's pattern, a list whose ENTER opens a properties box, should later replace how the RSS Feeds and the Calendars change their settings; it is open in lane 4.

**Discussion.** **Marie** said it belongs to the extras' clean-up, not to the publisher's round 2. **José** noted the Feeds box already has a properties box (F6); what is left is ENTER opening it, which today reads the feed, and renaming moving into it. **Dr. Russell** warned that ENTER reading a feed is a habit the chair has, so the change needs asking first.

**Decided:** it stays in lane 4, after round 2, an item of its own; what ENTER does there is asked when it is built.

## § 11 Ways of working: each step's code review found about ten bugs

**Background.** Seven reviews found about 70 real problems after the gate had passed: among them a hang, writing outside the site's folder, lost upload settings, records kept before the preview was confirmed, a crash, and the Extras switch bypassed.

**Discussion.** **José** said the reviews paid for themselves, but the findings fall into a few kinds: what a file from an older version does, what a crafted file can carry, settings that collide or nest, and a guard that can be reached around; the feature skill's four questions cover only part of that. **Joe** asked to fix the method, not only the code: ask those questions before the code, so their tests come first. **Claude**, speaking for itself, said it had designed the happy path in several steps and left the review to find the edges, and that writing the edge tests first is cheaper. **Marie** asked to extend the checklist rather than add a ritual.

**Decided:** the feature skill's questions grow from four to seven: what is stored (an older file, a crafted one), settings that collide or nest, and a guard that can be reached around. Their tests come before the code; the review stays after the gate.

## § 12 Small: the devlog's templates and git

**Background.** Publishing writes `templates/` into `pages/devlog/`, untracked; the site no longer serves it.

**Discussion.** **Joe** advised committing them, as the devlog's design worth versioning. **Marie** said either is tidy as long as it is decided, and written in `.gitignore` if ignored. **Carsten** noted committed templates would show readers how the devlog is made.

**Decided:** ignored for now, in `.gitignore`.

## § 13 Round 2 of the publisher

**Background.** The chair asked for a round 2. Decided above: images, the archive, publishing on its day (optional), splitting R74. The panel proposed tag pages (**Carsten**: a Tags family, each tag a page of its posts, which SPEC lists as not yet), a post preview in Agendum (**Dr. Russell**), sharing details and a sitemap (**Claude**), and a 404 page (**Joe**). **Marie** asked to pick what would be used in the next month.

**Discussion.** The chair chose tag pages and the 404 page. The chair also said they are not satisfied that every feed must be a category under Posts, which is cumbersome: they would like to publish any view as a feed (the Journal starter's Gym log, for one), or perhaps choose a feed's posts by an assignment rule, and asked to explore it at a meeting of its own. **Carsten** noted that a tag page and a view as a feed overlap, both a view of a category, so building tags first could build them twice. **Marie** advised building first what that meeting cannot change; **Joe** agreed.

**Decided:** round 2, in order: 1 split R74; 2 images from `assets/`; 3 the newest N and an archive; 4 a 404 page; 5 tag pages, after the meeting on views as feeds; 6 optional, `--publish --quiet` with launchd and cron. The post preview and the sharing details go to Ideas.

**Tabled:** publishing any view as a feed, or a feed's posts chosen by an assignment rule, to a meeting of its own, before tag pages.

## § 14 Any other business

None.

## § 15 Next meeting

The meeting on publishing any view as a feed, when the chair calls it.

## § 16 Closing of the meeting

The chair closed the meeting. *Carsten closed the laptop on the devlog, Marie unfolded the agenda to file it, and Owl rang the bell-pull, which this time stayed on.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | What went well | — |
| 6 | Images from `assets/` in posts; a missing one stops publishing | `docs/plans/PUBLISHER_2.md` (step 2) |
| 7 | The newest N posts and an archive | `docs/plans/PUBLISHER_2.md` (step 3) |
| 8 | Optional: `--publish --quiet`, exit codes, launchd and cron examples | `docs/plans/PUBLISHER_2.md` (step 6) |
| 9 | Split R74 into R74–R74f, meaning unchanged | `docs/plans/PUBLISHER_2.md` (step 1) |
| 10 | The list-and-box pattern for Feeds and Calendars after round 2 | `docs/ROADMAP.md` (lane 4) |
| 11 | Seven questions in the feature skill, their tests first | `.claude/skills/feature/SKILL.md` |
| 12 | The devlog's templates ignored for now | `.gitignore` |
| 13 | Round 2 in order; post preview and sharing details to Ideas | `docs/plans/PUBLISHER_2.md`, `docs/ROADMAP.md` (In order 1, Ideas) |
| 13 | Tabled: any view as a feed, a meeting of its own | `docs/ROADMAP.md` (In order 2), `docs/plans/PUBLISHER_2.md` |

*Minutes kept by Claude. Approved by Carsten Stargazer and Little Marie-Who-Folds.*
