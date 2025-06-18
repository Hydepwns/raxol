defmodule Raxol.Test.IntegrationHelper do
  @moduledoc """
  Test helper module for integration testing.
  Provides utilities for setting up test environments with multiple components,
  coordinating interactions between components, and cleaning up after tests.
  """

  @doc """
  Sets up an integration test environment.

  ## Options
    * `:components` - List of components to start (default: [:metrics, :buffer, :renderer])
    * `:metrics_opts` - Options for metrics collection
    * `:buffer_opts` - Options for buffer management
    * `:renderer_opts` - Options for rendering

  ## Returns
    * `{:ok, state}` - The test state containing all started components
  """
  def setup_integration_test(opts \\ []) do
    components = Keyword.get(opts, :components, [:metrics, :buffer, :renderer])
    state = %{}

    state =
      if :metrics in components do
        metrics_state =
          Raxol.Test.MetricsHelper.setup_metrics_test(
            Keyword.get(opts, :metrics_opts, [])
          )

        Map.put(state, :metrics, metrics_state)
      else
        state
      end

    state =
      if :buffer in components do
        buffer_state =
          Raxol.Test.BufferHelper.setup_buffer_test(
            Keyword.get(opts, :buffer_opts, [])
          )

        Map.put(state, :buffer, buffer_state)
      else
        state
      end

    state =
      if :renderer in components do
        renderer_state =
          Raxol.Test.RendererHelper.setup_renderer_test(
            Keyword.get(opts, :renderer_opts, [])
          )

        Map.put(state, :renderer, renderer_state)
      else
        state
      end

    {:ok, state}
  end

  @doc """
  Cleans up the integration test environment.

  ## Parameters
    * `state` - The test state returned by `setup_integration_test/1`
  """
  def cleanup_integration_test(state) do
    if state.metrics do
      Raxol.Test.MetricsHelper.cleanup_metrics_test(state.metrics)
    end

    if state.buffer do
      Raxol.Test.BufferHelper.cleanup_buffer_test(state.buffer)
    end

    if state.renderer do
      Raxol.Test.RendererHelper.cleanup_renderer_test(state.renderer)
    end
  end

  @doc """
  Performs an end-to-end test of the terminal system.

  ## Parameters
    * `state` - The test state
    * `test_data` - The data to write to the buffer
    * `opts` - Test options

  ## Returns
    * `{:ok, metrics}` - Test results and metrics
    * `{:error, reason}` - If the test fails

  ## Examples
      iex> perform_end_to_end_test(state, "Hello, World!")
      {:ok, %{write_time: 5, render_time: 16}}
  """
  def perform_end_to_end_test(state, test_data, opts \\ []) do
    with {:ok, _} <-
           Raxol.Test.BufferHelper.write_test_data(
             state.buffer.buffer,
             test_data
           ),
         :ok <-
           Raxol.Test.RendererHelper.render_test_content(
             state.renderer.renderer,
             state.buffer.buffer
           ),
         :ok <-
           Raxol.Test.RendererHelper.verify_rendered_content(
             state.renderer.renderer,
             test_data
           ) do
      metrics = %{
        write_time:
          Raxol.Test.MetricsHelper.get_metric_value(
            state.metrics,
            "buffer_write_time"
          ),
        render_time:
          Raxol.Test.MetricsHelper.get_metric_value(
            state.metrics,
            "render_operation"
          )
      }

      {:ok, metrics}
    end
  end

  @doc """
  Tests the interaction between buffer and renderer components.

  ## Parameters
    * `state` - The test state
    * `test_data` - The data to write to the buffer
    * `opts` - Test options

  ## Returns
    * `{:ok, metrics}` - Test results and metrics
    * `{:error, reason}` - If the test fails

  ## Examples
      iex> test_buffer_renderer_interaction(state, "Test content")
      {:ok, %{buffer_metrics: %{}, renderer_metrics: %{}}}
  """
  def test_buffer_renderer_interaction(state, test_data, opts \\ []) do
    with {:ok, buffer_metrics} <-
           Raxol.Test.BufferHelper.perform_test_operation(
             state.buffer.buffer,
             :write,
             test_data
           ),
         :ok <-
           Raxol.Test.RendererHelper.render_test_content(
             state.renderer.renderer,
             state.buffer.buffer
           ),
         {:ok, renderer_metrics} <-
           Raxol.Test.RendererHelper.test_render_performance(
             state.renderer.renderer,
             state.buffer.buffer,
             Keyword.get(opts, :iterations, 1)
           ) do
      {:ok,
       %{buffer_metrics: buffer_metrics, renderer_metrics: renderer_metrics}}
    end
  end

  @doc """
  Tests the interaction between metrics and other components.

  ## Parameters
    * `state` - The test state
    * `operations` - List of operations to perform
    * `opts` - Test options

  ## Returns
    * `{:ok, metrics}` - Collected metrics
    * `{:error, reason}` - If the test fails

  ## Examples
      iex> test_metrics_interaction(state, [:buffer_write, :render])
      {:ok, %{buffer_write: 5, render: 16}}
  """
  def test_metrics_interaction(state, operations, opts \\ []) do
    metrics =
      Enum.reduce_while(operations, %{}, fn operation, acc ->
        case perform_operation(state, operation, opts) do
          {:ok, operation_metrics} ->
            {:cont, Map.put(acc, operation, operation_metrics)}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case metrics do
      {:error, reason} -> {:error, reason}
      metrics -> {:ok, metrics}
    end
  end

  @doc """
  Waits for all components to reach a desired state.

  ## Parameters
    * `state` - The test state
    * `conditions` - Map of component conditions to check
    * `opts` - Wait options
      * `:timeout` - Maximum time to wait (default: 5000ms)
      * `:check_interval` - Interval between checks (default: 100ms)

  ## Returns
    * `:ok` - If all conditions are met
    * `{:error, :timeout}` - If conditions aren't met within timeout

  ## Examples
      iex> wait_for_components(state, %{buffer: "content", renderer: "content"})
      :ok
  """
  def wait_for_components(state, conditions, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    check_interval = Keyword.get(opts, :check_interval, 100)
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + timeout

    wait_for_components_loop(state, conditions, opts, check_interval, end_time)
  end

  defp wait_for_components_loop(
         state,
         conditions,
         opts,
         check_interval,
         end_time
       ) do
    case check_conditions(state, conditions) do
      :ok ->
        :ok

      {:error, _} ->
        if System.monotonic_time(:millisecond) >= end_time do
          {:error, :timeout}
        else
          Process.sleep(check_interval)

          wait_for_components_loop(
            state,
            conditions,
            opts,
            check_interval,
            end_time
          )
        end
    end
  end

  defp check_conditions(state, conditions) do
    Enum.reduce_while(conditions, :ok, fn {component, condition}, :ok ->
      case check_component_condition(state, component, condition) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp check_component_condition(state, :buffer, expected_content) do
    Raxol.Test.BufferHelper.verify_buffer_content(
      state.buffer.buffer,
      expected_content
    )
  end

  defp check_component_condition(state, :renderer, expected_content) do
    Raxol.Test.RendererHelper.verify_rendered_content(
      state.renderer.renderer,
      expected_content
    )
  end

  defp check_component_condition(state, :metrics, expected_metrics) do
    case Raxol.Test.MetricsHelper.verify_metrics(
           state.metrics,
           expected_metrics
         ) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_operation(state, :buffer_write, opts) do
    Raxol.Test.BufferHelper.perform_test_operation(
      state.buffer.buffer,
      :write,
      Keyword.get(opts, :data, "test data")
    )
  end

  defp perform_operation(state, :render, opts) do
    Raxol.Test.RendererHelper.perform_test_render(
      state.renderer.renderer,
      state.buffer.buffer,
      opts
    )
  end

  defp perform_operation(state, :metrics_collect, opts) do
    Raxol.Test.MetricsHelper.collect_metrics(
      state.metrics,
      Keyword.get(opts, :metrics, [])
    )
  end
end
