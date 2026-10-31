# SPDX-License-Identifier: AGPL-3.0-only
defmodule Agendum.TUI.Terminal do
  @moduledoc """
  The only module that talks to the real terminal (imperative shell).

  Uses OTP 28+'s raw mode (`:shell.start_interactive({:noshell, :raw})`), so
  no native dependencies are needed.
  """

  @spec start() :: :ok | {:error, term}
  def start do
    # `:shell` is an Erlang module: Erlang modules are atoms, called with
    # the same dot syntax as Elixir ones. Raw mode hands every byte typed
    # straight to the program, with no line editing or echo.
    case :shell.start_interactive({:noshell, :raw}) do
      :ok ->
        # let CTRL-S / CTRL-Q / CTRL-C / CTRL-O / CTRL-V reach us as keys
        # instead of acting as XOFF / XON / SIGINT / discard / literal-next
        stty("-ixon -isig -iexten")
        # alternate screen, hide cursor, no autowrap, clear. Without
        # autowrap a line wider than the screen (wide characters such as
        # CJK or emoji take two columns each) is cut at the right edge
        # instead of spilling onto the next row, or scrolling the screen
        # when it is the last
        IO.write("\e[?1049h\e[?25l\e[?7l\e[2J")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec stop() :: :ok
  def stop do
    IO.write("\e[0m\e[2J\e[?25h\e[?7h\e[?1049l")
    stty("ixon isig iexten")
    :ok
  end

  # Best effort; harmless where stty is unavailable. Commands run by
  # :os.cmd have no controlling terminal, so address our tty device by name.
  # The redirection needs a shell, hence :os.cmd; the settings are our own
  # constants and the device a plain /dev path, so nothing can be injected.
  defp stty(setting) do
    with {:unix, _} <- :os.type(),
         device when is_binary(device) <- tty_device(),
         true <- Regex.match?(~r{\A/dev/[\w/.-]+\z}, device) do
      # `~c"…"` is a charlist (a list of character codes), the string type
      # Erlang functions such as `:os.cmd/1` expect; `"…"` is a binary.
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeExec
      :os.cmd(~c"stty #{setting} < #{device} 2>/dev/null")
    end

    :ok
  end

  defp tty_device do
    case ~c"ps -o tty= -p #{System.pid()}" |> :os.cmd() |> to_string() |> String.trim() do
      "" -> nil
      "?" <> _ -> nil
      "/dev/" <> _ = path -> path
      name -> "/dev/" <> name
    end
  end

  @spec size() :: {pos_integer, pos_integer}
  def size do
    with {:ok, cols} <- :io.columns(), {:ok, rows} <- :io.rows() do
      {max(cols, 40), max(rows, 10)}
    else
      _ -> {80, 25}
    end
  end

  @spec write(iodata) :: :ok
  def write([]), do: :ok
  def write(iodata), do: IO.write(iodata)

  @doc """
  Starts a process that forwards keyboard input to `target` as
  `{:input, binary, at}`, `at` the arrival time in monotonic milliseconds.
  """
  @spec start_reader(pid) :: pid
  def start_reader(target) do
    # A process of its own, because `IO.getn/2` blocks until a byte comes:
    # the main loop must stay free to wake for the clock and resizes. Linked
    # (`spawn_link`), so if either process dies the other goes too, and
    # no reader is left behind reading a closed terminal.
    spawn_link(fn -> read_loop(target) end)
  end

  # A process's loop is a function calling itself last (a tail call, which
  # needs no stack), so it can run forever. `send/2` puts a message in
  # `target`'s mailbox and returns at once; `App.wait/5` takes it out.
  defp read_loop(target) do
    case IO.getn("", 1) do
      data when is_binary(data) ->
        send(target, {:input, data, System.monotonic_time(:millisecond)})
        read_loop(target)

      _eof_or_error ->
        send(target, :input_closed)
    end
  end
end
