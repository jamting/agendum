# Agenda (dagordning) for the panel meeting, 2026-10-16-1905 (third)

**Called by:** the owner **Place:** Owl's house, the Hundred Acre Wood **Date:** 2026-10-16

## § 1 Opening of the meeting

## § 2 Election of a chair, a secretary and two approvers of the minutes

## § 3 Adoption of the agenda

## § 4 The previous minutes: decisions followed up

## § 5 Should Quadsyl-24 be Agendum's Zettel id, and should it be brought into the project?

The owner has designed Quadsyl-24, a system of pronounceable ids: a counter number (0 to 16,777,215) is scrambled and spelled as four consonant-vowel syllables (`bonalaku`), and the id decodes back to the number; the 267 ids that are real English or Swedish words are reserved for special notes. The documents (`QUADSYL.md`, `PRIOR_ART.md`) and an Elixir module with tests (`ZettelId`) are in the new folder `import-into-project/`. If the meeting so decides, the documents and the source files are imported into the project. The roadmap's earlier design used the creation time as the id.

## § 6 How an item gets its Zettel id

The owner proposes a command that attaches the next available Zettel id to an item; the "special" (reserved) ids are kept for later. Their purpose is mainly to give some reserved entry places, so that Agendum instances can communicate with each other. The ids would be kept as a category ZID, whose children are never shown in the category manager, and adding the next ZID is made a command.

## § 7 Run a command by name: a key, and fuzzy matching

A new function in the terminal program: run a command by its name, from a reasonable shortcut, with fuzzy matching of the available commands.

## Any other business

## Next meeting

## Closing of the meeting
