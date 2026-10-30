# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Splash do
  @moduledoc """
  The splash screen (SPEC R52), laid out as Agenda 2.0's: a box over an
  empty screen with the owl and WOL, the title spaced out, the tagline, the
  release, the copyright, the person's name and company, and a word on
  sharing. Any key, or five seconds, lets the program start (`Update`
  and `Update.tick/2`). Pure.
  """

  alias Agendum.TUI.{Boxes.Template, Terminal.Draw, State}

  @version Mix.Project.config()[:version]
  @seconds 5

  @doc "Puts the splash screen over the program, until a key or five seconds."
  def open(state) do
    until = NaiveDateTime.add(state.now, @seconds)
    %{state | modes: [%Agendum.TUI.Modes.Splash{until: until} | state.modes]}
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
    top = max(div(h - length(box) - 5, 2), 0)
    left = div(w - inner - 2, 2)

    List.duplicate([], h)
    |> Enum.map(&Draw.line(&1, w))
    |> Draw.overlay(box, top, left)
    |> Draw.shadow(top, left, length(box), inner + 2)
  end

  # Agenda's splash, written as it looks (`Agendum.TUI.Boxes.Template`): the
  # owl and the WOL letters stand on the box itself (the owner's wish,
  # 2026-10-25: no block around the logo); a row whose value is missing,
  # such as Company, is left out. `~S` keeps the owl's backslash as it is
  @layout ~S"""

        .___,        [title                        ]
     ___('v')___
     `"-\._./-"'     [tagline                      ]
         ^ ^
        W O L        [release                      ]

      Copyright 2026 WOL and JW&D - All rights reversed

              Name:  [name                         ]
           Company:  [company                      ]
  """

  @sharing "PLES HELP. WE ARE TRYING THINGS OWT RIGHT NOW. " <>
             "STAY IN TUCH. - WOL"

  defp content(state, inner) do
    prefs = state.prefs

    values = %{
      title: [{:splash_title, "W O L ' S   A G E N D U M"}],
      tagline: [{:splash_title, "Hoo's in control? You are."}],
      release: [{:splash_value, "Release #{@version}"}],
      name: value(prefs.name || prefs.user),
      company: value(prefs.company)
    }

    sharing =
      @sharing
      |> Draw.wrap(inner - 8)
      |> Enum.map(&[{:box, "    " <> &1}])

    Template.render(@layout, values) ++ [[]] ++ sharing ++ [[]]
  end

  # nil leaves the row out
  defp value(text) when text in [nil, ""], do: nil
  defp value(text), do: [{:splash_value, text}]
end
