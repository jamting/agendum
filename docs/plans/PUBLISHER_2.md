# The publisher, round 2

**Status:** under way (meetings 2026-11-02-1954 and 2026-11-02-2244); steps 1 and 2 done 2026-11-03 (v0.87.0), step 3 (Lists) next, after its questions. Round 1 is [`archive/PUBLISHER.md`](archive/PUBLISHER.md) (v0.79.0–v0.85.0). Every step is part of the micro-blog, an extra (R74, ADR 0043), built the `feature` way, one step per release, each tried by the owner before the next.

The owner asked the panel to evaluate round 1 (omissions, improvements, what went well) and to formulate a round 2. A second meeting (2026-11-02-2244) replaced the blog's feeds with Lists and set the order below.

## The steps

1. [x] **Split R74 into sub-rules** (meeting 2026-11-02-1954, § 9): R74 the blog and publishing, R74a Site and Upload, R74b addresses and a post's metadata, R74c templates and assets, R74d pages and the menu, R74e feeds (named so it can become Lists in step 3; meeting 2026-11-02-2244, § 7), R74f publishing without the screen; each in SPEC's rule index; the meaning unchanged. Docs only. Done 2026-11-03 (R74a is the Site and Upload settings, R74b post addresses and records, R74d pages).
2. [x] **Images from `assets/` in posts and pages** (meeting 2026-11-02-1954, § 6): `![alt](assets/me.jpg)` is shown, its address made right for each page (`../assets/…` from a post in a folder); an image naming an asset that is not there stops publishing and says which. Done in v0.87.0 (R74c): written `assets/…` from the site's root, an image without alt text allowed (`alt=""`; the owner's choices, 2026-11-02).
3. [ ] **Lists** (meeting 2026-11-02-2244, § 6): Publish ▸ Feeds becomes **Publish ▸ Lists**. Details below.
4. [ ] **The newest N posts, and an archive** (meeting 2026-11-02-1954, § 7): the index, each list's index and the feeds carry the newest N items (a Site setting, 20 by default); `archive.html` (and a list's own) lists every item's title and date by month, its links never moving. Per list, after step 3 (meeting 2026-11-02-2244, § 7).
5. [ ] **A 404 page** (meeting 2026-11-02-1954, § 13): `404.html` drawn from a `404.html` template, which GitHub Pages and most servers show for an address that leads nowhere.
6. [ ] **Tag pages, as a list made from a family** (meetings 2026-11-02-1954, § 13, and 2026-11-02-2244, § 7): a list's option "one page per child category", so a Tags family gives each tag a page of its items; a post's tags shown on it. Not a feature of its own.
7. [ ] **Optional: publishing on its day** (meeting 2026-11-02-1954, § 8): no scheduler inside Agendum; `agendum --publish FILE --quiet` prints nothing when nothing changed, exits 0 or 1, and the docs show a launchd and a cron example.

## Lists (step 3)

Decided (meeting 2026-11-02-2244, § 6):

- **A list is any of the person's own categories** (never an ingested one, R75a), added in Publish ▸ Lists. Its items are handed to the templates, which decide what it becomes: a blog stream, a page of co-workers, a gym table.
- **Per list, switched on or off:** an index page (drawn from a template), RSS and JSON Feed, and a page per item.
- **A list's items need not be in Posts:** the list publishes them. Posts stays the site's main index and main feed.
- **No automatic lists:** a child of Posts is no longer a feed by itself. The existing feeds (the owner's Devlog) are kept as lists when the file is opened, with their folders, so the site does not change.
- **"Chosen by rule" comes free:** a category fills itself by Agenda's own conditions and Also match (R15, R15d), so a list can be filled by rule with nothing new built.

Added by the owner after the meeting (2026-11-02, an addendum to § 6): an RSS feed is a special case of a list, so **a list's outputs are templates**:

- **The RSS feed is a template,** `rss.xml`, as the pages are; Agendum ships a default word for word what it writes today (`Agendum.Core.Extras.Site`), so a site that does not change it sees no difference. Other outputs (Atom, an `.ics`, a CSV, `sitemap.xml`) become a template each, with nothing built for them.
- **The JSON Feed stays built in code:** the templates escape for HTML, which is close to right for XML but wrong for JSON, and the template language gets no JSON escape for this.
- **Every feed written is read back** with Agendum's own feed reader (`Agendum.Core.Extras.FeedParser`) before publishing; one that does not read stops publishing and says which, as a missing image does (step 2), since a broken feed fails silently in readers.
- **Dates in RSS's form** (`Mon, 02 Nov 2026 22:44:00 +0000`) are a value of their own for templates, beside `date_iso`.

Referred to this plan, to settle with the owner before step 3 is built (the `feature` skill's questions):

- **What a template sees of a list's items:** beyond `title`, `content`, dates and `url`, an item's columns (Role, Email for co-workers; Sets, Reps, Weight for the gym), and what they are called in a template.
- **The privacy guard:** what leaves the file from a list made of any category; whether a list's item notes are published, or only chosen fields; whether Drafts holds a list's items back as it holds posts.
- **Defaults of a new list's switches,** and whether a list's items appear on the main index when they are also in Posts.
- **The stored change:** the blog's feeds are kept by category id today (`Agendum.Core.Extras.BlogFeed`, `Blog.feeds`); a list adds its switches and template; a new format version and its golden file.

## Ideas, not in round 2

A post preview in Agendum, sharing details (Open Graph and description meta tags, `sitemap.xml`) and a view published as one web page (its sections and columns as the view looks, Print on the web; meeting 2026-11-02-2244, § 5) are on the roadmap's Ideas.
