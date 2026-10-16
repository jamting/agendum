# ADR 0024 — Settings boxes are drawn from layouts written as they look

**Status:** accepted · 2026-10-13

## Context

A settings box (File ▸ Customize, File Properties, Column Properties, Category Properties…) used to be built in code. The rows were a list of atoms, which also set the cursor's order, and a `lines/1` function gave a `{label, value}` pair for each row. The renderer then padded the labels into one column. That worked, but:

- you could not see the box's shape by reading its module, and comparing it with Agenda's screenshot (ADR 0018) meant running the program;
- every box was one column of `label: value`, while Agenda's boxes put fields side by side, used two columns, and had rules and text between groups (File Properties, screenshot 130; Column Properties, screenshot 142);
- the cursor order and the drawn rows were two lists that had to be kept in step.

## Decision

- A box is drawn from a layout: a heredoc written as the box looks on screen. A field is its name in square brackets, `[name      ]`, and the brackets' width is the field's width. Everything else is plain text in the box style.
- `Agendum.TUI.Boxes.Template.render/3` fills in the values, padding them or cutting them with `…` to the field's width, so the columns line up by themselves. It also highlights the selected field, draws the field being edited as the input line, and leaves out a row whose value is `nil` (a setting that does not apply).
- `Template.fields/1` gives the fields in reading order (left to right, top to bottom). That is the cursor's order, so it cannot drift from what is drawn.
- The layout follows Agenda's box from the DOSBox screenshots (`docs/reference/screens/notes.md`), keeping only the settings Agendum has.
- Boxes move over gradually. When a change touches a box's behaviour, the same change converts that box to a layout. File ▸ Customize was first, then File Properties and Column Properties. The rest is a roadmap item.

## Consequences

- A box's module shows its shape. Reviewing a layout against a screenshot means reading text side by side, not running the program.
- Boxes can now have Agenda's two-column and grouped layouts (File Properties' two `...` rows side by side, Column Properties with the numeric or date part below a rule).
- Values may be cut to fit. A field must be as wide as its longest value, or the `…` shows that it is not.
- Until every box is converted, there are two ways of drawing boxes in the code.
- The layouts are English text in the code, like the rest of the UI. If the screen texts are ever translated, the layouts would be translated as a whole.
