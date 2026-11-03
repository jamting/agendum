# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.Core.Extras.BlogFeed do
  @moduledoc """
  The settings of one of the blog's feeds as a file of format 50 kept them
  (`Blog.feeds`, by category: each child category of Posts was a feed),
  read only to become a list (`Agendum.Core.Extras.BlogList.from_feed/1`;
  meeting 2026-11-02-2244, § 6). Kept so an older file still loads: its
  struct's name is an atom in the file, which a safe read takes only when
  it exists already.
  """

  @type t :: %__MODULE__{title: String.t(), description: String.t(), slug: String.t()}
  defstruct title: "", description: "", slug: ""
end
