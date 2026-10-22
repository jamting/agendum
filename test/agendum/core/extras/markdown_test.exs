defmodule Agendum.Core.Extras.MarkdownTest do
  @moduledoc "The micro-blog's Markdown (R74)."
  use ExUnit.Case, async: true

  alias Agendum.Core.Extras.Markdown

  defp html(text), do: Markdown.to_html(text)

  test "paragraphs, separated by blank lines; a line break is a space" do
    assert html("One\ntwo\n\nThree") == "<p>One two</p>\n<p>Three</p>"
  end

  test "headings, a rule and a code block kept as it is" do
    assert html("# Title\n## Sub") == "<h1>Title</h1>\n<h2>Sub</h2>"
    assert html("---") == "<hr>"
    assert html("```\na < b *not*\n```") == "<pre><code>a &lt; b *not*</code></pre>"
  end

  test "quotes and lists" do
    assert html("> Said\n> twice") == "<blockquote><p>Said twice</p></blockquote>"
    assert html("- a\n- b") == "<ul><li>a</li><li>b</li></ul>"
    assert html("1. a\n2. b") == "<ol><li>a</li><li>b</li></ol>"
    assert html("- long\n  item") == "<ul><li>long item</li></ul>"
  end

  test "the owner's task boxes: to do, done, cancelled" do
    assert html("- [ ] Buy honey\n- [x] Find Pooh\n- [-] Fly a balloon") ==
             ~s(<ul class="tasks">) <>
               ~s(<li class="todo"><span class="box">[ ]</span> Buy honey</li>) <>
               ~s(<li class="done"><span class="box">[x]</span> Find Pooh</li>) <>
               ~s(<li class="cancelled"><span class="box">[-]</span> <del>Fly a balloon</del></li>) <>
               "</ul>"
  end

  test "emphasis, strong, code, links, images and bare addresses" do
    assert html("*a* **b** `c` _d_") ==
             "<p><em>a</em> <strong>b</strong> <code>c</code> <em>d</em></p>"

    assert html("[Owl](https://wol.example/) ![tree](https://wol.example/t.png)") ==
             ~s(<p><a href="https://wol.example/">Owl</a> <img src="https://wol.example/t.png" alt="tree"></p>)

    assert html("See https://wol.example/a.") ==
             ~s(<p>See <a href="https://wol.example/a">https://wol.example/a</a>.</p>)

    # an underscore inside a word is not emphasis
    assert html("snake_case_word") == "<p>snake_case_word</p>"
  end

  test "HTML in a note is text, never markup" do
    assert html("<script>alert(1)</script> & co") ==
             "<p>&lt;script&gt;alert(1)&lt;/script&gt; &amp; co</p>"

    assert html(~s{[x](https://a.example/"onclick="x)}) =~ "&quot;"
    # only web addresses become links
    assert html("[x](javascript:alert(1))") == "<p>[x](javascript:alert(1))</p>"
  end

  test "a backslash keeps the next character as it is" do
    assert html("\\*not emphasis\\*") == "<p>*not emphasis*</p>"
  end

  test "Zettel links go through the link function given" do
    used = %{1 => 42}
    link = fn target, word -> "<a data-item=\"#{target}\">#{word}</a>" end

    assert Markdown.to_html("See [[bonalaku]] and bonalaku, not [[kitolido]]", used, link) ==
             ~s(<p>See <a data-item="42">bonalaku</a> and <a data-item="42">bonalaku</a>, ) <>
               ~s(not <a data-item="">kitolido</a></p>)
  end
end
