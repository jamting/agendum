defmodule Agendum.TUI.LoggerCaptureTest do
  @moduledoc """
  Erlang's logger never prints over the screen while Agendum runs: its
  reports go to the debug log, or nowhere when it is off; a fetch that
  crashes comes back as an error to show (meeting 2026-10-26-1524, § 6).
  """
  # the logger's handlers are global: not beside other tests
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Agendum.TUI.{App, DebugLog}

  @moduletag :tmp_dir

  test "while it runs, the logger writes to the debug log, not the terminal", %{tmp_dir: dir} do
    task =
      Task.async(fn ->
        path = DebugLog.start(%{"AGENDUM_LOG" => dir}, [])
        saved = DebugLog.capture_logger()

        shown =
          capture_io(fn ->
            capture_io(:stderr, fn -> :logger.error("Owl's report from the network") end)
            |> IO.write()
          end)

        DebugLog.release_logger(saved)
        DebugLog.stop()
        {path, shown}
      end)

    {path, shown} = Task.await(task)
    assert shown == ""
    assert File.read!(path) =~ "Owl's report from the network"
    assert {:ok, _} = :logger.get_handler_config(:default)
  end

  test "without a debug log, the reports go nowhere" do
    task =
      Task.async(fn ->
        saved = DebugLog.capture_logger()

        shown =
          capture_io(fn ->
            capture_io(:stderr, fn -> :logger.error("Nobody hears this") end) |> IO.write()
          end)

        DebugLog.release_logger(saved)
        shown
      end)

    assert Task.await(task) == ""
    assert {:ok, _} = :logger.get_handler_config(:default)
  end

  test "a fetch that crashes is an error to show, not a silent stop" do
    assert App.fetched(fn -> {:ok, []} end) == {:ok, []}
    assert {:error, message} = App.fetched(fn -> raise "no such host" end)
    assert message =~ "could not be read"
  end
end
