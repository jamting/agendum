# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.SubscriptionPropsBox do
  @moduledoc """
  A feed's or a calendar's properties (F6 in the Feeds or Calendars
  manager; R75, R45; the owner's answers, 2026-10-27): its name, how often
  it is read, and how long a feed's entries stay or how far ahead a
  calendar reads, with its address and when it was last read shown. As the
  clone's settings boxes: SPACE goes round a choice, a letter picks one,
  F3 lists them; typing on Name renames it (and its category, R75a), F2
  edits the name; every change applies at once and is one undo step;
  ENTER closes the box, ESC closes it and puts back what was changed in
  it; F8 and ALT-F8 put a setting back to a new subscription's.

  The address is not changed here: a new address is a new subscription
  (unsubscribe, then subscribe), so a read under way never answers for
  another address. Drawn from `@layouts` (`Agendum.TUI.Boxes.Template`),
  one for a feed and one for a calendar. Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done, cancels: true

  alias Agendum.Core.DateFormat
  alias Agendum.Core.Extras.{Calendar, Feed}
  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.Extras.{Calendars, CalendarsBox, Feeds, FeedsBox}
  alias Agendum.TUI.{State, Typing.LineEdit}

  @layouts %{
    feed: """
     Name       : [name                          ]
     Address    : [address                                     ]
     Read every : [refresh                       ]
     Keep       : [keep                          ]
     Last read  : [last_read                     ]
    """,
    calendar: """
     Name       : [name                          ]
     Address    : [address                                     ]
     Read every : [refresh                       ]
     Read ahead : [ahead                         ]
     Last read  : [last_read                     ]
    """
  }

  # the fields the cursor stops at: the address and the last read are
  # only shown
  @shown [:address, :last_read]

  @help %{
    name: "Its name, and its category's. Type a new one; F2 edits it.",
    refresh: "How often Agendum reads it while running. SPACE for the next, F3 the list.",
    keep: "How long an entry you left alone stays. SPACE for the next, F3 the list.",
    ahead: "How far ahead its events are brought in. SPACE for the next, F3 the list."
  }

  @doc "Opens the box for the feed or calendar `id` (`kind` `:feed` or `:calendar`)."
  @spec open(State.t(), :feed | :calendar, pos_integer) :: State.t()
  def open(state, kind, id),
    do:
      State.push(state, %Agendum.TUI.Modes.SubscriptionProps{
        kind: kind,
        id: id,
        cursor: 0,
        typing: nil
      })

  # the subscription the box is for (nil once it is gone)
  defp subscription(state, %{kind: :feed, id: id}), do: state.db.feeds[id]
  defp subscription(state, %{kind: :calendar, id: id}), do: state.db.calendars[id]

  defp fields(mode), do: Template.fields(@layouts[mode.kind]) -- @shown
  defp grid(mode), do: Template.grid(@layouts[mode.kind], fields(mode))
  defp current(mode), do: Enum.at(fields(mode), mode.cursor)

  @impl Box
  def handle(state, mode, key) do
    cond do
      FieldTyping.typing?(mode) -> FieldTyping.key(state, mode, key, &typed/3)
      current(mode) == :name -> start_typing(state, mode, key)
      true -> state
    end
  end

  # a character on Name starts typing a new name
  defp start_typing(state, mode, {:char, c}) when c != " ",
    do: FieldTyping.start(state, mode, :name, c)

  defp start_typing(state, _mode, _key), do: state

  # the name typed: the subscription and its category renamed (R75a)
  defp typed(state, :name, text) do
    mode = State.mode(state)
    rename = if mode.kind == :feed, do: :rename_feed, else: :rename_calendar

    case State.command(state, {rename, mode.id, text}) do
      {:ok, state, _} ->
        state

      {:error, :empty_text} ->
        State.error(state, messages(mode).text(:no_name))

      {:error, :duplicate} ->
        State.error(state, messages(mode).text(:duplicate, String.trim(text)))
    end
  end

  defp messages(%{kind: :feed}), do: Feeds.Messages
  defp messages(%{kind: :calendar}), do: Calendars.Messages

  @impl Box
  def keymap(_mode), do: Box.settings_keymap(%{{:f, 2} => :edit})

  @impl Box
  def commands(_mode),
    do: Box.settings_commands([{:edit, "Edit", "Edit the name as it is"}])

  @impl Box
  def run(state, mode, :change), do: change(state, mode, current(mode), 1)

  def run(state, mode, :edit) do
    case {subscription(state, mode), current(mode)} do
      {sub, :name} when sub != nil ->
        State.put_mode(state, %{mode | typing: {:name, LineEdit.new(sub.name)}})

      _ ->
        state
    end
  end

  def run(state, mode, id), do: Box.run_settings(state, mode, grid(mode), id)

  # SPACE on a setting: its next choice, one undo step
  defp change(state, %{kind: :feed} = mode, field, step) when field in [:refresh, :keep],
    do: State.run(state, {:cycle_feed_setting, mode.id, setting(field), step})

  defp change(state, %{kind: :calendar} = mode, field, step) when field in [:refresh, :ahead],
    do: State.run(state, {:cycle_calendar_setting, mode.id, setting(field), step})

  defp change(state, _mode, _field, _step), do: state

  defp setting(:refresh), do: :refresh_minutes
  defp setting(:keep), do: :keep_days
  defp setting(:ahead), do: :ahead_days

  # F8 and ALT-F8 (R81c): a new subscription's settings, reached by the
  # steps between, as SPACE takes them
  @impl Box
  def defaults(_state, mode) do
    new = if mode.kind == :feed, do: %Feed{}, else: %Calendar{}

    for field <- fields(mode) -- [:name], into: %{} do
      {field, &back_to(&1, mode, field, Map.fetch!(new, setting(field)))}
    end
  end

  defp back_to(state, mode, field, default) do
    case subscription(state, mode) do
      nil -> state
      sub -> step_to(state, mode, field, Map.fetch!(sub, setting(field)), default)
    end
  end

  defp step_to(state, mode, field, value, default) do
    choices = choices(mode, field)
    from = Enum.find_index(choices, &(&1 == value)) || 0
    to = Enum.find_index(choices, &(&1 == default))
    if from == to, do: state, else: change(state, mode, field, to - from)
  end

  defp choices(%{kind: :feed}, :refresh), do: Feed.refresh_choices()
  defp choices(%{kind: :feed}, :keep), do: Feed.keep_choices()
  defp choices(%{kind: :calendar}, :refresh), do: Calendar.refresh_choices()
  defp choices(%{kind: :calendar}, :ahead), do: Calendar.ahead_choices()

  @impl Box
  def title(_state, %{kind: :feed}), do: "Feed Properties"
  def title(_state, %{kind: :calendar}), do: "Calendar Properties"

  @impl Box
  def width(state, _mode), do: min(state.width - 8, 64)

  @impl Box
  def content(state, mode, inner, _max_rows) do
    case subscription(state, mode) do
      nil ->
        [[{:box, " It is no longer subscribed."}]]

      sub ->
        Template.render(
          @layouts[mode.kind],
          values(state, mode, sub),
          [selected: current(mode)] ++ FieldTyping.editing(mode)
        ) ++ [[], Box.hint(keys(state, mode), inner)]
    end
  end

  defp values(state, mode, sub) do
    %{
      name: sub.name,
      address: sub.url,
      refresh: CalendarsBox.refresh(sub.refresh_minutes),
      last_read: last_read(state, sub)
    }
    |> Map.merge(
      if mode.kind == :feed,
        do: %{keep: FeedsBox.keep(sub.keep_days)},
        else: %{ahead: "#{sub.ahead_days} days"}
    )
  end

  defp last_read(_state, %{refreshed_at: nil}), do: "not read yet"
  defp last_read(state, sub), do: DateFormat.datetime(sub.refreshed_at, state.db.date_format)

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys([{"type", "Name"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: current(mode)

  @impl Box
  def about(_state, %{kind: kind}) do
    """
    A #{kind}'s settings. Type on Name to rename it and its category, F2 to
    edit the name. SPACE goes round Read every#{if kind == :feed, do: " and Keep", else: " and Read ahead"}, F3 lists the choices,
    F8 puts one back as a new #{kind} has it. Each change applies at once;
    ENTER closes the box, ESC puts back what you changed in it. The
    address cannot change: unsubscribe and subscribe again for another.
    """
  end
end
