defmodule Raxol.PluginTestHelpers do
  @moduledoc """
  Test helpers for Raxol plugins.

  Provides utilities for testing plugin lifecycle, hook registration,
  event handling, and configuration management.

  ## Usage

      defmodule MyPluginTest do
        use ExUnit.Case
        import Raxol.PluginTestHelpers

        test "plugin initializes correctly" do
          plugin = create_test_plugin(MyPlugin)
          assert plugin.state.initialized == true
        end

        test "plugin handles events" do
          plugin = create_test_plugin(MyPlugin)
          {plugin, result} = call_hook(plugin, :on_key, %{key: :enter})
          assert result == :handled
        end
      end
  """

  @type test_plugin :: %{
          module: atom(),
          state: term(),
          config: map(),
          hooks: list(),
          events: list(),
          call_log: list()
        }

  @doc """
  Create a test instance of a plugin.

  ## Options

    - `:config` - Plugin configuration
    - `:state` - Initial state override

  ## Example

      plugin = create_test_plugin(MyPlugin, config: %{enabled: true})
  """
  @spec create_test_plugin(module(), keyword()) :: test_plugin()
  def create_test_plugin(plugin_module, opts \\ []) do
    config = Keyword.get(opts, :config, %{})
    initial_state = Keyword.get(opts, :state)

    state =
      cond do
        initial_state != nil ->
          initial_state

        function_exported?(plugin_module, :init, 1) ->
          case plugin_module.init(config) do
            {:ok, s} -> s
            s when is_map(s) -> s
          end

        function_exported?(plugin_module, :init, 0) ->
          case plugin_module.init() do
            {:ok, s} -> s
            s when is_map(s) -> s
          end

        true ->
          %{}
      end

    hooks = get_plugin_hooks(plugin_module)

    %{
      module: plugin_module,
      state: state,
      config: config,
      hooks: hooks,
      events: [],
      call_log: []
    }
  end

  @doc """
  Call a hook on a test plugin.

  ## Example

      {plugin, result} = call_hook(plugin, :on_key, %{key: :enter})
  """
  @spec call_hook(test_plugin(), atom(), term()) :: {test_plugin(), term()}
  def call_hook(plugin, hook_name, args) do
    module = plugin.module
    state = plugin.state

    {new_state, result} =
      if function_exported?(module, hook_name, 2) do
        case apply(module, hook_name, [args, state]) do
          {:ok, new_state} -> {new_state, :ok}
          {:ok, new_state, result} -> {new_state, result}
          {:error, reason} -> {state, {:error, reason}}
          :ok -> {state, :ok}
          result -> {state, result}
        end
      else
        {state, {:error, :hook_not_found}}
      end

    call_entry = %{
      hook: hook_name,
      args: args,
      result: result,
      timestamp: System.monotonic_time(:millisecond)
    }

    updated_plugin = %{
      plugin
      | state: new_state,
        call_log: [call_entry | plugin.call_log]
    }

    {updated_plugin, result}
  end

  @doc """
  Simulate plugin lifecycle events.

  ## Example

      plugin = simulate_lifecycle(plugin, :enable)
      plugin = simulate_lifecycle(plugin, :disable)
  """
  @spec simulate_lifecycle(map(), atom()) :: map()
  def simulate_lifecycle(plugin, event) do
    module = plugin.module

    callback =
      case event do
        :enable -> :on_enable
        :disable -> :on_disable
        :load -> :on_load
        :unload -> :on_unload
        :start -> :on_start
        :stop -> :on_stop
        other -> other
      end

    if function_exported?(module, callback, 1) do
      new_state =
        case apply(module, callback, [plugin.state]) do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> plugin.state
        end

      %{plugin | state: new_state}
    else
      plugin
    end
  end

  @doc """
  Assert that a hook was called with specific arguments.

  ## Example

      assert_hook_called(plugin, :on_key)
      assert_hook_called(plugin, :on_key, %{key: :enter})
  """
  @spec assert_hook_called(map(), atom(), term()) :: :ok
  def assert_hook_called(plugin, hook_name, expected_args \\ nil) do
    calls =
      plugin.call_log
      |> Enum.filter(fn entry -> entry.hook == hook_name end)

    if Enum.empty?(calls) do
      raise ExUnit.AssertionError,
        message:
          "Expected hook #{inspect(hook_name)} to be called\nCall log: #{inspect(plugin.call_log)}"
    end

    if expected_args != nil do
      matching =
        Enum.any?(calls, fn entry ->
          entry.args == expected_args
        end)

      unless matching do
        actual_args = Enum.map(calls, & &1.args)

        raise ExUnit.AssertionError,
          message:
            "Expected hook #{inspect(hook_name)} to be called with #{inspect(expected_args)}\nActual calls: #{inspect(actual_args)}"
      end
    end

    :ok
  end

  @doc """
  Assert that a hook was not called.

  ## Example

      refute_hook_called(plugin, :on_error)
  """
  @spec refute_hook_called(map(), atom()) :: :ok
  def refute_hook_called(plugin, hook_name) do
    calls =
      plugin.call_log
      |> Enum.filter(fn entry -> entry.hook == hook_name end)

    unless Enum.empty?(calls) do
      raise ExUnit.AssertionError,
        message:
          "Expected hook #{inspect(hook_name)} NOT to be called\nBut it was called #{length(calls)} times"
    end

    :ok
  end

  @doc """
  Get the call count for a specific hook.

  ## Example

      count = hook_call_count(plugin, :on_key)
  """
  @spec hook_call_count(map(), atom()) :: non_neg_integer()
  def hook_call_count(plugin, hook_name) do
    plugin.call_log
    |> Enum.count(fn entry -> entry.hook == hook_name end)
  end

  @doc """
  Clear the call log.

  ## Example

      plugin = clear_call_log(plugin)
  """
  @spec clear_call_log(test_plugin()) :: test_plugin()
  def clear_call_log(plugin) do
    %{plugin | call_log: []}
  end

  @doc """
  Update plugin configuration.

  ## Example

      plugin = update_config(plugin, %{enabled: false})
  """
  @spec update_config(test_plugin(), map()) :: test_plugin()
  def update_config(plugin, new_config) do
    module = plugin.module
    merged_config = Map.merge(plugin.config, new_config)

    new_state =
      if function_exported?(module, :on_config_change, 2) do
        case module.on_config_change(merged_config, plugin.state) do
          {:ok, s} -> s
          s when is_map(s) -> s
          _ -> plugin.state
        end
      else
        plugin.state
      end

    %{plugin | config: merged_config, state: new_state}
  end

  @doc """
  Assert plugin state matches expected values.

  ## Example

      assert_state(plugin, %{enabled: true, count: 5})
  """
  @spec assert_state(map(), map() | keyword()) :: :ok
  def assert_state(plugin, expected) do
    expected_map =
      case expected do
        m when is_map(m) -> m
        kw when is_list(kw) -> Map.new(kw)
      end

    Enum.each(expected_map, fn {key, expected_value} ->
      actual_value = Map.get(plugin.state, key)

      unless actual_value == expected_value do
        raise ExUnit.AssertionError,
          message:
            "Expected plugin state.#{key} to be #{inspect(expected_value)}, got #{inspect(actual_value)}\n\nFull state: #{inspect(plugin.state)}"
      end
    end)

    :ok
  end

  @doc """
  Check if a plugin supports a specific hook.

  ## Example

      supports_hook?(plugin, :on_key)
  """
  @spec supports_hook?(map(), atom()) :: boolean()
  def supports_hook?(plugin, hook_name) do
    hook_name in plugin.hooks
  end

  @doc """
  Get plugin metadata if available.

  ## Example

      metadata = get_metadata(plugin)
  """
  @spec get_metadata(map()) :: map()
  def get_metadata(plugin) do
    module = plugin.module

    if function_exported?(module, :metadata, 0) do
      module.metadata()
    else
      %{
        name: module |> Module.split() |> List.last(),
        version: "0.0.0",
        description: "No description"
      }
    end
  end

  # Private helpers

  defp get_plugin_hooks(module) do
    # Common plugin hooks
    hooks = [
      :on_enable,
      :on_disable,
      :on_load,
      :on_unload,
      :on_start,
      :on_stop,
      :on_key,
      :on_mouse,
      :on_resize,
      :on_focus,
      :on_blur,
      :on_render,
      :on_config_change,
      :on_error
    ]

    Enum.filter(hooks, fn hook ->
      function_exported?(module, hook, 1) or function_exported?(module, hook, 2)
    end)
  end
end
