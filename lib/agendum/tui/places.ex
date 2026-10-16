defmodule Agendum.TUI.Places do
  @moduledoc """
  Where the person left a file (R69; meeting 2026-10-16, § 5): the view
  shown and the highlighted item, and the views used lately with how the
  view manager lists them (R68, § 8), kept in their preferences by the file's
  path (`Agendum.Preferences.Place`), never in the file, so moving around
  never makes the file "changed".

  `remember/1` puts the place into `state.prefs` when the file is left (by
  Quit, or by Retrieve, New or Import opening another); `restore/1` goes
  back to it when the file is opened again: the view, then the item in the
  section it was in; failing that the section, failing that the top of
  the view. A view that is gone leaves the file on its first view. Pure:
  the shell saves the preferences.
  """

  alias Agendum.Preferences
  alias Agendum.Preferences.Place
  alias Agendum.TUI.{Layout, State}

  @doc "Keeps where the person is in the open file in their preferences; nothing for an untitled file."
  @spec remember(State.t()) :: State.t()
  def remember(%State{path: nil} = state), do: state

  def remember(%State{} = state) do
    # the cursor's key says what it rests on: an item in a section, or a
    # section head (`Agendum.TUI.Layout`)
    {section, item} =
      case state.cursor_key do
        {:item, section, item} -> {section, item}
        {:section, section} -> {section, nil}
        nil -> {nil, nil}
      end

    place = %Place{
      view: state.view_id,
      section: section,
      item: item,
      recent: Place.recent([state.view_id | state.views.recent]),
      by_recent: state.views.by_recent
    }

    %{state | prefs: Preferences.put_place(state.prefs, state.path, place)}
  end

  @doc "Goes back to where the person left the file, as far as it is still there."
  @spec restore(State.t()) :: State.t()
  def restore(%State{} = state) do
    case Preferences.place(state.prefs, state.path) do
      nil ->
        state

      place ->
        state = %{state | views: %{recent: place.recent, by_recent: place.by_recent}}

        if place.view in state.db.view_order,
          do: to_row(%{state | view_id: place.view}, place),
          else: state
    end
  end

  # the item in its section, else the section head, else the top
  defp to_row(state, %Place{section: section, item: item}) do
    keys = state |> Layout.rows() |> Enum.map(& &1.key)

    key =
      Enum.find([{:item, section, item}, {:section, section}], &(&1 in keys)) ||
        List.first(keys)

    Layout.settle(%{state | cursor: 0, cursor_key: key})
  end
end
