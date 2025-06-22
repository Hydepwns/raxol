defmodule Raxol.Test.Support.TestHelper do
  @moduledoc """
  Provides common test utilities and setup functions for Raxol tests.

  This module includes:
  - Test environment setup
  - Mock data generation
  - Common test scenarios
  - Cleanup utilities
  """

  use ExUnit.CaseTemplate
  alias Raxol.Core.Events.{Event}
  require Raxol.Core.Runtime.Log

  @doc """
  Sets up a test environment with necessary services and configurations.
  """
  def setup_test_env do
    # Start any required services
    {:ok, _} = Application.ensure_all_started(:raxol)

    # Set up mocks
    Raxol.Test.Support.Mocks.setup_mocks()

    # Create a test context
    context = %{
      test_id: :rand.uniform(1_000_000),
      start_time: System.monotonic_time()
    }

    {:ok, context}
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
    {:ok, pid} = module.start_link(initial_state)
    pid
  end

  @doc """
  Cleans up test resources and resets the environment.
  """
  def cleanup_test_env do
    # Implement cleanup logic if needed
    :ok
  end
end
