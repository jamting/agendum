defmodule Agendum.TUI.AppEffectsTest do
  @moduledoc """
  Every effect the pure TUI asks for with `State.effect/2` must have a case
  in `Agendum.TUI.App.run_effects/2`, or the shell crashes with a
  `CaseClauseError` the moment it is asked (ALT-N on the last note rang a
  `:bell` that only the alarm path knew, 2026-10-17). `App` touches the
  terminal and is not unit-tested, so the sources are read: the effect's
  tag (`:bell`, `{:list_dir, …}`) must appear in `app.ex`.
  """
  use ExUnit.Case, async: true

  @tui "lib/agendum/tui"

  test "every effect asked for with State.effect/2 is handled by App" do
    app = File.read!(Path.join(@tui, "app.ex"))

    # `State.effect(:bell` or `State.effect({:list_dir, dir})`: the tag
    tags =
      Path.wildcard(Path.join(@tui, "**/*.ex"))
      |> Enum.flat_map(fn path ->
        Regex.scan(~r/State\.effect\(\{?:([a-z_]+)/, File.read!(path), capture: :all_but_first)
      end)
      |> List.flatten()
      |> Enum.uniq()

    assert "bell" in tags

    missing = Enum.reject(tags, &handled?(app, &1))
    assert missing == [], "effects with no case in App: #{inspect(missing)}"
  end

  # a case clause (`:bell ->`, `{:list_dir, dir} ->`), or the effects
  # taken out before `run_effects/2` (`{:play, _}`, `[:quit | _]`)
  defp handled?(app, tag) do
    String.contains?(app, ["{:#{tag},", "    :#{tag} ->", "[:#{tag} |", "{:#{tag}, _}"])
  end
end
