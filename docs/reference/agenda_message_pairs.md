# Agendum's messages paired with Agenda's (2026-10-25)

Summary: 174 messages. Agenda's words: 61 (24 sure, 37 likely); keep: ours: 43; keep: no Agenda message: 70.

Agenda's texts from docs/reference/agenda_messages.json (AGENDA.RI); '|' line breaks shown as spaces. Not checked in DOSBox. The owner chose Agenda's words, adapted (2026-10-25); applied in `Agendum.TUI.Messages`, except #18 and #67 (another situation than Agenda's: F1's command list, opening a web link), #87 (a Zettel command) and #103 (Agenda counts the file's marks, ours the view's), which stay ours. The same texts also stood in places this table lists once; those changed too.

## The 10 most visible pairs

| # | ours | Agenda's |
|---|---|---|
| 84 | Highlight an item first | The highlight isn't on an item.  Highlight the item you want and repeat the command. |
| 153 | There are no marked items in the file. | There are no marked items in the file. |
| 103 | No marked items in this view | There are no marked items in the file. |
| 114 | Not a date: #{text} (try friday, next week, 12/24, December 24) | The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar. |
| 118 | Not a number: #{String.trim(text)} | The number you entered isn't valid.  Retype a number. |
| 120 | Not a time: #{text} | The time you entered isn't valid.  Type a valid time. |
| 5 | #{cat.name} cannot be discarded | You can't discard the MAIN category from the file. / You can't discard the Done, Entry, or When date categories. |
| 52 | A view needs at least one section | Every view must have at least one section.  Type a category name or press F3 to pick an existing category for the section head. |
| 40 | A category needs a name | The name of the category must contain at least one character (other than a space) and can't begin with a semicolon.  Type a valid category name. |
| 94 | Mark the items it depends on with F7, then ALT-O | To make an item dependent, you must first highlight the prerequisite item(s) and mark them by pressing F7. |

## All

