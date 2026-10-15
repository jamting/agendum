defmodule Agendum.TUI.Boxes.Box do
  @moduledoc """
  Everything about one box, in the box's own module (docs/plans/REFACTORING.md,
  step 3): its keys, how it is drawn, the key bar, the help for its
  highlighted setting, and how it ends.

  A box module says `use Agendum.TUI.Boxes.Box` with its options and
  implements the callbacks below. `registry/0` maps each mode type
  (`%{type: :macro_props}`) to its module; the shared code (`Agendum.TUI.Update`'s
  dispatch, `Agendum.TUI.Render.Boxes`, `Agendum.TUI.Render.KeyBar`, the control
  panel, `Agendum.TUI.Boxes.BoxCancel`, `Agendum.TUI.Boxes.BoxChoices`,
  `Agendum.TUI.Boxes.FieldHelp`) asks the module through this registry; every
  box has one.

  Options of `use`:

    * `finish:` the words in the bottom edge: `:done` ("Press ENTER when
      done, ESC to cancel"), `:accept`, `:esc_done`, `:return` or `:none`;
      a box whose words depend on its mode defines `finish/1` instead
    * `indicator:` the mode shown at the top right ("PROPS"); nil for the
      one of what is beneath (READY in a view)
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

  @doc "The words in the bottom edge (`finish:`); by default the same for every mode."
  @callback finish(mode) :: :done | :accept | :esc_done | :return | :none

  @doc "The width inside the frame; by default 60 columns, less on a narrow screen."
  @callback width(State.t(), mode) :: pos_integer

  @doc """
  The box's own keys (R65, ADR 0033): key to command id. A box with a
  keymap gets its keys through `run/3`; keys not in it, and every key
  while a field is being typed, still go to `c:handle/3`. By default
  none: the box reads all its keys in `c:handle/3`.
  """
  @callback keymap(mode) :: %{term => atom}

  @doc "The box's commands, `{id, name, summary}`, in the order the command list shows."
  @callback commands(mode) :: [{atom, String.t(), String.t()}]

  @doc "Runs one of the box's commands."
  @callback run(State.t(), mode, id :: atom) :: State.t()

  @doc """
  F1's text about the box (R65): what it is for and what to do in it,
  paragraphs separated by a blank line; nil (the default) for the one
  `default_about/3` makes from its title and its settings' help.
  """
  @callback about(State.t(), mode) :: String.t() | nil

  @doc """
  Whether the person is typing in the box, so that every key goes to
  `c:handle/3` and none to the keymap; by default while `state.edit` or
  the mode's `:typing` holds a field being typed.
  """
  @callback typing?(State.t(), mode) :: boolean

  # The boxes, by their mode's type. A module holds a box's
  # name only (no call at compile time), so the boxes and this module can
  # refer to each other.
  @registry %{
    action_box: Agendum.TUI.Boxes.ActionBox,
    alarm_list: Agendum.TUI.Boxes.AlarmList,
    auto_assign: Agendum.TUI.Boxes.AutoAssignBox,
    calendar: Agendum.TUI.Boxes.CalendarBox,
    calendars: Agendum.TUI.Boxes.CalendarsBox,
    category_match: Agendum.TUI.Boxes.CategoryMatchBox,
    category_stats: Agendum.TUI.Boxes.CategoryStatsBox,
    file_stats: Agendum.TUI.Boxes.FileStatsBox,
    choice: Agendum.TUI.CategoryScreens.Choices,
    choice_list: Agendum.TUI.Boxes.ChoiceListBox,
    column_add: Agendum.TUI.Boxes.ColumnAddBox,
    column_props: Agendum.TUI.Boxes.ColumnBox,
    confirm: Agendum.TUI.Update.Prompts,
    copy_items: Agendum.TUI.Boxes.CopyBox,
    customize: Agendum.TUI.Boxes.CustomizeBox,
    datebook_props: Agendum.TUI.Boxes.DatebookBox,
    date_rule: Agendum.TUI.Boxes.DateRuleBox,
    date_settings: Agendum.TUI.Boxes.DateSettingsBox,
    display_format: Agendum.TUI.Boxes.DisplayFormatBox,
    execute: Agendum.TUI.Boxes.ExecuteBox,
    file_props: Agendum.TUI.Boxes.FileProperties,
    goto: Agendum.TUI.Boxes.GoTo,
    group_profile: Agendum.TUI.CategoryScreens.Profile,
    input_format: Agendum.TUI.Boxes.InputFormatBox,
    item_column: Agendum.TUI.Boxes.ItemColumnBox,
    item_props: Agendum.TUI.Boxes.ItemProperties,
    macros: Agendum.TUI.Macros,
    macro_props: Agendum.TUI.Boxes.MacroProps,
    note_search: Agendum.TUI.Typing.NoteSearch,
    numeric_functions: Agendum.TUI.Boxes.NumericFunctionsBox,
    picker: Agendum.TUI.CategoryScreens.Picker,
    profile: Agendum.TUI.CategoryScreens.Profile,
    props: Agendum.TUI.CategoryScreens.Properties,
    questions: Agendum.TUI.Boxes.QuestionsBox,
    range_filter: Agendum.TUI.Boxes.RangeFilterBox,
    schedule: Agendum.TUI.Boxes.ScheduleBox,
    scope: Agendum.TUI.Update.Marked,
    search_box: Agendum.TUI.Boxes.SearchBox,
    section_props: Agendum.TUI.Boxes.SectionBox,
    select_file: Agendum.TUI.Boxes.SelectFile,
    sort: Agendum.TUI.Boxes.SortBox,
    viewmgr: Agendum.TUI.Boxes.ViewManager
  }

  @doc "The box modules, by mode type."
  @spec registry() :: %{atom => module}
  def registry, do: @registry

  @doc "The module of the box `mode` is, or nil for a mode that is not a box."
  @spec module(mode | nil) :: module | nil
  def module(%{type: type}), do: Map.get(@registry, type)
  def module(_mode), do: nil

  @doc "The module of the box `mode` is, where only a box can be on top."
  @spec module!(mode) :: module
  def module!(%{type: type}), do: Map.fetch!(@registry, type)

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
  A key for `box`, on top as `mode`: the command its keymap binds the key
  to, or else (and while one of its fields is being typed in) the box's
  `c:handle/3`.
  """
  @spec dispatch(module, State.t(), mode, term) :: State.t()
  def dispatch(box, state, mode, key) do
    case if(box.typing?(state, mode), do: nil, else: Map.get(box.keymap(mode), key)) do
      nil -> box.handle(state, mode, key)
      id -> box.run(state, mode, id)
    end
  end

  # --- the keys of a settings box ----------------------------------------------

  # Agenda's keys in a box of settings (User's Guide 2-16, ADR 0031): the
  # arrows, TAB, HOME and END move (`BoxNav`), SPACE changes the setting,
  # ENTER is done and ESC cancels (`BoxCancel` puts the changes back)
  @settings_keymap %{
    :up => :up,
    :down => :down,
    :left => :left,
    :right => :right,
    :tab => :next,
    :shift_tab => :previous,
    :home => :first,
    :end => :last,
    {:char, " "} => :change,
    :enter => :done,
    :esc => :close
  }

  @settings_commands [
    {:change, "Change", "Next choice of the setting"},
    {:up, "Up", "The setting above"},
    {:down, "Down", "The setting below"},
    {:left, "Left", "The setting to the left"},
    {:right, "Right", "The setting to the right"},
    {:next, "Next", "The next setting"},
    {:previous, "Previous", "The previous setting"},
    {:first, "First", "The first setting"},
    {:last, "Last", "The last setting"},
    {:done, "Done", "Close, keeping the changes"},
    {:close, "Cancel", "Close, putting back the changes"}
  ]

  # the key each move is, for `BoxNav`
  @move_keys %{
    up: :up,
    down: :down,
    left: :left,
    right: :right,
    next: :tab,
    previous: :shift_tab,
    first: :home,
    last: :end
  }

  @doc "A settings box's keymap: the shared keys, with the box's own (`extra`) over them."
  @spec settings_keymap(%{term => atom}) :: %{term => atom}
  def settings_keymap(extra \\ %{}), do: Map.merge(@settings_keymap, extra)

  @doc "A settings box's commands: the shared ones, `extra` after Change."
  @spec settings_commands([{atom, String.t(), String.t()}]) :: [{atom, String.t(), String.t()}]
  def settings_commands(extra \\ []) do
    [change | rest] = @settings_commands
    ids = for {id, _, _} <- extra, do: id
    [change | extra] ++ Enum.reject(rest, fn {id, _, _} -> id in ids end)
  end

  @doc """
  Runs a command every settings box has: a move through `grid`
  (`Agendum.TUI.Boxes.BoxNav`), Done or Cancel (both close the box here;
  ESC's putting back is `BoxCancel`'s, before the box sees the key).
  """
  @spec run_settings(State.t(), mode, Agendum.TUI.Boxes.BoxNav.grid(), atom) :: State.t()
  def run_settings(state, _mode, _grid, id) when id in [:done, :close], do: State.pop(state)

  def run_settings(state, mode, grid, id) when is_map_key(@move_keys, id),
    do: Agendum.TUI.Boxes.BoxNav.move(state, mode, grid, @move_keys[id])

  @doc """
  F1's text for a box without its own (`c:about/2`): its title, how a box
  of settings is worked, and the help of the highlighted setting.
  """
  @spec default_about(module, State.t(), mode) :: String.t()
  def default_about(box, state, mode) do
    title = box.title(state, mode)
    settings? = Map.get(box.keymap(mode), {:char, " "}) == :change

    work =
      if settings?,
        do:
          "Move between the settings with the arrows or TAB. SPACE changes the " <>
            "highlighted one; a letter picks the choice it begins, F3 lists the choices. " <>
            "ENTER keeps what you changed; ESC puts it all back.",
        else: "F1 then c lists what you can do here, with the keys."

    setting = help_text(box, state, mode)

    [if(title != "", do: title <> "."), work, setting && "This setting: " <> setting]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  # --- the keys of a list box -----------------------------------------------------

  @list_moves [
    {:up, "Up", "Highlight the one above"},
    {:down, "Down", "Highlight the one below"},
    {:first, "First", "Highlight the first"},
    {:last, "Last", "Highlight the last"}
  ]

  @doc "A list box's moves, `{id, name, summary}`, for its `c:commands/1`."
  @spec list_moves() :: [{atom, String.t(), String.t()}]
  def list_moves, do: @list_moves

  @doc "Moves the highlight of a list box with `count` rows: `:up`, `:down`, `:first` or `:last`."
  @spec list_move(State.t(), mode, non_neg_integer, atom) :: State.t()
  def list_move(state, mode, count, id) do
    cursor =
      case id do
        :up -> mode.cursor - 1
        :down -> mode.cursor + 1
        :first -> 0
        :last -> count - 1
      end

    State.put_mode(state, %{mode | cursor: cursor |> min(count - 1) |> max(0)})
  end

  @doc """
  `use Agendum.TUI.Boxes.Box, finish: :done, indicator: "PROPS", cancels: true`
  declares the module a box: it must define the callbacks, and gets
  `finish/1`, `indicator/0`, `cancels?/0` and `choices?/0` from the options.
  """
  # `use` runs this macro in the box module: the `quote` block is code
  # written into that module, with the options' values put in by `unquote`
  defmacro __using__(opts) do
    cancels = Keyword.get(opts, :cancels, false)

    quote do
      @behaviour Agendum.TUI.Boxes.Box

      @impl true
      def finish(_mode), do: unquote(Keyword.get(opts, :finish, :done))
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
      # no keymap: the box reads its keys in handle/3
      @impl true
      def keymap(_mode), do: %{}
      @impl true
      def commands(_mode), do: []
      @impl true
      def run(state, _mode, _id), do: state
      @impl true
      def typing?(state, mode), do: state.edit != nil or Map.get(mode, :typing) != nil
      @impl true
      def about(_state, _mode), do: nil

      defoverridable width: 2,
                     field: 2,
                     finish: 1,
                     keymap: 1,
                     commands: 1,
                     run: 3,
                     typing?: 2,
                     about: 2
    end
  end
end
