# Minutes of the panel meeting, 2026-11-02-2244

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); Old Mitch Lilypad, Carsten Stargazer, Dr. Russell, Little Marie-Who-Folds, Claude (Owl's cousin); Owl, host
**Secretary:** Claude · **Approvers:** Carsten Stargazer, Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `f7708a1f`

*Owl's house at a quarter to eleven at night, the good cushions out and Dr. Russell's tea on the table; the second meeting of the evening. The panel's voices are lenses in the spirit of the named people, written by Claude, not their words; made with the `meeting` skill.*

## § 1 Opening of the meeting

Owl opened the meeting.

## § 2 Election of a chair, a secretary and two approvers

The owner chaired; Claude was secretary; Carsten Stargazer and Little Marie-Who-Folds were chosen to approve the minutes.

## § 3 Adoption of the agenda

The agenda was adopted as proposed: the item tabled at meeting 2026-11-02-1954, § 13, split into three. Great-Uncle Joe, José Who Brews and David the Squirrel were excused, the agenda being about the user's side rather than the runtime or GTD.

## § 4 The previous minutes

| Decision (meeting 2026-11-02-1954) | Status | Evidence |
| --- | --- | --- |
| § 6–9, § 13: round 2's steps | Not yet; step 1 next | `docs/plans/PUBLISHER_2.md` |
| § 10: the list-and-box pattern for Feeds and Calendars | Not yet; after round 2 | `docs/ROADMAP.md`, lane 4 |
| § 11: seven questions in the feature skill | Done | `5782d4f8` |
| § 12: the devlog's templates ignored | Done | `eefe43f4` |
| § 13: any view as a feed, a meeting of its own | Done: this meeting | — |

## § 5 What a view becomes when it is published

**Background.** A view is more than a list of items: sections, columns, and in a datebook such as the Journal's Gym log, weeks with sums under each (`lib/agendum/starters/journal.ex:113`). Publishing one could make each item a post in a feed, or draw the whole view as one web page, as Print current view does on paper.

**Discussion.** **Mitch** noted that Agenda had no feeds; its way of showing a view outside the program was Print current view (SPEC, the menus), the whole view as laid out, so a page is the clone-shaped answer. **Carsten** said Org-mode has both shapes, an agenda view written as HTML and a subtree exported as RSS, and that they do different jobs. **Dr. Russell** said nobody wants twelve "Bench press" lines in their feed reader; the weekly page is what one looks at. **Claude** said a feed of items is cheap on the existing feed code, a page of the view needs a renderer of its own. **Marie** asked for one shape first.

The chair clarified the wish behind the tabled item: not to be bound to publishing a child of Posts, but to make a feed from any category in the settings (§ 6). Publishing a view's sections as one HTML page is an interesting idea, to be kept.

**Noted:** a view published as one web page goes to the roadmap's Ideas.

## § 6 How a feed's posts are chosen

**Background.** Today every category right under Posts is a feed by itself (`lib/agendum/core/extras/blog.ex:138`, R74 Feeds), which the owner finds cumbersome. The chair wished to create a feed from any category in the settings.

**Discussion.** **Mitch** observed that a feed "chosen by an assignment rule" needs nothing new: a category with conditions or Also match fills itself (R15, R15d). **Dr. Russell** said that requiring items to be in Posts too would keep the cumbersome part. **Carsten** advised keeping a feed's items off the main index, so a gym log does not flood the blog's front page. **Marie** preferred one rule: a feed is what is listed in the settings. **Claude** said a feed's category must stay one of the person's own, never an ingested one (R75a), and that feeds are already kept by category id (`BlogFeed`).

The chair asked whether publishing a category's items as posts was a good idea at all, and proposed a broader view: a feed is "a list of things" that the templates can do whatever they like with, such as a page presenting a Co-workers category as a list. **Claude** agreed the earlier framing was too narrow, as it assumed every list is a blog stream, and named the costs: templates would need an item's columns, which they do not see today; a list from any category needs a privacy guard; the name Feeds would mislead; and it should be built in small steps, today's Devlog first. The framing also covers tag pages, and a list can be filled by rule through conditions.

**Decided:** Publish ▸ Feeds becomes **Publish ▸ Lists**. A list is any of the person's own categories, its items handed to the templates; per list an index page, RSS and JSON Feed, and a page per item are switched on or off. A list's items need not be in Posts. A child of Posts is no longer a feed by itself; the existing feeds (Devlog) are kept as lists, so the site does not change.

**Referred** to `docs/plans/PUBLISHER_2.md`: which of an item's fields (columns, note, dates) a template sees and their names, and the privacy guard (what leaves the file, whether notes are published).

## § 7 Tag pages and the order of round 2

**Background.** Round 2's step 5, tag pages, was put after this meeting, as the two overlap. Steps 3 and 4 are untouched by Lists, though step 3's archive would be per list.

**Discussion.** **Carsten** said a tag page is a list made from a family, one page per child, so it becomes an option of Lists. **Marie** advised building Lists before the archive, so the archive is not built per feed and rebuilt per list; images touch none of it and can stay first. **Claude** said the R74 split should name the feeds' sub-rule with Lists in mind, and that Lists is the largest step of the round (a stored change, Devlog moved over, a new box), one release of its own. **Dr. Russell** wanted Lists early, as it is the one the chair asked for.

**Decided:** round 2 in order: 1 split R74 (Lists in mind); 2 images; 3 Lists; 4 the newest N and an archive, per list; 5 a 404 page; 6 tag pages as a list made from a family; 7 optional, `--publish --quiet`.

## § 8 Any other business

None.

## § 9 Next meeting

When the agenda has enough items.

## § 10 Closing of the meeting

The chair closed the meeting with thanks. *Owl blew out the candles; Dr. Russell took the teapot home.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | A view published as one web page, an idea kept | `docs/ROADMAP.md` (Ideas), `docs/plans/PUBLISHER_2.md` |
| 6 | Publish ▸ Lists: any own category a list, switches per list, Devlog kept | `docs/plans/PUBLISHER_2.md` (step 3, Lists) |
| 6 | Referred: the fields a template sees, the privacy guard | `docs/plans/PUBLISHER_2.md` (Lists) |
| 7 | Round 2 reordered; tag pages as a list from a family | `docs/plans/PUBLISHER_2.md`, `docs/ROADMAP.md` (In order 1) |

*Minutes kept by Claude. Approved by Carsten Stargazer and Little Marie-Who-Folds.*
