defmodule Agenda.Core.DateLanguage.Swedish do
  @moduledoc """
  Swedish dates and times (SPEC R14c): "fredag", "på fre", "nästa vecka",
  "i fredags", "den 5 november", "5:e nov", "5/11" (day/month), "om två
  dagar", "för 3 veckor sedan", "i morgon kl 8", "kl. 15.30", "i kväll",
  "i slutet av månaden", and recurring dates: "varje måndag", "varannan
  fredag", "var tredje månad", "varje kvartal", "den 15:e varje månad";
  and (R14d) "om fem arbetsdagar", "nästa kvartal", "första kvartalet",
  "första onsdagen i november", "den 15:e nästa månad", "i april", "i
  slutet av mars".

  Times use a 24-hour clock ("kl 3" is 03:00). Bare abbreviations ("fre",
  "sön") count in item text only after "på", "till" or "senast"; "tor" is
  left out of that, as it is also a name. "Nu" and "morgon" on its own are
  not read, being too common in ordinary text ("i morgon" is tomorrow).
  A month alone is read only by its full name, so "i jul" stays Christmas.
  """

  @behaviour Agenda.Core.DateLanguage
  import Agenda.Core.DateLanguage, only: [alt: 1, alt: 2]

  @full_weekdays %{
    "måndag" => 1,
    "tisdag" => 2,
    "onsdag" => 3,
    "torsdag" => 4,
    "fredag" => 5,
    "lördag" => 6,
    "söndag" => 7
  }

  # "på fredagen"
  @definite_weekdays Map.new(@full_weekdays, fn {day, n} -> {day <> "en", n} end)

  @abbreviated_weekdays %{
    "mån" => 1,
    "tis" => 2,
    "ons" => 3,
    "tors" => 4,
    "tor" => 4,
    "fre" => 5,
    "lör" => 6,
    "sön" => 7
  }

  @months %{
    "januari" => 1,
    "jan" => 1,
    "februari" => 2,
    "feb" => 2,
    "mars" => 3,
    "mar" => 3,
    "april" => 4,
    "apr" => 4,
    "maj" => 5,
    "juni" => 6,
    "jun" => 6,
    "juli" => 7,
    "jul" => 7,
    "augusti" => 8,
    "aug" => 8,
    "september" => 9,
    "sept" => 9,
    "sep" => 9,
    "oktober" => 10,
    "okt" => 10,
    "november" => 11,
    "nov" => 11,
    "december" => 12,
    "dec" => 12
  }

  @full_months ~w(januari februari mars april maj juni juli augusti september oktober
                  november december)

  @ordinals ~w(första andra tredje fjärde femte sjätte sjunde åttonde nionde tionde elfte tolfte
               trettonde fjortonde femtonde sextonde sjuttonde artonde nittonde tjugonde
               tjugoförsta tjugoandra tjugotredje tjugofjärde tjugofemte tjugosjätte tjugosjunde
               tjugoåttonde tjugonionde trettionde trettioförsta)

  @words %{
    weekdays: @full_weekdays |> Map.merge(@definite_weekdays) |> Map.merge(@abbreviated_weekdays),
    months: @months,
    numbers: %{
      "en" => 1,
      "ett" => 1,
      "två" => 2,
      "tre" => 3,
      "fyra" => 4,
      "fem" => 5,
      "sex" => 6,
      "sju" => 7,
      "åtta" => 8,
      "nio" => 9,
      "tio" => 10,
      "elva" => 11,
      "tolv" => 12
    },
    ordinals: @ordinals |> Enum.with_index(1) |> Map.new(),
    relative: %{
      "denna" => 0,
      "detta" => 0,
      "den här" => 0,
      "det här" => 0,
      "nästa" => 1,
      "nästkommande" => 1,
      "förra" => -1
    },
    last: %{"sista" => :last},
    periods: %{
      "vecka" => :week,
      "veckan" => :week,
      "månad" => :month,
      "månaden" => :month,
      "kvartal" => :quarter,
      "kvartalet" => :quarter,
      "år" => :year,
      "året" => :year
    },
    units: %{
      "dag" => :day,
      "dagar" => :day,
      "arbetsdag" => :working_day,
      "arbetsdagar" => :working_day,
      "vardag" => :working_day,
      "vardagar" => :working_day,
      "vecka" => :week,
      "veckor" => :week,
      "månad" => :month,
      "månader" => :month,
      "kvartal" => :quarter,
      "år" => :year
    },
    intervals: %{
      "varje" => 1,
      "varannan" => 2,
      "var annan" => 2,
      "vartannat" => 2,
      "vart annat" => 2,
      "var tredje" => 3,
      "vart tredje" => 3,
      "var fjärde" => 4,
      "vart fjärde" => 4
    },
    edges: %{"början" => :start, "slutet" => :end, "slut" => :end},
    offsets: %{
      "idag" => 0,
      "i dag" => 0,
      "imorgon" => 1,
      "i morgon" => 1,
      "övermorgon" => 2,
      "i övermorgon" => 2,
      "igår" => -1,
      "i går" => -1,
      "förrgår" => -2,
      "i förrgår" => -2
    },
    time_words: %{
      "förmiddag" => :morning,
      "förmiddagen" => :morning,
      "lunch" => ~T[12:00:00],
      "eftermiddag" => :afternoon,
      "eftermiddagen" => :afternoon,
      "kväll" => :evening,
      "kvällen" => :evening,
      "ikväll" => :evening,
      "i kväll" => :evening,
      "midnatt" => ~T[00:00:00]
    },
    time_units: %{
      "minut" => :minute,
      "minuter" => :minute,
      "min" => :minute,
      "timme" => :hour,
      "timmar" => :hour,
      "tim" => :hour
    }
  }

  @impl true
  def name, do: "swedish"

  @impl true
  def words, do: @words

  @impl true
  def numeric_order, do: :day_month

  @impl true
  def clock, do: :twenty_four

  @impl true
  def text_excluded, do: [:weekday_abbr, :bare_month]

  @impl true
  def rules do
    m = alt(__MODULE__, :months)
    n = "\\d+|" <> alt(__MODULE__, :numbers)
    unit = alt(__MODULE__, :units)
    relative = alt(__MODULE__, :relative)
    full = alt(Map.keys(@full_weekdays) ++ Map.keys(@definite_weekdays))
    w_all = alt(__MODULE__, :weekdays)
    abbr = alt(Map.keys(@abbreviated_weekdays))

    every = alt(__MODULE__, :intervals)
    ordinals = alt(__MODULE__, :ordinals)
    nth = ordinals <> "|sista"
    edge = alt(__MODULE__, :edges)
    full_month = alt(@full_months)

    [
      {:recurring_weekday, "(#{every})\\s+(#{w_all})"},
      {:recurring_unit, "(#{every})\\s+(#{unit})"},
      {:recurring_day_of_month, "(?:den\\s+)?(\\d{1,2})(?::[ae])?\\s+varje\\s+månad"},
      {:recurring_day_of_month, "(?:den\\s+)?(#{ordinals})\\s+varje\\s+månad"},
      {:iso, "(\\d{4})-(\\d{1,2})-(\\d{1,2})"},
      {:numeric, "(\\d{1,2})/(\\d{1,2})(?:[/-](\\d{4}|\\d{2}))?"},
      {:day_month, "(?:den\\s+)?(\\d{1,2})(?::[ae])?\\s+(#{m})\\.?(?:,?\\s+(\\d{4}))?"},
      {:ordinal_of_month,
       "(?:den\\s+)?(#{alt(__MODULE__, :ordinals)})\\s+(#{m})\\.?(?:,?\\s+(\\d{4}))?"},
      {:nth_weekday_relative,
       "(?:den\\s+)?(#{nth})\\s+(#{w_all})\\s+i\\s+(?:(#{relative})\\s+)?månad(?:en)?"},
      {:nth_weekday,
       "(?:den\\s+)?(#{nth})\\s+(#{w_all})\\s+i\\s+(#{full_month})(?:\\s+(\\d{4}))?"},
      {:day_of_relative_month,
       "(?:den\\s+)?(\\d{1,2}(?::[ae])?|#{ordinals})\\s+(?:i\\s+månaden|(#{relative})\\s+månad(?:en)?)"},
      {:nth_quarter, "(#{ordinals})\\s+kvartalet"},
      {:edge_of_month,
       "(?:i\\s+)?(#{edge})\\s+(?:av|på)\\s+(?:(#{relative})\\s+)?(#{full_month})"},
      {:month_alone, "(#{relative})\\s+(#{full_month})"},
      {:month_alone, "i\\s+(?:(#{relative})\\s+)?(#{full_month})"},
      {:bare_month, "(?:(#{relative})\\s+)?(#{full_month})"},
      {:in_units, "om\\s+(#{n})\\s+(#{unit})"},
      {:units_ago, "(?:för\\s+)?(#{n})\\s+(#{unit})\\s+sedan"},
      {:edge_of_period,
       "(?:i\\s+)?(#{alt(__MODULE__, :edges)})\\s+(?:av|på)\\s+(?:(#{relative})\\s+)?(#{alt(__MODULE__, :periods)})"},
      {:relative_period, "(#{relative})\\s+(#{alt(__MODULE__, :periods)})"},
      {:relative_weekday, "(#{relative})\\s+(#{w_all})"},
      {:past_weekday, "i\\s+(#{alt(Map.keys(@full_weekdays))})s"},
      {:offset_word, "(#{alt(__MODULE__, :offsets)})"},
      {:weekday, "(#{full})"},
      {:weekday,
       "(?:på|till|senast)\\s+(#{alt(Map.keys(@abbreviated_weekdays) -- ["tor"])})\\.?"},
      {:weekday_abbr, "(#{abbr})"}
    ]
  end

  @impl true
  def time_rules do
    n = "\\d+|" <> alt(__MODULE__, :numbers)

    [
      {:clock, "kl\\.?\\s*(\\d{1,2})[.:](\\d{2})"},
      {:clock, "(?<![:\\d])(\\d{1,2}):(\\d{2})(?!:\\d)"},
      {:at_hour, "kl\\.?\\s*(\\d{1,2})"},
      {:time_word, "(#{alt(__MODULE__, :time_words)})"},
      {:in_time, "om\\s+(#{n})\\s+(#{alt(__MODULE__, :time_units)})"}
    ]
  end
end
