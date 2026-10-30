# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.Xml do
  @moduledoc """
  A small, forgiving XML reader, for feeds (R75). Pure, and with no atoms
  made from what it reads: tag and attribute names stay strings, so a
  hostile feed cannot fill the atom table (OTP's `xmerl` makes atoms).

  It reads elements, attributes, text, CDATA, comments, processing
  instructions and a DOCTYPE (skipped), and the five named entities and
  numeric ones. A feed that is broken is read as far as it goes: a closing
  tag with no opening one is ignored, and elements left open at the end
  are closed. Text that is not valid UTF-8 (a feed in Latin-1, or with a
  stray byte) is made so first (`Agendum.Core.Extras.Utf8`).

  A document is a list of nodes: `{name, attributes, children}` for an
  element (attributes a map of strings, names as written, `"dc:date"`), or
  a string for text.
  """

  @type node_ :: {String.t(), %{optional(String.t()) => String.t()}, [node_]} | String.t()

  @doc "The document's top-level nodes."
  @spec parse(String.t()) :: [node_]
  def parse(text) do
    # bytes that are no UTF-8 would reach the items, where text matching's
    # Unicode regular expressions raise on them
    text
    |> strip_bom()
    |> Agendum.Core.Extras.Utf8.repair()
    |> tokens([])
    |> build([{nil, %{}, []}], %{})
  end

  defp strip_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  defp strip_bom(text), do: text

  # --- tokens ------------------------------------------------------------------

  # The text cut into `{:open, name, attrs, self_closing?}`, `{:close,
  # name}` and `{:text, text}`, in order.
  defp tokens("", acc), do: Enum.reverse(acc)

  defp tokens("<!--" <> rest, acc), do: tokens(after_marker(rest, "-->"), acc)
  defp tokens("<?" <> rest, acc), do: tokens(after_marker(rest, "?>"), acc)

  defp tokens("<![CDATA[" <> rest, acc) do
    case :binary.split(rest, "]]>") do
      [data, rest] -> tokens(rest, [{:text, data} | acc])
      [data] -> tokens("", [{:text, data} | acc])
    end
  end

  defp tokens("<!" <> rest, acc), do: tokens(after_doctype(rest, 0), acc)

  defp tokens("</" <> rest, acc) do
    case :binary.split(rest, ">") do
      [name, rest] -> tokens(rest, [{:close, String.trim(name)} | acc])
      [_] -> tokens("", acc)
    end
  end

  defp tokens("<" <> rest, acc) do
    case tag(rest) do
      {:ok, name, attrs, closed, rest} -> tokens(rest, [{:open, name, attrs, closed} | acc])
      :error -> tokens(rest, [{:text, "<"} | acc])
    end
  end

  defp tokens(text, acc) do
    case :binary.split(text, "<") do
      [plain, rest] -> tokens("<" <> rest, [{:text, entities(plain)} | acc])
      [plain] -> tokens("", [{:text, entities(plain)} | acc])
    end
  end

  defp after_marker(text, marker) do
    case :binary.split(text, marker) do
      [_, rest] -> rest
      [_] -> ""
    end
  end

  # a DOCTYPE may hold [ … ] with > inside
  defp after_doctype("", _depth), do: ""
  defp after_doctype("[" <> rest, depth), do: after_doctype(rest, depth + 1)
  defp after_doctype("]" <> rest, depth), do: after_doctype(rest, max(depth - 1, 0))
  defp after_doctype(">" <> rest, 0), do: rest

  defp after_doctype(<<_::utf8, rest::binary>>, depth), do: after_doctype(rest, depth)
  defp after_doctype(<<_, rest::binary>>, depth), do: after_doctype(rest, depth)

  # A start tag: its name, its attributes, whether it closes itself.
  # Not Unicode expressions (no `u`): one checks that the whole text after
  # the tag is valid UTF-8 before matching, on every tag, which made a feed
  # of many tags take quadratic time (20,000 tags: 1.6 s; the hostile files,
  # 2026-10-26). The text is valid UTF-8 already (`Utf8.repair/1`), XML's
  # spaces are ASCII ones, and the classes below match any other byte, so
  # the names and values come out the same.
  @tag ~r/\A([^\s\/>]+)((?:\s+[^\s=\/>]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>/s
  @attr ~r/([^\s=\/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/s

  defp tag(text) do
    case Regex.run(@tag, text) do
      [whole, name, attrs, slash] ->
        rest = binary_part(text, byte_size(whole), byte_size(text) - byte_size(whole))
        {:ok, name, attributes(attrs), slash == "/", rest}

      _ ->
        :error
    end
  end

  defp attributes(""), do: %{}

  defp attributes(text) do
    for [_ | parts] <- Regex.scan(@attr, text), into: %{} do
      [name | values] = parts
      {name, values |> Enum.reject(&(&1 == "")) |> List.first("") |> entities()}
    end
  end

  # --- the tree ----------------------------------------------------------------

  # A stack of open elements, innermost first, each `{name, attrs,
  # children reversed}`; the bottom one (name nil) is the document. `open`
  # counts the open elements by name, so a closing tag knows at once
  # whether it closes anything: looking down the stack for it each time
  # made a feed of many open elements and stray closing tags take
  # quadratic time (10,000 of each: 1.7 s; the hostile files, 2026-10-26).
  defp build([], [{nil, _, children}], _open), do: Enum.reverse(children)
  defp build([], stack, open), do: build([{:close, nil}], stack, open)

  defp build([{:text, text} | rest], [{name, attrs, children} | up], open),
    do: build(rest, [{name, attrs, [text | children]} | up], open)

  defp build([{:open, name, attrs, true} | rest], [{n, a, children} | up], open),
    do: build(rest, [{n, a, [{name, attrs, []} | children]} | up], open)

  # Map.update/4: the count plus one, or 1 when the name is not there yet
  defp build([{:open, name, attrs, false} | rest], stack, open),
    do: build(rest, [{name, attrs, []} | stack], Map.update(open, name, 1, &(&1 + 1)))

  defp build([{:close, name} | rest], stack, open) do
    if name == nil or Map.get(open, name, 0) > 0 do
      {stack, open} = close_until(stack, name, open)
      build(rest, stack, open)
    else
      build(rest, stack, open)
    end
  end

  # closes elements until (and with) the one named; nil closes all but the document
  defp close_until([{nil, _, _}] = stack, nil, open), do: {stack, open}

  defp close_until([{name, attrs, children}, {pn, pa, pc} | up], target, open) do
    stack = [{pn, pa, [{name, attrs, Enum.reverse(children)} | pc]} | up]
    open = Map.update!(open, name, &(&1 - 1))
    if name == target, do: {stack, open}, else: close_until(stack, target, open)
  end

  defp close_until(stack, _target, open), do: {stack, open}

  # --- entities ---------------------------------------------------------------------

  @named %{"amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", "nbsp" => " "}

  @doc "Text with its entities (`&amp;`, `&#233;`, `&#xE9;`) as the characters."
  @spec entities(String.t()) :: String.t()
  def entities(text) do
    if String.contains?(text, "&") do
      Regex.replace(~r/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/, text, fn whole, code ->
        case code do
          "#x" <> hex -> codepoint(Integer.parse(hex, 16), whole)
          "#" <> dec -> codepoint(Integer.parse(dec), whole)
          name -> Map.get(@named, name, whole)
        end
      end)
    else
      text
    end
  end

  defp codepoint({n, ""}, _whole) when n in 1..0x10FFFF and n not in 0xD800..0xDFFF,
    do: <<n::utf8>>

  defp codepoint(_, whole), do: whole

  # --- reading the tree -------------------------------------------------------------

  @doc "An element's local name: `\"dc:date\"` is `\"date\"`, case aside."
  @spec local(String.t()) :: String.t()
  def local(name), do: name |> String.split(":") |> List.last() |> String.downcase()

  @doc "The child elements of a node."
  @spec elements(node_ | [node_]) :: [node_]
  def elements({_, _, children}), do: elements(children)
  def elements(nodes) when is_list(nodes), do: Enum.filter(nodes, &is_tuple/1)

  @doc "The first child element with one of the local names, or nil."
  @spec child(node_, [String.t()]) :: node_ | nil
  def child(node, names), do: Enum.find(elements(node), &(local(elem(&1, 0)) in names))

  @doc "The child elements with the local name."
  @spec children(node_, String.t()) :: [node_]
  def children(node, name), do: Enum.filter(elements(node), &(local(elem(&1, 0)) == name))

  @doc "All the text inside a node, trimmed."
  @spec text(node_ | nil) :: String.t()
  def text(nil), do: ""
  def text(node), do: node |> raw_text() |> String.trim()

  @doc "The text of the first child with one of the names, or \"\"."
  @spec child_text(node_, [String.t()]) :: String.t()
  def child_text(node, names), do: text(child(node, names))

  defp raw_text(text) when is_binary(text), do: text
  defp raw_text({_, _, children}), do: Enum.map_join(children, &raw_text/1)
end
