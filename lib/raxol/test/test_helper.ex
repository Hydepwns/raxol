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
  import ExUnit.Assertions
  alias Raxol.Core.Events.{Event}
  require Raxol.Core.Runtime.Log

  @doc """
  Sets up a test environment with necessary services and configurations.
  """
  def setup_test_env do
    # Start any required services
    {:ok, _} = Application.ensure_all_started(:raxol)

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
    # Ensure the component's init/1 is called to set up required keys
    state =
      case function_exported?(module, :init, 1) do
        true -> module.init(initial_state)
        false -> initial_state
      end

    state =
      state
      |> (fn s ->
            if Map.has_key?(s, :style), do: s, else: Map.put(s, :style, %{})
          end).()
      |> (fn s ->
            if Map.has_key?(s, :disabled),
              do: s,
              else: Map.put(s, :disabled, false)
          end).()
      |> (fn s ->
            if Map.has_key?(s, :focused),
              do: s,
              else: Map.put(s, :focused, false)
          end).()
      |> (fn s ->
            attrs = Map.get(s, :attrs, %{})

            attrs =
              cond do
                is_list(attrs) -> Map.new(attrs)
                is_map(attrs) -> attrs
                true -> %{}
              end

            Map.put(s, :attrs, attrs)
          end).()

    %{
      module: module,
      state: state,
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
  @dialyzer {:nowarn_function, cleanup_test_env: 0}
  def cleanup_test_env do
    # Clean up any test-specific resources
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

  @doc """
  Waits for a condition to be true, with a timeout.
  Uses event-based synchronization instead of Process.sleep.
  """
  def wait_for_state(condition_fun, timeout_ms \\ 100) do
    start = System.monotonic_time(:millisecond)
    ref = make_ref()
    do_wait_for_state(condition_fun, start, timeout_ms, ref)
  end

  defp do_wait_for_state(condition_fun, start, timeout_ms, ref) do
    if condition_fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - start < timeout_ms do
        Process.send_after(self(), {:check_condition, ref}, 100)

        receive do
          {:check_condition, received_ref} when received_ref == ref ->
            do_wait_for_state(condition_fun, start, timeout_ms, ref)
        after
          timeout_ms ->
            flunk("Condition not met within \\#{timeout_ms}ms")
        end
      else
        flunk("Condition not met within \\#{timeout_ms}ms")
      end
    end
  end

  @doc """
  Cleans up a process and waits for it to be down.
  """
  def cleanup_process(pid, timeout \\ 5000) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      Process.exit(pid, :normal)

      receive do
        {:DOWN, ^ref, :process, _pid, _reason} -> :ok
      after
        timeout -> :timeout
      end
    end
  end

  @doc """
  Cleans up an ETS table.
  """
  def cleanup_ets_table(table) do
    if :ets.whereis(table) != :undefined do
      :ets.delete_all_objects(table)
    end
  end

  @doc """
  Cleans up a registry.
  """
  def cleanup_registry(registry) do
    if Process.whereis(registry) do
      Registry.unregister(registry, self())
    end
  end

  @doc """
  Creates a temporary directory for test files.
  """
  def create_temp_dir do
    dir = Path.join(System.tmp_dir!(), "raxol_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Cleans up a temporary directory.
  """
  def cleanup_temp_dir(dir) do
    File.rm_rf!(dir)
  end

  @doc """
  Starts a test event source.
  """
  def start_test_event_source(args \\ %{}, context \\ %{pid: self()}) do
    case Raxol.Core.Runtime.EventSourceTest.TestEventSource.start_link(
           args,
           context
         ) do
      {:ok, pid} -> pid
      other -> other
    end
  end

  @doc """
  Returns a complete theme struct for tests, merging any overrides provided.
  Ensures all required component_styles are present.
  """
  def test_theme(overrides \\ %{}) do
    base = Raxol.UI.Theming.Theme.default_theme()

    # Merge overrides deeply for component_styles, always fallback to base for missing keys
    override_styles = Map.get(overrides, :component_styles, %{})

    merged_styles =
      Map.merge(base.component_styles, override_styles, fn _k, v1, v2 ->
        Map.merge(v1, v2)
      end)

    # Ensure all keys from base are present
    merged_styles = Map.merge(base.component_styles, merged_styles)

    base
    |> Map.merge(overrides)
    |> Map.put(:component_styles, merged_styles)
  end
end
