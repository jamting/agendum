# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Template do
  @moduledoc """
  The site's templates (R74; meeting 2026-11-02-1255, § 7): a small,
  logic-less language in the Mustache style, read by Agendum's own reader.
  Nothing in a template runs code, so a site folder copied from somewhere
  else is only text (Elixir's EEx was ruled out: its templates run code).
  Pure.

    * `{{name}}` a value, escaped for HTML (inside an attribute too); in a
      template whose name ends in `.xml` (`rss.xml`), for XML, `'` as
      `&apos;` too
    * `{{{name}}}` a value as it is: only the post's body needs it, which
      Agendum's Markdown has made safe already
    * `{{a.b}}` a value inside another; a name not found is empty
    * `{{#name}}…{{/name}}` once for each item of a list, once for a true
      value (the value is then `{{.}}`), never for an empty or false one;
      names not in the item are looked up outside it
    * `{{^name}}…{{/name}}` only when the value is empty or false
    * `{{> name}}` the template `templates/name.html` (`{{> rss.xml}}`
      one by its whole name)
    * `{{! …}}` a comment

  `parse/1` refuses a mistake with its line; `render/4` one that only
  shows when the parts are put together (a missing partial, one that
  includes itself, or templates that would grow without end: at most
  #{50} included in one another, #{100_000} inclusions in all). The
  mistakes are atoms and tuples; the front end words them.
  """

  @typedoc "A mistake in a template's text, on its line."
  @type mistake ::
          :tag_not_closed
          | {:not_closed, String.t()}
          | {:closes_nothing, String.t()}
          | {:closes, String.t(), String.t()}

  @typedoc "A mistake found putting templates together."
  @type render_error :: {:no_partial, String.t()} | {:includes_itself, String.t()} | :too_big

  @depth 50
  @budget 100_000

  @typedoc "A parsed template."
  @type t :: [node_]
  @typep node_ ::
           {:text, String.t()}
           | {:var, [String.t()], boolean}
           | {:section, [String.t()], boolean, t}
           | {:partial, String.t()}

  @doc """
  A template's file in `templates/` by its name: `post` is `post.html`, a
  name with its own extension (`rss.xml`) is that file.
  """
  @spec file(String.t()) :: String.t()
  def file(name), do: if(Path.extname(name) == "", do: name <> ".html", else: name)

  @doc "A template's text parsed, or its first mistake and the line it is on."
  @spec parse(String.t()) :: {:ok, t} | {:error, {pos_integer, mistake}}
  def parse(text) do
    text |> tokens() |> build([], [])
  catch
    {:mistake, line, message} -> {:error, {line, message}}
  end

  # --- reading -------------------------------------------------------------------

  # Domain: the text is cut at each tag; `{{{` is tried before `{{`, as it
  # starts with it. Each token carries the line it starts on, for messages.
  defp tokens(text), do: tokens(text, 1, [])

  defp tokens("", _line, acc), do: Enum.reverse(acc)

  defp tokens(text, line, acc) do
    case :binary.match(text, "{{") do
      :nomatch ->
        Enum.reverse([{:text, text, line} | acc])

      {at, 2} ->
        # `at` is a byte offset, so the text is cut by bytes
        {before, rest} = {binary_part(text, 0, at), binary_part(text, at, byte_size(text) - at)}
        acc = if before == "", do: acc, else: [{:text, before, line} | acc]
        line = line + newlines(before)
        {tag, rest} = tag(rest, line)
        tokens(rest, line + newlines(tag_text(tag)), [{:tag, tag, line} | acc])
    end
  end

  defp tag("{{{" <> rest, line), do: closed(rest, "}}}", line, :raw)
  defp tag("{{" <> rest, line), do: closed(rest, "}}", line, :tag)

  defp closed(rest, close, line, kind) do
    case :binary.split(rest, close) do
      [inside, after_] -> {{kind, inside}, after_}
      [_] -> throw({:mistake, line, :tag_not_closed})
    end
  end

  defp tag_text({_kind, inside}), do: inside
  defp newlines(text), do: length(:binary.matches(text, "\n"))

  # the tokens as a tree; `open` is the stack of sections still open, each
  # with what came before it
  defp build([], [], acc), do: {:ok, Enum.reverse(acc)}

  defp build([], [{name, _inverted, line, _before} | _], _acc),
    do: throw({:mistake, line, {:not_closed, name}})

  defp build([{:text, text, _line} | rest], open, acc),
    do: build(rest, open, [{:text, text} | acc])

  defp build([{:tag, {:raw, inside}, _line} | rest], open, acc),
    do: build(rest, open, [{:var, path(inside), false} | acc])

  defp build([{:tag, {:tag, inside}, line} | rest], open, acc) do
    case String.trim(inside) do
      "!" <> _comment -> build(rest, open, acc)
      "#" <> name -> build(rest, [{String.trim(name), false, line, acc} | open], [])
      "^" <> name -> build(rest, [{String.trim(name), true, line, acc} | open], [])
      ">" <> name -> build(rest, open, [{:partial, String.trim(name)} | acc])
      "/" <> name -> close(rest, open, acc, String.trim(name), line)
      name -> build(rest, open, [{:var, path(name), true} | acc])
    end
  end

  defp close(rest, [{name, inverted, _at, before} | open], acc, name, _line),
    do: build(rest, open, [{:section, path(name), inverted, Enum.reverse(acc)} | before])

  defp close(_rest, [{other, _, _, _} | _], _acc, name, line),
    do: throw({:mistake, line, {:closes, name, other}})

  defp close(_rest, [], _acc, name, line),
    do: throw({:mistake, line, {:closes_nothing, name}})

  defp path("."), do: ["."]
  defp path(name), do: name |> String.trim() |> String.split(".")

  # --- writing -------------------------------------------------------------------

  @doc """
  The template filled in from `context` (maps with string keys, lists,
  strings, numbers, booleans), with `partials` (name to parsed template)
  for `{{> name}}`; `name` is the template's own, so including itself is
  found at once, and one whose name ends in `.xml` escapes for XML.
  """
  @spec render(t, map, %{optional(String.t()) => t}, String.t() | nil) ::
          {:ok, String.t()} | {:error, render_error}
  def render(tree, context, partials, name \\ nil) do
    # Domain: the escaping is chosen once, by the template drawn, and its
    # partials share it: an `.xml` feed including an `.html` part still
    # escapes as XML
    xml? = is_binary(name) and String.ends_with?(name, ".xml")
    env = %{partials: partials, within: List.wrap(name), xml: xml?}
    {out, _budget} = fill(tree, [context], env, @budget)
    {:ok, IO.iodata_to_binary(out)}
  catch
    {:render, error} -> {:error, error}
  end

  # `stack` holds the values sections stepped into, the innermost first;
  # `env.within` the partials being filled, to find one that includes
  # itself. `budget` counts down the templates included, so templates that
  # include each other many times over stop instead of growing without end
  # (a site folder copied from elsewhere must not hang Agendum); values and
  # sections are bounded by the posts, however many, so they do not count.
  defp fill(tree, stack, env, budget),
    do: Enum.map_reduce(tree, budget, &fill_node(&1, stack, env, &2))

  defp fill_node({:text, text}, _stack, _env, budget), do: {text, budget}

  defp fill_node({:var, path, escape?}, stack, env, budget) do
    value = stack |> lookup(path) |> text()
    {if(escape?, do: esc(value, env.xml), else: value), budget}
  end

  defp fill_node({:section, path, false, body}, stack, env, budget) do
    case lookup(stack, path) do
      list when is_list(list) ->
        Enum.map_reduce(list, budget, &fill(body, [&1 | stack], env, &2))

      value ->
        if empty?(value), do: {[], budget}, else: fill(body, [value | stack], env, budget)
    end
  end

  defp fill_node({:section, path, true, body}, stack, env, budget) do
    if empty?(lookup(stack, path)), do: fill(body, stack, env, budget), else: {[], budget}
  end

  defp fill_node({:partial, name}, stack, env, budget) do
    cond do
      budget <= 0 -> throw({:render, :too_big})
      name in env.within -> throw({:render, {:includes_itself, name}})
      not Map.has_key?(env.partials, name) -> throw({:render, {:no_partial, name}})
      length(env.within) >= @depth -> throw({:render, :too_big})
      true -> fill(env.partials[name], stack, %{env | within: [name | env.within]}, budget - 1)
    end
  end

  # `.` is the value stepped into; a name is the innermost value that is a
  # map holding it, then each part after the first a value inside that
  defp lookup([top | _], ["."]), do: top

  defp lookup(stack, [first | rest]) do
    case Enum.find(stack, &(is_map(&1) and Map.has_key?(&1, first))) do
      nil -> nil
      map -> Enum.reduce(rest, map[first], &(is_map(&2) && Map.get(&2, &1)))
    end
  end

  defp empty?(value), do: value in [nil, false, "", []]

  defp text(value) when is_binary(value), do: value
  defp text(value) when is_integer(value), do: Integer.to_string(value)
  defp text(_value), do: ""

  defp esc(text, false), do: Agendum.Core.Extras.Markdown.attribute(text)
  defp esc(text, true), do: text |> esc(false) |> String.replace("'", "&apos;")
end
