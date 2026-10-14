defmodule Agendum.TUI.TemplateTest do
  @moduledoc "Box layouts drawn as text, with named fields in brackets."
  use ExUnit.Case, async: true

  alias Agendum.TUI.{Draw, LineEdit, Template}

  @layout """
   Name: [name        ]   Type: [type  ]
   Note: [note                        ]

   ESC closes
  """

  defp text(lines), do: Enum.map(lines, &(&1 |> Enum.map_join(fn {_, t} -> t end)))

  test "fields are filled in, padded to the width of their brackets" do
    lines = Template.render(@layout, %{name: "Calls", type: "Standard", note: "..."})

    assert text(lines) == [
             " Name: Calls            Type: Standard",
             " Note: ...                           ",
             "",
             " ESC closes"
           ]

    # every line keeps its width in the layout, so the columns line up
    assert lines |> Enum.take(2) |> Enum.map(&Draw.width/1) == [38, 37]
  end

  test "a value too long for its field is cut, with an ellipsis" do
    [line | _] = Template.render(@layout, %{name: "Miscellaneous Activity", type: "", note: ""})
    # the field is 14 wide: 13 letters and the ellipsis
    assert hd(text([line])) =~ " Name: Miscellaneous…   Type:"
  end

  test "the fields in reading order, for the cursor" do
    assert Template.fields(@layout) == [:name, :type, :note]
  end

  test "text is in the box style, the selected value highlighted" do
    [line | _] =
      Template.render(@layout, %{name: "Calls", type: "Standard", note: ""}, selected: :type)

    assert {:box_selected, "Standard"} in line
    assert {:box, " Name: "} in line
    refute Enum.any?(line, &match?({:box_selected, "Calls"}, &1))
  end

  test "a selected empty value still shows the highlight, one space wide" do
    [_, line | _] =
      Template.render(@layout, %{name: "Calls", type: "Standard", note: ""}, selected: :note)

    assert {:box_selected, " "} in line
    # and the row keeps its width
    assert Draw.width(line) == 37
  end

  test "a field being edited is the input line, the whole width of the field" do
    edit = LineEdit.new("Cal")

    [line | _] =
      Template.render(@layout, %{name: "Calls", type: "", note: ""}, editing: {:name, edit})

    assert Draw.width(line) == 38
    assert Enum.any?(line, &match?({:edit, _}, &1))
  end

  test "a field whose value is nil leaves its whole row out" do
    lines = Template.render(@layout, %{name: "Calls", type: "Standard", note: nil})
    assert length(lines) == 3
    refute Enum.any?(text(lines), &(&1 =~ "Note"))
  end

  test "a value may be styled segments" do
    [line | _] =
      Template.render(@layout, %{name: [{:dim, "Ca"}, {:box, "lls"}], type: "", note: ""})

    assert {:dim, "Ca"} in line
    assert Draw.width(line) == 38
  end

  test "brackets that are not a field name stay text" do
    lines = Template.render(" [Yes] or [No]: [answer ]\n", %{answer: "y"})
    assert text(lines) == [" [Yes] or [No]: y        "]
  end

  describe "grid/2" do
    @two """
     Head:  [head   ]  Type:  [type  ]
     Width: [width  ]  Link:  [linked]

            A heading
     Count: [count  ]
    """

    test "the rows with fields, each field with the column it starts at" do
      assert Template.grid(@two, Template.fields(@two)) == [
               [head: 8, type: 26],
               [width: 8, linked: 26],
               [count: 8]
             ]
    end

    test "fields the box hides are left out, and so are rows left empty" do
      assert Template.grid(@two, [:head, :width, :count]) == [[head: 8], [width: 8], [count: 8]]
      assert Template.grid(@two, [:type, :count]) == [[type: 26], [count: 8]]
    end
  end
end
