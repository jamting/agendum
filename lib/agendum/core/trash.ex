# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Trash do
  @moduledoc """
  A file's trash (R24a): the discarded items, oldest first, kept without
  their assignments until it is emptied; `day`, the day the oldest of them
  was discarded (nil while it is empty); and `empty`, File Properties ▸
  Empty trash, when it empties by itself (Agenda's default, End of day).
  What is done with it is in `Agendum.Core.Facade.Trash`.
  """

  @type empty :: :on_demand | :file_closed | :end_of_day | :discarded

  @type t :: %__MODULE__{
          items: [Agendum.Core.Item.t()],
          day: Date.t() | nil,
          empty: empty
        }

  defstruct items: [], day: nil, empty: :end_of_day
end
