# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.BoxGuidelinesTest do
  @moduledoc """
  The rules of `docs/UI_GUIDELINES.md` a test can hold, over every box in
  the registry (`Agendum.TUI.Boxes.Box.registry/0`), so a box added later
  is checked too (the owner's answers, 2026-10-27): 1.1, a settings box is
  drawn from a `Template` layout; 1.9, every field of every settings box
  has help; 6.2, no box writes its key hints by hand.

  A box that breaks a rule today is listed with the reason; the list must
  stay true, so a box fixed (by the extras' rework, ROADMAP In order 1)
  leaves it and cannot slip back.
  """
  use ExUnit.Case, async: true

  import Agendum.TUIHelpers
  alias Agendum.TUI.{CategoryScreens, State}
  alias Agendum.TUI.Boxes.{Box, FieldHelp}

  # the settings boxes: those with a help text for each field (`help/0`
  # returns a map), but the category picker, a list whose one help is
  # Agenda's top line for Section Select (R78)
  @settings Map.delete(FieldHelp.boxes(), :picker)

  # 1.1's exceptions: settings boxes not drawn from a layout (none today)
  @no_template %{}

  # 6.2's exceptions: boxes with a key hint written by hand, not made from
  # their keys with `Box.hint/2` (the UI guidelines' gap 4)
  @hand_hints %{
    publish_preview: "the extras' rework (gap 4)"
  }

  # a box's module, read as code (`Code.string_to_quoted/1`): its source
  defp ast(module) do
    {:ok, ast} = module.module_info(:compile)[:source] |> File.read!() |> Code.string_to_quoted()
    ast
  end

  # whether the compiled module calls into `Template` (its BEAM's imports:
  # the functions of other modules it calls)
  defp uses_template?(module) do
    {:ok, {_, [imports: imports]}} = :beam_lib.chunks(:code.which(module), [:imports])
    Enum.any?(imports, fn {mod, _fun, _arity} -> mod == Agendum.TUI.Boxes.Template end)
  end

  # a text that reads as a list of keys: a key, a word, and a "·" further
  # on (" INS subscribe · ENTER read now"); "N = marked items" is a legend
  @hint ~r/^\s*(INS|DEL|ENTER|ESC|SPACE|TAB|F\d+|ALT-\S+|CTRL-\S+|[A-Z](\/[A-Z])?)\s+[a-z].*·/

  defp hand_hints(module) do
    # `Macro.prewalk/3` visits every node of the code, carrying `acc`
    {_ast, found} =
      Macro.prewalk(ast(module), [], fn
        text, acc when is_binary(text) ->
          {text, if(Regex.match?(@hint, text), do: [text | acc], else: acc)}

        node, acc ->
          {node, acc}
      end)

    found
  end

  test "1.1: every settings box is drawn from a Template layout" do
    without =
      for {type, module} <- @settings, not uses_template?(module), into: %{}, do: {type, module}

    assert Map.keys(without) |> Enum.sort() == Map.keys(@no_template) |> Enum.sort(),
           "not drawn from a layout: #{inspect(Map.keys(without))}"
  end

  test "6.2: no box writes its key hints by hand" do
    found = for {type, module} <- Box.registry(), hand_hints(module) != [], do: type

    assert Enum.sort(found) == Enum.sort(Map.keys(@hand_hints)),
           "hints written by hand: #{inspect(found -- Map.keys(@hand_hints))}; " <>
             "fixed, so off the list: #{inspect(Map.keys(@hand_hints) -- found)}"
  end

  test "7.5: an extra's boxes write no message of their own; it is in the extra's Messages" do
    # a call to State.error/info or a prompt or question whose text is
    # written out ("…" or "…#{x}…") in the box's code
    says? = fn
      {{:., _, [{:__aliases__, _, alias}, fun]}, _, [_state, text | _]} ->
        {alias, fun} in [
          {[:State], :error},
          {[:State], :info},
          {[:Prompts], :prompt},
          {[:Prompts], :ask}
        ] and
          (is_binary(text) or match?({:<<>>, _, _}, text))

      _ ->
        false
    end

    found =
      for path <- Path.wildcard("lib/agendum/tui/extras/*_box.ex"),
          {:ok, ast} = path |> File.read!() |> Code.string_to_quoted(),
          {_, hits} =
            Macro.prewalk(ast, [], fn node, acc ->
              {node, if(says?.(node), do: [node | acc], else: acc)}
            end),
          hits != [],
          do: Path.basename(path)

    assert found == [], "messages written in the box: #{inspect(found)}"
  end

  describe "1.9: every field of every settings box has help" do
    setup do
      db =
        Agendum.Starters.Planner.build() |> Agendum.Starters.Planner.with_samples(~D[2026-10-08])

      {people, _} = Enum.find(db.views, fn {_, v} -> v.name == "People" end)
      %{state: db |> start(width: 80, height: 25) |> State.switch_view(people)}
    end

    test "each settings box in the registry is opened and walked", %{state: state} do
      openers = openers()

      assert Enum.sort(Map.keys(openers)) == Enum.sort(Map.keys(@settings)),
             "settings boxes without an opener here: #{inspect(Map.keys(@settings) -- Map.keys(openers))}"

      for {type, open} <- openers do
        box = open.(state)
        assert %{type: ^type} = State.mode(box), "#{type} opened #{State.mode(box).type}"
        refute nil in walk(box), "#{type}: a field without help"
      end
    end
  end

  # the help of every field of the box on top, moving down until the
  # cursor stops
  defp walk(state, seen \\ []) do
    help = FieldHelp.text(state)
    next = press(state, :down)

    if Map.get(State.mode(next), :cursor) == Map.get(State.mode(state), :cursor),
      do: Enum.reverse([help | seen]),
      else: walk(next, [help | seen])
  end

  # how each settings box is opened, from the Planner's People view with
  # the highlight on its first section head (↓ to its first item, → to its
  # Priority column, → again to When)
  defp openers do
    %{
      file_props: &menu(&1, "fp"),
      date_settings: &(&1 |> menu("fp") |> sub("Global date settings")),
      display_format: &(&1 |> menu("fp") |> sub("Global date settings") |> sub("Display format")),
      input_format: &(&1 |> menu("fp") |> sub("Global date settings") |> sub("Input format")),
      auto_assign: &(&1 |> menu("fp") |> sub("Auto-assign settings")),
      item_props: &press(&1, [:down, {:f, 6}]),
      props: &cat_props(&1, "Calls"),
      category_match: &(&1 |> cat_props("Calls") |> sub("Advanced settings")),
      date_rule: &(&1 |> cat_props("When") |> sub("Advanced settings")),
      view_props: &menu(&1, "vvp"),
      sort: &(&1 |> menu("vvp") |> sub("Item sorting")),
      section_props: &menu(&1, "vvsp"),
      column_props: &(&1 |> press([:down, :right]) |> menu("vvcp")),
      column_add: &menu(&1, "vvca"),
      item_column: &(&1 |> press(:down) |> menu("vvcp")),
      customize: &menu(&1, "uc"),
      execute: &menu(&1, "ue"),
      schedule: &menu(&1, "uss"),
      set_alarm: &(&1 |> press(:down) |> menu("ia")),
      search_box: &press(&1, {:alt_f, 6}),
      macro_props: &press(&1, [{:alt_f, 3}, {:f, 6}]),
      new_file: &Agendum.TUI.Boxes.NewFileBox.open(&1, "new.agendum"),
      numeric_functions: &Agendum.TUI.Boxes.NumericFunctionsBox.open(&1, 0),
      action_box: &Agendum.TUI.Boxes.ActionBox.open(&1, cat(&1, "Calls"), cat(&1, "When")),
      range_filter: &Agendum.TUI.Boxes.RangeFilterBox.open(&1, :view, cat(&1, "When")),
      what_to_copy: &Agendum.TUI.Boxes.WhatToCopyBox.open(&1, :copy, :line),
      publish: &Agendum.TUI.Extras.PublishBox.open/1,
      # kept by the file's path, so the file needs one
      publish_upload: &Agendum.TUI.Extras.UploadBox.open(%{&1 | path: "/owl/blog.agendum"}),
      subscription_props: &subscription_props/1
    }
  end

  # a feed's properties, for a feed subscribed to first
  defp subscription_props(state) do
    {:ok, db, id} =
      Agendum.Core.subscribe_feed(state.db, "Owl's Gazette", "https://o.example/rss")

    Agendum.TUI.Extras.SubscriptionPropsBox.open(%{state | db: db}, :feed, id)
  end

  defp menu(state, letters), do: press(state, [{:f, 10} | String.graphemes(letters)])
  defp sub(state, label), do: state |> to_setting(label) |> press(" ")
  defp cat_props(state, name), do: CategoryScreens.open_props(state, cat(state, name))

  defp cat(state, name) do
    {id, _} = Enum.find(state.db.categories, fn {_, c} -> c.name == name end)
    id
  end
end
