defmodule Agendum.Core.AgFile do
  @moduledoc """
  Imports a Lotus Agenda 2.0 data file (`.AG`) as a new Agendum file
  (R72). Pure: the bytes come from the shell.

  The steps: `Reader` reads the bytes; a file with a password needs it
  (Agenda's password does not encrypt, so this only keeps the protection
  its owner chose); `Convert` makes an Agendum JSON document, which
  `JSONFile` checks and builds; the assignments made by hand in Agenda are
  then made, through `Assign` (so the file keeps Agendum's rules, R7,
  R7c); and Agendum's own text matching, conditions and actions are run
  on every item (Utilities Execute, R15e) for the rest. The items Agendum
  then files differently from Agenda are in the report.
  """

  alias Agendum.Core.{Assign, Database, JSONFile}
  alias Agendum.Core.AgFile.{Convert, Reader}

  @typedoc """
  What an import brought and left: the counts, the notes on what was
  simplified or left out, and each item Agendum files differently from
  Agenda (`only_agenda`: categories Agenda had it in and Agendum has
  not; `only_agendum`: the other way), by category name.
  """
  @type report :: %{
          items: non_neg_integer,
          categories: non_neg_integer,
          views: non_neg_integer,
          trashed: non_neg_integer,
          notes: [String.t()],
          differences: [
            %{text: String.t(), only_agenda: [String.t()], only_agendum: [String.t()]}
          ]
        }

  @doc """
  Whether `bytes` look like an Agenda file (its first byte is "T", and it
  has at least the header), to tell it from a JSON file.
  """
  @spec agenda_file?(binary) :: boolean
  def agenda_file?(<<"T", _::binary-size(1023), _::binary>>), do: true
  def agenda_file?(_bytes), do: false

  @doc """
  Imports an Agenda file. `opts`: `password:` (nil when none was asked
  yet), `clock:` for date conditions (a date or `Agendum.Core.Context`).
  Errors: `:not_an_agenda_file`, `:password_required` (the file has one
  and none was given), `:wrong_password`, or a message from `JSONFile`.
  """
  @spec import(binary, keyword) ::
          {:ok, Database.t(), report}
          | {:error, :not_an_agenda_file | :password_required | :wrong_password | String.t()}
  def import(bytes, opts \\ []) do
    with {:ok, file} <- Reader.read(bytes),
         :ok <- password(file.password, opts[:password]),
         converted = Convert.convert(file),
         {:ok, db} <- JSONFile.decode_document(converted.document) do
      db = db |> assign(converted.assign) |> recompute(opts[:clock])
      {:ok, db, report(db, converted)}
    end
  end

  # Domain: Agenda compared passwords without regard to case, as DOS did
  # with names; a password typed in another case is accepted here too.
  defp password(nil, _given), do: :ok
  defp password(_set, nil), do: {:error, :password_required}

  defp password(set, given) do
    if String.downcase(set) == String.downcase(given), do: :ok, else: {:error, :wrong_password}
  end

  defp assign(db, assign) do
    Enum.reduce(assign, db, fn {item, cats}, db ->
      Enum.reduce(cats, db, &Assign.assign(&2, item, &1))
    end)
  end

  defp recompute(db, clock), do: Agendum.Core.execute(db, db.item_order, clock: clock)

  defp report(db, converted) do
    %{
      items: map_size(db.items),
      categories: map_size(db.categories),
      views: map_size(db.views),
      trashed: converted.trashed,
      notes: converted.notes,
      differences: differences(db, converted.agenda)
    }
  end

  # Membership on both sides: the categories an item is in and their
  # ancestors (Agenda's file lists some of both), standard ones, not MAIN.
  defp differences(db, agenda) do
    for id <- db.item_order,
        agenda_in = within(db, Map.get(agenda, id, [])),
        agendum_in = within(db, Database.explicit_categories(db, id)),
        agenda_in != agendum_in do
      %{
        text: db.items[id].text,
        only_agenda: names(db, MapSet.difference(agenda_in, agendum_in)),
        only_agendum: names(db, MapSet.difference(agendum_in, agenda_in))
      }
    end
  end

  defp within(db, cats) do
    for cat <- cats,
        Map.has_key?(db.categories, cat),
        c <- [cat | Database.ancestors(db, cat)],
        c != db.main_id and db.categories[c].kind == :standard,
        into: MapSet.new(),
        do: c
  end

  defp names(db, cats), do: cats |> Enum.map(&db.categories[&1].name) |> Enum.sort()
end
