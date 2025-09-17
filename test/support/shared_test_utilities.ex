defmodule Raxol.Test.SharedUtilities do
  @moduledoc """
  Shared test utilities used across multiple test helper modules.
  Centralizes common test functionality to avoid duplication.
  """

  @doc """
  Creates a test plugin module dynamically for testing purposes.

  ## Parameters
  - `name`: The name suffix for the test plugin module
  - `callbacks`: Map of callback name to arity for implementing the plugin behavior

  ## Examples
      iex> create_test_plugin_module("TestPlugin", %{start: 1, stop: 0})
      :"Elixir.TestPlugin.TestPlugin"
  """
  def create_test_plugin_module(name, callbacks \\ %{}) do
    module_name = String.to_atom("TestPlugin.#{name}")

    # Create a module with the given callbacks
    Module.create(
      module_name,
      """
      defmodule #{module_name} do
        @behaviour Raxol.Plugins.Plugin

        #{generate_callback_implementations(callbacks)}
      end
      """,
      Macro.Env.location(__ENV__)
    )

    module_name
  end

  @doc """
  Sets up basic test environment configuration.
  """
  def setup_basic_test_env do
    Application.put_env(:raxol, :test_mode, true)
    Application.put_env(:raxol, :database_enabled, false)
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
  Generates callback implementations for test plugin modules.
  """
  def generate_callback_implementations(callbacks) do
    Enum.map_join(callbacks, "\n\n", fn {callback, arity} ->
      args = List.duplicate("_", arity) |> Enum.join(", ")

      """
      @impl Raxol.Plugins.Plugin
      def #{callback}(#{args}) do
        :ok
      end
      """
    end)
  end

  @doc """
  Creates a basic test context map with common test data.
  """
  def create_test_context(opts \\ []) do
    %{
      test_mode: true,
      start_time: System.monotonic_time(),
      cleanup_functions: [],
      test_data: Keyword.get(opts, :test_data, %{})
    }
  end

  @doc """
  Cleans up test environment by resetting application environment.
  """
  def cleanup_basic_test_env do
    Application.delete_env(:raxol, :test_mode)
    Application.delete_env(:raxol, :database_enabled)
    Application.delete_env(:raxol, :terminal_test_mode)
  end

  @doc """
  Starts a supervised GenServer with automatic cleanup and unique naming.
  """
  def start_supervised_genserver(module, opts \\ []) do
    name = generate_unique_name(module)
    opts = Keyword.put(opts, :name, name)
    {:ok, pid} = ExUnit.Callbacks.start_supervised({module, opts})
    {pid, name}
  end

  @doc """
  Creates a temporary directory for test files with automatic cleanup.
  """
  def with_temp_dir(fun) do
    temp_dir =
      System.tmp_dir!() |> Path.join("raxol_test_#{:rand.uniform(100_000)}")

    File.mkdir_p!(temp_dir)

    try do
      fun.(temp_dir)
    after
      File.rm_rf!(temp_dir)
    end
  end

  @doc """
  Asserts that a process received a specific message within timeout.
  """
  def assert_received_message(expected_message, timeout \\ 100) do
    receive do
      ^expected_message -> :ok
    after
      timeout ->
        raise ExUnit.AssertionError,
          message:
            "Expected to receive #{inspect(expected_message)} within #{timeout}ms"
    end
  end

  @doc """
  Refutes that a process received a specific message within timeout.
  """
  def refute_received_message(unexpected_message, timeout \\ 100) do
    receive do
      ^unexpected_message ->
        raise ExUnit.AssertionError,
          message: "Unexpectedly received #{inspect(unexpected_message)}"
    after
      timeout -> :ok
    end
  end

  @doc """
  Generates a unique name for test processes to avoid conflicts.
  """
  def generate_unique_name(prefix) when is_binary(prefix) do
    String.to_atom("#{prefix}_#{System.unique_integer([:positive])}")
  end

  def generate_unique_name(module) when is_atom(module) do
    module
    |> Module.split()
    |> List.last()
    |> then(&"#{&1}_#{System.unique_integer([:positive])}")
    |> String.to_atom()
  end

  @doc """
  Sets up a test buffer with common configuration.
  """
  def setup_test_buffer(opts \\ []) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    %{
      width: width,
      height: height,
      cells:
        List.duplicate(List.duplicate(%{char: " ", style: %{}}, width), height),
      cursor: %{x: 0, y: 0},
      scroll_region: {0, height - 1}
    }
  end

  @doc """
  Asserts that two buffers are equal, with helpful diff output.
  """
  def assert_buffers_equal(actual, expected) do
    if actual != expected do
      raise ExUnit.AssertionError,
        message: """
        Buffers do not match:

        Expected:
        #{inspect(expected, pretty: true)}

        Actual:
        #{inspect(actual, pretty: true)}
        """
    end
  end

  @doc """
  Creates a test event with common fields.
  """
  def create_test_event(type, data \\ %{}) do
    %{
      type: type,
      timestamp: System.monotonic_time(),
      data: data,
      metadata: %{test: true}
    }
  end
end
