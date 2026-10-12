defmodule Agenda.TUI.Splash do
  @moduledoc """
  The splash screen (SPEC R52), laid out as Agenda 2.0's: a box over an
  empty screen with the WOL block, the title spaced out, the tagline, the
  release, the copyright, the person's name and company, and a word on
  sharing. Any key, or three seconds, lets the program start (`Update`
  and `Update.tick/2`). Pure.
  """

  alias Agenda.TUI.{Draw, State}

  @version Mix.Project.config()[:version]
  @seconds 3

  @doc "Puts the splash screen over the program, until a key or three seconds."
  def open(state) do
    until = NaiveDateTime.add(state.now, @seconds)
    %{state | modes: [%{type: :splash, until: until} | state.modes]}
  end

  @doc "Takes the splash away, leaving the prompt under it as typed."
  def close(%State{modes: [%{type: :splash} | rest]} = state), do: %{state | modes: rest}

  @doc "Whether its time is up at `now`."
  def over?(%{until: until}, now), do: NaiveDateTime.compare(now, until) != :lt

  @doc "The whole screen: the box, centred, with its shadow."
  def render(%State{width: w, height: h} = state) do
    inner = min(w - 8, 60)
    content = content(state, inner)
    box = Draw.box("", content, inner) |> Enum.map(&Draw.paint(&1, %{box_title: :box_frame}))
    top = max(div(h - length(box), 2), 0)
    left = div(w - inner - 2, 2)

    List.duplicate([], h)
    |> Enum.map(&Draw.line(&1, w))
    |> Draw.overlay(box, top, left)
    |> Draw.shadow(top, left, length(box), inner + 2)
  end

  defp content(state, inner) do
    prefs = state.prefs
    logo = &{:splash_logo, Draw.pad(&1, 7)}
    text = fn indent, segments -> [{:box, Draw.spaces(indent)} | segments] end

    name = prefs.name || prefs.user

    people =
      [{"Name", name}, {"Company", prefs.company}]
      |> Enum.reject(&(elem(&1, 1) in [nil, ""]))
      |> Enum.map(fn {label, value} ->
        [{:box, Draw.rpad(label <> ": ", 15)}, {:splash_value, value}]
      end)

    sharing =
      "Use, duplication and sharing of this program are welcome. Violators may be offered a small something."
      |> Draw.wrap(inner - 16)
      |> Enum.map(&text.(15, [{:box, &1}]))

    [
      [],
      text.(2, [logo.(" WOL"), {:box, "    "}, {:splash_title, "W O L ' S   A G E N D U M"}]),
      text.(2, [logo.(""), {:box, "    "}]),
      text.(2, [logo.(""), {:box, "    "}, {:splash_title, "Hoo's in control? You are."}]),
      [],
      [],
      text.(15, [{:splash_value, "Release #{@version}"}]),
      [],
      text.(15, [{:box, "Copyright JW&D + WOL."}]),
      text.(15, [{:box, "All rites reserved."}]),
      []
    ] ++ people ++ [[]] ++ sharing ++ [[]]
  end
end
