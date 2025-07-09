defmodule Raxol.Test.RendererHelper do
  @moduledoc """
  Test helper module for the rendering system.
  Provides utilities for setting up test environments, creating test renderers,
  performing rendering operations, and cleaning up after tests.
  """

  @doc """
  Sets up a test environment for renderer testing.

  ## Options
    * `:renderer_opts` - Options for the renderer
    * `:metrics_opts` - Options for metrics collection

  ## Returns
    * `{:ok, state}` - The test state containing the renderer
  """
  def setup_renderer_test(opts \\ []) do
    # Start renderer
    {:ok, renderer} =
      Raxol.Terminal.Renderer.start_link(
        Keyword.get(opts, :renderer_opts,
          mode: :gpu,
          double_buffering: true,
          vsync: true,
          batch_size: 1000,
          cache_size: 100
        )
      )

    # Setup metrics if enabled
    metrics_state =
      if Keyword.get(opts, :enable_metrics, true) do
        Raxol.Test.MetricsHelper.setup_metrics_test(
          Keyword.get(opts, :metrics_opts, [])
        )
      end

    %{
      renderer: renderer,
      metrics: metrics_state
    }
  end

  @doc """
  Cleans up the renderer test environment.

  ## Parameters
    * `state` - The test state returned by `setup_renderer_test/1`
  """
  def cleanup_renderer_test(state) do
    Raxol.Terminal.Renderer.stop(state.renderer)

    if state.metrics do
      Raxol.Test.MetricsHelper.cleanup_metrics_test(state.metrics)
    end
  end

  @doc """
  Creates a test renderer with the specified options.

  ## Parameters
    * `opts` - Renderer creation options

  ## Returns
    * `{:ok, renderer}` - The created renderer
    * `{:error, reason}` - If renderer creation fails

  ## Examples
      iex> create_test_renderer(mode: :gpu, double_buffering: true)
      {:ok, renderer}
  """
  def create_test_renderer(opts \\ []) do
    Raxol.Terminal.Renderer.start_link(
      Keyword.merge(
        [
          mode: :gpu,
          double_buffering: true,
          vsync: true,
          batch_size: 1000,
          cache_size: 100
        ],
        opts
      )
    )
  end

  @doc """
  Renders test content.

  ## Parameters
    * `renderer` - The renderer to use
    * `buffer` - The buffer to render
    * `opts` - Render options

  ## Returns
    * `:ok` - If the render was successful
    * `{:error, reason}` - If the render failed

  ## Examples
      iex> render_test_content(renderer, buffer)
      :ok
  """
  def render_test_content(renderer, buffer, opts \\ []) do
    if is_nil(buffer) do
      {:error, :invalid_buffer}
    else
      Raxol.Terminal.Renderer.render(renderer, buffer, opts)
    end
  end

  @doc """
  Verifies rendered content.

  ## Parameters
    * `renderer` - The renderer to check
    * `expected_content` - The expected rendered content
    * `opts` - Verification options

  ## Returns
    * `:ok` - If the content matches
    * `{:error, reason}` - If the content doesn't match

  ## Examples
      iex> verify_rendered_content(renderer, "Hello, World!")
      :ok
  """
  def verify_rendered_content(renderer, expected_content, opts \\ []) do
    # Get content from the renderer's screen buffer
    case Raxol.Terminal.Renderer.get_content(renderer.screen_buffer, opts) do
      {:ok, ^expected_content} -> :ok
      {:ok, actual_content} -> {:error, {:unexpected_content, actual_content}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies rendered content from a buffer manager.

  ## Parameters
    * `buffer_manager` - The buffer manager to check
    * `expected_content` - The expected rendered content
    * `opts` - Verification options

  ## Returns
    * `:ok` - If the content matches
    * `{:error, reason}` - If the content doesn't match

  ## Examples
      iex> verify_rendered_content_from_buffer(buffer_manager, "Hello, World!")
      :ok
  """
  def verify_rendered_content_from_buffer(buffer_manager, expected_content, opts \\ []) do
    # Get content directly from the buffer manager
    case Raxol.Terminal.Renderer.get_content(buffer_manager, opts) do
      {:ok, ^expected_content} -> :ok
      {:ok, actual_content} -> {:error, {:unexpected_content, actual_content}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Performs a test rendering operation and records metrics.

  ## Parameters
    * `renderer` - The renderer to use
    * `buffer` - The buffer to render
    * `opts` - Render options

  ## Returns
    * `:ok` - If the operation was successful
    * `{:error, reason}` - If the operation failed

  ## Examples
      iex> perform_test_render(renderer, buffer)
      :ok
  """
  def perform_test_render(renderer, buffer, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    result = render_test_content(renderer, buffer, opts)

    # Handle both :ok and HTML content as successful results
    case result do
      :ok ->
        duration = System.monotonic_time(:millisecond) - start_time

        Raxol.Test.MetricsHelper.record_test_metric(
          "render_operation",
          :performance,
          duration,
          tags: %{mode: Keyword.get(opts, :mode, :gpu)}
        )

        :ok

      html when is_binary(html) ->
        duration = System.monotonic_time(:millisecond) - start_time

        Raxol.Test.MetricsHelper.record_test_metric(
          "render_operation",
          :performance,
          duration,
          tags: %{mode: Keyword.get(opts, :mode, :gpu)}
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Tests rendering performance.

  ## Parameters
    * `renderer` - The renderer to test
    * `buffer` - The buffer to render
    * `iterations` - Number of render iterations
    * `opts` - Test options

  ## Returns
    * `{:ok, metrics}` - Performance metrics
    * `{:error, reason}` - If the test fails

  ## Examples
      iex> test_render_performance(renderer, buffer, 1000)
      {:ok, %{avg_time: 16, min_time: 15, max_time: 18}}
  """
  def test_render_performance(renderer, buffer, iterations, opts \\ []) do
    times =
      for _ <- 1..iterations do
        start_time = System.monotonic_time(:millisecond)
        case render_test_content(renderer, buffer, opts) do
          :ok -> :ok
          html when is_binary(html) -> :ok
          {:error, reason} -> {:error, reason}
        end
        System.monotonic_time(:millisecond) - start_time
      end

    metrics = %{
      avg_time: Enum.sum(times) / iterations,
      min_time: Enum.min(times),
      max_time: Enum.max(times)
    }

    Raxol.Test.MetricsHelper.record_test_metric(
      "render_performance",
      :performance,
      metrics.avg_time,
      tags: %{
        mode: Keyword.get(opts, :mode, :gpu),
        iterations: iterations
      }
    )

    {:ok, metrics}
  end

  @doc """
  Waits for rendered content to match expected value.

  ## Parameters
    * `renderer` - The renderer to check
    * `expected_content` - The expected content
    * `opts` - Wait options
      * `:timeout` - Maximum time to wait (default: 1000ms)
      * `:check_interval` - Interval between checks (default: 100ms)

  ## Returns
    * `:ok` - If the content matches
    * `{:error, :timeout}` - If the content doesn't match within the timeout

  ## Examples
      iex> wait_for_rendered_content(renderer, "Hello, World!", timeout: 2000)
      :ok
  """
  def wait_for_rendered_content(renderer, expected_content, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    check_interval = Keyword.get(opts, :check_interval, 100)
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + timeout

    wait_for_rendered_content_loop(
      renderer,
      expected_content,
      opts,
      check_interval,
      end_time
    )
  end

  defp wait_for_rendered_content_loop(
         renderer,
         expected_content,
         opts,
         check_interval,
         end_time
       ) do
    case verify_rendered_content(renderer, expected_content, opts) do
      :ok ->
        :ok

      {:error, _} ->
        if System.monotonic_time(:millisecond) >= end_time do
          {:error, :timeout}
        else
          Process.sleep(check_interval)

          wait_for_rendered_content_loop(
            renderer,
            expected_content,
            opts,
            check_interval,
            end_time
          )
        end
    end
  end

  @doc """
  Compares rendering performance between different modes.

  ## Parameters
    * `buffer` - The buffer to render
    * `iterations` - Number of render iterations
    * `opts` - Test options

  ## Returns
    * `{:ok, comparison}` - Performance comparison
    * `{:error, reason}` - If the comparison fails

  ## Examples
      iex> compare_rendering_modes(buffer, 1000)
      {:ok, %{gpu: %{avg_time: 16}, cpu: %{avg_time: 32}}}
  """
  def compare_rendering_modes(buffer, iterations, _opts \\ []) do
    with {:ok, gpu_renderer} <- create_test_renderer(mode: :gpu),
         {:ok, cpu_renderer} <- create_test_renderer(mode: :cpu),
         {:ok, gpu_metrics} <-
           test_render_performance(gpu_renderer, buffer, iterations, mode: :gpu),
         {:ok, cpu_metrics} <-
           test_render_performance(cpu_renderer, buffer, iterations, mode: :cpu) do
      Raxol.Terminal.Renderer.stop(gpu_renderer)
      Raxol.Terminal.Renderer.stop(cpu_renderer)
      {:ok, %{gpu: gpu_metrics, cpu: cpu_metrics}}
    end
  end
end
