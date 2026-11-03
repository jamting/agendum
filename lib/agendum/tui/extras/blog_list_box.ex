# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Extras.BlogListBox do
  @moduledoc """
  One of the blog's lists, its settings (Extras ▸ Publish ▸ Lists, ENTER;
  or a new one, INS; R74e, the owner's choices of 2026-11-03), kept in the
  file: its title, a line about it, its folder; whether it has an index
  page, feeds and a page per item, and publishes its items' notes; the
  fields (families) the templates see; and where its item pages go.
  Changing the folder moves the list at the next publish.

  A new list's box starts with its Category, completed as it is typed
  (R32), F3 or SPACE listing the categories; the rest as a new list has
  them (only the index page on). ENTER keeps the settings, a new list made
  and set in one undo step; ESC changes nothing. A letter on a text field
  starts typing it, F2 edits what is there; SPACE turns a switch over, Y
  and N set it; F3 on Fields lists the categories, and the one picked is
  added to the line. Drawn from `@layouts` (`Agendum.TUI.Boxes.Template`).
  Pure.
  """

  use Agendum.TUI.Boxes.Box, finish: :done

  alias Agendum.TUI.Boxes.{Box, FieldTyping, Template}
  alias Agendum.TUI.Extras.Publish.Messages
  alias Agendum.TUI.{State, Typing.LineEdit}

  @layouts %{
    new: """
     Category       : [category                 ]
     Title          : [title                                            ]
     Description    : [description                                      ]
     Folder         : [slug                     ]
     Index page     : [index]   Feeds : [feeds]   Item pages : [item_pages]
     Notes          : [notes]   Newest : [newest]
     Fields         : [fields                                           ]
     Item address   : [address                                          ]
    """,
    edit: """
     Title          : [title                                            ]
     Description    : [description                                      ]
     Folder         : [slug                     ]
     Index page     : [index]   Feeds : [feeds]   Item pages : [item_pages]
     Notes          : [notes]   Newest : [newest]
     Fields         : [fields                                           ]
     Item address   : [address                                          ]
    """
  }

  @help %{
    category: "The category to publish as a list. Type a name or F3 to pick.",
    title:
      "The list's name on its page and in its feeds. Type it; empty for the category's name.",
    description: "A line about the list, on its page and in its feeds. Type it.",
    slug:
      "Its folder on the site: a-z, 0-9 and -. Changing it moves the list when you publish. Type it.",
    index: "An index page of its items, in its folder. SPACE turns it over.",
    feeds: "An RSS feed and a JSON Feed of its items, in its folder. SPACE turns it over.",
    item_pages: "A page for each item that is not a post. SPACE turns it over.",
    notes: "Whether its items' notes are published, as their bodies. SPACE turns it over.",
    newest:
      "How many of its newest items its index and feeds show; empty: the Site's, 0: all. Type it.",
    fields:
      "The families the templates see, by name with commas: Role, Email. Type them; F3 adds one.",
    address:
      "Where an item's page goes, made once: {zettel} {slug} {year} {month} {day}, ending .html. Empty: folder/{zettel}.html."
  }

  @text_fields ~w(category title description slug newest fields address)a
  @switches ~w(index feeds item_pages notes)a
  @kept ~w(title description slug newest fields address)a ++ @switches

  @doc "Opens the box for `list` (as `Agendum.Core.blog_lists/2` gives it)."
  @spec open(State.t(), map) :: State.t()
  def open(state, list) do
    settings = state.db.blog.lists[list.category]
    names = names_of(state, list.fields)

    State.push(state, %Agendum.TUI.Modes.PublishList{
      category: list.category,
      new: false,
      made: list.slug,
      settings: %{
        title: list.title,
        description: list.description,
        # the folder as set: empty while it is still to be made from the
        # name (at the first publish), so keeping the box does not fix it
        slug: if(list.made, do: "", else: list.slug),
        index: list.index,
        feeds: list.feeds,
        item_pages: list.item_pages,
        notes: list.notes,
        # its own number as text, empty while it follows the Site's
        newest: if(settings.newest, do: Integer.to_string(settings.newest), else: ""),
        fields: names,
        address: settings.address
      },
      # the fields as ids, kept while the line still names them as it
      # opened: a name with a comma, or one two categories have, then
      # never stops the box from being kept (code review 2026-11-03)
      field_ids: list.fields,
      cursor: 0,
      typing: nil,
      choice: nil
    })
  end

  @doc "Opens the box for a new list (INS): its category to be named, the rest as a new list has them."
  @spec open_new(State.t()) :: State.t()
  def open_new(state) do
    new = %Agendum.Core.Extras.BlogList{}

    State.push(state, %Agendum.TUI.Modes.PublishList{
      category: nil,
      new: true,
      made: "",
      settings:
        new
        |> Map.take(@kept)
        |> Map.merge(%{category: "", fields: "", newest: ""}),
      field_ids: [],
      cursor: 0,
      typing: nil,
      choice: nil
    })
  end

  defp layout(mode), do: if(mode.new, do: @layouts.new, else: @layouts.edit)
  defp fields(mode), do: Template.fields(layout(mode))
  defp current(mode), do: Enum.at(fields(mode), min(mode.cursor, length(fields(mode)) - 1))

  @impl Box
  def handle(state, mode, key) do
    if FieldTyping.typing?(mode),
      do: FieldTyping.key(state, mode, key, &typed/3),
      else: start_typing(state, mode, current(mode), key)
  end

  # a letter on a text field starts typing it; Y or N sets a switch
  defp start_typing(state, mode, field, {:char, c}) when field in @text_fields,
    do: FieldTyping.start(state, mode, field, c)

  defp start_typing(state, _mode, field, {:char, c}) when field in @switches do
    case String.downcase(c) do
      "y" -> put(state, field, true)
      "n" -> put(state, field, false)
      _ -> state
    end
  end

  defp start_typing(state, _mode, _field, _key), do: state

  # Category completes a name (R32): ENTER gives the match shown as
  # `{:category, id}`, F5 exactly what was typed (made under MAIN when the
  # list is added)
  defp typed(state, field, {:category, id}), do: picked(state, nil, field, id)

  # a name typed for Category is looked up when the list is added
  defp typed(state, :category, text),
    do: state |> put(:category, String.trim(text)) |> update(&%{&1 | category: nil})

  defp typed(state, field, text), do: put(state, field, String.trim(text))

  # a setting changed in the box, found by its type: a picker may be over it
  defp put(state, field, value),
    do: update(state, &%{&1 | settings: Map.put(&1.settings, field, value)})

  defp update(state, fun) do
    i = Enum.find_index(state.modes, &(&1.type == :publish_list))
    %{state | modes: List.update_at(state.modes, i, fun)}
  end

  @impl Box
  def category_fields(%{new: true}), do: [:category]
  def category_fields(_mode), do: []

  # a feed's or a calendar's category is never a list (R75a), nor MAIN's
  # dates; as a field, any but MAIN
  @impl Box
  def category_choice?(state, _mode, :category, id),
    do:
      not Agendum.Core.ingested?(state.db, id) and
        not Agendum.Core.Database.protected?(state.db, id) and
        not Agendum.Core.Database.date_category?(state.db, id)

  def category_choice?(_state, _mode, _field, _id), do: true

  # a category picked (F3) or completed: Category takes its name; Fields
  # gets it added after the names already there
  # (the category picked is kept by id too: two of one name are told apart)
  @impl Box
  def picked(state, _mode, :category, id) do
    state
    |> put(:category, state.db.categories[id].name)
    |> update(&%{&1 | category: id})
  end

  def picked(state, _mode, :fields, id) do
    mode = Enum.find(state.modes, &(&1.type == :publish_list))
    name = state.db.categories[id].name

    by_id? = mode.settings.fields == names_of(state, mode.field_ids)

    line =
      case String.trim(mode.settings.fields) do
        "" -> name
        names -> names <> ", " <> name
      end

    state
    |> put(:fields, line)
    |> update(&%{&1 | field_ids: if(by_id?, do: mode.field_ids ++ [id], else: [])})
  end

  def picked(state, _mode, _field, _id), do: state

  @impl Box
  def keymap(_mode),
    do: Box.settings_keymap(%{{:f, 2} => :edit, {:f, 3} => :pick_category})

  @impl Box
  def commands(_mode) do
    Box.settings_commands([
      {:edit, "Edit", "Edit the setting's text"},
      {:pick_category, "Choices", "The categories to pick from"},
      {:done, "Keep", "Keep the list's settings"},
      {:close, "Cancel", "Close, changing nothing"}
    ])
  end

  @impl Box
  def run(state, mode, :change), do: change(state, mode, current(mode))
  def run(state, mode, :edit), do: edit(state, mode, current(mode))
  def run(state, mode, :done), do: keep(state, mode)

  def run(state, mode, :pick_category) do
    case current(mode) do
      field when field in [:category, :fields] -> pick(state, field)
      _ -> state
    end
  end

  def run(state, mode, id),
    do: Box.run_settings(state, mode, Template.grid(layout(mode), fields(mode)), id)

  # SPACE: a switch turned over; on Category the categories listed, as a
  # category field does in the clone's boxes; on a text field, its editing
  defp change(state, mode, field) when field in @switches,
    do: put(state, field, not Map.fetch!(mode.settings, field))

  defp change(state, _mode, :category), do: pick(state, :category)
  defp change(state, mode, field), do: edit(state, mode, field)

  # F2: the text as it is, without completion (as Agenda's EDIT)
  defp edit(state, mode, field) when field in @text_fields do
    line = LineEdit.new(Map.fetch!(mode.settings, field))
    State.put_mode(state, %{mode | typing: {field, line}, choice: :off})
  end

  defp edit(state, _mode, _field), do: state

  defp pick(state, field),
    do: Agendum.TUI.CategoryScreens.open_picker(state, {:box_field, :publish_list, field}, nil)

  # ENTER: the settings kept, one undo step; a new list made first, in the
  # same key, and nothing kept when either is refused
  defp keep(state, %{new: true} = mode) do
    # the category picked, by id while the line still names it; else the
    # name typed
    category =
      case state.db.categories[mode.category] do
        %{name: name} when name == mode.settings.category -> mode.category
        _ -> {:name, mode.settings.category}
      end

    case State.command(state, {:add_blog_list, category}) do
      {:ok, added, %{new: id}} -> set(added, %{mode | category: id}, state)
      {:error, reason} -> State.error(state, error_text(reason))
    end
  end

  defp keep(state, mode), do: set(state, mode, state)

  defp set(state, mode, before) do
    # the fields by id while the line names them as they were, else by
    # the names typed
    fields =
      if mode.settings.fields == names_of(state, mode.field_ids),
        do: mode.field_ids,
        else: names(mode.settings.fields)

    changes = mode.settings |> Map.take(@kept) |> Map.put(:fields, fields)

    case newest(mode.settings.newest) do
      {:ok, newest} -> set_changes(state, mode, Map.put(changes, :newest, newest), before)
      :error -> State.error(before, Messages.text(:bad_list_newest))
    end
  end

  # empty: the Site's number; else a whole number from 0
  defp newest(text) do
    case String.trim(text) do
      "" ->
        {:ok, nil}

      text ->
        case Integer.parse(text) do
          {n, ""} when n >= 0 -> {:ok, n}
          _ -> :error
        end
    end
  end

  defp set_changes(state, mode, changes, before) do
    case State.command(state, {:set_blog_list, mode.category, changes}) do
      {:ok, state, _changes} -> state |> State.pop() |> State.info(Messages.text(:list_kept))
      {:error, reason} -> State.error(before, error_text(reason))
    end
  end

  # the line the field ids are shown as: "Role, Email"
  defp names_of(state, ids), do: Enum.map_join(ids, ", ", &state.db.categories[&1].name)

  # "Role, Email" as the names, each trimmed, none empty
  defp names(line),
    do: line |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp error_text({:unknown_field, name}), do: Messages.text(:unknown_field, name)
  defp error_text({:ambiguous_field, name}), do: Messages.text(:ambiguous_field, name)
  defp error_text(:bad_slug), do: Messages.text(:bad_slug)
  defp error_text(:bad_address), do: Messages.text(:bad_address)
  defp error_text(:already_a_list), do: Messages.text(:already_a_list)
  defp error_text(:ambiguous), do: Messages.text(:ambiguous_list)
  defp error_text(:ingested), do: Messages.text(:list_ingested)
  defp error_text(_reason), do: Messages.text(:bad_list)

  @impl Box
  def title(_state, %{new: true}), do: "Publish: add a list"
  def title(state, mode), do: "List: " <> state.db.categories[mode.category].name

  @impl Box
  def width(state, _mode), do: min(state.width - 4, 76)

  @impl Box
  def content(_state, mode, inner, _max_rows) do
    values =
      Map.new(fields(mode), fn field ->
        value = Map.fetch!(mode.settings, field)
        {field, if(is_boolean(value), do: yes_no(value), else: value)}
      end)

    Template.render(layout(mode), values, [selected: current(mode)] ++ FieldTyping.editing(mode)) ++
      [
        [],
        [{:box, " " <> where(mode)}],
        Box.hint(keys(nil, mode), inner)
      ]
  end

  defp yes_no(true), do: "Yes"
  defp yes_no(false), do: "No"

  # where its index goes; a folder still to be made says so
  defp where(%{settings: %{slug: ""}, new: true}), do: Messages.text(:list_folder_new)
  defp where(%{settings: %{slug: ""}} = mode), do: Messages.text(:list_made, mode.made)
  defp where(mode), do: Messages.text(:list_where, mode.settings.slug)

  @impl Box
  def keys(_state, _mode), do: Box.settings_keys([{"type", "Text"}, {"F3", "Choices"}])

  @impl Box
  def help, do: @help

  @impl Box
  def field(_state, mode), do: current(mode)

  @impl Box
  def about(_state, _mode) do
    """
    One of the blog's lists: a category of yours, its items published as
    the list says. Title is its name there (empty: the category's),
    Description a line about it, Folder where it is on the site (a-z, 0-9
    and -). Index page, Feeds and Item pages switch its index, its RSS and
    JSON Feed, and a page for each item that is not a post; Notes whether
    the items' notes go out. Fields names the families a template sees
    (Role, Email), by name with commas; nothing else of an item leaves the
    file. Item address is where an item's page goes, made once.

    SPACE turns a switch over (Y and N set it), F3 lists the categories
    for Category or Fields. A list moved to another folder is written there
    at the next publish, and its old folder's files removed: whoever
    followed the old address loses it. ENTER keeps the settings; ESC
    closes the box, changing nothing.
    """
  end
end
