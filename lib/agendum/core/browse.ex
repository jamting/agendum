# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Browse do
  @moduledoc """
  Browsing dates (R47, R48; User's Guide 10-12 to 10-14): the date
  arithmetic of flipping a datebook's pages or moving a view's date filter,
  so that every front end browses alike. A front end keeps where the person
  has browsed to (a `t:place/0`) and asks this module what the view then
  shows, and which command keeps it.

  Pure: the clock comes in as an argument.
  """

  alias Agendum.Core.{Context, Database, Datebook, MonthCalendar, View}

  @typedoc """
  Where browsing has got to: a datebook's date (`%{date: date}`), or how
  far a view's or a section's date filter has moved
  (`%{scope: :view | {:section, index}, shift: %{days: n, months: n}}`).
  It may carry the front end's own keys too (the TUI keeps it in its mode);
  they are kept as they are.
  """
  @type place ::
          %{required(:date) => Date.t(), optional(atom) => term}
          | %{required(:scope) => scope, required(:shift) => shift, optional(atom) => term}
  @type scope :: :view | {:section, non_neg_integer}
  @type shift :: %{days: integer, months: integer}

  @no_shift %{days: 0, months: 0}

  # how far each move goes in a date filter (a datebook goes a period)
  @moves %{
    earlier: {:days, -1},
    later: {:days, 1},
    week_earlier: {:days, -7},
    week_later: {:days, 7},
    month_earlier: {:months, -1},
    month_later: {:months, 1},
    year_earlier: {:months, -12},
    year_later: {:months, 12}
  }

  @doc """
  Where browsing starts in a view: its datebook's date, or its date
  filter's, the section's (`sidx`) when that one has a date filter, else
  the view's. Nil when there is nothing to browse.
  """
  @spec start(Database.t(), View.t(), non_neg_integer | nil, Context.clock()) :: place | nil
  def start(db, %View{datebook: %Datebook{} = d}, _sidx, clock),
    do: %{date: Datebook.base_date(d, db.date_settings, clock)}

  def start(db, view, sidx, _clock) do
    section = sidx && Enum.at(view.sections, sidx)

    cond do
      section && Agendum.Core.Facade.Views.date_filters?(db, section.filter) ->
        %{scope: {:section, sidx}, shift: @no_shift}

      Agendum.Core.Facade.Views.date_filters?(db, view.filter) ->
        %{scope: :view, shift: @no_shift}

      true ->
        nil
    end
  end

  @doc """
  One move: in a datebook, `:earlier` and `:later` go a period (a day, a
  week, a month or a quarter); in a filter, by a day, a week
  (`:week_earlier`…), a month or a year. A move that does not apply leaves
  the place as it is.
  """
  @spec move(View.t(), place, atom) :: place
  # a datebook's place has a date; a filter's a shift (a front end's struct
  # may have both keys, one nil, so the patterns look at the values)
  def move(%View{datebook: %Datebook{period: period}}, %{date: %Date{} = date} = place, id)
      when id in [:earlier, :later] do
    n = if id == :earlier, do: -1, else: 1

    date =
      case period do
        :quarter -> MonthCalendar.move(date, :month, 3 * n)
        unit -> MonthCalendar.move(date, unit, n)
      end

    %{place | date: date}
  end

  def move(_view, %{shift: %{} = shift} = place, id) when is_map_key(@moves, id) do
    {unit, n} = @moves[id]
    %{place | shift: Map.update!(shift, unit, &(&1 + n))}
  end

  def move(_view, place, _id), do: place

  @doc """
  Goes to a date: a datebook shows its period; a filter moves so that its
  range starts on it (or ends on it, when it has no start).
  """
  @spec go_to(Database.t(), View.t(), place, Date.t(), Context.clock()) :: place
  def go_to(_db, _view, %{date: %Date{}} = place, date, _clock), do: %{place | date: date}

  def go_to(db, view, place, date, clock) do
    case first_date(db, shown(db, view, place, clock), place.scope, clock) do
      nil -> place
      from -> %{place | shift: Map.update!(place.shift, :days, &(&1 + Date.diff(date, from)))}
    end
  end

  @doc "The view as it shows while browsed: with the browsed dates, nothing kept."
  @spec shown(Database.t(), View.t(), place, Context.clock()) :: View.t()
  def shown(_db, view, %{date: %Date{} = date}, _clock),
    do: %{view | datebook: %{view.datebook | base: Date.to_iso8601(date)}}

  def shown(db, view, %{scope: scope, shift: shift}, clock) do
    shifted = Agendum.Core.Facade.Views.shift_filters(db, filters(view, scope), shift, clock)
    put_filters(view, scope, shifted)
  end

  @doc """
  The command that keeps what is shown (ENTER): the datebook's base date,
  or the filter's dates fixed; nil when nothing moved.
  """
  @spec keep(Database.t(), View.t(), place, Context.clock()) :: Agendum.Core.Command.t() | nil
  def keep(db, %View{datebook: %Datebook{} = d} = view, %{date: %Date{} = date}, clock) do
    if date == Datebook.base_date(d, db.date_settings, clock),
      do: nil,
      else: {:set_datebook, view.id, %{d | base: Date.to_iso8601(date)}}
  end

  def keep(_db, _view, %{shift: @no_shift}, _clock), do: nil

  def keep(db, view, %{scope: scope} = place, clock),
    do: {:set_filters, view.id, scope, filters(shown(db, view, place, clock), scope)}

  # the first date a date filter shows: its range's start, else its end
  defp first_date(db, view, scope, clock) do
    Enum.find_value(filters(view, scope), fn
      {cat, {:range, from, to, _}} ->
        if Agendum.Core.Facade.Views.date_filters?(db, [{cat, {:range, from, to, :inside}}]) do
          with text when text != nil <- from || to,
               {:ok, date, _} <- Agendum.Core.Facade.Dates.read_when(db, text, clock),
               do: date,
               else: (_ -> nil)
        end

      _ ->
        nil
    end)
  end

  defp filters(view, :view), do: view.filter
  defp filters(view, {:section, i}), do: Enum.at(view.sections, i).filter

  defp put_filters(view, :view, filters), do: %{view | filter: filters}

  defp put_filters(view, {:section, i}, filters),
    do: %{view | sections: List.update_at(view.sections, i, &%{&1 | filter: filters})}
end
