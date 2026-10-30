# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Links do
  @moduledoc """
  A bidirectional many-to-many relation between two kinds of ids.

  This is the functional equivalent of the "independent link structures" in
  US patent 5,115,504: each link is independent of the objects it joins, and
  it can be reached from either side. The patent chains link structures with
  pointers; here we keep two indexes (`left -> rights` and `right -> lefts`)
  that are always updated together.

  It is used for item <-> category assignments, but is deliberately generic.
  """

  @type id :: term()
  @type t :: %__MODULE__{
          by_left: %{optional(id) => MapSet.t(id)},
          by_right: %{optional(id) => MapSet.t(id)}
        }

  defstruct by_left: %{}, by_right: %{}

  @spec new() :: t
  def new, do: %__MODULE__{}

  @spec link(t, id, id) :: t
  def link(%__MODULE__{} = links, left, right) do
    %__MODULE__{
      by_left: add(links.by_left, left, right),
      by_right: add(links.by_right, right, left)
    }
  end

  @spec unlink(t, id, id) :: t
  def unlink(%__MODULE__{} = links, left, right) do
    %__MODULE__{
      by_left: delete(links.by_left, left, right),
      by_right: delete(links.by_right, right, left)
    }
  end

  @spec linked?(t, id, id) :: boolean
  def linked?(%__MODULE__{by_left: by_left}, left, right) do
    by_left |> Map.get(left, MapSet.new()) |> MapSet.member?(right)
  end

  @doc "All right-hand ids linked to `left`."
  @spec rights(t, id) :: MapSet.t(id)
  def rights(%__MODULE__{by_left: by_left}, left), do: Map.get(by_left, left, MapSet.new())

  @doc "All left-hand ids linked to `right`."
  @spec lefts(t, id) :: MapSet.t(id)
  def lefts(%__MODULE__{by_right: by_right}, right), do: Map.get(by_right, right, MapSet.new())

  @doc "Removes every link touching `left`."
  @spec drop_left(t, id) :: t
  def drop_left(%__MODULE__{} = links, left) do
    Enum.reduce(rights(links, left), links, &unlink(&2, left, &1))
  end

  @doc "Removes every link touching `right`."
  @spec drop_right(t, id) :: t
  def drop_right(%__MODULE__{} = links, right) do
    Enum.reduce(lefts(links, right), links, &unlink(&2, &1, right))
  end

  @doc "Total number of links."
  @spec size(t) :: non_neg_integer
  def size(%__MODULE__{by_left: by_left}) do
    by_left |> Map.values() |> Enum.map(&MapSet.size/1) |> Enum.sum()
  end

  defp add(index, key, value) do
    Map.update(index, key, MapSet.new([value]), &MapSet.put(&1, value))
  end

  defp delete(index, key, value) do
    case Map.fetch(index, key) do
      {:ok, set} ->
        set = MapSet.delete(set, value)
        if MapSet.size(set) == 0, do: Map.delete(index, key), else: Map.put(index, key, set)

      :error ->
        index
    end
  end
end
