# Minutes of the panel meeting, 2026-11-02-1255

**Place:** Owl's house, the Hundred Acre Wood
**Present:** the owner (chair); José Who Brews (Elixir), Great-Uncle Joe (Erlang/OTP), Carsten Stargazer (Org-mode), Old Mitch Lilypad (Lotus Agenda), Little Marie-Who-Folds (tidiness), Claude (Owl's cousin); Owl, host. David the Squirrel and Dr. Russell sent apologies, nothing on the agenda being theirs.
**Secretary:** Claude · **Approvers:** Carsten Stargazer and Little Marie-Who-Folds
**Agenda:** [dagordning.md](dagordning.md) · **At commit:** `6efaba81`

*Early afternoon, an hour after undo had come to the note editor. Old Mitch wedged himself in by the umbrella stand, his papers sliding to the floor before he had sat down; Carsten had brought an Org file printed on a long strip of paper, which Little Marie-Who-Folds looked at the way she looks at all paper. Great-Uncle Joe and José shared the stairs. The panel's voices are lenses in the spirit of the people named, written by Claude, not their words; made with the `meeting` skill.*

## § 1 Opening of the meeting

The chair opened the meeting. Owl said it was an idea meeting, his favourite kind, as ideas take up no room.

## § 2 Election of a chair, a secretary and two approvers

The owner chairs, Claude is secretary, and Carsten Stargazer and Little Marie-Who-Folds approve the minutes.

## § 3 Adoption of the agenda

The owner's one thought for the meeting, an idea meeting on the publisher, covered several subjects; the secretary worded it as nine items (§§ 5–13). The agenda was adopted as it stood.

## § 4 The previous minutes

| Decision (meeting 2026-11-02-1043) | Status | Evidence |
| --- | --- | --- |
| § 5 A To-do lists starter with a Projects view | Parked (the owner, 2026-11-02) | `docs/ROADMAP.md`, lane 3 |
| § 6 The Journal starter | Done | v0.77.0, `starters/journal.agendum` |
| § 7 A Gym collection in the Journal | Done | v0.77.0 |
| Addition: a Health collection | Done | v0.77.0 |

## § 5 A better note editor for Markdown

**Background.** The owner wants the editor to help with Markdown: headings, lists and to-do lists, and links to other pages. Today a note is plain text on screen (R64e); Markdown becomes HTML only on the site (`lib/agendum/core/extras/markdown.ex`, task boxes included). Zettel links are already coloured in a note and can be followed (R73b).

**Discussion.** **Carsten** said Org's lesson is to keep the text plain and show its structure, and that the two helpers Org users use most are continuing a list on ENTER and toggling a check box. **Joe** asked that the colouring be done only when drawing, through the core's one Markdown reader, so that the editor and the site cannot disagree. **Mitch** noted Agenda's note was bare text, which is fine for an extra behind the switch as long as nothing changes with it off (ADR 0043). **Marie** warned that "more will surely come" is not a reason to build it now. **Claude** noted that plain Markdown suits an agent too.

*Carsten demonstrated list continuation on the back of his printout; the strip of paper reached the stairs.*

**Decided:** an extra behind the Extras switch: headings, list markers and task boxes stand out; ENTER continues a list or task list; a key toggles a task box. What is stored does not change; links to other pages are the Zettel links.

## § 6 A post's metadata

**Background.** The owner wants a publishing date (like Things' start date), a modified date on every item set automatically, a slug for addresses like `/year/month/day-slug.html` (configurable), and a title that can override the item's text. Today a post's date is When, else Entry (`lib/agendum/core/extras/blog.ex`); its address `posts/<zettel id>.html`, chosen on 2026-10-16 because it never changes; its title the item's text.

**Discussion.** On the date, **Mitch** pointed to Agenda's own way, a date category with a column (R6b, R56); **Marie** preferred to let a When in the future mean "not yet", with no second date; **Carsten** likened it to Org's SCHEDULED. On the modified date, **Joe** and **Marie** called a field on every item the costly choice (a format change, set by every edit, and Agenda had none); **Claude** noted the feeds have a field for it; **Marie** proposed stamping it when publishing finds a post changed, as Agendum already tracks the site's files. On the slug, **Joe** insisted an address must never change and the devlog's must not break, and the panel agreed on a slug made once, at first publishing, as the Zettel id is given once. On the title, **Carsten** proposed a note's first `# Heading`, as Org's `#+TITLE`, and **Mitch** agreed: the item keeps its short text in the view.

**Decided:** When stays the post's date, and a future When keeps the post out until that day; the modified date is stamped at publishing, with no field on items; a slug is made once from the title and kept, the address pattern a setting with the Zettel id as default, and published posts keep their addresses; a note's first `# Heading` gives the post its title.

## § 7 Templates edited outside Agendum, with assets

**Background.** Templates for the start page, a blog's index and detail pages and other pages, kept outside Agendum with their assets; the owner asked whether the menu could be one. Today the HTML is made in code, and only `style.css` can be changed (written when missing, kept once changed).

**Discussion.** **José** said Elixir's EEx would be easy, but an EEx template runs code, so a shared or copied site folder would become a door (`docs/SECURITY.md`); he advised logic-less templates in the Mustache style, escaped by default. **Joe** proposed a small reader of our own in the core, pure and without a package (ADR 0021). **Carsten** proposed Org's way: defaults written when missing and kept once changed, and an `assets/` folder copied as it is. **Marie** asked for few templates: a layout, the index, a post and a page, with the menu as a partial. **Claude** noted that logic-less templates are also what an agent can edit without risk.

*Owl asked whether a template could have a portrait of Uncle Robert in it. José said it could, in `assets/`.*

**Decided:** logic-less, Mustache-style templates read by our own pure reader in the core: a layout, index, post and page template and a menu partial, written as defaults when missing and kept once changed; an `assets/` folder copied unchanged.

## § 8 Other pages, such as /about and /now

**Background.** The ability to add pages that are not posts. Today the site has the index, the posts and the feeds only.

**Discussion.** **Mitch** proposed the Agenda way, a Pages category picked as Posts is, each item a page. **Carsten** said a page stays out of the index and the feeds, and lives at its slug at the top level. **Marie** noted it reuses everything decided under §§ 6 and 7. **Joe** proposed the default menu lists the pages alphabetically, and the person writes `menu.html` to choose the order. **Claude** noted `/now` is just an item updated and published again.

**Decided:** a Pages category in the publisher's settings; each of its items is a page at `/<slug>.html`, outside the index and the feeds; the default menu lists them alphabetically, or the person writes `menu.html`.

## § 9 Several feeds from one Agendum file

**Background.** Multiple sources of feeds in one Agendum file. Today a file has one blog with one Posts category and one pair of feeds (`Database.blog`).

**Discussion.** The secretary read the note three ways: one site with several feeds, several sites, or one blog fed by several categories. The chair meant one site with several feeds. **Mitch** proposed letting the categories do it: each child of Posts is a feed. **Marie** liked that it needs no new setting: a new feed is a new child in the category manager. **Joe** noted a post under two children is in both their feeds and once in the main one. **Claude** said the main feed is what most readers want. **José** said the menu partial can list the feeds as well as the pages.

**Decided:** each child category of Posts is a feed, with its own index page and feeds under `/<slug>/`; the site's main index and feeds hold every post.

## § 10 The Publish settings need rework

**Background.** Today one box holds thirteen fields (R74): what is published, about the site, where it goes and how it is uploaded, all kept in the file; today's decisions add Pages and the address pattern.

**Discussion.** **Marie** observed that the box does three jobs; **Mitch** that Agenda split large settings into boxes and sub-boxes; **Joe** that the folder and the upload belong to the Mac, not the file; **Carsten** that Org keeps them in the person's own configuration. The chair said the box holds too much and the upload belongs to this Mac, and added an idea of their own: sub-boxes for each feed, chosen from a list, a pattern the RSS reader's Feeds could use later. **Mitch** said a list whose ENTER opens the thing's properties box is Agenda's own (the view manager, the category manager), so it passes ADR 0049; **Marie** that it is also the fix ADR 0049 asked for in the Feeds and Calendars. The secretary drew the shape (a submenu: Publish, Site, Feeds, Upload), and **Joe** proposed keeping the upload in the preferences by the file's path, moved there on first opening.

*Marie quietly folded the thirteen fields into four piles on the table. Owl thanked the fourteenth, a teacup, and let it go.*

**Decided:** Extras ▸ Publish becomes a submenu: Publish, Site, Feeds, Upload. Feeds is a list of Posts' children whose ENTER opens a feed's properties box. The folder and the upload move to the person's preferences, kept per file and moved there on first opening. The same list-and-box pattern later for the RSS reader's Feeds and the Calendars.

## § 11 Maybe: a third-party static publisher?

**Background.** Whether Agendum should use a third-party static site generator instead of growing its own. Today the publisher is our own, about 2,200 lines, inside the single-file escript, with rsync as its one outside program.

**Discussion.** **Marie** said §§ 6–10 are much of what Hugo or Zola give for free, and that it was a fair question to ask before building them; but a generator is another program to install, another template language and two tools to keep in step. **Joe** said our own stays one binary, works offline and is tested end to end, and that what was decided today is small. **Carsten** said Org kept its publishing built in for the same reason, and proposed an export of the posts as Markdown with front matter as a cheap middle way. **Claude** noted the content is plain Markdown either way, so nothing is locked in.

**Decided:** Agendum keeps its own publisher and builds §§ 6–10 in it; an export as Markdown with front matter is parked as an idea.

## § 12 Maybe: dogfooding

**Background.** Build `jamting.github.io/agendum/` with the publisher. Today `mix agendum.pages` assembles it in CI: a hand-written front page, the devlog by the blog extra, the guide, the manual, the API docs and `llms.txt`.

**Discussion.** **Mitch** said that after §§ 7–9 the site maps cleanly: the front page a Page, the devlog a feed, the menu linking what is copied in. **Joe** said CI needs a headless publish, `mix agendum.publish FILE`. **Claude** noted a headless publish is also an agent's entry point, beside the roadmap's headless read command. **Marie** advised it as the last step, as a test that the rest works, not as the first, where it would bend the design to one site.

**Decided:** yes, as the last step: the front page a Page and the devlog a feed, published in CI by a headless `mix agendum.publish`; the guide, the manual and the API docs stay copied in as now.

## § 13 The publisher's roadmap: the order

**Background.** The decisions above, put in an order; the roadmap's In order list was empty.

**Discussion.** The panel proposed the settings first, as every later step adds a field, then the metadata, templates, pages, several feeds, the note editor and dogfooding. **Marie** asked for one step per release, each tried before the next. **Carsten** noted the editor is what the owner would feel every day and could go first; the chair kept the proposed order.

**Decided:** the order: 1 the settings split, 2 a post's metadata, 3 templates and assets, 4 pages, 5 several feeds, 6 the note editor for Markdown, 7 dogfooding.

## § 14 Any other business

None.

## § 15 Next meeting

When the agenda has enough items.

## § 16 Closing of the meeting

The chair closed the meeting. *Mitch gathered his papers from under the table, and with them, by mistake, the last of Carsten's printout.*

## Decisions and where they are recorded

| § | Decision | Recorded in |
| --- | --- | --- |
| 5 | The note editor for Markdown: highlighting, list continuation, a task-box toggle, as an extra | `docs/plans/PUBLISHER.md` (step 6) |
| 6 | Future When waits; modified date stamped at publishing; a slug made once and an address pattern; the title from a note's `# Heading` | `docs/plans/PUBLISHER.md` (step 2) |
| 7 | Logic-less Mustache-style templates, our own reader; defaults kept once changed; `assets/` | `docs/plans/PUBLISHER.md` (step 3) |
| 8 | A Pages category; pages at `/<slug>.html`; a menu partial | `docs/plans/PUBLISHER.md` (step 4) |
| 9 | Posts' children as feeds, each with its own index and feeds | `docs/plans/PUBLISHER.md` (step 5) |
| 10 | Publish submenu (Publish, Site, Feeds, Upload); upload in the preferences; the pattern later for Feeds and Calendars | `docs/plans/PUBLISHER.md` (step 1), `docs/ROADMAP.md` (lane 4, item 1) |
| 11 | Keep our own publisher; export as Markdown with front matter parked | `docs/ROADMAP.md` (Ideas) |
| 12 | Dogfood the project's site, last, with a headless `mix agendum.publish` | `docs/plans/PUBLISHER.md` (step 7) |
| 13 | The order of the seven steps | `docs/ROADMAP.md` (In order 1), `docs/plans/PUBLISHER.md` § The steps |

*Minutes kept by Claude. Approved by Carsten Stargazer and Little Marie-Who-Folds.*
