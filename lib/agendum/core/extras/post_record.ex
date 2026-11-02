# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.PostRecord do
  @moduledoc """
  What publishing remembers of a post (R74), kept in the file with the
  blog (`Agendum.Core.Extras.Blog.published`), by the item's id:

    * `path`: its page's address, made once from the Site's address
      pattern the first time it was published, and never changed
      (`Agendum.Core.Extras.Address`)
    * `print`: a fingerprint of its title, note and date as last
      published (`Agendum.Core.Extras.Fingerprint`), to tell whether it
      changed since
    * `modified`: the day a publish found it changed, nil until then; the
      pages and the JSON Feed show it
  """

  @type t :: %__MODULE__{path: String.t(), print: non_neg_integer, modified: Date.t() | nil}
  defstruct path: "", print: 0, modified: nil
end
