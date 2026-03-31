defmodule Raxol.Terminal.Driver.Dispatch do
  @moduledoc """
  Event dispatching helpers for Driver: sends events to the dispatcher
  and handles initial resize notification.
  """

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Runtime.Log
  alias Raxol.Terminal.ANSI.InputParser
  alias Raxol.Terminal.Driver.TerminalSize
  alias Raxol.Terminal.Env

  @doc """
  Sends an event to the dispatcher pid, using direct send in test mode.
  """
  def send_event_to_dispatcher(dispatcher_pid, event) do
    if Env.test?() do
      Log.debug(
        "[Driver] Sending event in test mode: #{inspect(event)} to #{inspect(dispatcher_pid)}"
      )

      send(dispatcher_pid, {:"$gen_cast", {:dispatch, event}})
    else
      GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  @doc """
  Sends an initial resize event to the dispatcher based on current terminal size.
  """
  def send_initial_resize_event(dispatcher_pid) do
    {:ok, width, height} = TerminalSize.get_terminal_size()
    Log.info("Initial terminal size: #{width}x#{height}")
    event = %Event{type: :resize, data: %{width: width, height: height}}

    if Env.test?() do
      Log.info("[Driver] Sending resize event in test mode: #{inspect(event)}")
      send(dispatcher_pid, {:"$gen_cast", {:dispatch, event}})
    else
      GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  @doc """
  Parses test input data into an Event struct.
  """
  def parse_test_input(input_data) when is_binary(input_data) do
    Log.debug("[TerminalDriver.parse_test_input] Parsing: #{inspect(input_data)}")

    case InputParser.parse(input_data) do
      [event | _] -> event
      [] -> %Event{type: :unknown_test_input, data: %{raw: input_data}}
    end
  end
end
