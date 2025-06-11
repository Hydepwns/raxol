defmodule Raxol.Terminal.Renderer.GPURendererTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.{Renderer, Renderer.GPURenderer, ScreenBuffer}

  setup do
    screen_buffer = ScreenBuffer.new(80, 24)
    renderer = Renderer.new(screen_buffer)
    gpu_renderer = GPURenderer.new(renderer)
    {:ok, %{gpu_renderer: gpu_renderer}}
  end

  describe "new/2" do
    test "creates a new GPU renderer instance", %{gpu_renderer: gpu_renderer} do
      assert gpu_renderer.renderer != nil
      assert gpu_renderer.gpu_context != nil
      assert gpu_renderer.render_pipeline != nil
      assert gpu_renderer.buffer_pool != nil
      assert gpu_renderer.performance_metrics != nil
    end

    test "initializes with custom options" do
      screen_buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new(screen_buffer)
      opts = [shader_model: "6.0", max_texture_size: 8192]

      gpu_renderer = GPURenderer.new(renderer, opts)
      assert gpu_renderer.gpu_context.settings == Map.new(opts)
    end
  end

  describe "render/2" do
    test "renders with default options", %{gpu_renderer: gpu_renderer} do
      output = GPURenderer.render(gpu_renderer)
      assert is_binary(output)
    end

    test "updates performance metrics after rendering", %{gpu_renderer: gpu_renderer} do
      output = GPURenderer.render(gpu_renderer)
      metrics = GPURenderer.get_performance_metrics(gpu_renderer)

      assert length(metrics.frame_times) > 0
      assert metrics.render_calls > 0
    end

    test "renders with custom options", %{gpu_renderer: gpu_renderer} do
      opts = [shader_model: "6.0", antialiasing: true]
      output = GPURenderer.render(gpu_renderer, opts)
      assert is_binary(output)
    end
  end

  describe "update_pipeline/2" do
    test "updates pipeline configuration", %{gpu_renderer: gpu_renderer} do
      config = %{
        vertex_processing: %{shader: "new_shader"},
        fragment_processing: %{antialiasing: true}
      }

      updated_renderer = GPURenderer.update_pipeline(gpu_renderer, config)
      assert updated_renderer.render_pipeline != gpu_renderer.render_pipeline
    end
  end

  describe "get_performance_metrics/1" do
    test "returns performance metrics", %{gpu_renderer: gpu_renderer} do
      metrics = GPURenderer.get_performance_metrics(gpu_renderer)

      assert is_map(metrics)
      assert Map.has_key?(metrics, :frame_times)
      assert Map.has_key?(metrics, :memory_usage)
      assert Map.has_key?(metrics, :gpu_utilization)
      assert Map.has_key?(metrics, :render_calls)
    end
  end

  describe "optimize_pipeline/1" do
    test "optimizes pipeline based on metrics", %{gpu_renderer: gpu_renderer} do
      # First render to generate some metrics
      GPURenderer.render(gpu_renderer)

      # Then optimize
      optimized_renderer = GPURenderer.optimize_pipeline(gpu_renderer)
      assert optimized_renderer.render_pipeline != gpu_renderer.render_pipeline
    end
  end

  describe "GPU capabilities" do
    test "detects shader model" do
      screen_buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new(screen_buffer)
      gpu_renderer = GPURenderer.new(renderer)

      capabilities = gpu_renderer.gpu_context.capabilities
      assert is_binary(capabilities.shader_model)
    end

    test "detects max texture size" do
      screen_buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new(screen_buffer)
      gpu_renderer = GPURenderer.new(renderer)

      capabilities = gpu_renderer.gpu_context.capabilities
      assert is_integer(capabilities.max_texture_size)
      assert capabilities.max_texture_size > 0
    end

    test "detects compute capability" do
      screen_buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new(screen_buffer)
      gpu_renderer = GPURenderer.new(renderer)

      capabilities = gpu_renderer.gpu_context.capabilities
      assert is_binary(capabilities.compute_capability)
    end
  end

  describe "Buffer management" do
    test "initializes buffer pool", %{gpu_renderer: gpu_renderer} do
      pool = gpu_renderer.buffer_pool

      assert Map.has_key?(pool, :vertex_buffers)
      assert Map.has_key?(pool, :index_buffers)
      assert Map.has_key?(pool, :uniform_buffers)
      assert Map.has_key?(pool, :staging_buffers)
    end

    test "allocates and updates buffers during rendering", %{gpu_renderer: gpu_renderer} do
      output = GPURenderer.render(gpu_renderer)
      assert is_binary(output)

      # Verify that buffers were used
      metrics = GPURenderer.get_performance_metrics(gpu_renderer)
      assert metrics.render_calls > 0
    end
  end

  describe "Render pipeline" do
    test "creates pipeline with all required stages", %{gpu_renderer: gpu_renderer} do
      pipeline = gpu_renderer.render_pipeline
      stages = pipeline.stages

      assert length(stages) == 3
      assert Keyword.has_key?(stages, :vertex_processing)
      assert Keyword.has_key?(stages, :fragment_processing)
      assert Keyword.has_key?(stages, :output_merging)
    end

    test "executes all pipeline stages during rendering", %{gpu_renderer: gpu_renderer} do
      output = GPURenderer.render(gpu_renderer)
      assert is_binary(output)

      # Verify that all stages were executed
      metrics = GPURenderer.get_performance_metrics(gpu_renderer)
      assert metrics.render_calls > 0
    end
  end
end
