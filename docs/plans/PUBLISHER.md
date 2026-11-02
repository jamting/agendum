# The publisher: a roadmap

**Status:** under way (meeting 2026-11-02-1255): step 1 done (v0.79.0); step 2 next. The publisher today is R74 (the micro-blog, ADR 0041), an extra behind the Extras switch (ADR 0043); every step here stays one, built in the clone's patterns (ADR 0049).

The owner asked for an idea meeting to give the publisher a roadmap. The meeting decided what each part should be and in what order; the details of each step are settled when it is built (the `feature` skill), and the decisions below are the starting point, not a specification.

## What was decided

### Settings (§ 10)

- **Extras ▸ Publish becomes a submenu:** Publish (the preview, then write and upload, as the box's ENTER today), Site, Feeds, Upload.
- **Site** (kept in the file): title, description, author, language, base address, `rel="me"` links, Posts, Drafts, Pages (§ 8) and the address pattern (§ 6).
- **Feeds** (kept in the file): the list of the Posts category's children (§ 9); ENTER opens the highlighted feed's properties box (its title, description, slug), as the view manager opens a view's.
- **Upload** (kept in the person's preferences, for this file, not in the file): the folder, the method (None, rsync, SFTP), target, user, remote folder. A file that holds upload settings moves them to the preferences the first time it is opened. Why: the folder and the server belong to this Mac; a file shared or opened elsewhere should not carry them.
- **Later:** the same list-and-properties-box pattern for the RSS reader's Feeds and the Calendars, which today change settings by letter keys and one-line prompts (ADR 0049's finding).

### A post's metadata (§ 6)

- **Publishing date:** When stays a post's date (else Entry). A When in the future keeps the post out until that day (as Things' start date, Org's SCHEDULED). No new field.
- **Modified date:** stamped when publishing finds a post changed since it was last published (Agendum already lists what changed, `.agendum-site`), for the pages and the feeds (`date_modified`, `updated`). No field on every item, no format change for it.
- **Slug:** made once from the title when a post is first published, and kept, as its Zettel id is given once. The **address pattern** is a Site setting: `posts/<zettel id>.html` stays the default, or `{year}/{month}/{day}-{slug}.html` and the like. Posts already published keep their addresses, so no link breaks (the devlog's among them).
- **Title:** a note whose first line is `# Heading` gives the post that title; the item keeps its short text in the view. Otherwise the item's text is the title, as today.

### Templates and assets (§ 7)

- **Logic-less templates** in the Mustache style (`{{title}}`, `{{#posts}}…{{/posts}}`, `{{> menu}}`), read by a small reader of our own in the core (pure, no package, ADR 0021). Values escaped by default; only the post's body, already HTML from our Markdown, goes in as it is. Not EEx: a template that runs code would make a shared site folder a door (`SECURITY.md`).
- **Four templates and a partial:** a layout, the index, a post, a page, and `menu.html`, written into the site folder's `templates/` when missing and kept once changed, as `style.css` is today.
- **An `assets/` folder** beside them is copied to the site as it is.

### Other pages (§ 8)

- A **Pages** category, picked in Site. Each of its items is a page at `/<slug>.html` ("About" → `/about.html`), its title and body as a post's (§ 6), in the page template; not in the index or the feeds.
- The default menu lists the pages alphabetically; the person writes `menu.html` to choose.

### Several feeds (§ 9)

- One site with several feeds: each **child category of Posts** is a feed with its own index page and feeds under `/<slug>/` (`index.html`, `rss.xml`, `feed.json`). The site's main index and feeds hold every post. A post under two children is in both their feeds, once in the main one. A new feed is a new child in the category manager.

### The note editor (§ 5)

- An extra: headings, list markers and task boxes stand out when drawn (through the core's Markdown reader, so editor and site agree); ENTER on a list line continues the list (`- `, `- [ ] `); a key toggles a task box between `[ ]` and `[x]`. What is stored does not change. Links to other pages are the Zettel links (R73b), already there.

### Not now (§ 11)

- Agendum keeps its own publisher; no third-party static site generator. **Parked** as an idea: export the posts as Markdown with front matter (title, date, slug), for Hugo, Zola or Eleventy if one is ever wanted.

### Dogfooding (§ 12)

- The project's site (`jamting.github.io/agendum/`) built with the publisher, as the last step: the front page a Page, the devlog a feed, the menu linking the guide, the manual and the API docs, which stay copied in by `mix agendum.pages`. CI needs a headless `mix agendum.publish FILE` (beside the roadmap's headless read command).

## The steps (§ 13)

One step per release, each tried by the owner before the next.

1. [x] The settings split: the Publish submenu, the Site box, Upload in the preferences (a format change: the upload leaves the file); v0.79.0, format 47. Feeds joins the submenu with step 5
2. [ ] A post's metadata: the `# Heading` title, a future When waits, the modified date stamped at publish, the slug made once and the address pattern
3. [ ] Templates and assets: the Mustache-style reader, the default templates, `assets/`
4. [ ] Pages: the Pages category, the menu partial
5. [ ] Several feeds: Posts' children as feeds, the Feeds list and each feed's box
6. [ ] The note editor for Markdown: highlighting, list continuation, the task-box toggle
7. [ ] Dogfooding: `mix agendum.publish`, the project's site built with it
