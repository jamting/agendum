---
name: update-guide
description: Bring the end-user guide (docs/guide/index.html, the short guide with Piglet) up to date with features added since it was last updated. Use only when the user asks to update the guide; the long manual has its own skill, update-manual.
---

# Update the user guide

The guide (`docs/guide/index.html` + `docs/guide/guide.css`) is a single static
page for end users. It is updated on request only, never as part of a feature.

## 1. Find what changed since the last update

```sh
last=$(git log -1 --format=%H -- docs/guide)
git log --oneline "$last"..HEAD
git diff "$last"..HEAD -- docs/SPEC.md docs/KEYBOARD.md docs/ROADMAP.md
```

Read the new or changed SPEC rules (R-numbers) and KEYBOARD.md rows; these
are the source of truth for keys, menu paths and behaviour. Check menu paths
against `Agenda.TUI.Menu.tree/0` and keys against the F1 help in
`Agenda.TUI.Render` before writing them down.

## 2. Edit the guide

- Describe features briefly, from the user's side: what it is for, which
  keys or menu path, one or two sentences. No internals, no R-numbers.
- Put each feature in the chapter it belongs to; add a chapter (and a link in
  the `nav.toc` contents) only for a new area. Keep the anchors stable.
- Update the keyboard reference table (chapter "Keyboard reference") for new
  keys, with the Mac-friendly alternative.
- Remove the feature from "Still to come" when it has arrived.
- Keep the running story: Piglet planning Eeyore's birthday party, in
  `<div class="story">` boxes. Pooh lore stays light and tasteful (names,
  small allusions from A. A. Milne's books); no quotations, no Disney or
  E. H. Shepard images. Only our own simple SVG drawings.
- Screens are `<pre class="screen">` mock-ups; keep them about 80 columns.
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

Then summarise the changes for the user and ask before committing (one
commit, e.g. "Update the user guide").
