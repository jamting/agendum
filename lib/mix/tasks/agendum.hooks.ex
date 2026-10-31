# SPDX-License-Identifier: AGPL-3.0-only
defmodule Mix.Tasks.Agendum.Hooks do
  @shortdoc "Warns when git would not run the pre-push hook"
  @moduledoc """
  A step of `mix check`: warns, without failing, when git's
  `core.hooksPath` leads to no `pre-push` hook, so a push would not run
  `mix check` first. On 2026-10-26 it pointed to the project's old folder,
  an absolute path that no longer existed, and pushes had gone out
  unchecked since the move. An absolute path to this repository's
  `.githooks` is fine (git worktrees may set one).

      mix agendum.hooks     # silent when all is well

  Quiet in CI (the `CI` variable GitHub sets) and outside a git checkout.
  `mix setup` sets the path.
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # a worktree's `.git` is a file, a checkout's a folder
    inside? = File.exists?(".git")
    path = hooks_path()
    # a relative path is read from the top of the checkout, as git does;
    # unset, git looks in .git/hooks
    hook? =
      case path do
        nil -> false
        "" -> runnable?(".git/hooks/pre-push")
        dir -> runnable?(Path.join(dir, "pre-push"))
      end

    if message = warning(path, hook?, inside?, System.get_env("CI")),
      do: Mix.shell().info([:yellow, message, :reset])
  end

  # git runs a hook only when it is an executable file: one that lost its
  # x bit is skipped without a word. `Bitwise.band/2` picks the three x
  # bits (owner, group, others) out of the file's mode.
  defp runnable?(file) do
    case File.stat(file) do
      {:ok, %{type: :regular, mode: mode}} -> Bitwise.band(mode, 0o111) != 0
      _ -> false
    end
  end

  # what `git config core.hooksPath` prints: "" when it is not set (git
  # answers status 1), nil when git cannot tell; System.cmd/3 raises when
  # git itself is missing, and `rescue` turns that into nil too
  defp hooks_path do
    case System.cmd("git", ["config", "core.hooksPath"], stderr_to_stdout: true) do
      {out, 0} -> String.trim(out)
      {_out, 1} -> ""
      _ -> nil
    end
  rescue
    ErlangError -> nil
  end

  @doc """
  The warning, or nil: `path` is what `git config core.hooksPath` printed
  ("" when unset, nil when git could not tell), `hook?` whether a
  `pre-push` file is there, `inside?` whether this is a git checkout, `ci`
  the `CI` variable.
  """
  @spec warning(String.t() | nil, boolean, boolean, String.t() | nil) :: String.t() | nil
  def warning(_path, _hook?, _inside?, ci) when ci not in [nil, ""], do: nil
  def warning(_path, _hook?, false, _ci), do: nil
  def warning(nil, _hook?, _inside?, _ci), do: nil
  def warning(_path, true, _inside?, _ci), do: nil

  def warning(path, false, _inside?, _ci) do
    now =
      if path == "",
        do: "not set (and .git/hooks has no runnable pre-push)",
        else: "#{path}, which has no runnable pre-push hook"

    "warning: git's core.hooksPath is #{now}: a push will not run mix check " <>
      "first. Fix: mix setup (or git config core.hooksPath .githooks)"
  end
end
