# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.TemplateTest do
  @moduledoc """
  The site's templates (R74; plans/PUBLISHER.md step 3, meeting
  2026-11-02-1255, § 7): a logic-less, Mustache-style language read by
  Agendum's own reader. Nothing in a template runs code; a mistake is
  refused with its line.
  """
  use ExUnit.Case, async: true

  alias Agendum.Core.Extras.Template

  defp render(text, context, partials \\ %{}) do
    {:ok, tree} = Template.parse(text)
    parsed = Map.new(partials, fn {k, v} -> {k, elem(Template.parse(v), 1)} end)
    {:ok, out} = Template.render(tree, context, parsed)
    out
  end

  test "{{name}} is escaped, {{{name}}} is not; dotted names reach into maps" do
    ctx = %{"site" => %{"title" => ~s(Owl's "Notes" & <more>)}, "html" => "<p>x</p>"}

    assert render("{{site.title}}", ctx) == "Owl's &quot;Notes&quot; &amp; &lt;more&gt;"
    assert render("{{{html}}}", ctx) == "<p>x</p>"
  end

  test "an unknown name is empty, as in Mustache" do
    assert render("a{{nope}}b{{site.nope}}c", %{"site" => %{}}) == "abc"
  end

  test "a section repeats for a list, shows once for a true value, not for an empty one" do
    ctx = %{"posts" => [%{"t" => "A"}, %{"t" => "B"}], "yes" => "x", "no" => "", "none" => []}

    assert render("{{#posts}}[{{t}}]{{/posts}}", ctx) == "[A][B]"
    assert render("{{#yes}}shown {{.}}{{/yes}}", ctx) == "shown x"
    assert render("{{#no}}hidden{{/no}}{{#none}}hidden{{/none}}", ctx) == ""
    assert render("{{^none}}empty{{/none}}{{^posts}}no{{/posts}}", ctx) == "empty"
  end

  test "inside a section, names not in the item are looked up outside it" do
    ctx = %{"root" => "../", "posts" => [%{"t" => "A"}]}
    assert render("{{#posts}}{{root}}{{t}}{{/posts}}", ctx) == "../A"
  end

  test "partials are included; comments show nothing" do
    assert render("a{{> menu}}b{{! a note }}c", %{"x" => "1"}, %{"menu" => "<{{x}}>"}) ==
             "a<1>bc"
  end

  test "a mistake is refused with its line" do
    assert {:error, {2, {:not_closed, "posts"}}} = Template.parse("a\n{{#posts}}\nb")
    assert {:error, {1, {:closes_nothing, "posts"}}} = Template.parse("{{/posts}}")
    assert {:error, {3, {:closes, "a", "b"}}} = Template.parse("{{#b}}\n\n{{/a}}")
    assert {:error, {1, :tag_not_closed}} = Template.parse("x {{name")
  end

  test "a partial that is missing, or includes itself, is refused" do
    {:ok, tree} = Template.parse("{{> menu}}")

    assert {:error, {:no_partial, "menu"}} =
             Template.render(tree, %{}, %{})

    {:ok, loop} = Template.parse("{{> menu}}")
    assert {:error, {:includes_itself, "menu"}} = Template.render(tree, %{}, %{"menu" => loop})
  end

  test "a template holding Elixir is only text: nothing runs" do
    assert render("<%= System.halt() %>{{#{1 + 1}}}", %{}) == "<%= System.halt() %>"
  end

  test "a huge template or deep nesting ends in time" do
    deep = String.duplicate("{{#a}}", 2_000) <> String.duplicate("{{/a}}", 2_000)
    assert {:ok, _} = Template.parse(deep)
    big = String.duplicate("{{x}}", 300_000)
    assert String.length(render(big, %{"x" => "y"})) == 300_000

    # a blog of many posts is not "too big": only inclusions count
    many = %{"posts" => for(i <- 1..20_000, do: %{"t" => "#{i}"})}
    assert render("{{#posts}}<{{t}}>{{/posts}}", many) =~ "<20000>"
  end

  test "templates that include each other many times over stop, and do not hang" do
    # a1 includes a2 twice, a2 includes a3 twice … : 2^30 copies
    partials =
      Map.new(1..30, fn i ->
        {:ok, tree} = Template.parse("{{> a#{i + 1}}}{{> a#{i + 1}}}")
        {"a#{i}", tree}
      end)
      |> Map.put("a31", elem(Template.parse("x"), 1))

    {:ok, top} = Template.parse("{{> a1}}")
    assert {:error, :too_big} = Template.render(top, %{}, partials)
  end

  test "a template including itself is found at the first step" do
    {:ok, layout} = Template.parse("{{> layout}}")

    assert {:error, {:includes_itself, "layout"}} =
             Template.render(layout, %{}, %{"layout" => layout}, "layout")
  end
end
