defmodule Raxol.Terminal.IntegrationTest do
  use ExUnit.Case, async: false
  alias Raxol.Test.{IntegrationHelper, MetricsHelper, BufferHelper, RendererHelper}

  setup do
    {:ok, state} = IntegrationHelper.setup_integration_test(
      metrics_opts: [enable_collector: true, enable_aggregator: true],
      buffer_opts: [enable_metrics: true],
      renderer_opts: [enable_metrics: true]
    )
    on_exit(fn -> IntegrationHelper.cleanup_integration_test(state) end)
    {:ok, state: state}
  end

  describe "end-to-end terminal operations" do
    test "basic text rendering", %{state: state} do
      test_data = "Hello, World!"

      assert {:ok, metrics} = IntegrationHelper.perform_end_to_end_test(state, test_data)
      assert is_integer(metrics.write_time)
      assert is_integer(metrics.render_time)
    end

    test "buffer-renderer interaction", %{state: state} do
      test_data = "Test content with multiple lines\nLine 2\nLine 3"

      assert {:ok, %{buffer_metrics: buffer_metrics, renderer_metrics: renderer_metrics}} =
        IntegrationHelper.test_buffer_renderer_interaction(state, test_data)

      assert is_map(buffer_metrics)
      assert is_map(renderer_metrics)
    end

    test "metrics collection across components", %{state: state} do
      operations = [:buffer_write, :render, :metrics_collect]

      assert {:ok, metrics} = IntegrationHelper.test_metrics_interaction(state, operations)
      assert map_size(metrics) == length(operations)
    end
  end

  describe "component state synchronization" do
    test "waiting for components to reach desired state", %{state: state} do
      test_data = "Synchronized content"

      # Write to buffer
      assert {:ok, _} = BufferHelper.write_test_data(state.buffer.buffer, test_data)

      # Wait for both buffer and renderer to have the content
      assert :ok = IntegrationHelper.wait_for_components(state, %{
        buffer: test_data,
        renderer: test_data
      })
    end

    test "timeout when waiting for components", %{state: state} do
      assert {:error, :timeout} = IntegrationHelper.wait_for_components(
        state,
        %{buffer: "non-existent content"},
        timeout: 100
      )
    end
  end

  describe "performance testing" do
    test "renderer performance comparison", %{state: state} do
      test_data = String.duplicate("Test content ", 100)

      assert {:ok, _} = BufferHelper.write_test_data(state.buffer.buffer, test_data)

      assert {:ok, comparison} = RendererHelper.compare_rendering_modes(
        state.buffer.buffer,
        100
      )

      assert is_map(comparison.gpu)
      assert is_map(comparison.cpu)
      assert comparison.gpu.avg_time < comparison.cpu.avg_time
    end

    test "buffer write performance", %{state: state} do
      test_data = String.duplicate("Test content ", 1000)

      assert {:ok, metrics} = BufferHelper.perform_test_operation(
        state.buffer.buffer,
        :write,
        test_data
      )

      assert is_integer(metrics.write_time)
      assert is_integer(metrics.memory_usage)
    end
  end

  describe "error handling" do
    test "invalid buffer operations", %{state: state} do
      assert {:error, _} = BufferHelper.perform_test_operation(
        state.buffer.buffer,
        :invalid_operation,
        "test"
      )
    end

    test "invalid renderer operations", %{state: state} do
      assert {:error, _} = RendererHelper.render_test_content(
        state.renderer.renderer,
        nil
      )
    end

    test "metrics collection errors", %{state: state} do
      assert {:error, _} = MetricsHelper.verify_metrics(
        state.metrics,
        %{"non_existent_metric" => 100}
      )
    end
  end

  describe "component cleanup" do
    test "cleanup after test completion", %{state: state} do
      # Perform some operations
      test_data = "Test content"
      assert {:ok, _} = IntegrationHelper.perform_end_to_end_test(state, test_data)

      # Cleanup
      IntegrationHelper.cleanup_integration_test(state)

      # Verify components are stopped
      assert_raise RuntimeError, fn ->
        BufferHelper.write_test_data(state.buffer.buffer, "test")
      end

      assert_raise RuntimeError, fn ->
        RendererHelper.render_test_content(state.renderer.renderer, state.buffer.buffer)
      end
    end
  end
end
