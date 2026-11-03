# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Store do
  @moduledoc """
  Saving and loading Agendum files (imperative shell). A file is
  `.agendum`; a name typed without an extension also finds a `.agenda`
  file from before the rename. Inside, the tag stays `:agenda`, so every
  file ever saved still loads. The modules were `Agenda.*` until the code
  was renamed too (ADR 0019): a file keeps the struct names it was saved
  with, so loading turns `Agenda.*` into `Agendum.*`.

  A file is the database serialized with `:erlang.term_to_binary/1`,
  wrapped in a versioned envelope so the format can evolve.

  Versions: 1 (initial); 2 adds `Item.when_explicit` and
  `Database.auto_date` (R14); 3 adds `Category.conditions` and
  `Database.conditional` (R15); 4 adds view and section `filter` and
  `sort` (R28, R36); 5 adds the view `match` of the Show View (R37); 6
  adds `Item.when_time`, `alarm_minutes` and `alarm_rung_at` (R14b, R38);
  7 adds `Database.date_format` (R41); 8 adds `Database.numbers` and
  `View.Column.number` (R29); 9 adds `Item.recurrence` (R14a); 10 adds
  `Database.dependencies` and `View.hide_dependent` (R43); 11 adds
  `Category.also_match` (R15d); 12 adds `Category.actions` and
  `Category.special` (R15b); 13 adds `Database.confirm_assignments` and
  `Database.suggestions` (R16); 14 adds `Database.date_settings` (R14e);
  15 replaces `Database.auto_date` with `Database.when_from` (R14f); 16
  adds `Category.excludes` (R9); 17 adds `Database.dates`, the dates of
  date categories the user made (R6a); 18 adds `Category.date_rule` (R6b),
  replacing `Database.when_from` with When's rule, and marks dates set by
  hand in `Database.dates`; 19 adds `Database.match_settings` (R16a); 20 adds
  `Category.match_overrides` (R16b); 21 adds `View.Column.date` and the
  `DateFormat` fields `show`, `am_pm` and `time_separator` (R41a); 22 adds
  `Database.calendars`, calendar subscriptions (R45); 23 adds
  `View.datebook` (R47); 24 adds `Database.macros` and `macro_order` (R50);
  25 moves a standard view's columns into its sections and adds
  `View.Column.linked` (R55); 26 adds `Database.insert_columns` (R55); 27
  replaces `View.Column.linked` with `link`, each column one of its own (R55);
  28 adds `View.Section.item_column` (R55); 29 adds its `position`;
  30 adds `NumberFormat.percent` (Display % of total); 31 adds
  `View.Column.format`, `note_line` and `title` (standard column formats);
  32 adds `View.hide_column_heads` (R57); 33 adds `View.section_separators`
  (R58); 34 adds `Item.zettel` and `Database.next_zettel`, Zettel ids
  (R73); 35 adds `Database.blog`, the micro-blog (R74); 36 adds
  `Database.feeds`, feed subscriptions (R75); 37 adds `Database.tab_size`
  (R64e); 38 moves the extras' stored structs, `Feed`, `Blog` and
  `Calendar`, to `Agendum.Core.Extras.*` (ADR 0044), and loading maps their
  old names to the new ones; 39 adds `View.number_items` (R79); 40 adds
  `Database.texts` and the `:unindexed` kind of `Category`, unindexed
  categories (R29b); 41 adds `Item.alarm_category`, an alarm's date
  category (R38); 42 adds `Database.description` and `backup_on_open`
  (File Properties, R82); 43 adds `Database.password`, never written: a
  file with a password is encrypted with it (ADR 0046); 44 adds
  `Database.trash`, the trash (R24a); 47 moves the blog's folder and
  upload settings out of the file, into the person's preferences
  (`Agendum.Core.Extras.Upload`; loading an older file keeps them in
  `Blog.moved_upload`, never written, for the program to move); 48 adds
  `Blog.address`, the address pattern, and `Blog.published`, what
  publishing remembers of each post (`Agendum.Core.Extras.PostRecord`);
  49 adds `Blog.pages`, the category whose items are the site's pages;
  50 adds `Blog.feeds`, the settings of the blog's own feeds
  (`Agendum.Core.Extras.BlogFeed`, by category); 51 replaces them by
  `Blog.lists`, the blog's lists (`Agendum.Core.Extras.BlogList`, by
  category): loading an older file makes each child of Posts a list with
  everything on, with its feed's settings.
  Older versions are upgraded on load by filling new struct fields with
  their defaults.
  """

  alias Agendum.Core.Database
  alias Agendum.Core.Extras.BlogList

  # Module attributes (`@name value`) are constants fixed when the module is
  # compiled; each use of `@format_version` is replaced by its value.
  # Domain: raising this number is what a new stored field needs; DATA_MODEL.md
  # has a row per version, and the golden-file tests hold a file of each.
  @format_version 51
  @extension ".agendum"
  # files from before the program was called Wol's Agendum (ADR 0019)
  @old_extension ".agenda"

  # The extras' stored structs moved to a namespace of their own (ADR 0044,
  # format 38). A file saved before keeps the old names; loading maps them.
  # Domain: the old names are written here as atoms, so they exist whenever
  # this module is loaded, as `:safe` decoding needs.
  @moved %{
    Agendum.Core.Feed => Agendum.Core.Extras.Feed,
    Agendum.Core.Blog => Agendum.Core.Extras.Blog,
    Agendum.Core.Calendar => Agendum.Core.Extras.Calendar
  }

  def extension, do: @extension

  @doc "The file format version this program writes."
  def format_version, do: @format_version

  @typedoc """
  A file's bytes as they were when Agendum read or wrote them: their MD5
  sum, in hex (R71). Two stamps differ when the bytes do.
  """
  @type stamp :: String.t()

  @doc """
  Where a crash keeps the unsaved changes of the file at `path` (R82b):
  beside it, with Agenda's `@` before the extension, as Agenda named a
  damaged file's changes (`MYINFO.AG` → `MYINFO@.AG`, User's Guide 22-16).
  An untitled file (`path` nil) has no folder: its changes go to the state
  folder (`$XDG_STATE_HOME/agendum`, `~/.local/state/agendum`), from `env`.
  """
  @spec recovery_path(Path.t() | nil, %{String.t() => String.t()}) :: Path.t() | nil
  def recovery_path(path, env \\ %{})

  def recovery_path(nil, env) do
    case env do
      %{"XDG_STATE_HOME" => dir} when dir != "" ->
        Path.join([dir, "agendum", "untitled@.agendum"])

      %{"HOME" => home} when home != "" ->
        Path.join(home, ".local/state/agendum/untitled@.agendum")

      _ ->
        nil
    end
  end

  def recovery_path(path, _env), do: Path.rootname(path) <> "@" <> Path.extname(path)

  @doc "Saves `db` to `path`, whatever is there."
  @spec save(Database.t(), Path.t()) :: :ok | {:error, term}
  def save(%Database{} = db, path) do
    with {:ok, _stamp} <- save(db, path, :any), do: :ok
  end

  @doc """
  Saves `db` to `path` if the file there is still as `expected` (R71): the
  stamp it was read or last saved with, nil for a file that was not there
  then, or `:any`. A file removed since is written again. Returns the new
  file's stamp, or `{:error, :changed_on_disk}` without writing.
  """
  @spec save(Database.t(), Path.t(), stamp | nil | :any) ::
          {:ok, stamp} | {:error, :changed_on_disk | term}
  def save(%Database{} = db, path, expected) do
    # Any Elixir value can be turned into bytes by the Erlang runtime
    # (`:erlang` is an Erlang module, called directly). The tuple is the
    # envelope: a tag, the format version, then the database itself.
    # a password is never written: the file is encrypted with it (ADR 0046)
    # Domain: zlib's fastest level, 1: on the owner's file (2026-10-26) the
    # default level took 117 of a save's 123 ms, level 1 42 ms for a file
    # 15% larger (meeting 2026-10-26-1524, § 5). Reading is the same for any
    # level, so files saved either way open in every version.
    binary =
      {:agenda, @format_version, %{db | password: nil, blog: %{db.blog | moved_upload: nil}}}
      |> :erlang.term_to_binary(compressed: 1)
      |> encrypt(db.password, db.description)

    # Domain: write to a temporary file, then rename it over the real one. A
    # rename within one folder is atomic, so a crash or a full disk mid-write
    # leaves the old file whole instead of half a new one.
    tmp = path <> ".tmp"

    # `with` runs its steps while each result matches its pattern (`:ok`).
    # With no `else`, the first result that does not match, such as
    # `{:error, :enospc}`, is returned as it is, so the caller sees either
    # `{:ok, stamp}` or the first error.
    # Domain: another writer could still change the file between this
    # look and the rename, a moment's window; the guard is for the minutes
    # and hours a file stays open, not for two saves in the same instant.
    with :ok <- unchanged(path, expected),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, binary),
         :ok <- File.rename(tmp, path) do
      {:ok, stamp_of(binary)}
    end
  end

  # `^expected` pins the variable: the clause matches only a stamp equal
  # to it, instead of binding a new value to the name.
  defp unchanged(_path, :any), do: :ok

  defp unchanged(path, expected) do
    case stamp(path) do
      nil -> :ok
      ^expected -> :ok
      _other -> {:error, :changed_on_disk}
    end
  end

  @doc "The stamp of the file at `path` as it is now, or nil when there is none (R71)."
  @spec stamp(Path.t()) :: stamp | nil
  def stamp(path) do
    case File.read(path) do
      {:ok, binary} -> stamp_of(binary)
      {:error, _} -> nil
    end
  end

  # `:erlang.md5/1` is built into the runtime (no `:crypto` needed); it is
  # no guard against tampering, nor needs to be, only against change.
  defp stamp_of(binary), do: binary |> :erlang.md5() |> Base.encode16(case: :lower)

  @spec load(Path.t(), String.t() | nil) :: {:ok, Database.t()} | {:error, term}
  def load(path, password \\ nil) do
    with {:ok, db, _stamp} <- load_with_stamp(path, password), do: {:ok, db}
  end

  @doc """
  Loads a file, with the stamp of the bytes read, so a later save can tell
  whether another writer changed it since (R71).
  """
  @spec load_with_stamp(Path.t(), String.t() | nil) ::
          {:ok, Database.t(), stamp} | {:error, term}
  def load_with_stamp(path, password \\ nil) do
    with {:ok, binary} <- File.read(path),
         {:ok, plain} <- decrypt(binary, password),
         {:ok, db} <- decode(plain) do
      {:ok, %{db | password: if(plain == binary, do: nil, else: password)}, stamp_of(binary)}
    end
  end

  # --- a file with a password (ADR 0046) ----------------------------------------

  @magic "AGENDUM-ENC1"
  @rounds 600_000

  # Domain: AES-256-GCM, its key made from the password by PBKDF2 with a
  # fresh salt, a fresh nonce each save; the magic is authenticated with
  # the text, and the description stays readable before the salt.
  # `<<…>>` builds a binary from its parts; `::16` a two-byte number.
  defp encrypt(binary, nil, _description), do: binary

  defp encrypt(binary, password, description) do
    salt = :crypto.strong_rand_bytes(16)
    nonce = :crypto.strong_rand_bytes(12)
    key = :crypto.pbkdf2_hmac(:sha256, password, salt, @rounds, 32)
    {cipher, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, binary, @magic, true)

    # the readable description in the header, for the Select File box, is
    # at most 40 characters (set_description's limit), so its two-byte length
    # always fits; the whole one is inside, encrypted (code review 2026-10-26)
    shown = String.slice(description, 0, 40)

    <<@magic, byte_size(shown)::16, shown::binary, salt::binary-16, nonce::binary-12,
      tag::binary-16, cipher::binary>>
  end

  # A binary pattern takes a file apart the same way; one without the
  # magic is an ordinary file, returned as it is.
  defp decrypt(<<@magic, _::binary>>, nil), do: {:error, :password_required}

  defp decrypt(
         <<@magic, len::16, _description::binary-size(len), salt::binary-16, nonce::binary-12,
           tag::binary-16, cipher::binary>>,
         password
       ) do
    key = :crypto.pbkdf2_hmac(:sha256, password, salt, @rounds, 32)

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, nonce, cipher, @magic, tag, false) do
      plain when is_binary(plain) -> {:ok, plain}
      :error -> {:error, :wrong_password}
    end
  end

  defp decrypt(<<@magic, _::binary>>, _password), do: {:error, :not_an_agenda_file}
  defp decrypt(binary, _password), do: {:ok, binary}

  # an encrypted file's description, read without the password
  defp clear_description(<<@magic, len::16, description::binary-size(len), _::binary>>),
    do: description

  defp clear_description(_binary), do: nil

  defp decode(binary) do
    # `:safe` decoding refuses unknown atoms, and struct field names only
    # exist once their modules are loaded (modules load lazily).
    ensure_modules_loaded()

    # Elixir mostly lets bad input crash ("let it crash"), but a file that
    # is not an Agendum file is expected input, not a bug: `binary_to_term`
    # raises `ArgumentError` on bytes it cannot read, and `rescue` turns
    # that into an error tuple the UI can show as a message.
    try do
      case binary |> :erlang.binary_to_term([:safe]) |> renamed() do
        # `in` with a range is allowed in a guard. Domain: a file from a newer
        # Agendum (a version above ours) is refused, not misread.
        {:agenda, version, %{__struct__: Database} = db} when version in 1..@format_version ->
          with {:ok, db} <- upgraded(db), do: db |> repair_text() |> checked()

        {:agenda, version, _} ->
          {:error, {:unsupported_version, version}}

        _ ->
          {:error, :not_an_agenda_file}
      end
    rescue
      ArgumentError -> {:error, :not_an_agenda_file}
    end
  end

  # Domain: a crafted file can hold a value of a shape no Agendum wrote (a
  # blog's lists that are text, code review 2026-11-03), on which the
  # upgrade raises; that is a damaged file, refused, not a crash
  defp upgraded(db) do
    {:ok, upgrade(db)}
  rescue
    _ -> {:error, {:damaged, "its parts do not fit together"}}
  end

  # Domain: a file whose values are of the wrong kind, or whose parts do not
  # agree, is refused as damaged (`Agendum.Core.FileCheck`; SECURITY.md,
  # door 2), with the first thing wrong in words
  defp checked(db) do
    case Agendum.Core.FileCheck.problem(db) do
      nil -> {:ok, db}
      problem -> {:error, {:damaged, problem}}
    end
  end

  # Every string in the file made valid UTF-8 (R82c): a file written by
  # another tool, edited by hand or damaged can hold Latin-1 bytes, which
  # Agendum's text functions and the screen would crash on. A bad byte
  # becomes the Latin-1 character of its number, as a feed's text does
  # (`Agendum.Core.Extras.Utf8`). The walk goes into maps (structs too,
  # whose `__struct__` atom stays), lists and tuples; a valid string comes
  # back as it was.
  defp repair_text(text) when is_binary(text), do: Agendum.Core.Extras.Utf8.repair(text)

  # a struct's keys are atoms, and `Map.new/2` takes no struct: `:maps.map/2`
  # (Erlang's) maps over the values of any map, a struct too
  defp repair_text(%{__struct__: _} = struct),
    do: :maps.map(fn _key, value -> repair_text(value) end, struct)

  defp repair_text(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {repair_text(k), repair_text(v)} end)

  defp repair_text(list) when is_list(list), do: Enum.map(list, &repair_text/1)

  defp repair_text(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&repair_text/1) |> List.to_tuple()

  defp repair_text(other), do: other

  @doc """
  Brings a database from any older format version up to date: every struct
  is rebuilt so fields added since it was saved get their defaults, and
  fields since removed are dropped. An old file's struct may have fields
  `Database` no longer has, so it is matched as a plain map.
  """
  @spec upgrade(map) :: Database.t()
  def upgrade(%{__struct__: Database} = db) do
    # The upgrade is one idea used everywhere below: `struct(Module, map)`
    # builds a fresh struct from a map, taking the keys the struct has,
    # giving missing ones their defaults and dropping unknown ones. A
    # struct saved by version 5 comes back with every field of today's.
    # Domain: it runs on every load, current files too; doing it again
    # changes nothing. Only changes that need a translation (an old setting
    # that meant something else) have code of their own.
    fields = Map.from_struct(db)

    # before 15 a file that did not read dates had auto_date: false; from
    # 15 to 17, when_from said where When dates came from
    when_assign =
      case fields do
        %{auto_date: false} -> :never
        %{when_from: :never} -> :never
        %{when_from: :note} -> :note_text
        %{when_from: :item_or_note} -> :item_or_note_text
        _ -> :item_text
      end

    # `db` is rebound step by step: each line makes a new value, and the
    # name now points at it (nothing is changed in place).
    db = struct(Database, fields)
    db = %{db | dates: Map.new(db.dates, &upgrade_date/1)}

    db = %{
      db
      | match_settings: struct(Agendum.Core.TextMatch, Map.from_struct(db.match_settings))
    }

    db = %{db | date_format: struct(Agendum.Core.DateFormat, Map.from_struct(db.date_format))}
    # before 47 the blog kept the folder and the upload, now the person's
    # (meeting 2026-11-02-1255, § 10): lifted out for the preferences
    old_blog = Map.from_struct(db.blog)

    blog = struct(Agendum.Core.Extras.Blog, old_blog)
    moved = Agendum.Core.Extras.Upload.from_old_blog(old_blog)
    db = %{db | blog: %{blog | moved_upload: moved}}

    # before 48 no records: the posts already out keep posts/<zettel id>.html
    # (after the rest is upgraded, as finding the posts reads the links)
    seed? = not Map.has_key?(old_blog, :published)
    # before 51 no lists: each child of Posts was a feed, and becomes a list
    # (meeting 2026-11-02-2244, § 6); a file of 50 kept their settings
    feeds =
      cond do
        Map.has_key?(old_blog, :lists) -> nil
        is_map(Map.get(old_blog, :feeds)) -> old_blog.feeds
        true -> %{}
      end

    db = %{
      db
      | date_settings: struct(Agendum.Core.DateSettings, Map.from_struct(db.date_settings))
    }

    # the calendars where this version keeps them, in Calendars (R75a)
    db = db |> upgrade_db(when_assign) |> Agendum.Core.Facade.Extras.Calendars.name_family()
    db = if seed?, do: Agendum.Core.Extras.Blog.seed_records(db), else: db
    db = if feeds, do: Agendum.Core.Extras.Blog.lists_from_feeds(db, feeds), else: db
    %{db | blog: %{db.blog | lists: upgrade_lists(db.blog.lists)}}
  end

  # each list's settings rebuilt as today's struct, as every struct is; a
  # value of another shape (a crafted file) is left as it is, for the
  # file's check to refuse it as damaged rather than crash here
  # each list's settings rebuilt as today's struct, as every struct is
  defp upgrade_lists(lists),
    do: Map.new(lists, fn {id, list} -> {id, struct(BlogList, Map.from_struct(list))} end)

  defp upgrade_db(db, when_assign) do
    alias Agendum.Core.{Category, View}

    %{
      db
      | items: Map.new(db.items, fn {id, i} -> {id, upgrade_item(i)} end),
        trash: upgrade_trash(db.trash),
        categories:
          Map.new(db.categories, fn {id, c} ->
            {id, upgrade_category(db, struct(Category, Map.from_struct(c)), when_assign)}
          end),
        views: Map.new(db.views, fn {id, v} -> {id, upgrade_view(v)} end),
        macros:
          Map.new(db.macros, fn {id, m} ->
            {id, struct(Agendum.Core.Macro, Map.from_struct(m))}
          end),
        feeds:
          Map.new(db.feeds, fn {id, f} ->
            {id, upgrade_feed(struct(Agendum.Core.Extras.Feed, Map.from_struct(f)))}
          end),
        calendars:
          Map.new(db.calendars, fn {id, c} ->
            c = struct(Agendum.Core.Extras.Calendar, Map.from_struct(c))
            # events read before ends were (format 23 and earlier) have none
            {id, %{c | events: Map.new(c.events, fn {uid, s} -> {uid, upgrade_event(s)} end)}}
          end)
    }
  end

  # before 45 a faded entry kept its title, note and link: only its publish
  # date is kept now (`Feed.forget/1`)
  # before 46 a live one kept its title, note and link: fingerprints now
  # (`Feed.snapshot/2`, ADR 0048)
  defp upgrade_feed(feed) do
    alias Agendum.Core.Extras.Feed

    entries =
      Map.new(feed.entries, fn
        {id, %{item: nil} = snap} -> {id, Feed.forget(snap)}
        {id, %{item: item, title: _, note: _} = snap} -> {id, Feed.snapshot(item, snap)}
        pair -> pair
      end)

    %{feed | entries: entries}
  end

  # before 46 an event kept its title and description: fingerprints now
  # (`Calendar.prints/1`, ADR 0048)
  defp upgrade_event(%{summary: _, description: _} = s),
    do:
      s
      |> Map.drop([:summary, :description])
      |> Map.merge(Agendum.Core.Extras.Calendar.prints(s))
      |> Map.put_new(:ends, nil)

  defp upgrade_event(s), do: Map.put_new(s, :ends, nil)

  # Date categories get a date rule: Agenda's for Entry, When (with the
  # file's old setting) and Done, Never for the user's (R6b).
  defp upgrade_category(db, %{kind: :date, date_rule: nil} = cat, when_assign) do
    rule =
      case Enum.find(db.special, fn {_key, id} -> id == cat.id end) do
        {:when, _} -> %{Agendum.Core.DateRule.builtin(:when) | assign: when_assign}
        {key, _} -> Agendum.Core.DateRule.builtin(key)
        nil -> %Agendum.Core.DateRule{}
      end

    %{cat | date_rule: rule}
  end

  # `%_{}` matches any struct (any `__struct__`), so this clause takes a
  # category that already has a rule; clauses are tried top to bottom, and
  # the last one, matching anything, is the fallback.
  defp upgrade_category(_db, %{date_rule: %_{} = rule} = cat, _when_assign),
    do: %{cat | date_rule: struct(Agendum.Core.DateRule, Map.from_struct(rule))}

  defp upgrade_category(_db, cat, _when_assign), do: cat

  # dates of user date categories: {date, time} before 18
  defp upgrade_date({key, {date, time}}), do: {key, {date, time, true}}
  defp upgrade_date(entry), do: entry

  # the trash's own fields filled in, and its items brought up to date
  defp upgrade_trash(trash) do
    trash = struct(Agendum.Core.Trash, Map.from_struct(trash))
    %{trash | items: Enum.map(trash.items, &upgrade_item/1)}
  end

  defp upgrade_item(item) do
    item = struct(Agendum.Core.Item, Map.from_struct(item))

    case item.recurrence do
      nil -> item
      rule -> %{item | recurrence: struct(Agendum.Core.Recurrence, Map.from_struct(rule))}
    end
  end

  defp upgrade_view(view) do
    alias Agendum.Core.View
    view = struct(View, Map.from_struct(view))
    # 25 and 26 marked columns `linked`, read before the structs drop it
    linked = old_linked(view.sections)

    # before 25 a standard view's columns were the view's, in every section
    %{
      view
      | sections: Enum.map(view.sections, &upgrade_section/1),
        columns: Enum.map(view.columns, &upgrade_column/1),
        sort: upgrade_keys(view.sort),
        # `&&` returns its left side when that is nil or false, so a view
        # without a datebook keeps nil and only a real one is rebuilt
        datebook: view.datebook && struct(Agendum.Core.Datebook, Map.from_struct(view.datebook))
    }
    # `then/2` lets a pipe go through a function that does not take the
    # value as its first argument, here an `if`.
    |> then(fn view -> if linked, do: View.link_by_head(view, linked), else: view end)
    |> View.columns_into_sections()
  end

  # The places of the columns marked `linked: true`, or nil when the file
  # has no such marks (before 25, or from 27 on).
  defp old_linked(sections) do
    places =
      for {section, s} <- Enum.with_index(sections),
          {column, i} <- Enum.with_index(Map.get(section, :columns, [])),
          Map.has_key?(column, :linked),
          do: {{s, i}, column.linked}

    # In a `for`, a generator's pattern filters: only `{place, true}` pairs
    # pass. `into:` collects into a set instead of a list. An `if` without
    # `else` gives nil when the condition is false.
    if places != [],
      do: for({place, true} <- places, into: MapSet.new(), do: place)
  end

  defp upgrade_section(section) do
    section = struct(Agendum.Core.View.Section, Map.from_struct(section))

    %{
      section
      | sort: upgrade_keys(section.sort),
        columns: Enum.map(section.columns, &upgrade_column/1),
        item_column: struct(Agendum.Core.View.ItemColumn, Map.from_struct(section.item_column))
    }
  end

  # Sort keys gain fields too (`line`, R36).
  defp upgrade_keys(nil), do: nil

  defp upgrade_keys(keys),
    # `&struct(..., &1)` is a capture: shorthand for `fn key -> ... end`.
    do: Enum.map(keys, &struct(Agendum.Core.View.SortKey, Map.from_struct(&1)))

  defp upgrade_column(column) do
    column = struct(Agendum.Core.View.Column, Map.from_struct(column))

    %{
      column
      | number: struct(Agendum.Core.NumberFormat, Map.from_struct(column.number)),
        date: column.date && struct(Agendum.Core.DateFormat, Map.from_struct(column.date))
    }
  end

  # Atoms (`:name`, and every struct field and module name) are never
  # garbage-collected and the runtime has a fixed number of them, so `:safe`
  # decoding refuses to make new ones from a file: a hostile file cannot
  # fill the table. The atoms a real file needs must therefore exist first.
  defp ensure_modules_loaded do
    {:ok, modules} = :application.get_key(:agendum, :modules)
    Enum.each(modules, &Code.ensure_loaded/1)
    # the names they had before the rename, so `:safe` decoding accepts a
    # file saved then: only these, made from our own modules' names
    Enum.each(modules ++ Map.keys(@moved), &old_name/1)
  end

  # Agendum.Core.Database -> :"Elixir.Agenda.Core.Database"
  defp old_name(module) do
    case Atom.to_string(module) do
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      "Elixir.Agendum." <> rest -> String.to_atom("Elixir.Agenda." <> rest)
      _ -> module
    end
  end

  # Every Agenda.* struct name in a loaded term as the Agendum.* it is now;
  # a term saved since the rename comes back as it was.
  # One function, a clause per kind of value (guards like `is_map/1` pick
  # it), calling itself on what is inside: the usual way to walk a whole
  # nested term in Elixir.
  defp renamed(term) when is_atom(term) do
    # `Agenda.*` becomes `Agendum.*`, then a struct that moved to the
    # extras' shelf gets its new name (`Map.get/3` with itself as default)
    term |> agendum_name() |> then(&Map.get(@moved, &1, &1))
  end

  # a struct is a map with a `__struct__` key; `Map.to_list/1` takes both
  defp renamed(term) when is_map(term),
    do: term |> Map.to_list() |> Map.new(fn {k, v} -> {renamed(k), renamed(v)} end)

  defp renamed(term) when is_list(term), do: Enum.map(term, &renamed/1)

  defp renamed(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> renamed() |> List.to_tuple()

  defp renamed(term), do: term

  defp agendum_name(term) do
    case Atom.to_string(term) do
      # `"prefix" <> rest` in a pattern matches a string that starts with the
      # prefix and binds the remainder. `to_existing_atom` cannot make new
      # atoms either; the old names were made, from our own modules only,
      # by `old_name/1` above.
      "Elixir.Agenda." <> rest -> String.to_existing_atom("Elixir.Agendum." <> rest)
      _ -> term
    end
  end

  @doc """
  A folder's contents for the Select File box: its folders, then its files,
  each by name, with when it was last changed (local time); hidden ones
  (starting with a dot) are left out.
  """
  @spec list_dir(Path.t()) ::
          {:ok, [%{name: String.t(), dir?: boolean, modified: NaiveDateTime.t()}]}
          | {:error, String.t()}
  def list_dir(dir) do
    case File.ls(dir) do
      {:ok, names} ->
        entries =
          for name <- names,
              not String.starts_with?(name, "."),
              # a one-element list as a generator: if `File.stat` fails, the
              # pattern `{:ok, stat}` does not match and the name is skipped
              {:ok, stat} <- [File.stat(Path.join(dir, name), time: :local)] do
            %{
              name: name,
              dir?: stat.type == :directory,
              modified: NaiveDateTime.from_erl!(stat.mtime)
            }
          end

        # Tuples compare element by element and `false` sorts before `true`,
        # so `{not dir?, name}` puts folders first, then by name.
        {:ok, Enum.sort_by(entries, &{not &1.dir?, String.downcase(&1.name)})}

      {:error, reason} ->
        {:error, :file.format_error(reason) |> to_string()}
    end
  end

  @doc """
  Each file's description (File Properties ▸ File description, R82), for
  the Select File box's F8: read from the files named in `dir`; "" for one
  without, or that is not an Agendum file.
  """
  @spec descriptions(Path.t(), [String.t()]) :: %{String.t() => String.t()}
  def descriptions(dir, names) do
    Map.new(names, fn name ->
      path = Path.join(dir, name)

      with {:ok, binary} <- File.read(path),
           described when is_binary(described) <- clear_description(binary) do
        {name, described}
      else
        _ ->
          case load(path) do
            {:ok, db} -> {name, db.description}
            _ -> {name, ""}
          end
      end
    end)
  end

  @doc """
  Copies a file to its backup beside it, `NAME.agendum.bak`, replacing the
  last one (File Properties ▸ Make backup on open, R82; Agenda's `.BG`).
  The backup is not listed among the files to open; renamed to
  `.agendum`, it opens as any file.
  """
  @spec backup(Path.t()) :: :ok | {:error, term}
  def backup(path), do: File.cp(path, path <> ".bak")

  @doc """
  Moves a file to the system's Trash, where it can be got back (File ▸
  Maintenance ▸ Erase, R82; the owner's choice: Agenda deleted it): on a
  Mac into `~/.Trash`, on Linux into the XDG Trash (`~/.local/share/Trash`,
  with the `.trashinfo` file managers read to put it back). A name already
  in the Trash gets a number ("old 2.agendum"). Elsewhere, or when the
  file cannot be moved there (another disk), the file stays and the
  reason comes back. `opts` (`os:`, `home:`) are for the tests.
  """
  @spec trash(Path.t(), keyword) :: :ok | {:error, term}
  def trash(path, opts \\ []) do
    home = Keyword.get_lazy(opts, :home, &System.user_home!/0)

    case Keyword.get_lazy(opts, :os, &os/0) do
      :darwin -> move_into(path, Path.join(home, ".Trash"))
      :linux -> xdg_trash(path, home, opts[:home] != nil)
      _ -> {:error, :no_trash}
    end
  end

  # `:os.type/0` gives `{:unix, :darwin}` on a Mac, `{:unix, :linux}` on Linux
  defp os do
    case :os.type() do
      {:unix, name} when name in [:darwin, :linux] -> name
      _ -> :other
    end
  end

  # the XDG Trash: the file under files/, and info/NAME.trashinfo saying
  # where it came from and when, so that a file manager can put it back
  defp xdg_trash(path, home, home_given?) do
    default = Path.join([home, ".local", "share"])
    base = if home_given?, do: default, else: System.get_env("XDG_DATA_HOME") || default
    trash = Path.join(base, "Trash")
    File.mkdir_p(Path.join(trash, "info"))

    with {:ok, moved} <- move_into(path, Path.join(trash, "files"), :name) do
      when_ = NaiveDateTime.local_now() |> NaiveDateTime.truncate(:second)

      File.write(
        Path.join([trash, "info", Path.basename(moved) <> ".trashinfo"]),
        "[Trash Info]\nPath=#{Path.expand(path)}\nDeletionDate=#{NaiveDateTime.to_iso8601(when_)}\n"
      )
    end
  end

  # moves `path` into `dir` under a free name; `:name` returns that name
  defp move_into(path, dir, return \\ :ok) do
    File.mkdir_p(dir)
    target = free_name(dir, Path.rootname(Path.basename(path)), Path.extname(path), 1)

    case File.rename(path, target) do
      :ok when return == :name -> {:ok, target}
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # "old.agendum", or "old 2.agendum", "old 3.agendum" … when it is taken
  defp free_name(dir, stem, ext, n) do
    name = if n == 1, do: stem <> ext, else: "#{stem} #{n}#{ext}"
    target = Path.join(dir, name)
    if File.exists?(target), do: free_name(dir, stem, ext, n + 1), else: target
  end

  @doc "Adds the default extension when the path has none."
  @spec normalize_path(String.t()) :: String.t()
  def normalize_path(path) do
    path = Path.expand(String.trim(path))

    cond do
      Path.extname(path) != "" ->
        path

      not File.exists?(path <> @extension) and File.exists?(path <> @old_extension) ->
        path <> @old_extension

      true ->
        path <> @extension
    end
  end
end
