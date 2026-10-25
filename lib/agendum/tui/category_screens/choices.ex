defmodule Agendum.TUI.CategoryScreens.Choices do
  @moduledoc """
  Choice boxes and the hierarchy changes behind them: making children
  mutually exclusive (Figure 16-10) and moving categories (promote, demote,
  move; Figure 16-16), with their conflicts; also the boxes for a
  category's type, Learn mode and a new view's type. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :accept

  alias Agendum.Core
  alias Agendum.Core.Database
  alias Agendum.TUI.{Boxes.Box, CategoryScreens, State}
  alias Agendum.TUI.CategoryScreens.Properties
  alias Agendum.TUI.Update.Prompts

  # --- the box (`Agendum.TUI.Boxes.Box`) ---------------------------------------------------

  @impl Box
  def handle(state, mode, key), do: choice_key(state, mode, key)

  # R65: ↑ ↓ ENTER ESC; a letter picks the choice starting with it (in
  # `handle/3`)
  @impl Box
  def keymap(_mode), do: %{:up => :up, :down => :down, :enter => :choose, :esc => :close}

  @impl Box
  def commands(_mode) do
    [{:choose, "Choose", "Choose the highlighted one"}] ++
      Enum.take(Box.list_moves(), 2) ++ [{:close, "Cancel", "Close without choosing"}]
  end

  # the key each command is in `choice_key/3`
  @keys %{up: :up, down: :down, choose: :enter, close: :esc}

  @impl Box
  def run(state, mode, id), do: choice_key(state, mode, Map.fetch!(@keys, id))

  @impl Box
  def title(state, %{kind: :move, cat_id: id}),
    do: "Moving #{state.db.categories[id].name} creates a conflict"

  def title(_state, %{kind: :view_type, name: name}), do: "New view: #{name}"

  def title(_state, %{kind: :make_item}), do: "Make item (ALT-F7)"

  def title(_state, %{kind: :append}), do: "Append (ALT-F9)"

  def title(state, %{kind: :remove_column, at: {sidx, index}}) do
    column = state |> State.view() |> Agendum.Core.View.columns(sidx) |> Enum.at(index)
    "Remove column: #{state.db.categories[column.category_id].name}"
  end

  def title(state, %{kind: :learn, macro_id: id}),
    do: "Learn: #{state.db.macros[id].name}"

  def title(state, %{kind: :type, cat_id: id}),
    do: "Category type: #{state.db.categories[id].name}"

  def title(state, %{cat_id: id}),
    do: "Make children of #{state.db.categories[id].name} mutually exclusive"

  # what is wrong and what to do, the choices, and what the highlighted one does
  @impl Box
  def content(_state, mode, _inner, _max_rows) do
    options = choice_options(mode)
    [problem, question] = choice_lines(mode)
    {_, description, _} = Enum.at(options, mode.cursor)

    choices =
      options
      |> Enum.with_index()
      |> Enum.map(fn {{label, _, _}, i} ->
        [{:box, "   "}, {if(i == mode.cursor, do: :box_selected, else: :box), " #{label} "}]
      end)

    [[{:box, " " <> problem}], [], [{:box, " " <> question}]] ++
      choices ++ [[], [{:box, " " <> description}]]
  end

  @impl Box
  def keys(_state, _mode),
    do: [{"↑↓", "Highlight", "Highlight a choice"}, {"ENTER", "Select"}, {"ESC", "Cancel"}]

  @impl Box
  def help, do: nil

  # --- making children mutually exclusive -----------------------------------------------------

  @doc "The choices offered when items are in several children (Agenda 2.0, Figure 16-10)."
  def exclusive_resolutions do
    [
      {"Parent category", "Remove them from the children and assign them to the parent", :parent},
      {"Existing category", "Keep only the child closest to the top of the family", :first_child},
      {"New category", "Type a name; a new child category gets them", :new_child}
    ]
  end

  @doc "Makes a category's children mutually exclusive, or no longer."
  def toggle_exclusive(state, cat) do
    cond do
      cat.exclusive ->
        State.run(
          state,
          {:make_unexclusive, cat.id},
          "Children of #{cat.name} are no longer mutually exclusive"
        )

      Database.protected?(state.db, cat.id) ->
        State.error(state, "#{cat.name} cannot have mutually exclusive children")

      Core.exclusive_conflicts(state.db, cat.id) == [] ->
        apply_exclusive(state, cat.id, :parent)

      true ->
        conflicts = length(Core.exclusive_conflicts(state.db, cat.id))

        State.push(state, %Agendum.TUI.Modes.Choice{
          kind: :exclusive,
          cat_id: cat.id,
          conflicts: conflicts,
          cursor: 0
        })
    end
  end

  # --- moving categories (promote, demote, move) ---------------------------------------------

  @doc "The choices offered when a move puts items in two exclusive branches (Figure 16-16)."
  def move_resolutions do
    [
      {"Removing from current category", "Remove them from the category being moved",
       :remove_moved},
      {"Removing from conflicting category", "Remove them from the category they clash with",
       :remove_other},
      {"Moving to new category",
       "Type a name; a new category under the conflicting one gets them", :new_category}
    ]
  end

  @doc "Options and explanatory lines for a choice box."
  def choice_options(%{kind: :exclusive}), do: exclusive_resolutions()
  def choice_options(%{kind: :move}), do: move_resolutions()

  def choice_options(%{kind: :type}),
    do: [
      # Agenda's order (checked in Agenda 2.0, 2026-10-25)
      {"Unindexed", "A text for each item, such as a phone number; children become texts",
       :unindexed},
      {"Numeric", "A number for each item: totals and averages; children become numbers",
       :numeric},
      {"Date", "A date and time for each item; children become dates; cannot change back", :date}
    ]

  def choice_options(%{kind: :learn}),
    do: [
      {"Replace", "Record new keystrokes instead of the macro's", :replace},
      {"Append", "Record keystrokes to add after the macro's", :append}
    ]

  def choice_options(%{kind: :remove_column}),
    do: [
      {"All sections in view", "Remove the column from every section it is in", :all},
      {"Current section only", "Remove the column from this section; the others keep it",
       :section}
    ]

  def choice_options(%{kind: :append}), do: choice_options(%{kind: :make_item})

  def choice_options(%{kind: :make_item}),
    do: [
      {"Word", "The word at the cursor", :word},
      {"Line", "The line the cursor is on", :line},
      {"All text", "Everything in the note", :all}
    ]

  def choice_options(%{kind: :view_type}),
    do: [
      {"Standard", "Sections headed by categories you choose", :standard},
      {"Datebook", "Sections for the hours, days, weeks or months of a period", :datebook}
    ]

  def choice_lines(%{kind: :learn}),
    do: ["The macro already has keystrokes.", "Learn mode should:"]

  def choice_lines(%{kind: :remove_column}),
    do: ["The column is in more than one section.", "Remove it from:"]

  def choice_lines(%{kind: :append}),
    do: ["Nothing is marked (F7). The text leaves the note.", "Append to the item or category:"]

  def choice_lines(%{kind: :make_item}),
    do: ["The text leaves the note and becomes a new item.", "Make into an item:"]

  def choice_lines(%{kind: :view_type}),
    do: ["Sections by category, or by date like an appointment book.", "Type of view:"]

  def choice_lines(%{kind: :type}),
    do: ["Standard categories can become numeric or date categories.", "Change the type to:"]

  def choice_lines(%{kind: :exclusive, conflicts: n}),
    do: ["#{n} item(s) are assigned to more than one child.", "Assign conflicting item(s) to:"]

  def choice_lines(%{kind: :move, conflicts: n}),
    do: [
      "#{n} item(s) would be in two conflicting categories.",
      "Process conflicting item(s) by:"
    ]

  @doc "Promotes, demotes or moves a category, asking first when items conflict."
  # `relocation` is :promote, :demote or {:move, parent, after_id} (see Core.relocate/4).
  def move(state, id, relocation) do
    case Core.relocation_conflicts(state.db, id, relocation) do
      {:ok, []} ->
        apply_move(state, id, relocation, :remove_moved)

      {:ok, conflicts} ->
        State.push(state, %Agendum.TUI.Modes.Choice{
          kind: :move,
          cat_id: id,
          relocation: relocation,
          conflicts: length(conflicts),
          cursor: 0
        })

      error ->
        CategoryScreens.hierarchy_change(state, error)
    end
  end

  @doc "Relocates a category with the given conflict resolution and reports the result."
  def apply_move(state, id, relocation, rule) do
    conflicts =
      with {:ok, items} <- Core.relocation_conflicts(state.db, id, relocation), do: length(items)

    case State.command(state, {:relocate, id, relocation, rule}) do
      {:ok, state, _} ->
        state = CategoryScreens.move_cursor_to(state, id)

        if conflicts > 0,
          do: State.info(state, "#{conflicts} conflicting item(s) reassigned"),
          else: state

      error ->
        CategoryScreens.hierarchy_change(state, error)
    end
  end

  @doc "Keys of a choice box."
  def choice_key(state, mode, key) do
    options = choice_options(mode)

    pick = fn index ->
      resolve_choice(State.pop(state), mode, elem(Enum.at(options, index), 2))
    end

    case key do
      :up ->
        State.put_mode(state, %{mode | cursor: max(mode.cursor - 1, 0)})

      :down ->
        State.put_mode(state, %{mode | cursor: min(mode.cursor + 1, length(options) - 1)})

      :enter ->
        pick.(mode.cursor)

      :esc ->
        State.pop(state)

      {:char, c} ->
        case Enum.find_index(options, fn {label, _, _} ->
               String.downcase(String.first(label)) == String.downcase(c)
             end) do
          nil -> state
          index -> pick.(index)
        end

      _ ->
        state
    end
  end

  defp resolve_choice(state, %{kind: :move} = mode, :new_category) do
    Prompts.prompt(
      state,
      "New category for the conflicting items:",
      {:move_new_category, mode.cat_id, mode.relocation}
    )
  end

  defp resolve_choice(state, %{kind: :move} = mode, rule),
    do: apply_move(state, mode.cat_id, mode.relocation, rule)

  defp resolve_choice(state, %{kind: :learn, macro_id: id}, how),
    do: Agendum.TUI.Macros.learn(state, state.db.macros[id], how)

  defp resolve_choice(state, %{kind: :remove_column, at: at}, from),
    do: Agendum.TUI.Update.Actions.remove_column(state, at, from)

  defp resolve_choice(state, %{kind: :append}, what),
    do: Agendum.TUI.Update.Notes.append(state, what)

  defp resolve_choice(state, %{kind: :make_item}, what),
    do: Agendum.TUI.Update.Notes.make_item(state, what)

  defp resolve_choice(state, %{kind: :view_type, name: name}, :standard),
    do: CategoryScreens.open_picker(state, {:new_view, name}, nil)

  # a datebook view with Agenda's defaults (When, a week from today), then
  # its settings (R47)
  defp resolve_choice(state, %{kind: :view_type, name: name}, :datebook) do
    {:ok, state, %{new: view_id}} =
      State.command(state, {:add_datebook_view, name, %Agendum.Core.Datebook{}})

    state
    |> State.switch_view(view_id)
    |> Agendum.TUI.Boxes.ViewProps.open(view_id)
  end

  defp resolve_choice(state, %{kind: :type} = mode, :unindexed),
    do: Properties.to_unindexed(state, state.db.categories[mode.cat_id])

  defp resolve_choice(state, %{kind: :type} = mode, :numeric),
    do: Properties.to_numeric(state, state.db.categories[mode.cat_id])

  defp resolve_choice(state, %{kind: :type} = mode, :date),
    do: Properties.to_date(state, state.db.categories[mode.cat_id])

  defp resolve_choice(state, mode, :new_child),
    do:
      Prompts.prompt(
        state,
        "New category for the conflicting items:",
        {:exclusive_new_child, mode.cat_id}
      )

  defp resolve_choice(state, mode, rule), do: apply_exclusive(state, mode.cat_id, rule)

  @doc "Makes a category's children exclusive with the given resolution and reports the result."
  def apply_exclusive(state, cat_id, rule) do
    name = state.db.categories[cat_id].name
    conflicts = length(Core.exclusive_conflicts(state.db, cat_id))

    case State.command(state, {:make_exclusive, cat_id, rule}) do
      {:ok, state, _} ->
        resolved =
          if conflicts == 0, do: "", else: "; #{conflicts} conflicting item(s) reassigned"

        State.info(state, "Children of #{name} are now mutually exclusive" <> resolved)

      {:error, :empty} ->
        State.error(state, "A category needs a name")

      {:error, :duplicate} ->
        State.error(state, "That category already exists under #{name}")

      {:error, :protected} ->
        State.error(state, "#{name} cannot have mutually exclusive children")
    end
  end
end
