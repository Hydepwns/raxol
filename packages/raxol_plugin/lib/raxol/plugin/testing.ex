defmodule Raxol.Plugin.Testing do
  @moduledoc """
  Test helpers for Raxol plugins.

  Provides utilities for exercising plugin callbacks in isolation
  without starting the full plugin manager infrastructure.

  ## Usage

      use ExUnit.Case
      import Raxol.Plugin.Testing

      test "handles events" do
        {:ok, state} = setup_plugin(MyPlugin, %{key: "value"})
        assert_handles_event(MyPlugin, :some_event, state)
      end
  """

  @compile {:no_warn_undefined, Raxol.Core.Runtime.Plugins.Plugin}

  @doc """
  Initializes a plugin module with the given config and returns its state.

  Calls `module.init(config)` and asserts it returns `{:ok, state}`.

  ## Examples

      {:ok, state} = setup_plugin(MyPlugin, %{})
  """
  @spec setup_plugin(module(), map()) :: {:ok, term()} | {:error, term()}
  def setup_plugin(module, config \\ %{}) do
    module.init(config)
  end

  @doc """
  Asserts that a plugin handles an event without halting.

  Calls `module.filter_event(event, state)` and asserts the result
  matches `{:ok, _}`. Returns the (possibly modified) event.

  ## Examples

      event = assert_handles_event(MyPlugin, :click, state)
  """
  @spec assert_handles_event(module(), term(), term()) :: term()
  def assert_handles_event(module, event, state) do
    result = module.filter_event(event, state)

    case result do
      {:ok, returned_event} ->
        returned_event

      :halt ->
        raise ExUnit.AssertionError,
          message: "Expected plugin to handle event, but it halted",
          expr: {:filter_event, [event, state]}

      other ->
        raise ExUnit.AssertionError,
          message: "Expected {:ok, event}, got: #{inspect(other)}",
          expr: {:filter_event, [event, state]}
    end
  end

  @doc """
  Asserts that a plugin handles a command successfully.

  Calls `module.handle_command(command, args, state)` and asserts the
  result matches `{:ok, new_state, result}`. Returns `{new_state, result}`.

  ## Examples

      {new_state, result} = assert_handles_command(MyPlugin, :do_thing, [1, 2], state)
  """
  @spec assert_handles_command(module(), atom() | tuple(), list(), term()) :: {term(), term()}
  def assert_handles_command(module, command, args, state) do
    result = module.handle_command(command, args, state)

    case result do
      {:ok, new_state, cmd_result} ->
        {new_state, cmd_result}

      {:error, reason, _new_state} ->
        raise ExUnit.AssertionError,
          message: "Expected command to succeed, got error: #{inspect(reason)}",
          expr: {:handle_command, [command, args, state]}

      other ->
        raise ExUnit.AssertionError,
          message: "Expected {:ok, state, result}, got: #{inspect(other)}",
          expr: {:handle_command, [command, args, state]}
    end
  end

  @doc """
  Runs a plugin through its full lifecycle: init -> enable -> disable -> terminate.

  Asserts each step succeeds. Returns a list of `{callback, result}` tuples
  for inspection.

  ## Examples

      steps = simulate_lifecycle(MyPlugin, %{option: true})
      assert length(steps) == 4
  """
  @spec simulate_lifecycle(module(), map()) :: [{atom(), term()}]
  def simulate_lifecycle(module, config \\ %{}) do
    {:ok, state} = module.init(config)
    init_step = {:init, {:ok, state}}

    {:ok, enabled_state} = module.enable(state)
    enable_step = {:enable, {:ok, enabled_state}}

    {:ok, disabled_state} = module.disable(enabled_state)
    disable_step = {:disable, {:ok, disabled_state}}

    terminate_result = module.terminate(:normal, disabled_state)
    terminate_step = {:terminate, terminate_result}

    [init_step, enable_step, disable_step, terminate_step]
  end

  @doc """
  Asserts that a plugin halts a given event.

  Calls `module.filter_event(event, state)` and asserts the result is `:halt`.

  ## Examples

      assert_halts_event(MyPlugin, :blocked_event, state)
  """
  @spec assert_halts_event(module(), term(), term()) :: :halt
  def assert_halts_event(module, event, state) do
    result = module.filter_event(event, state)

    case result do
      :halt ->
        :halt

      {:ok, _} ->
        raise ExUnit.AssertionError,
          message: "Expected plugin to halt event, but it passed through",
          expr: {:filter_event, [event, state]}

      other ->
        raise ExUnit.AssertionError,
          message: "Expected :halt, got: #{inspect(other)}",
          expr: {:filter_event, [event, state]}
    end
  end
end
