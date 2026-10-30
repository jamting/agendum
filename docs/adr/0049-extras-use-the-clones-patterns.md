# ADR 0049 — The extras use the clone's patterns

**Status:** accepted · 2026-10-26 (meeting 2026-10-26-2234, §§ 5–8)

## Context

The extras (ADR 0043) were built on 2026-10-16/17, before the clone's bar was raised: the `feature` checklist, settings boxes drawn from `Template` layouts and checked against Agenda in DOSBox, and the fuzz walks crossing every box. The clone's boxes were brought up to that bar while the extras were frozen to bug fixes, and nobody lifted them. The meeting found two lags with that one cause. In robustness, the worst findings of the code review were in the extras (a Markdown loop, a crash at every start, an upload stalling the program), and the v0.69.1 crash sat in `App`, out of reach of the pure tests and the fuzz walks. In conventions, the extras' boxes improvised where the clone's follow Agenda: Publish's Posts and Drafts are typed, not picked from the category list, so a typo makes a new category; Feeds and Calendars change a feed's settings by letter keys and one-line prompts, not a properties box; paths are typed, not chosen from the file list. The clone had Agenda as its guide; the extras had none.

## Decision

- **An extra's screens use only patterns the clone already has**: a category field offers the category list (SPACE, F3), a choice goes round with SPACE, a thing's settings are a properties box drawn from a `Template` layout with field help on the bottom line, a file is chosen from the file list (`select_file.ex`), commands have Agenda's names and unique first letters. No interaction style of its own, so that someone who knows Agenda knows the extras too (the chair, § 8: "not to confuse old users").
- **The patterns are written down** in `docs/UI_GUIDELINES.md`, drawn from the clone's boxes and Agenda's manual (User's Guide 2-17, Appendix A), each rule marked "(as Agenda)" or "Our choice" as SPEC's rules are. A rule a test can check gets a test, as the menu test checks first letters.
- **No new extras** until the existing ones meet the guidelines (ROADMAP, In order 4–5); Wol stays on its shelf until then.
- **New patterns wait for Beyond Agenda**: an idea that would be new to Agenda's users, such as settings as views (the feeds and calendars as a view of their own, a window onto their structs, ADR 0048), is a later Beyond Agenda item, chosen on purpose, not slipped in with an extra.

## Consequences

- The extras' rework is wiring, not design: parts that exist, a handful of feature commits, and the boxes join the box tests and the fuzz walks the clone's have.
- A review can hold an extra's box against the guidelines, as the clone's boxes are held against Agenda's (`docs/reference/agenda_boxes.json`).
- A new pattern, when it comes, is a decision of its own (a meeting or an ADR), and goes into the guidelines before it is built.
