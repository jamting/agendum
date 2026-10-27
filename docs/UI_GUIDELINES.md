# UI guidelines

**Status:** adopted 2026-10-27, the owner having answered its questions (below); drafted 2026-10-26 night. Written for meeting 2026-10-26-6 (§§ 5–8) and ADR 0049.

The conventions the clone's screens and boxes follow, written down so that the extras, which have no Agenda to copy, follow them too. Only patterns the clone already has are here (ADR 0049; the chair, meeting 2026-10-26-6, § 8: "not to confuse old users"). Each rule is one line: what is true, then "(as Agenda)" with where Agenda says or shows it, or "Our choice"; then where it is seen in our code. **Test:** names the test that checks it today; **Could test:** is a suggestion, not built.

When a rule here and a box disagree, the box is the bug, unless the rule is wrong; then the rule is changed first, at a meeting or in an ADR, and the box after.

## 1. Settings boxes

- **1.1** A box of settings is drawn from a layout written as it looks on screen, its fields `[name   ]` placeholders, which are also the cursor's order. Our choice (CLAUDE.md, Conventions); `Agendum.TUI.Boxes.Template`, `customize_box.ex`. **Test:** `box_guidelines_test.exs` (every settings box in the registry calls `Template`).
- **1.2** The box's layout follows Agenda's box of the same name where there is one: labels, order, rows. (as Agenda: `docs/reference/agenda_boxes.json`, captured in DOSBox) **Test:** `test/agendum/tui/agenda_boxes_test.exs`.
- **1.3** ↑ ↓ → ← TAB SHIFT-TAB HOME END move between settings, by the grid of the layout. (as Agenda: User's Guide 2-16) `Agendum.TUI.Boxes.BoxNav`, `Box.settings_keymap/1`.
- **1.4** ENTER leaves the box keeping the changes; ESC leaves it putting them back, and the whole box is one undo step. (as Agenda: User's Guide 2-18) `Agendum.TUI.Boxes.BoxCancel`, ADR 0030. **Test:** `box_cancel_test.exs`.
- **1.5** The bottom edge says how the box ends: "Press ENTER when done, ESC to cancel" for a box of settings. (as Agenda: SPEC § 5) `use Box, finish: :done`.
- **1.6** A setting with "..." opens a second box of settings, with SPACE (or F2). (as Agenda: User's Guide 2-17) `Agendum.TUI.Boxes.BoxEdit`. **Test:** `box_keys_test.exs` ("on a ... field opens it").
- **1.7** F8 (DEFAULT) puts the highlighted setting back to its default, ALT-F8 (DFLTALL) all of them; a setting without a default is left alone, without a word. (as Agenda: User's Guide 2-17) `Agendum.TUI.Boxes.BoxDefaults`. **Test:** `box_keys_test.exs` ("F8 on a setting without a default").
- **1.8** A box's settings live in the box until ENTER, or are applied inside and put back by ESC; either way the screen behind is drawn as it was until the box closes. (as Agenda, checked 2026-10-22; ADR 0030) `BoxCancel.behind/2`.
- **1.9** Every setting has a help text, shown in the control panel while it is highlighted: what it does, then the keys that change it, in two lines at 80 columns. (as Agenda: screenshots 130–143, its F1 SETTING/DESCRIPTION tables) `Agendum.TUI.Boxes.FieldHelp`. **Test:** `field_help_test.exs` ("fits the control panel's two lines"); `box_guidelines_test.exs` walks every settings box in the registry (2026-10-27).

## 2. Choosing values

- **2.1** On a setting with choices: SPACE goes to the next choice, round the list. (as Agenda: User's Guide 2-17) `Box.settings_keymap/1` (`:change`).
- **2.2** On a setting with choices: the first letter of a choice picks it (the next one with that letter). (as Agenda: User's Guide 2-17) `Agendum.TUI.Boxes.BoxChoices`. **Test:** `box_choices_test.exs`.
- **2.3** On a setting with choices: F3 (CHOICES) lists them in a box titled "Choices"; ↑ ↓ HOME END highlight, ENTER takes one as one change, ESC leaves it. (as Agenda: User's Guide 2-17/2-18, checked 2026-10-25) `ChoiceListBox`, `use Box, choices: true`. **Test:** `box_choices_test.exs`.
- **2.4** A setting that holds a category takes a typed name of a new or existing category (with completion as typed), or F3 for the category list to pick from. (as Agenda: User's Guide 3-17, "Type the name of a new or existing category. Press F3 (CHOICES) and select an existing category"; checked 2026-10-25) `column_add_box.ex:7`, `section_box.ex:7`, `Typing.Completion.box_field?/1`.
- **2.5** Where a category may not be new (a date category, a sort key), SPACE or F3 opens the category list and typing is not offered. (as Agenda, e.g. Datebook settings) `datebook_settings.ex:11`, `CategoryScreens.open_picker/3`.
- **2.6** On a field that holds a category, F6 (PROPS) opens that category's Category Properties. (as Agenda) `docs/KEYBOARD.md` (box fields that hold a category). **Test:** `box_keys_test.exs` ("in Column Properties opens the column head's Category Properties").
- **2.7** A prompt for a file name offers F3 (CHOICES): the Select File box, with the folder's files of the prompt's kinds. (as Agenda: User's Guide chapter 2, opening a file, and 22-4) `Agendum.TUI.Boxes.SelectFile` (its `@extensions`).
- **2.8** A value too wide for its field is cut with "…" in the box, never wraps. Our choice; `Template.render/3`.

## 3. Typing in fields

- **3.1** On a setting without choices, a character starts typing in it, replacing the value; ENTER hands it to the box, ESC stops the typing and stays in the box. (as Agenda: User's Guide 2-17, "Type your own choice and press ENTER") `Agendum.TUI.Boxes.FieldTyping`.
- **3.2** F2 (EDIT) edits the value the setting has, the cursor after it; on a list of choices it does nothing. (as Agenda: User's Guide 2-17, checked 2026-10-25) `Agendum.TUI.Boxes.BoxEdit`. **Test:** `box_keys_test.exs`.
- **3.3** While typing, the key bar is Agenda's editing bar and the hint line shows. (as Agenda; ADR 0045, amended) **Test:** `box_key_bar_test.exs` ("typing in a field").
- **3.4** Dates offered for editing are ISO 8601, the parser's own; dates shown are in the file's date format. Our choice (CLAUDE.md, Conventions); `DateParser.format/1`, `DateFormat.date/2`.

## 4. Lists of things, and their properties

- **4.1** A list of things the person keeps (views, macros) is a manager: ↑ ↓ PGUP PGDN HOME END move, typing a name highlights the thing starting with it. (as Agenda: User's Guide 9-5) `view_manager.ex`, `macros.ex`.
- **4.2** In a manager, INS adds one (asking its name), DEL removes it (asking first when it holds something), F2 renames or edits it. (as Agenda) `view_manager.ex:156`, `macros.ex:167`.
- **4.3** In a manager, F6 (PROPS) opens the highlighted thing's properties: a box of settings, as 1. (as Agenda: the View Manager's F6, R78; the macro manager's F6) `docs/KEYBOARD.md` (lines on the view manager and the macro manager).
- **4.4** A thing's settings are changed in its properties box, not by keys of their own in the list. Our reading of Agenda's managers (to check in Agenda for a manager with a letter command).
- **4.5** ENTER in a manager does the thing's main action (show the view, run the macro); ESC goes back. (as Agenda) `view_manager.ex` (`finish: :done`).
- **4.6** A list longer than the box scrolls, keeping the highlight in sight, by whole entries. Our choice; `Agendum.TUI.Boxes.Scroll`.

## 5. Commands and menus

- **5.1** Every level of the menu has unique first letters, and a letter chooses its entry. (as Agenda) **Test:** `test/agendum/tui/menu_test.exs`.
- **5.2** Commands take Agenda's names where Agenda has the command. (as Agenda: User's Guide, Appendix A) `Agendum.TUI.Menu.tree/0`.
- **5.3** Every command a key runs in a place has an id, a name and a summary in that place's keymap and command list, from which the F1 help is made. Our choice (R65, ADR 0033) `c:Box.keymap/1`, `c:Box.commands/1`. **Test:** `help_coverage_test.exs`.
- **5.4** Function keys carry the commands, as Agenda's; a command on INS, HOME or END also has a CTRL key for Mac keyboards. (as Agenda, ADR 0032; CLAUDE.md, Conventions) `docs/KEYBOARD.md`. **Test:** `keymap_test.exs` ("docs/KEYBOARD.md names every named key").
- **5.5** An action that loses something asks first, in a yes/no question in the control panel. (as Agenda) `Update.Prompts.ask/3`.

## 6. Key bar and help

- **6.1** The key bar has Agenda's ten slots, made from the place's keymap; a box's bar is fixed per field. (as Agenda; ADR 0045 and its amendment) `Agendum.TUI.Render.KeyBar`. **Test:** `box_key_bar_test.exs`, `agenda_boxes_test.exs`.
- **6.2** A box's hint line, where it has one, is made from the same key list as its bar (`Box.hint/2`), never written by hand, so the two cannot disagree. Our choice; `box.ex:232-238`. **Test:** `box_guidelines_test.exs` (no literal key list in a box's code; the boxes that still have one listed with why).
- **6.3** F1 in a box shows its help topic: what the box is for and how it is worked, in Agenda's terse layout. (as Agenda's help; approved 2026-10-26) `c:Box.about/2`, `Box.default_about/3`.

## 7. Messages

- **7.1** Where Agendum meets a situation Agenda had, the message is Agenda's words (adapted where Agendum differs). (as Agenda: `docs/reference/agenda_messages.json`) `Agendum.TUI.Messages`. **Test:** `agenda_messages_test.exs`.
- **7.2** A core error is an atom; the TUI turns it into the message, in one place per situation. Our choice (CLAUDE.md, Conventions); `Agendum.TUI.Messages.text/1`.
- **7.3** Messages, prompts and help are written plainly, terse, in Agenda's tone; a Hundred Acre Wood touch only where it is natural. Our choice (help topic tone, 2026-10-26).
- **7.4** A long action in the shell says it is under way in the control panel ("Reading …") and its outcome when done; it never stops the keys. Our choice (v0.68.4: publishing in the background) `Update.Results`.
- **7.5** An extra's messages live in a module beside it (`Agendum.TUI.Extras.<Extra>.Messages`), one per error atom, never written in the box; removing an extra takes its messages with it. Our choice (the owner, 2026-10-27: separation for modularity). **Test:** `box_guidelines_test.exs` (no message written out in an extra's box).

## The extras against the guidelines

Each gap in `lib/agendum/tui/extras/`, the rule it breaks, and the existing part that would mend it. The first five were found at meeting 2026-10-26-6, § 6; the rest by reading the boxes for this draft. "Mend" is what the rework does (ROADMAP, Beyond Agenda), as the owner settled it on 2026-10-27 (below).

| # | Box | Gap | Rule | Existing part that would mend it |
| --- | --- | --- | --- | --- |
| 1 | Publish | Posts and Drafts can only be typed, without completion; no F3 list, so a typo makes a new category under MAIN | 2.4 | Done 2026-10-27: completion, F3 or SPACE the list, DEL leaves Drafts empty (`Box.category_fields/1`, `Box.picked/4`) |
| 2 | Feeds, Calendars | A feed's settings are changed by letter keys in the list (F how often, K days kept, A how far ahead), each press going one step round, with no way back and no list | 4.3, 4.4, 2.1–2.3 | A properties box per feed and calendar on F6 (`Template` layout: Name, Address, Read every, Keep / Read ahead, Last read), whose choices get SPACE, a letter and F3 from `BoxChoices` |
| 3 | Feeds, Calendars | Commands on plain letters (R, F, K, A, I, E) are not on the key bar, which shows function keys only, so the bar does not show them | 5.4, 6.1 | Once 2 is done, F6 Props carries the settings; Read now stays on ENTER; OPML import and export go to the menu (File ▸ Transfer, as now) |
| 4 | Feeds, Calendars | The hint lines at the bottom are written by hand, apart from the key list (`feeds_box.ex`, `calendars_box.ex`, `content/4`) | 6.2 | `Box.hint/2` from `keys/2`, or no hint line, as the clone's managers |
| 5 | Publish | Folder is a typed path, with no list to choose from; the meeting's note that OPML import and export are typed paths was wrong: their prompts offer F3 already (`select_file.ex`, `import_opml`, `export_opml`) | 2.7 | Done 2026-10-27: F3 lists the folders, `./  (this folder)` first (`SelectFile.open_folder/3`) |
| 6 | Publish | SPACE on a text field starts editing it; in the clone's boxes SPACE goes round a setting's choices, and F2 edits | 2.1, 3.2 | Drop SPACE's editing (F2 already does it); SPACE only on Upload |
| 7 | Publish | Upload's choices (None, rsync, SFTP) go round with SPACE, but no letter picks one and F3 lists nothing, as the box is not `choices: true` | 2.2, 2.3 | `use Box, finish: :done, choices: true`, as the clone's settings boxes |
| 8 | Publish | No F8 (DEFAULT): Folder's default ("site") and Title's (the file's name) cannot be put back | 1.7 | Done 2026-10-27: F8 and ALT-F8 back to a new blog's settings |
| 9 | Publish | Error messages are written in the box (`publish_box.ex`, `publish/2`), not in `Messages` | 7.2 | Done 2026-10-27: `Agendum.TUI.Extras.Publish.Messages`, and the feeds' and calendars' too |
| 10 | Feeds, Calendars | Subscribing asks two prompts in a row (the address, then the name), where the clone adds a thing with one prompt for its name, its settings after in its box | 4.2 | Two prompts kept (the owner, 2026-10-27), the name's prompt filled in with the feed's own title |
| 11 | Feeds, Calendars | The bottom edge says nothing (`finish: :none`); the clone's managers say how the box ends | 1.5, 4.5 | `finish: :return` (the Publish preview's) or `:done`, as the view manager |
| 12 | All four | Not in `agenda_boxes_test.exs` (they have no Agenda box) and not in the field-help walk, so no test holds them to the rules above | 1.9, 6.1 | Done 2026-10-27: `box_guidelines_test.exs` checks 1.1, 1.9 and 6.2 over the box registry; Feeds, Calendars and the Publish preview are its listed 6.2 exceptions until reworked |
| 13 | Feeds, Calendars, Publish | No rule in SPEC for how the boxes look; R45, R74 and R75 say what they do | 1.2 | SPEC rules for the reworked boxes, each "Our choice" pointing here |

## The owner's answers (2026-10-27)

- **Feeds and Calendars as managers**, the Macros manager the model: INS subscribes, F2 renames, F6 opens a feed's or calendar's properties box (its settings, with SPACE, a letter and F3), DEL unsubscribes, ENTER reads the highlighted one now. **ALT-ENTER reads them all** (the owner asked for Shift-ENTER, which no terminal tells from ENTER; ALT-ENTER reaches Agendum as its own key, `keys.ex`, and was unused). The letter keys F, K, A and R go: a habit change, accepted. OPML import and export stay on the menu (File ▸ Transfer).
- **Subscribing: two prompts**, the address, then the name, the second filled in with the feed's own title.
- **Publish's Folder is chosen from the file list** (`SelectFile`, taught to accept a folder).
- **Each extra keeps its own messages, beside it** (`Agendum.TUI.Extras.Feeds.Messages`, `…Calendars.Messages`, `…Publish.Messages` in `tui/extras/`); `Agendum.TUI.Messages` stays Agenda's words. The owner: keep the extras separate as much as possible, for modularity (rule 7.5).
- **All three "Could test" items are built** with the rework (1.1, 1.9, 6.2), over the box registry, so they cover the extras by themselves. Built 2026-10-27 (`test/agendum/tui/box_guidelines_test.exs`), before the rework.
