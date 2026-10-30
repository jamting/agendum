---
name: update-guide
description: Bring the end-user guide (docs/guide/index.html, the short guide with Piglet) up to date with features added since it was last updated. Use only when the user asks to update the guide; the long manual has its own skill, update-manual.
---

# Update the user guide

The guide (`docs/guide/index.html`) is a single static page for end users. Its look is `docs/guide/guide.css`, shared with the manual, with its knobs at the top (fonts in `docs/fonts/`; meeting 2026-10-28-2214, § 5); `docs/guide/place.js` shows the reader's chapter in the contents and remembers their place. It is updated on request only, never as part of a feature.

## 1. Find what changed since the last update

```sh
last=$(git log -1 --format=%H -- docs/guide/index.html)   # the page itself: commits touching only the sources or the CSS are not updates
git log --oneline "$last"..HEAD
git diff "$last"..HEAD -- docs/SPEC.md docs/KEYBOARD.md docs/ROADMAP.md
```

Read the new or changed SPEC rules (R-numbers) and KEYBOARD.md rows; these are the source of truth for keys, menu paths and behaviour. Check menu paths against `Agendum.TUI.Menu.tree/0` and keys against the F1 help in `Agendum.TUI.Render.Help` before writing them down.

## 2. Edit the guide

- Describe features briefly, from the user's side: what it is for, which keys or menu path, one or two sentences. No internals, no R-numbers.
- Put each feature in the chapter it belongs to; add a chapter (and a link in the `nav.toc` contents) only for a new area. Keep the anchors stable.
- Update the keyboard reference table (chapter "Keyboard reference") for new keys, with the Mac-friendly alternative.
- Remove the feature from "Still to come" when it has arrived.
- **Every chapter has a subtitle** under its `<h2>`, in the books' style: `<p class="in-which">In Which Piglet Flips Forward to Make Sure Nothing Clashes with Christmas</p>`, title case, naming something that happens in the chapter, preferably from its Piglet story. A new chapter gets one; a chapter whose story changes may need a new one. Subtitles are not in the contents list.
- Keep the running story: Piglet planning Eeyore's birthday party, in `<div class="story">` boxes. Pooh lore stays light and tasteful (names, small allusions from A. A. Milne's books); no quotations, no Disney or E. H. Shepard images. Only our own simple SVG drawings.
- Screens are pictures, `<img class="screen" src="screens/NAME.png" width="720" height="400" alt="Agendum's screen: …">`, the alt text the screen's control panel. Each is a mock-up of Piglet's file written by hand in `docs/guide/src/screens/NAME.txt` (80 columns; `<span class="t">` white on blue for the control panel and key bar, `<span class="h">` a section head, `<span class="c">` the highlight; the last two lines are the key bar) and drawn with `python3 docs/guide/src/draw_screens.py` (macOS). Commit the `.txt` and the `.png`.
- A side remark, a cross-reference or a tip can be a margin note: `<aside>…</aside>` (or `<aside class="tip">`) just before the paragraph it belongs to. It sits in the margin on a wide window and in the text on a narrow one. Use them for variety, not for anything the reader must not miss.
- **The version line** (meeting 2026-10-30-2020, § 6): the title header ends with `<p class="written-for">Written for Agendum X.Y</p>`, the major and minor numbers of `version` in `mix.exs` at the time of this update (`0.72` for 0.72.4), so a reader sees how fresh the guide is. Set it on every run, even when little else changed.
- Minimal markup; styling lives in `guide.css` (light and dark).

## 3. Check

```sh
cd docs/guide && python3 - <<'EOF'
import re
s = open('index.html').read()
links = set(re.findall(r'href="#([\w-]+)"', s)); ids = set(re.findall(r'id="([\w-]+)"', s))
print("missing anchors:", links - ids)
EOF
```

Then summarise the changes for the user and ask before committing (one commit, e.g. "Update the user guide").
