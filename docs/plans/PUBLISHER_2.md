# The publisher, round 2

**Status:** planned (meeting 2026-11-02-1954); step 1 next. Round 1 is [`archive/PUBLISHER.md`](archive/PUBLISHER.md) (v0.79.0–v0.85.0). Every step is part of the micro-blog, an extra (R74, ADR 0043), built the `feature` way, one step per release, each tried by the owner before the next.

The owner asked the panel to evaluate round 1 (omissions, improvements, what went well) and to formulate a round 2. What was decided, in order:

## The steps

1. [ ] **Split R74 into sub-rules** (§ 9): R74 the blog and publishing, R74a Site and Upload, R74b addresses and a post's metadata, R74c templates and assets, R74d pages and the menu, R74e feeds, R74f publishing without the screen; each in SPEC's rule index; the meaning unchanged. Docs only.
2. [ ] **Images from `assets/` in posts and pages** (§ 6): `![alt](assets/me.jpg)` is shown, its address made right for each page (`../assets/…` from a post in a folder); an image naming an asset that is not there stops publishing and says which. Today an image needs a whole web address (`markdown.ex`).
3. [ ] **The newest N posts, and an archive** (§ 7): the index, each feed's index and the feeds carry the newest N posts (a Site setting, 20 by default); `archive.html` (and a feed's own) lists every post's title and date by month, its links never moving.
4. [ ] **A 404 page** (§ 13): `404.html` drawn from a `404.html` template, which GitHub Pages and most servers show for an address that leads nowhere.
5. [ ] **Tag pages** (§ 13): a Tags family picked in Site; each tag a page listing its posts; a post's tags shown on it. After the meeting on publishing any view as a feed (below), as the two overlap.
6. [ ] **Optional: publishing on its day** (§ 8): no scheduler inside Agendum; `agendum --publish FILE --quiet` prints nothing when nothing changed, exits 0 or 1, and the docs show a launchd and a cron example.

## Tabled to a meeting of its own

**Any view as a feed** (§ 13): the owner is not satisfied that every feed must be a category under Posts, which is cumbersome; they would like to publish any view as a feed (the Journal starter's Gym log, for one), or perhaps choose a feed's posts by an assignment rule. To be explored at a meeting of its own, before tag pages are built.

## Ideas, not in round 2

A post preview in Agendum (a key in a post's note shows it as the site would) and sharing details (Open Graph and description meta tags, `sitemap.xml`) are on the roadmap's Ideas.