| # | ours (verbatim) | where (file:line) | situation | Agenda's (verbatim, or —) | sure? | proposal |
|---|---|---|---|---|---|---|
| 18 | #{name} cannot run here | tui/help_screen.ex:355 | macro not allowed in this place | You can't run this macro in this part of Agenda.  Macros can be limited to any one or more of these parts of Agenda: views, category manager, and notes.  You can check these limits by displaying the macro properties for the current macro. | sure | Agenda's words |
| 40 | A category needs a name | tui/category_screens.ex:407 | empty category name | The name of the category must contain at least one character (other than a space) and can't begin with a semicolon.  Type a valid category name. | sure | Agenda's words |
| 41 | A category with grandchildren cannot change type | tui/category_screens/properties.ex:339 | convert category with grandchildren | You can't convert the MAIN category or a category with grandchildren to numeric, date, or unindexed. | sure | Agenda's words |
| 52 | A view needs at least one section | tui/boxes/view_props.ex:508 | remove the last section | Every view must have at least one section.  Type a category name or press F3 to pick an existing category for the section head. | sure | Agenda's words (first sentence) |
| 58 | ALT-F1, ALT-F3 and ALT-Z cannot run a macro | tui/boxes/macro_props.ex:115 | attach macro to ALT-F1/F3/Z | You can't attach a macro to any of these keys: ALT-Z, ALT-F3, or ALT-F1. Choose a different key. | sure | Agenda's words |
| 80 | File not found | tui/update.ex:571 | file not found | The file you requested doesn't exist.  Check the name you typed for errors and make sure you specified the correct directory. | sure | Agenda's words |
| 84 | Highlight an item first | tui/update/actions.ex:187 | item command off an item | The highlight isn't on an item.  Highlight the item you want and repeat the command. | sure | Agenda's words |
| 85 | Highlight an item to copy | tui/update/actions.ex:239 | copy off an item | The highlight isn't on an item.  Highlight the item you want and repeat the command. | sure | Agenda's words |
| 94 | Mark the items it depends on with F7, then ALT-O | tui/update/view_keys.ex:734 | ALT-O without marked items | To make an item dependent, you must first highlight the prerequisite item(s) and mark them by pressing F7. | sure | Agenda's words |
| 111 | Not a date: #{bad(mode, &parse_date(&1, state))} | tui/boxes/range_filter_box.ex:155 | bad date (range filter) | The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar. | sure | Agenda's words |
| 112 | Not a date: #{String.trim(mode.line.text)} | tui/boxes/action_box.ex:115 | bad date (action) | The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar. | sure | Agenda's words |
| 113 | Not a date: #{text} | tui/moves/browse.ex:104 | bad date (browse ALT-F5) | The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar. | sure | Agenda's words |
| 114 | Not a date: #{text} (try friday, next week, 12/24, December 24) | tui/update/prompts.ex:233 | bad date typed | The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar. | sure | Agenda's words (our examples could follow it) |
| 115 | Not a date: #{text} (try friday, next week, 12/24) | tui/update/prompts.ex:267 | bad date typed | The date you entered isn't valid.  Type a valid date or press ALT-C to pick a date from the calendar. | sure | Agenda's words |
| 116 | Not a number: #{bad(mode, &Core.NumberFormat.parse(&1, opts))} | tui/boxes/range_filter_box.ex:159 | bad number (range) | The number you entered isn't valid.  Retype a number. | sure | Agenda's words |
| 117 | Not a number: #{String.trim(mode.line.text)} | tui/boxes/action_box.ex:118 | bad number (action) | The number you entered isn't valid.  Retype a number. | sure | Agenda's words |
| 118 | Not a number: #{String.trim(text)} | tui/update/prompts.ex:280 | bad number typed | The number you entered isn't valid.  Retype a number. | sure | Agenda's words |
| 120 | Not a time: #{text} | tui/boxes/datebook_settings.ex:156 | bad time | The time you entered isn't valid.  Type a valid time. | sure | Agenda's words |
| 121 | Not done: the item would depend on itself (through the marked items) | tui/update/prompts.ex:436 | dependency on itself | An item can't be dependent on itself. | sure | Agenda's words |
| 132 | Only standard categories can change type | tui/category_screens/properties.ex:333 | change type of date/numeric | You can't change the category type of date, numeric, and unindexed categories. | sure | Agenda's words |
| 135 | Pick a date category | tui/boxes/datebook_settings.ex:125 | datebook: non-date category picked | You must select a date category. | sure | Agenda's words |
| 145 | The date category must be a date category | tui/boxes/schedule_box.ex:113 | Show Schedule: non-date category | You must select a date category. | sure | Agenda's words |
| 148 | The item column stays; remove the other columns | tui/boxes/section_box.ex:283 | remove item column | You can't remove the item column from the section. | sure | Agenda's words |
| 153 | There are no marked items in the file. | tui/update/notes.ex:386 | no marked items in the file | There are no marked items in the file. | sure | Agenda's words (already Agenda's) |
| 5 | #{cat.name} cannot be discarded | tui/update/actions.ex:151 | discard MAIN or Entry/When/Done | You can't discard the MAIN category from the file. / You can't discard the Done, Entry, or When date categories. | likely | Agenda's words (two messages: MAIN, or the date categories) |
| 7 | #{cat.name} cannot change type | tui/category_screens/properties.ex:336 | change type of MAIN/special category | You can't convert the MAIN category or a category with grandchildren to numeric, date, or unindexed. | likely | Agenda's words |
| 14 | #{name(state, mode.head)} cannot change type | tui/boxes/column_add_box.ex:282 | Column Add: head of another kind can't change type | You can't change the category type of date, numeric, and unindexed categories. | likely | Agenda's words |
| 16 | #{name} cannot be discarded | tui/category_screens/manager.ex:126 | discard MAIN/special in manager | You can't discard the MAIN category from the file. / You can't discard the Done, Entry, or When date categories. | likely | Agenda's words (as #5) |
| 19 | #{name} is not an Agenda file Agendum can read | tui/update.ex:755 | import a file that is not a readable .AG | Agenda can't retrieve this file.  It is either not an Agenda file, or it is too damaged to open. | likely | Agenda's words (Agenda's Retrieve message; ours is Import) |
| 22 | #{state.db.categories[cat_id].name} cannot become a date category | tui/update/prompts.ex:59 | conversion to date refused | You can't convert the MAIN category or a category with grandchildren to numeric, date, or unindexed. | likely | Agenda's words |
| 23 | #{state.db.categories[cat_id].name} cannot become numeric | tui/update/prompts.ex:48 | conversion to numeric refused | You can't convert the MAIN category or a category with grandchildren to numeric, date, or unindexed. | likely | Agenda's words |
| 43 | A datebook view's item text fills the width its columns leave | tui/update/actions.ex:223 | datebook: item column width | You can't make this change in a datebook view. | likely | Agenda's words |
| 44 | A datebook view's item text stays first | tui/update/actions.ex:408 | datebook: item column moved | You can't make this change in a datebook view. | likely | Agenda's words |
| 45 | A datebook view's sections are its dates; they follow its settings | tui/update/actions.ex:62 | datebook: section command | You can't make this change in a datebook view. | likely | Agenda's words |
| 65 | Could not import #{name}: #{message} | tui/update.ex:758 | import failed | Agenda can't import the file you requested.  Either the file is damaged, or it contains control characters that Agenda can't accept. | likely | Agenda's words (keep the reason after it?) |
| 66 | Could not import #{Path.basename(path)}: #{reason} | tui/update.ex:714 | import failed | Agenda can't import the file you requested.  Either the file is damaged, or it contains control characters that Agenda can't accept. | likely | Agenda's words |
| 67 | Could not open it: #{reason} | tui/update.ex:550 | could not open file | Agenda couldn't open the file.  Try exiting to the system to see if the file is damaged.  If the file is on a network drive, the drive may be read-only, so you'll have to use a different drive. | likely | Agenda's words (first sentence; ours adds the reason) |
| 68 | Could not open: #{inspect(reason)} | tui/update.ex:681 | could not open | Agenda couldn't open the file.  Try exiting to the system to see if the file is damaged.  If the file is on a network drive, the drive may be read-only, so you'll have to use a different drive. | likely | Agenda's words |
| 70 | Could not read: #{inspect(reason)} | tui/update.ex:574 | could not read | Agenda couldn't open the file.  Try exiting to the system to see if the file is damaged.  If the file is on a network drive, the drive may be read-only, so you'll have to use a different drive. | likely | Agenda's words |
| 81 | Give the item a When date and time first (ALT-F2) | tui/update/actions.ex:252 | alarm without When date | You must provide a date for the item. | likely | Agenda's words |
| 87 | Highlight an item, or mark some with F7 | tui/update/marked.ex:184 | command needs item or marks | The highlight isn't on an item.  Highlight the item you want and repeat the command. | likely | Agenda's words |
| 88 | In a datebook view, change the item's date instead | tui/update/marked.ex:323 | datebook: move item | You can't make this change in a datebook view. | likely | Agenda's words |
| 89 | In a datebook view, give the item another date instead | tui/boxes/copy_box.ex:25 | datebook: copy item | You can't make this change in a datebook view. | likely | Agenda's words |
| 97 | No category here to have a note | tui/update/view_keys.ex:447 | note off a category (manager) | The highlight isn't on a category.  Highlight the category you want and repeat the command. | likely | Agenda's words |
| 99 | No item in this view contains \"#{...}\" | tui/boxes/search_box.ex:156 | search finds nothing | Agenda couldn't find any matches for the text you entered. | likely | Agenda's words |
| 102 | No macro run yet (ALT-F3 shows them) | tui/macros.ex:323 | repeat last macro: none | There is no macro to restart. | likely | Agenda's words |
| 103 | No marked items in this view | tui/update/marked.ex:37 | marked command: none marked in view | There are no marked items in the file. | likely | Agenda's words (Agenda counts the file's marks) |
| 104 | No more matches after this one | tui/boxes/search_box.ex:202 | search: no further match | No matching text found | likely | Agenda's words |
| 105 | No more matches before this one | tui/boxes/search_box.ex:203 | search: no earlier match | No matching text found | likely | Agenda's words |
| 119 | Not a text file: #{path} | tui/update.ex:771 | import: not a text file | Agenda can't import the file you requested.  Either the file is damaged, or it contains control characters that Agenda can't accept. | likely | Agenda's words |
| 151 | The item was discarded by a special action | tui/update/editing.ex:213 | special action discarded the item | You assigned the current item to a category with a special action that discarded the item when you made the assignment.  You can recover the item from the trash (unless you have set Empty trash to When item is discarded). | likely | Agenda's words (its trash sentence does not apply: no trash) |
| 155 | This category cannot be discarded | tui/update/prompts.ex:459 | discard protected category | You can't discard the MAIN category from the file. / You can't discard the Done, Entry, or When date categories. | likely | Agenda's words (as #5) |
| 160 | Type 0 to #{@max_decimals} decimal places | tui/boxes/column_box.ex:268 | decimals out of range | The number you entered isn't valid.  Retype a number. | likely | Agenda's words |
| 161 | Type a line number | tui/boxes/column_box.ex:257 | bad line number | The number you entered isn't valid.  Retype a number. | likely | Agenda's words |
| 162 | Type a number | tui/boxes/column_add_box.ex:124 | bad number | The number you entered isn't valid.  Retype a number. | likely | Agenda's words |
| 163 | Type a number of minutes from 0 to 60 | tui/update/prompts.ex:257 | alarm minutes | The number you entered isn't valid.  Retype a number. | likely | Agenda's words |
| 164 | Type a number, e.g. 120 or 1,234.50 | tui/update/view_keys.ex:673 | bad number in column | The number you entered isn't valid.  Retype a number. | likely | Agenda's words |
| 165 | Type a tab size from 1 to 16 | tui/boxes/file_properties.ex:77 | tab size | The number you entered isn't valid.  Retype a number. | likely | Agenda's words |
| 166 | Type a width, a number | tui/boxes/item_column_box.ex:96 | bad width | The number you entered isn't valid. Either the number is outside the allowable range, or the new width exceeds the total width limit for the view. | likely | Agenda's words |
| 168 | Type one key, as {F4}, {ShfF4}, {AltD} or {CtlE} | tui/boxes/macro_props.ex:121 | attach: not one key | You can't attach a macro to more than one key.  Enter a single key for the macro attachment. | likely | Agenda's words |
| 170 | Type the section head's name, or press F3 to pick it | tui/boxes/section_box.ex:214 | empty section head name | The name of the section head must contain at least one character (other than a space).  Type a valid category name or press F3 to choose an existing category. | likely | Agenda's words |
| 72 | Could not save: #{inspect(reason)}#{tail} | tui/update.ex:632 | could not save | Error writing file | likely | keep: no Agenda message (keep our reason; Agenda's is terse) |
| 73 | Could not write: #{inspect(reason)} | tui/update.ex:782 | could not write | Error writing file | likely | keep: no Agenda message |
| 154 | There is no room left; the text stays in the note | tui/update/notes.ex:360 | note too long to make item | There isn't enough room in the file for the text you entered or attached, so Agenda shortened the text. | likely | keep: no Agenda message (different outcome) |
| 1 | \"#{text}\" matches several categories; type more or press F3 | tui/update/editing.ex:137 | typed category name matches several | — | none found | keep: no Agenda message (Agenda autocompletes; no message) |
| 6 | #{cat.name} cannot be renamed | tui/category_screens/properties.ex:266 | rename a protected category (MAIN, dates) | — | none found | keep: no Agenda message |
| 8 | #{cat.name} cannot have mutually exclusive children | tui/category_screens/choices.ex:116 | exclusive children on MAIN/date category | — | none found | keep: no Agenda message |
| 9 | #{conflicts} conflicting item(s) reassigned | tui/category_screens/choices.ex:251 | exclusive: conflicting items moved | — | none found | keep: no Agenda message (Agenda asks 'Make child categories mutually exclusive?' first) |
| 13 | #{macro.name} has no keystrokes yet (F7 in the macro manager) | tui/macros.ex:308 | run a macro with no keystrokes | — | none found | keep: no Agenda message |
| 15 | #{name(state, mode.head)} stays a #{kind_name(mode.kind)} category | tui/boxes/column_add_box.ex:194 | Column Add: head keeps its type | — | none found | keep: no Agenda message |
| 17 | #{name} cannot have mutually exclusive children | tui/category_screens/choices.ex:368 | exclusive children on MAIN/date (choices) | — | none found | keep: no Agenda message |
| 24 | #{state.db.categories[cat_id].name} is now a date category | tui/update/prompts.ex:56 | category became date | — | none found | keep: no Agenda message (Agenda only asks first) |
| 25 | #{state.db.categories[cat_id].name} is now numeric | tui/update/prompts.ex:45 | category became numeric | — | none found | keep: no Agenda message (Agenda only asks first) |
| 26 | #{state.db.categories[id].name} cannot be moved | tui/category_screens/manager.ex:118 | move MAIN/special category | — | none found | keep: no Agenda message |
| 28 | #{state.db.categories[parent].name} already has a #{name} | tui/update/notes.ex:448 | note word → category that exists | — | none found | keep: no Agenda message |
| 29 | #{state.db.items[id].text} is already in #{row.category.name} | tui/update/view_keys.ex:647 | copy item to a section it is in | — | none found | keep: no Agenda message |
| 30 | #{String.trim(text)} already exists at this level | tui/category_screens.ex:420 | new category name exists at this level | — | none found | keep: no Agenda message (Agenda selects the existing one) |
| 31 | #{String.trim(text)} already exists; select it from the list | tui/category_screens.ex:435 | typed name exists; pick it | — | none found | keep: no Agenda message |
| 32 | #{text} already exists | tui/update/prompts.ex:198 | name exists | — | none found | keep: no Agenda message |
| 36 | A category cannot act on itself | tui/category_screens/picker.ex:451 | action on its own category | — | none found | keep: no Agenda message |
| 37 | A category cannot depend on itself | tui/category_screens/picker.ex:459 | condition on its own category | — | none found | keep: no Agenda message |
| 42 | A category's type is changed in its Category Properties | tui/boxes/column_box.ex:316 | Column Properties: type is set elsewhere | — | none found | keep: no Agenda message (Agenda's box let the type change) |
| 48 | A file must have at least one view | tui/update/prompts.ex:470 | delete the last view | — | none found | keep: no Agenda message (Agenda asks: No views left in the file.  Delete the file?) |
| 50 | A macro is already called #{String.trim(name)} | tui/macros.ex:234 | macro name taken | — | none found | keep: no Agenda message |
| 51 | A macro's name has at most 35 characters | tui/macros.ex:237 | macro name too long | — | none found | keep: no Agenda message |
| 54 | Add a section first (ALT-D) | tui/update/view_keys.ex:405 | type with no section in view | — | none found | keep: no Agenda message |
| 55 | Added #{text} under MAIN | tui/update/prompts.ex:197 | category added under MAIN | — | none found | keep: no Agenda message |
| 56 | Alarm set for  | tui/update/prompts.ex:255 | alarm set | — | none found | keep: no Agenda message |
| 57 | All suggested assignments answered | tui/boxes/questions_box.ex:154 | Questions: all answered | — | none found | keep: no Agenda message |
| 59 | ALT-F7 makes items from a note opened in a view | tui/update/notes.ex:220 | ALT-F7 outside a view's note | — | none found | keep: no Agenda message |
| 60 | ALT-F9 appends to an item or a category | tui/update/notes.ex:327 | ALT-F9 not on item/category | — | none found | keep: no Agenda message |
| 61 | Assigned to #{state.db.categories[cat_id].name} | tui/update/editing.ex:82 | assigned (info) | — | none found | keep: no Agenda message |
| 62 | Category discarded | tui/update/prompts.ex:458 | category discarded (info) | — | none found | keep: no Agenda message |
| 63 | Children of #{name} are now mutually exclusive | tui/category_screens/choices.ex:359 | children exclusive (info) | — | none found | keep: no Agenda message |
| 64 | Choose what to sort on first | tui/boxes/sort_box.ex:162 | secondary key without a primary | — | none found | keep: no Agenda message (Agenda's You must select a category to complete the primary sort settings. is for a missing category) |
| 75 | Deleted | tui/update/notes.ex:260 | note deleted (info) | — | none found | keep: no Agenda message |
| 76 | Depends on #{Draw.count(count,  | tui/update/prompts.ex:433 | dependency set (info) | — | none found | keep: no Agenda message |
| 82 | Highlight a column first (use → or TAB) | tui/update/actions.ex:449 | column command off a column | — | none found | keep: no Agenda message |
| 83 | Highlight a column head or entry first | tui/update/actions.ex:228 | column command off a column | — | none found | keep: no Agenda message |
| 90 | Item text cannot be empty | tui/boxes/item_properties.ex:277 | empty item text | — | none found | keep: no Agenda message |
| 91 | Item text cannot be empty (use ALT-F4 to discard) | tui/update/editing.ex:101 | empty item text | — | none found | keep: no Agenda message (Agenda asks Remove this item from the section? (Use ALT-F4 to discard the item completely.)) |
| 92 | Items cannot be removed from MAIN; use ALT-F4 to discard | tui/update/marked.ex:203 | remove item from MAIN | — | none found | keep: no Agenda message |
| 96 | New category #{name} under #{parent} | tui/update/notes.ex:445 | note word → new category (info) | — | none found | keep: no Agenda message |
| 98 | No choice starts with #{String.upcase(c)} | tui/boxes/box_choices.ex:62 | letter picks no choice | — | none found | keep: no Agenda message (Agenda beeps) |
| 106 | No more notes in this direction | tui/update/notes.ex:579 | note ALT-N/P: no more notes | — | none found | keep: no Agenda message |
| 108 | No previous view | tui/update/actions.ex:307 | ALT-F8 last view: none | — | none found | keep: no Agenda message |
| 110 | No word at the cursor to make into a category | tui/update/notes.ex:419 | note: no word to make category | — | none found | keep: no Agenda message |
| 123 | Nothing there to #{action} | tui/update/notes.ex:251 | note: nothing to cut/copy | — | none found | keep: no Agenda message |
| 124 | Nothing there to append | tui/update/notes.ex:355 | note: nothing to append | — | none found | keep: no Agenda message |
| 125 | Nothing there to make into an item | tui/update/notes.ex:290 | note: nothing for ALT-F7 | — | none found | keep: no Agenda message |
| 126 | Nothing to paste: F3 copies, F4 cuts | tui/update/notes.ex:271 | note: nothing to paste | — | none found | keep: no Agenda message |
| 128 | Nothing to search for yet; press ALT-F6 | tui/typing/note_search.ex:276 | note search: no text yet | — | none found | keep: no Agenda message |
| 130 | Numeric categories have no advanced settings | tui/category_screens/properties.ex:308 | numeric: no advanced settings | — | none found | keep: no Agenda message |
| 136 | Replaced #{n} occurrences | tui/typing/note_search.ex:387 | note replace: count | — | none found | keep: no Agenda message |
| 137 | Replaced 1 occurrence | tui/typing/note_search.ex:386 | note replace: one | — | none found | keep: no Agenda message |
| 138 | Search continued from the bottom · ALT-S finds the next | tui/typing/note_search.ex:270 | note search wrapped | — | none found | keep: no Agenda message |
| 139 | Search continued from the top · ALT-S finds the next | tui/typing/note_search.ex:267 | note search wrapped | — | none found | keep: no Agenda message |
| 140 | Set dates by typing in a date column | tui/category_screens/profile.ex:234 | profile: date category | — | none found | keep: no Agenda message |
| 141 | Set dates for marked items with ALT-F2 (When) or F4 (Done) | tui/category_screens/profile.ex:201 | profile marked: date category | — | none found | keep: no Agenda message |
| 142 | Set dates with ALT-F2 (When) or F4 (Done) | tui/category_screens/picker.ex:368 | profile: date category | — | none found | keep: no Agenda message |
| 143 | Several categories are called #{String.trim(name)}; F3 picks one | tui/boxes/field_typing.ex:59 | ambiguous category name | — | none found | keep: no Agenda message |
| 144 | That category already exists under #{name} | tui/category_screens/choices.ex:365 | category exists under parent | — | none found | keep: no Agenda message |
| 146 | The Entry date cannot be removed | tui/boxes/item_properties.ex:209 | remove Entry date | — | none found | keep: no Agenda message |
| 156 | This category cannot be renamed | tui/update/editing.ex:116 | rename protected category | — | none found | keep: no Agenda message |
| 158 | This setting has no default | tui/boxes/box_defaults.ex:38 | F8 on a setting without default | — | none found | keep: no Agenda message |
| 159 | This view sorts its sections; set Section sorting to None first | tui/update/actions.ex:318 | move section while sorted | — | none found | keep: no Agenda message (Agenda's Items in this section are sorted automatically, so you can't reposition items.  You can remove item sorting in the Section Properties box. is for items) |
| 167 | Type numbers in the #{state.db.categories[id].name} column | tui/category_screens.ex:444 | typing in numeric column | — | none found | keep: no Agenda message |
| 169 | Type the column's title | tui/boxes/column_add_box.ex:218 | SPACE on Column title | — | none found | keep: no Agenda message |
| 171 | Type what to search for | tui/typing/note_search.ex:212 | empty search | — | none found | keep: no Agenda message |
| 172 | When date set for #{Draw.count(length(ids),  | tui/update/prompts.ex:230 | When set (info) | — | none found | keep: no Agenda message |
| 173 | When:  | tui/update/prompts.ex:240 | When set (info) | — | none found | keep: no Agenda message |
| 2 | #{cal.name}: #{message} | tui/update.ex:494 | calendar fetch failed | — | none found | keep: ours (calendars (extra)) |
| 3 | #{cal.name}: #{parts} | tui/update.ex:486 | calendar fetched | — | none found | keep: ours (calendars) |
| 4 | #{cal.name}: no changes | tui/update.ex:487 | calendar unchanged | — | none found | keep: ours (calendars) |
| 10 | #{feed.name}: #{message} | tui/update.ex:543 | feed fetch failed | — | none found | keep: ours (feeds) |
| 11 | #{feed.name}: #{parts} | tui/update.ex:535 | feed fetched | — | none found | keep: ours (feeds) |
| 12 | #{feed.name}: nothing new | tui/update.ex:536 | feed unchanged | — | none found | keep: ours (feeds) |
| 20 | #{Path.basename(path)} is not an OPML feed list | tui/update.ex:567 | OPML import: not OPML | — | none found | keep: ours (feeds) |
| 21 | #{Path.basename(path)}: no feeds the file does not have already | tui/update.ex:556 | OPML import: nothing new | — | none found | keep: ours (feeds) |
| 27 | #{state.db.categories[mode.cat_id].name} always takes that key | tui/boxes/date_rule_box.ex:60 | Done/When key setting fixed | — | none found | keep: ours (our rule on Done/When) |
| 33 | #{what} in both #{a} and #{b}; move #{it} first | tui/category_screens/picker.ex:444 | negative link refused: items in both | — | none found | keep: ours (Excludes (R9, ours)) |
| 34 | A calendar needs a name | tui/update/prompts.ex:156 | calendar without name | — | none found | keep: ours (calendars) |
| 35 | A calendar needs an https:// or webcal:// address | tui/update/prompts.ex:153 | calendar address wrong | — | none found | keep: ours (calendars) |
| 38 | A category cannot exclude its parents or children | tui/category_screens/picker.ex:435 | exclude parent/child | — | none found | keep: ours (Excludes) |
| 39 | A category cannot exclude itself | tui/category_screens/picker.ex:432 | exclude itself | — | none found | keep: ours (Excludes) |
| 46 | A feed needs a name | tui/update/prompts.ex:175 | feed without name | — | none found | keep: ours (feeds) |
| 47 | A feed needs an https:// or feed:// address | tui/update/prompts.ex:172 | feed address wrong | — | none found | keep: ours (feeds) |
| 49 | A link goes when the text that has it is changed | tui/boxes/item_properties.ex:158 | link (Zettel) in edited text | — | none found | keep: ours (Zettel links) |
| 53 | A Zettel id is given by Extras ▸ Zettel ▸ Attach; it cannot be typed | tui/update/view_keys.ex:592 | type in a Zettel id column | — | none found | keep: ours (Zettel) |
| 69 | Could not read the site's folder: #{reason} | tui/update.ex:797 | blog folder unreadable | — | none found | keep: ours (blog) |
| 71 | Could not save your preferences: #{inspect(reason)} | tui/update.ex:586 | preferences not saved | — | none found | keep: ours (preferences) |
| 74 | Count: #{count} | tui/update/view_keys.ex:118 | count (ALT-? tools) | — | none found | keep: ours |
| 77 | Done · the next one is on #{date} | tui/update/view_keys.ex:746 | recurring done → next | — | none found | keep: ours (R14a) |
| 78 | Every Zettel id is in use (16,777,216); no more can be given | tui/update/marked.ex:255 | Zettel ids used up | — | none found | keep: ours (Zettel) |
| 79 | Every Zettel id is in use; the posts cannot all have one | tui/extras/publish_box.ex:170 | blog: ids used up | — | none found | keep: ours (blog) |
| 86 | Highlight an item to hop to its next occurrence | tui/update/view_keys.ex:607 | next occurrence off an item | — | none found | keep: ours (R14a) |
| 93 | Macros started #{@max_depth} deep; stopped | tui/macros.ex:311 | macros nested too deep | — | none found | keep: ours |
| 95 | Name the category whose items are the posts | tui/extras/publish_box.ex:167 | blog: posts category | — | none found | keep: ours (blog) |
| 100 | No item links to this one | tui/update/actions.ex:181 | no Zettel backlinks | — | none found | keep: ours (Zettel) |
| 101 | No macro is called #{name} | tui/macros.ex:55 | run macro by name: unknown | — | none found | keep: ours (CTRL-X / {CALL}) |
| 107 | No other occurrence of this item | tui/update/view_keys.ex:623 | no other occurrence | — | none found | keep: ours (R14a) |
| 109 | No removed item to yank back | tui/update/view_keys.ex:637 | yank back: nothing | — | none found | keep: ours (ALT-Y is ours (no trash)) |
| 122 | Not saved. File ▸ Write saves it under another name, keeping both | tui/update/prompts.ex:503 | not overwritten | — | none found | keep: ours (saving (ours)) |
| 127 | Nothing to redo | tui/history.ex:103 | nothing to redo | — | none found | keep: ours (undo (ours)) |
| 129 | Nothing to undo | tui/history.ex:93 | nothing to undo | — | none found | keep: ours (undo (ours)) |
| 131 | Only a macro attached to a key runs everywhere else | tui/boxes/macro_props.ex:103 | macro everywhere else | — | none found | keep: ours |
| 133 | Only standard categories can exclude each other | tui/category_screens/picker.ex:438 | excludes on non-standard | — | none found | keep: ours (Excludes) |
| 134 | Opened #{url} | tui/update.ex:547 | link opened | — | none found | keep: ours (feeds) |
| 147 | The folder already holds this site: nothing to publish | tui/update.ex:792 | blog: nothing new | — | none found | keep: ours (blog) |
| 149 | The item has no web address in its note or text | tui/update/actions.ex:206 | no web address | — | none found | keep: ours (feeds) |
| 150 | The item has no Zettel id, so nothing can link to it | tui/update/actions.ex:177 | no Zettel id | — | none found | keep: ours (Zettel) |
| 152 | The posts and drafts categories must differ, and be categories | tui/extras/publish_box.ex:173 | blog categories | — | none found | keep: ours (blog) |
| 157 | This item has no links to other items | tui/update/actions.ex:171 | no links | — | none found | keep: ours (Zettel) |
| 174 | Wrote #{path} | tui/update.ex:779 | export written | — | none found | keep: ours (JSON export) |
