defmodule Raxol.Test.Support.TestHelper do
  @moduledoc '''
  Provides common test utilities and setup functions for Raxol tests.

  This module includes:
  - Test environment setup
  - Mock data generation
  - Common test scenarios
  - Cleanup utilities
  '''

  use ExUnit.CaseTemplate
  # Remove unused imports
  # import ExUnit.Assertions
  # import Mox
  alias Raxol.Core.Events.{Event}
  require Raxol.Core.Runtime.Log

  @doc '''
  Sets up a test environment with necessary services and configurations.
  '''
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

  @doc '''
  Creates a mock terminal for testing.
  '''
  def setup_test_terminal do
    %{
      width: 80,
      height: 24,
      output: [],
      cursor: {0, 0}
    }
  end

  @doc '''
  Generates test events for common scenarios.
  '''
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

  @doc '''
  Creates a test component with the given module and initial state.
  '''
  def create_test_component(module, initial_state \\ %{}) do
    {:ok, pid} = module.start_link(initial_state)
    pid
  end

  @doc '''
  Cleans up test resources and resets the environment.
  '''
  def cleanup_test_env(context) do
    # Clean up any processes started during the test
    if pid = Process.whereis(context.test_id), do: Process.exit(pid, :shutdown)

    # Reset any global state
    Application.put_env(:raxol, :test_mode, true)

    :ok
  end

  @doc '''
  Sets up common mocks for a test.
  '''
  def setup_common_mocks do
    # Set up default mock implementations
    Raxol.Test.Support.Mocks.setup_mocks()

    # Set up specific mock expectations if needed
    # Example:
    # expect(FileWatcherMock, :setup_file_watching, fn state -> {:ok, state} end)

    :ok
  end

  @doc '''
  Creates a test plugin with the given configuration.
  '''
  def create_test_plugin(name, config \\ %{}) do
    %{
      name: name,
      module: String.to_atom("Elixir.Raxol.Test.Plugins.#{name}"),
      config: config,
      enabled: true,
      metadata: %{
        version: "1.0.0",
        description: "Test plugin #{name}",
        author: "Test Author",
        dependencies: []
      }
    }
  end

  @doc '''
  Creates a test plugin module with the given name and callbacks.
  '''
  def create_test_plugin_module(name, callbacks \\ %{}) do
    module_name = String.to_atom("Elixir.Raxol.Test.Plugins.#{name}")

    defmodule module_name do
      @behaviour Raxol.Core.Runtime.Plugins.Plugin.Behaviour

      @impl true
      def init(config) do
        {:ok, Map.merge(%{initialized: true}, config)}
      end

      @impl true
      def handle_event(event, state) do
        if callback = Map.get(callbacks, :handle_event) do
          callback.(event, state)
        else
          {:ok, state}
        end
      end

      @impl true
      def handle_command(command, args, state) do
        if callback = Map.get(callbacks, :handle_command) do
          callback.(command, args, state)
        else
          {:ok, state}
        end
      end

      @impl true
      def get_commands do
        Map.get(callbacks, :get_commands, [])
      end

      @impl true
      def get_metadata do
        Map.get(callbacks, :get_metadata, %{
          name: name,
          version: "1.0.0",
          description: "Test plugin #{name}",
          author: "Test Author",
          dependencies: []
        })
      end
    end

    module_name
  end
end
