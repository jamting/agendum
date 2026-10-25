defmodule Agendum.TUI.Modes do
  @moduledoc """
  The UI modes as structs (ROADMAP, Towards many users): one per kind of
  mode on `Agendum.TUI.State`'s stack, such as `Agendum.TUI.Modes.Menu`
  for the menu or `Agendum.TUI.Modes.Sort` for the Sort box. Each struct's
  `type` is its kind (`:menu`), so code that matches `%{type: :menu}`
  keeps working, and it has exactly the fields that mode uses.

  A mode written as a map is made a struct when it goes on the stack
  (`new/1`, called by `State.push/2` and `State.put_mode/2`): a field the
  struct does not have raises there, at once, instead of going unnoticed
  until a fuzz walk trips over it. Written as a struct literal
  (`%Modes.Menu{path: []}`), a misspelt field is a compile error, and
  Dialyzer checks the fields a mode is read or updated with.

  The fields were found from the code (every mode written literally) and
  by watching the whole test suite and a long fuzz run (every mode on the
  stack after every key), 2026-10-16. Pure.
  """

  # Domain: the kind of each mode, and its fields (all nil until set; a
  # mode is made with the fields it needs). Boxes whose changes ESC puts
  # back have `opened` (`Agendum.TUI.Boxes.BoxCancel`); boxes with fields
  # to type in have `typing` (`Agendum.TUI.Boxes.FieldTyping`).
  @modes [
    abandon: [:cursor, :revert],
    action_box: [:clear, :cursor, :line, :owner, :target],
    ag_import: [:report, :source, :top],
    auto_assign: [:cursor, :opened],
    away: [:groups],
    browse: [:date, :scope, :shift, :view_id],
    calendar: [:date, :target, :time],
    calendars: [:cursor],
    category_match: [:cat_id, :cursor, :opened],
    category_stats: [:cat_id],
    catmgr: [:cursor],
    choice: [
      :action,
      :at,
      :cat_id,
      :conflicts,
      :cursor,
      :kind,
      :macro_id,
      :name,
      :relocation
    ],
    choice_list: [:cursor, :frame, :labels, :title],
    column_add: [
      :choice,
      :col,
      :cursor,
      :format,
      :head,
      :insert_in,
      :kind,
      :note_line,
      :position,
      :sidx,
      :title,
      :typing,
      :width
    ],
    column_move: [:col, :from, :sidx, :to, :view_id, :what],
    column_props: [:choice, :column, :cursor, :opened, :typing],
    column_width: [:target, :typed, :view_id, :width],
    confirm: [:action, :answer, :help, :note, :question],
    copy_items: [:cursor, :ids],
    customize: [:cursor, :opened],
    date_rule: [:cat_id, :cursor, :opened],
    date_settings: [:cursor, :opened],
    devtools: [:key, :top],
    display_format: [:cursor, :opened],
    execute: [:against, :cursor, :old, :root],
    file_props: [:cursor, :opened, :typing],
    feeds: [:cursor],
    file_stats: [],
    goto: [:cursor],
    group_profile: [:cursor, :item_ids],
    help: [:cursor, :described, :edit, :filter, :from, :page, :pane, :top],
    input_format: [:cursor, :opened],
    item_column: [:cursor, :opened, :sidx, :typing],
    item_props: [:cursor, :item_id, :opened],
    macro_props: [:cursor, :macro_id, :opened],
    macros: [:cursor],
    menu: [:extras, :path, :resume, :selected, :tree],
    move_item: [:moves],
    note: [:edit, :match, :original, :target, :title, :top],
    note_search: [:cursor, :line, :replacement, :settings],
    numeric_functions: [:cursor, :opened, :sidx],
    picker: [:cursor, :purpose, :root, :search],
    profile: [:cursor, :item_id],
    publish: [:cursor, :settings, :typing],
    publish_preview: [:changes, :files, :folder, :top],
    prompt: [:action, :label],
    props: [:cat_id, :cursor, :opened],
    questions: [:cursor, :item, :picked],
    range_filter: [:cat_id, :cursor, :from, :purpose, :show, :to, :where],
    run_by_name: [:cursor, :filter, :from],
    schedule: [:cursor, :date, :date_category, :filter, :section],
    set_alarm: [:cursor, :date_category, :item_id, :minutes, :typing],
    scope: [:action, :cursor, :marked, :row],
    search_box: [:cursor, :direction, :line, :scope, :search],
    searching: [:search],
    section_move: [:cursor_key, :from, :to, :view_id],
    section_props: [:adding, :choice, :cursor, :opened, :sidx, :typing],
    select_file: [:cursor, :dates, :dir, :entries, :extensions, :filter, :line],
    sort: [:cursor, :opened, :remembered, :scope],
    splash: [:until],
    view_props: [:back, :choice, :cursor, :moving, :opened, :typing, :view_id],
    view_stats: [:view_id],
    what_to_copy: [:action, :choice, :cursor, :edit, :on],
    viewmgr: [:cursor, :from, :typed]
  ]

  # `Module.create/3` defines a module while this one compiles: one small
  # struct module per kind, named from it (`:column_add` → `ColumnAdd`).
  # `quote` builds the module's code; `unquote` puts this loop's values in.
  for {type, fields} <- @modes do
    name = Module.concat(__MODULE__, Macro.camelize(Atom.to_string(type)))

    Module.create(
      name,
      quote do
        @moduledoc "The `#{unquote(type)}` mode (see `Agendum.TUI.Modes`)."
        defstruct [type: unquote(type)] ++ unquote(fields)
        @type t :: %__MODULE__{}
      end,
      Macro.Env.location(__ENV__)
    )
  end

  @structs Map.new(@modes, fn {type, _} ->
             {type, Module.concat(__MODULE__, Macro.camelize(Atom.to_string(type)))}
           end)

  @typedoc "A mode: one of the structs above."
  @type t :: struct

  @doc "The struct module of a kind of mode (`:menu` → `Agendum.TUI.Modes.Menu`)."
  @spec module(atom) :: module
  def module(type), do: Map.fetch!(@structs, type)

  @doc "Every kind of mode."
  @spec types() :: [atom]
  def types, do: Keyword.keys(@modes)

  @doc """
  A mode as its struct: a struct is returned as it is; a map with `type:`
  becomes that kind's struct, and a key the struct does not have raises
  (`KeyError`).
  """
  @spec new(map) :: t
  def new(%{__struct__: _} = mode), do: mode
  def new(%{type: type} = mode), do: struct!(module(type), mode)
end
