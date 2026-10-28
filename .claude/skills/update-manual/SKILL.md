---
name: update-manual
description: Bring the Agendum manual (docs/manual/, Owl teaching Rabbit) up to date with features added since it was last updated, re-capturing its screens from the program. Use only when the user asks to update the manual.
---

# Update the manual

The manual (`docs/manual/index.html`) is the long companion of the user guide (`docs/guide/`, see the `update-guide` skill): the important features in depth, the rest in brief, told as an afternoon in which Owl, who knows Wol's Agendum well, teaches Rabbit, who is stressed by his lists. It is updated on request only, never as part of a feature.

`index.html` is **generated**; never edit it by hand. The sources are in `docs/manual/src/`:

| File                    | What it is                                                                    |
| ----------------------- | ----------------------------------------------------------------------------- |
| `template.html`         | The text, with `{{screen}}` placeholders                                      |
| `capture_screens.exs`   | Opens Rabbit's file (`Agendum.Sample.rabbit/1`) and drives the real TUI to capture each screen, as text and as a picture (macOS) |
| `screens/*.txt`         | The captured screens as text (committed, so screen changes show in diffs)     |
| `../screens/*.png`      | The same screens as the pictures the manual shows, all the same size (committed) |
| `build.py`              | Fills the placeholders and writes `../index.html`; fails on broken links      |
| `../manual.css`         | Dialogue styles; imports `../guide/guide.css` (the knobs, fonts, margin notes) for everything else |

## 1. Find what changed since the last update

```sh
last=$(git log -1 --format=%H -- docs/manual/index.html)   # the page itself: commits touching only the sources or the CSS are not updates
git log --oneline "$last"..HEAD
git diff "$last"..HEAD -- docs/SPEC.md docs/KEYBOARD.md docs/ROADMAP.md docs/SCREENS.md
```

Read the new or changed SPEC rules and KEYBOARD.md rows; they are the source of truth. Check menu paths against `Agendum.TUI.Menu.tree/0`, keys against the F1 help in `Agendum.TUI.Render.Help`, and box names and rows against the program (the captures show them). Never describe a key or a menu path you have not checked.

## 2. Re-capture the screens

```sh
MIX_ENV=test mix run docs/manual/src/capture_screens.exs
git diff --stat docs/manual/src/screens
```

The script checks that each key sequence reaches the box it should and stops with the capture's name if not; fix the sequence (the program changed). Look at every changed screen: the text around it may now be wrong. For a new screen, add a capture to `capture_screens.exs` (with the box type it must show) and a `{{name}}` placeholder in the template: every screen is shown whole, at the same size (meeting 2026-10-28-6, § 5). Keep screens 80 columns wide, captured on Monday 2026-10-12 at 10:15 in Rabbit's file, so dates in the text stay true.

## 3. Edit the template

- **Depth by importance.** Items, categories, automatic filing, views and dates get chapters with detail; features most people need less often get a sentence in an "In brief" box (`<div class="brief">`) or in the chapter "A few more things". A new major area may earn its own chapter (add it to `nav.toc`; keep existing anchors stable; links that name a chapter by number need renumbering).
- **From the user's side.** What it is for, how to reach it, what to expect. No internals, no R-numbers, no module names.
- **The story.** Owl is skilled and a little grand; Rabbit is busy, anxious, proud of being Organised, and learns quickly. Their dialogue (`<div class="talk">` with `<p class="owl"><b>Owl.</b> …</p>` and `<p class="rabbit"><b>Rabbit.</b> …</p>`) should teach: Rabbit asks or stumbles, Owl explains why, and the example uses Rabbit's file (garden, Notices, friends-and-relations, Small, Tigger). Use dialogue where it clarifies, not on every point. Narration goes in `<div class="story">`.
- **Every chapter has a subtitle** under its `<h2>`, in the books' style: `<p class="in-which">In Which Rabbit Teaches Agendum to Water the Carrots</p>`, title case, naming something that happens in the chapter, preferably from its Owl and Rabbit dialogue. A new chapter gets one; a chapter whose story changes may need a new one. Subtitles are not in the contents list.
- **Pooh lore stays light and tasteful**: names and small allusions from A. A. Milne's books, no quotations, no Disney or E. H. Shepard images, only our own simple SVG drawings.
- **Margin notes** add variety: a side remark, a cross-reference or a tip as `<aside>…</aside>` (or `<aside class="tip">`) just before the paragraph it belongs to; in the margin on a wide window, in the text on a narrow one. Never for anything the reader must not miss.
- Keep the reference chapter (keys, menu map) complete and in step with the F1 help.

## 4. Build and check

```sh
python3 docs/manual/src/build.py
```

It reports how many screens it inlined and fails on links without anchors. Read the changed parts of `index.html` once more, then summarise the changes for the user and ask before committing (one commit, e.g. "Update the manual").
