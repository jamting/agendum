defmodule Agenda.TUI.CategoryScreens.Choices do
  @moduledoc """
  Choice boxes and the hierarchy changes behind them: making children
  mutually exclusive (Figure 16-10) and moving categories (promote, demote,
  move; Figure 16-16), with their conflicts; also the boxes for a
  category's type, Learn mode and a new view's type. Pure.
  """

  alias Agenda.Core
  alias Agenda.Core.Database
  alias Agenda.TUI.{CategoryScreens, State}
  alias Agenda.TUI.CategoryScreens.Properties
  alias Agenda.TUI.Update.Prompts

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
        state
        |> State.change_db(Core.make_unexclusive(state.db, cat.id))
        |> State.info("Children of #{cat.name} are no longer mutually exclusive")

      Database.protected?(state.db, cat.id) ->
        State.error(state, "#{cat.name} cannot have mutually exclusive children")

      Core.exclusive_conflicts(state.db, cat.id) == [] ->
        apply_exclusive(state, cat.id, :parent)

      true ->
        conflicts = length(Core.exclusive_conflicts(state.db, cat.id))

        State.push(state, %{
          type: :choice,
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
      {"Numeric", "A number for each item: totals and averages; children become numbers",
       :numeric},
      {"Date", "A date and time for each item; children become dates; cannot change back", :date}
    ]

  def choice_options(%{kind: :learn}),
    do: [
      {"Replace", "Record new keystrokes instead of the macro's", :replace},
      {"Append", "Record keystrokes to add after the macro's", :append}
    ]

  def choice_options(%{kind: :view_type}),
    do: [
      {"Standard", "Sections headed by categories you choose", :standard},
      {"Datebook", "Sections for the hours, days, weeks or months of a period", :datebook}
    ]

  def choice_lines(%{kind: :learn}),
    do: ["The macro already has keystrokes.", "Learn mode should:"]

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
        State.push(state, %{
          type: :choice,
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

    case Core.relocate(state.db, id, relocation, rule) do
      {:ok, db} ->
        state = state |> State.change_db(db) |> CategoryScreens.move_cursor_to(id)

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
    do: Agenda.TUI.Macros.learn(state, state.db.macros[id], how)

  defp resolve_choice(state, %{kind: :view_type, name: name}, :standard),
    do: CategoryScreens.open_picker(state, {:new_view, name}, nil)

  # a datebook view with Agenda's defaults (When, a week from today), then
  # its settings (R47)
  defp resolve_choice(state, %{kind: :view_type, name: name}, :datebook) do
    {:ok, db, view_id} = Core.add_datebook_view(state.db, name, %Agenda.Core.Datebook{})

    state
    |> State.change_db(db)
    |> State.switch_view(view_id)
    |> Agenda.TUI.DatebookBox.open(view_id)
  end

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

    case Core.make_exclusive(state.db, cat_id, rule) do
      {:ok, db} ->
        resolved =
          if conflicts == 0, do: "", else: "; #{conflicts} conflicting item(s) reassigned"

        state
        |> State.change_db(db)
        |> State.info("Children of #{name} are now mutually exclusive" <> resolved)

      {:error, :empty} ->
        State.error(state, "A category needs a name")

      {:error, :duplicate} ->
        State.error(state, "That category already exists under #{name}")

      {:error, :protected} ->
        State.error(state, "#{name} cannot have mutually exclusive children")
    end
  end
end
