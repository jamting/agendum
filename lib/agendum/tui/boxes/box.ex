defmodule Agendum.TUI.Boxes.Box do
  @moduledoc """
  Everything about one box, in the box's own module (docs/REFACTORING.md,
  step 3): its keys, how it is drawn, the key bar, the help for its
  highlighted setting, and how it ends.

  A box module says `use Agendum.TUI.Boxes.Box` with its options and
  implements the callbacks below. `registry/0` maps each mode type
  (`%{type: :macro_props}`) to its module; the shared code (`Agendum.TUI.Update`'s
  dispatch, `Agendum.TUI.Render.Boxes`, `Agendum.TUI.Render.KeyBar`, the control
  panel, `Agendum.TUI.Boxes.BoxCancel`, `Agendum.TUI.Boxes.BoxChoices`,
  `Agendum.TUI.Boxes.FieldHelp`) asks the module through this registry. Boxes not
  moved here yet are still handled by those modules' own clauses.

  Options of `use`:

    * `finish:` the words in the bottom edge: `:done` ("Press ENTER when
      done, ESC to cancel"), `:accept`, `:esc_done`, `:return` or `:none`
    * `indicator:` the mode shown at the top right ("PROPS")
    * `cancels:` whether ESC puts back the changes made in the box
      (`Agendum.TUI.Boxes.BoxCancel`)
    * `choices:` whether a letter or F3 picks a setting's choice
      (`Agendum.TUI.Boxes.BoxChoices`); true for every box that cancels

  Pure.
  """

  alias Agendum.TUI.{State, Terminal.Draw}

  @typedoc "The box's mode: a map with its `type` and its own fields."
  @type mode :: %{required(:type) => atom, optional(atom) => term}

  @typedoc """
  A key for the key bar: `{key, label}`, `{key, label, full label}` or
  `{key, label, full key, full label}` (`Agendum.TUI.Render.KeyBar`).
  """
  @type key_entry ::
          {String.t(), String.t()}
          | {String.t(), String.t(), String.t()}
          | {String.t(), String.t(), String.t(), String.t()}

  @typedoc "The help for each setting (by `c:field/2`), or one help for the whole box."
  @type help :: %{atom => String.t()} | String.t() | nil

  @doc "A key pressed while the box is on top."
  @callback handle(State.t(), mode, key :: term) :: State.t()

  @doc "The title in the box's top edge."
  @callback title(State.t(), mode) :: String.t()

  @doc "The lines inside the box, at most `max_rows` of the list when it scrolls."
  @callback content(State.t(), mode, inner :: pos_integer, max_rows :: pos_integer) ::
              [Draw.line()]

  @doc "The keys for the key bar, and for the hint inside the box (`hint/1`)."
  @callback keys(State.t(), mode) :: [key_entry]

  @doc "The help shown in the control panel (`Agendum.TUI.Boxes.FieldHelp`)."
  @callback help() :: help

  @doc "The highlighted setting, the key of its help; nil (the default) for a box with one help."
  @callback field(State.t(), mode) :: atom | nil

  @doc "The width inside the frame; by default 60 columns, less on a narrow screen."
  @callback width(State.t(), mode) :: pos_integer

  # The boxes moved here, by their mode's type. A module holds a box's
  # name only (no call at compile time), so the boxes and this module can
  # refer to each other.
  @registry %{
    action_box: Agendum.TUI.Boxes.ActionBox,
    auto_assign: Agendum.TUI.Boxes.AutoAssignBox,
    category_match: Agendum.TUI.Boxes.CategoryMatchBox,
    column_add: Agendum.TUI.Boxes.ColumnAddBox,
    column_props: Agendum.TUI.Boxes.ColumnBox,
    customize: Agendum.TUI.Boxes.CustomizeBox,
    datebook_props: Agendum.TUI.Boxes.DatebookBox,
    date_rule: Agendum.TUI.Boxes.DateRuleBox,
    date_settings: Agendum.TUI.Boxes.DateSettingsBox,
    display_format: Agendum.TUI.Boxes.DisplayFormatBox,
    execute: Agendum.TUI.Boxes.ExecuteBox,
    file_props: Agendum.TUI.Boxes.FileProperties,
    input_format: Agendum.TUI.Boxes.InputFormatBox,
    item_column: Agendum.TUI.Boxes.ItemColumnBox,
    macro_props: Agendum.TUI.Boxes.MacroProps,
    note_search: Agendum.TUI.Typing.NoteSearch,
    numeric_functions: Agendum.TUI.Boxes.NumericFunctionsBox,
    range_filter: Agendum.TUI.Boxes.RangeFilterBox,
    schedule: Agendum.TUI.Boxes.ScheduleBox,
    search_box: Agendum.TUI.Boxes.SearchBox,
    section_props: Agendum.TUI.Boxes.SectionBox,
    sort: Agendum.TUI.Boxes.SortBox
  }

  @doc "The box modules, by mode type."
  @spec registry() :: %{atom => module}
  def registry, do: @registry

  @doc "The module of the box `mode` is, or nil for a box not moved here (and other modes)."
  @spec module(mode | nil) :: module | nil
  def module(%{type: type}), do: Map.get(@registry, type)
  def module(_mode), do: nil

  @doc """
  The help for the highlighted setting of `box`, on top as `mode`, or nil:
  `c:help/0` looked up with `c:field/2`.
  """
  @spec help_text(module, State.t(), mode) :: String.t() | nil
  def help_text(box, state, mode) do
    case box.help() do
      texts when is_map(texts) -> Map.get(texts, box.field(state, mode))
      text -> text
    end
  end

  @doc "Every help text of a box, for the tests (each must fit the control panel)."
  @spec help_texts(module) :: [String.t()]
  def help_texts(box) do
    case box.help() do
      texts when is_map(texts) -> Map.values(texts)
      nil -> []
      text -> [text]
    end
  end

  @doc """
  The hint at the bottom of a box `inner` wide: its keys from `c:keys/2`
  without the arrows and the ways to close it, which its bottom edge
  names; with the keys' fuller labels when they fit ("SPACE next choice"),
  else the short ones ("SPACE change · F2 edit · DEL detach"), and as many
  of those as fit (the key bar has them all). One list for the key bar and
  the hint, so they cannot disagree.
  """
  @spec hint([key_entry], pos_integer) :: Draw.line()
  def hint(keys, inner) do
    shown = Enum.reject(keys, fn entry -> closing?(entry) or moving?(elem(entry, 0)) end)
    # the fuller label is the last in an entry, the short one the second
    full = hint_text(shown, fn entry -> entry |> Tuple.to_list() |> List.last() end)
    fits? = &(String.length(&1) < inner - 1)

    text =
      if fits?.(full),
        do: full,
        else: shown |> short_hints() |> Enum.find("", fits?)

    [{:box, " " <> text}]
  end

  # the short hint of all the keys, then of one fewer, and so on
  defp short_hints(keys) do
    for n <- length(keys)..1//-1, do: hint_text(Enum.take(keys, n), &elem(&1, 1))
  end

  defp hint_text(keys, label),
    do: Enum.map_join(keys, " · ", &(elem(&1, 0) <> " " <> String.downcase(label.(&1))))

  defp closing?(entry), do: elem(entry, 1) in ~w(Done Cancel Select Accept Close Return)
  defp moving?(key), do: String.starts_with?(key, ["↑", "↓", "←", "→"])

  @doc """
  The keys of a box of settings whose choices SPACE goes through, for
  `c:keys/2`: moving, SPACE, ENTER and ESC; `extra` goes before ENTER.
  """
  @spec settings_keys([key_entry]) :: [key_entry]
  def settings_keys(extra \\ []) do
    [{"↑↓←→", "Setting", "Move between settings"}, {"SPACE", "Next", "Next choice"}] ++
      extra ++ [{"ENTER", "Done"}, {"ESC", "Cancel"}]
  end

  @doc """
  `use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true`
  declares the module a box: it must define the callbacks, and gets
  `finish/0`, `indicator/0`, `cancels?/0` and `choices?/0` from the options.
  """
  # `use` runs this macro in the box module: the `quote` block is code
  # written into that module, with the options' values put in by `unquote`
  defmacro __using__(opts) do
    cancels = Keyword.get(opts, :cancels, false)

    quote do
      @behaviour Agendum.TUI.Boxes.Box

      @doc false
      def finish, do: unquote(Keyword.get(opts, :finish, :done))
      @doc false
      def indicator, do: unquote(Keyword.get(opts, :indicator, "PROPS"))
      @doc false
      def cancels?, do: unquote(cancels)
      @doc false
      def choices?, do: unquote(Keyword.get(opts, :choices, cancels))

      # defaults a box may replace with its own (`defoverridable`)
      @impl true
      def width(state, _mode), do: min(state.width - 8, 60)
      @impl true
      def field(_state, _mode), do: nil
      defoverridable width: 2, field: 2
    end
  end
end
