defmodule Raxol.Test.Support.TestHelper do
  @moduledoc """
  Test helper functions for setting up test environments and common mocks.
  """

  @doc """
  Sets up the test environment with common configuration.
  """
  def setup_test_env do
    # Set up test-specific configuration
    Application.put_env(:raxol, :test_mode, true)
    Application.put_env(:raxol, :database_enabled, false)

    # Return a context map for tests
    {:ok,
     %{
       test_mode: true,
       database_enabled: false,
       mock_modules: []
     }}
  end

  @doc """
  Sets up common mocks used across tests.
  """
  def setup_common_mocks do
    # Set up Mox expectations for common mocks
    # This is a placeholder - actual mocks will be set up in individual tests
    :ok
  end

  @doc """
  Creates a test plugin for testing purposes.
  """
  def create_test_plugin(name, config \\ %{}) do
    %{
      name: name,
      module: String.to_atom("TestPlugin.#{name}"),
      config: config,
      enabled: true
    }
  end

  @doc """
  Creates a test emulator instance for testing.
  """
  def create_test_emulator do
    Raxol.Terminal.Emulator.new(80, 24)
  end

  @doc """
  Creates a test emulator instance with a struct cursor instead of a PID.
  This is useful for tests that need direct access to cursor fields.
  """
  def create_test_emulator_with_struct_cursor do
    emulator = Raxol.Terminal.Emulator.new(80, 24)

    # Create a struct cursor instead of using the PID cursor
    struct_cursor = %Raxol.Terminal.Cursor.Manager{
      row: 0,
      col: 0,
      style: :blink_block,
      visible: true
    }

    %{emulator | cursor: struct_cursor}
  end

  @doc """
  Creates a test emulator instance with custom settings.
  """
  def create_test_emulator(opts) do
    emulator = create_test_emulator()

    Enum.reduce(opts, emulator, fn {key, value}, acc ->
      case key do
        :settings -> set_settings(acc, value)
        :preferences -> set_preferences(acc, value)
        :environment -> set_environment(acc, value)
        _ -> acc
      end
    end)
  end

  @doc """
  Sets up test terminal environment.
  """
  def setup_test_terminal do
    # Set up terminal-specific test configuration
    Application.put_env(:raxol, :terminal_test_mode, true)
    :ok
  end

  @doc """
  Returns test events for testing.
  """
  def test_events do
    [
      {:key, %{key: :enter}},
      {:mouse, %{x: 10, y: 5, button: :left}},
      {:resize, %{width: 100, height: 50}}
    ]
  end

  @doc """
  Creates a test component for testing.
  """
  def create_test_component(module, initial_state \\ %{}) do
    %{
      module: module,
      state: initial_state,
      props: %{},
      children: []
    }
  end

  @doc """
  Creates a test plugin module for testing.
  """
  def create_test_plugin_module(name, callbacks \\ %{}) do
    module_name = String.to_atom("TestPlugin.#{name}")

    # Create a module with the given callbacks
    Module.create(
      module_name,
      """
      defmodule #{module_name} do
        @behaviour Raxol.Plugins.Plugin

        #{Enum.map_join(callbacks, "\n\n", fn {callback, arity} -> """
        @impl Raxol.Plugins.Plugin
        def #{callback}(#{List.duplicate("_", arity) |> Enum.join(", ")}) do
          :ok
        end
        """ end)}
      end
      """,
      Macro.Env.location(__ENV__)
    )

    module_name
  end

  @doc """
  Cleans up test environment for a specific environment.
  """
  def cleanup_test_env(env \\ :default)
  def cleanup_test_env(env) when is_atom(env) do
    # Clean up any test-specific configuration
    Application.delete_env(:raxol, :test_mode)
    Application.delete_env(:raxol, :database_enabled)
    Application.delete_env(:raxol, :terminal_test_mode)

    # Clean up environment-specific configuration
    case env do
      :test ->
        Application.delete_env(:raxol, :test_mode)

      :development ->
        Application.delete_env(:raxol, :dev_mode)

      :production ->
        Application.delete_env(:raxol, :prod_mode)

      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Cleans up test environment with context parameter.
  """
  def cleanup_test_env(context) when is_map(context) do
    # Extract environment from context or use default
    env = Map.get(context, :env, :default)
    cleanup_test_env(env)
  end

  # Private helper functions
  defp set_settings(emulator, settings) do
    Enum.reduce(settings, emulator, fn {key, value}, acc ->
      Raxol.Terminal.Config.Manager.set_setting(acc, key, value)
    end)
  end

  defp set_preferences(emulator, preferences) do
    Enum.reduce(preferences, emulator, fn {key, value}, acc ->
      Raxol.Terminal.Config.Manager.set_preference(acc, key, value)
    end)
  end

  defp set_environment(emulator, env) do
    Raxol.Terminal.Config.Manager.set_environment_variables(emulator, env)
  end
end
