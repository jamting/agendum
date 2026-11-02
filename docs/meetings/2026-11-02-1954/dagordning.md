# Agenda (dagordning) for the panel meeting, 2026-11-02-1954

**Called by:** the owner **Place:** Owl's house, the Hundred Acre Wood **Wished date:** 2026-11-02

The owner asked for a meeting to evaluate the work on the publishing features, the publisher's round 1 (v0.79.0–v0.85.0): omissions, possible improvements, and what is good; and, added at the adoption, to formulate a round 2. There were no thoughts under Next meeting in the owner's project file. An item on the guide and the manual was struck at the adoption.

## § 1 Opening of the meeting
## § 2 Election of a chair, a secretary and two approvers of the minutes
## § 3 Adoption of the agenda
## § 4 The previous minutes: decisions followed up

## Items to discuss

### § 5 What went well

Seven steps were built in one day, each through the whole checklist: questions first, failing tests, the gate, two fuzz runs, a code review, a smoke test. What is worth keeping as a habit?

### § 6 Omission: images in posts

The site's `assets/` folder goes out with the pages, but a post cannot show an image from it: the Markdown reader takes an image only by a whole web address.

### § 7 Improvement: the index holds every post in full

The index, and each feed's index, show every post in full, so they grow with every post; the feeds carry every post too. An archive, or paging?

### § 8 Improvement: future posts need a manual publish

A post with a When still to come waits until the person publishes on or after its day; Agendum has no scheduler. `agendum --publish FILE` now exists.

### § 9 Tidiness: R74 is one rule of about 2,900 words

The micro-blog's rule in SPEC grew with each step. Should it be split into sub-rules?

### § 10 Left over: the list-and-box pattern for the RSS Feeds and the Calendars

The last meeting (2026-11-02-1255, § 10) decided that the Feeds list's pattern should later replace how the RSS Feeds and Calendars change their settings. When?

### § 11 Ways of working: each step's code review found about ten bugs

Seven reviews found about 70 real problems, after the gate had passed. What does that say about how features are built?

### § 12 Small: the devlog's templates and git

Publishing writes `templates/` into `pages/devlog/`, untracked; the site no longer serves it. Commit it, or ignore it?

### § 13 Round 2 of the publisher

From the items decided above and any more the panel proposes: a round 2, in an order.

## Any other business
## Next meeting
## Closing of the meeting
