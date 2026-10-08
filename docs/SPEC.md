# Agenda — behaviour specification

What we are cloning, distilled from US patent 5,115,504 ("Information
Management System", Belove, Kapor, Kaplan et al., Lotus 1992) and the Lotus
Agenda 2.0 manuals. Rules are numbered so tests and commits can refer to them.
✅ = implemented and tested, ⏳ = planned (see `ROADMAP.md`).

## 1. Concepts

| Concept | Meaning | Code |
|---|---|---|
| **Item** | A free-form piece of text (up to a few lines), with an optional note. Exists independently of categories. | `Core.Item` |
| **Category** | A named node in one hierarchy rooted at **MAIN**. | `Core.Category` |
| **Link / assignment** | An independent many-to-many link between an item and a category (the patent's "link structures"). | `Core.Links` |
| **View** | A saved arrangement: **sections** (each headed by a category) and **columns** (each headed by a category). | `Core.View` |
| **Date category** | Entry, When, Done: categories whose membership is an item's date. | `Database.date_field/2` |

## 2. Data model rules

- **R1 ✅ Many-to-many.** An item may be assigned to any number of
  categories and a category may hold any number of items. Links are
  reachable from both sides (patent FIG. 2, 3B).
- **R2 ✅ Hierarchy.** Categories form a single tree under MAIN, with
  ordered children (patent FIG. 1). MAIN, Entry, When and Done cannot be
  deleted or renamed.
- **R3 ✅ Subsumption.** An item assigned to a category is also a member of
  every ancestor of that category (patent FIG. 4: I4 in C9 is also in C5, C2,
  C1). This is computed, not stored.
- **R4 ✅ Deletion side effects.** Deleting a category deletes its subtree
  and all its links. Items lose the memberships they had only through it
  (patent: deleting C5 removes I6 from C2 and C1). The category also
  disappears from view sections and columns.
- **R5 ✅ Every item is in MAIN.**
- **R6 ✅ Date categories.** Entry is set when an item is created, When is
  set by typing a date in a When column, and Done is set by F4.
- **R7 ✅ Mutual exclusion.** A category can declare its children mutually
  exclusive (e.g. Priority: High/Medium/Low). Assigning an item to one child
  removes it from the others and their subtrees. This applies at every
  exclusive level above the target. (Patent "negative links", FIG. 6;
  Agenda's "mutually exclusive" category property.)
- **R8 ✅ Category links.** A category can pass its items on to other
  categories (`also_assign`, patent FIG. 6). This applies transitively and is
  safe with cycles.
- **R9 ⏳ General negative links.** Two arbitrary categories that may not
  share an item.

## 3. Automatic assignment

- **R10 ✅ Text matching.** When an item is entered or edited, it is
  assigned to every category whose name (or short name) appears in its
  text as whole words, ignoring case and extra whitespace (patent: "Meet with
  John Smith on Tuesday" → Meetings + John Smith). Categories can opt out
  (`match_name: false`).
- **R11 ✅ Explicit wins.** An automatic match that conflicts with an
  existing explicit assignment (R7) is dropped.
- **R12 ✅ Ambiguity (patent claim 7).** If two matches conflict with each
  other, prefer the category that the adjacent item in the view belongs
  to (previous, then next). Otherwise prefer the category created first.
- **R13 ✅ Recalc.** The user can re-run automatic assignment for all items
  (Category ▸ Recalc).
- **R14 ⏳ Date parsing from item text** ("call Bob next Friday" → When).
- **R15 ⏳ Conditions and actions** (Agenda 2.0 assignment conditions,
  e.g. "items in Calls with When < today → Overdue").

## 4. Working through views

All modification happens in the context of a view (patent claims 1, 3, 4, 6).

- **R20 ✅ Sections.** A section lists every item that is a member of its
  head category (including via subcategories), in item order. Items
  that are members only through a subcategory are "inherited" and can be
  hidden.
- **R21 ✅ Entering an item.** Typing under a section creates an item
  assigned to the section's category (unless it is MAIN), placed after the
  highlighted item. Automatic assignment (R10–R12) then runs, using the
  neighbouring items in the section for R12.
- **R22 ✅ Columns (claim 2).** A column headed by category *C* shows, for
  each item, the descendants of *C* the item is assigned to. A childless
  head shows `*` when the item is a member. A date column shows the date.
- **R23 ✅ Typing in a column (claims 3, 6).** Text typed in a column cell is
  matched against the column head's descendants: exact name, then unique
  prefix. If nothing matches, a new child is created. Typing replaces the
  current entry; INS adds another one. Date columns parse dates.
- **R24 ✅ DEL** on an item removes it from the section's category (and its
  subtree). The item stays in the file. On a column entry DEL unassigns it,
  and on a section head DEL removes the section from the view.
  **DISCARD** (ALT-F4) deletes the item from the file.
- **R25 ✅ Editing the structure from a view.** Rename a category by editing
  a section head or column entry (F2). Add sections (ALT-D/ALT-U) and columns
  (ALT-R/ALT-L) with existing or new categories.
- **R26 ✅ Move (ALT-F10).** Moving an item to another section reassigns it
  from the old section's category to the new one and reorders it.
- **R27 ✅ View options.** Hide done items, empty sections, inherited items.
- **R28 ⏳ Filters and sorting** per section; **R29 ⏳ numeric columns**.

## 5. User interface (Agenda 2.0 conventions)

Screen: a title bar (file, view, mode indicator such as READY / EDIT /
MENU / CAT MGR), a two-line control panel (menus, prompts, messages), the
body, and a function-key bar.

| Key | View | Category manager |
|---|---|---|
| F1 | Help | |
| F2 | Edit item / section head / column entry | Rename |
| F3 | Choices (category box for a column; assignment profile) | |
| F4 | Done | |
| F5 | Note | Note |
| F6 | Properties (item: assignment profile; section: category properties) | Properties |
| F7 | Mark | Promote |
| F8 | View manager | Demote |
| F9 | Category manager | Return |
| F10 or `/` | Menu (File Item Category View Print Quit) | Return |
| ALT-F4 | Discard | Discard |
| ALT-F10 | Move item | Move under a new parent |
| ALT-D/U/R/L | Add section below/above, column right/left | |
| INS | New item / additional column entry | New category below |

Category manager navigation (from the manual): ↑/BACKSPACE, ↓/ENTER,
HOME = parent, END = last of family, CTRL-PGUP/PGDN = previous/next
sibling, CTRL-HOME/END = first/last.

Terminal compatibility extras (not in the original): ESC+digit = F-key,
ESC+shifted digit = ALT-F-key, CTRL-S save, CTRL-Q/CTRL-C quit, CTRL-D discard.

- **R30 ✅ Undo/redo** (CTRL-Z / CTRL-Y, menu Undo/Redo). Every action that
  changes the database is one undo step. Undo returns to the view and item
  where the change happened. It is available in views and in the category and
  view managers, but not while typing. Undoing back to the last save clears
  the "modified" marker. History holds 100 steps.

## 6. Out of scope for now

Macros, printing to a printer, import/export of structured files,
networking/file reservations, the Metro accessories.
