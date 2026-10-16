# ADR 0037 — UI modes are structs

**Status:** accepted · 2026-10-16

## Context

`Agendum.TUI.State.modes` is a stack of the screens and boxes on top of the view: about fifty-five kinds, each a map with a `type:` and its own fields (`%{type: :menu, path: [], selected: 0}`). A misspelt field in such a map, or one a mode never got, showed only when a key reached it, so only a test or a fuzz walk that went there found it (expert review 2026-10-16, ROADMAP "Typed UI modes"). The owner decided on 2026-10-16 to do this after the command layer, as its own sweep.

## Decision

- **A struct for each kind of mode**, defined from one table in `Agendum.TUI.Modes` (`Agendum.TUI.Modes.Menu`, `Agendum.TUI.Modes.Sort` …). Each keeps `type:` (its kind, set by the struct), so code that matches `%{type: :menu}` is unchanged. The fields were found from the code and by watching the whole test suite and a long fuzz run record every mode on the stack after every key.
- **Every mode on the stack is a struct.** `State.push/2` and `State.put_mode/2` turn a mode written as a map into its struct with `struct!`, which raises on a field the struct lacks; the fuzz walks assert after every key that no mode is a bare map.
- **Modes are written as struct literals** where they are made (`State.push(state, %Agendum.TUI.Modes.Prompt{label: …})`), so a misspelt field is a compile error, and Dialyzer knows the fields modes are read and updated with.
- **A field is nil when unused**, as a struct has every field. Code that told kinds of the same mode apart by whether a key was there now looks at the value: Browse's datebook place has a `%Date{}`, a filter's a `shift` map; BoxCancel's `opened` is nil until the box is tracked; the menu's `resume` is nil rather than absent.

## Consequences

- A new kind of mode, or a new field, goes in the table in `Agendum.TUI.Modes`; `docs/SCREENS.md` lists the kinds from `Modes.types/0` (a test checks).
- Field types are not written out (`@type t :: %__MODULE__{}`): the names are checked, which was the point; types per field can come where a mode is worth it.
- `Map.put/3` on a mode with a field its struct lacks would still slip past the compiler; `State.put_mode/2` checks it when the mode goes back on the stack.
