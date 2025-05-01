defmodule Raxol.Test.TestHelper do
  @moduledoc """
  Provides common test utilities and setup functions for Raxol tests.

  This module includes:
  - Test environment setup
  - Mock data generation
  - Common test scenarios
  - Cleanup utilities
  """

  use ExUnit.CaseTemplate
  import ExUnit.Callbacks
  alias Raxol.Core.Runtime.{EventLoop}
  alias Raxol.Core.Events.{Event, Manager}
  alias Raxol.Core.Runtime.Plugins.Manager, as: PluginManager
  require Logger

  @doc """
  Sets up a test environment with all necessary dependencies.

  Returns a context map with initialized services.
  """
  def setup_test_env do
    # Start event system
    {:ok, event_pid} = start_supervised(Manager)
    {:ok, loop_pid} = start_supervised(EventLoop)
    # Start plugin manager
    {:ok, plugin_manager_pid} = start_supervised(PluginManager)

    # Create test terminal
    terminal = setup_test_terminal()

    %{
      event_manager: event_pid,
      event_loop: loop_pid,
      terminal: terminal,
      plugin_manager: plugin_manager_pid
    }
  end

  @doc """
  Creates a mock terminal for testing.
  """
  def setup_test_terminal do
    %{
      width: 80,
      height: 24,
      output: [],
      cursor: {0, 0}
    }
  end

  @doc """
  Generates test events for common scenarios.
  """
  def test_events do
    %{
      keyboard: [
        Event.key(:enter),
        Event.key(:esc),
        Event.key({:char, ?a}),
        Event.key(:tab)
      ],
      mouse: [
        Event.mouse(:left, {0, 0}),
        Event.mouse(:right, {10, 5}),
        Event.mouse(:left, {20, 10}, drag: true)
      ],
      window: [
        Event.window(80, 24, :resize),
        Event.window(100, 30, :resize),
        Event.window(80, 24, :focus)
      ]
    }
  end

  @doc """
  Creates a test component with the given module and initial state.
  """
  def create_test_component(module, initial_state \\ %{}) do
    %{
      module: module,
      state: initial_state,
      subscriptions: [],
      rendered: nil
    }
  end

  @doc """
  Simulates a sequence of events on a component.
  """
  def simulate_event_sequence(component, events) when is_list(events) do
    Enum.reduce(events, {component, []}, fn event, {comp, all_commands} ->
      {updated_comp, commands} = Raxol.Test.Unit.simulate_event(comp, event)
      {updated_comp, all_commands ++ commands}
    end)
  end

  @doc """
  Generates test styles for component rendering.
  """
  def test_styles do
    %{
      default: %{
        color: :white,
        background: :black,
        bold: false,
        underline: false
      },
      highlighted: %{
        color: :yellow,
        background: :blue,
        bold: true,
        underline: false
      },
      error: %{
        color: :red,
        background: :black,
        bold: true,
        underline: true
      }
    }
  end

  @doc """
  Generates test layouts for component positioning.
  """
  def test_layouts do
    %{
      full_screen: %{
        x: 0,
        y: 0,
        width: 80,
        height: 24
      },
      centered: %{
        x: 20,
        y: 5,
        width: 40,
        height: 14
      },
      sidebar: %{
        x: 0,
        y: 0,
        width: 20,
        height: 24
      }
    }
  end

  @doc """
  Cleans up test resources and resets the environment.
  """
  @dialyzer {:nowarn_function, cleanup_test_env: 1}
  def cleanup_test_env(context) do
    # Stop supervised processes
    if context[:event_manager] do
      _ = stop_supervised(Manager)
    end

    if context[:event_loop] do
      _ = stop_supervised(EventLoop)
    end

    # Stop plugin manager if started
    if context[:plugin_manager] do
      _ = stop_supervised(PluginManager)
    end

    # Clear any remaining messages
    flush_messages()

    :ok
  end

  @doc """
  Captures all terminal output during a test.
  """
  def capture_terminal_output(fun) when is_function(fun, 0) do
    original_group_leader = Process.group_leader()
    {:ok, capture_pid} = StringIO.open("")
    Process.group_leader(self(), capture_pid)

    try do
      fun.()
      {_input, output} = StringIO.contents(capture_pid)
      output
    after
      Process.group_leader(self(), original_group_leader)
      StringIO.close(capture_pid)
    end
  end

  # Private Helpers

  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end
