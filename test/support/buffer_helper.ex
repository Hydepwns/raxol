defmodule Raxol.Test.BufferHelper do
  @moduledoc """
  Test helper module for the buffer system.
  Provides utilities for setting up test environments, creating test buffers,
  performing buffer operations, and cleaning up after tests.
  """

  @doc """
  Sets up a test environment for buffer testing.

  ## Options
    * `:manager_opts` - Options for the buffer manager
    * `:buffer_opts` - Options for the test buffer
    * `:metrics_opts` - Options for metrics collection

  ## Returns
    * `{:ok, state}` - The test state containing the buffer manager and test buffer
  """
  def setup_buffer_test(opts \\ []) do
    # Start buffer manager
    {:ok, manager} = Raxol.Terminal.Buffer.Manager.start_link(
      Keyword.get(opts, :manager_opts, [
        max_buffers: 10,
        default_size: {80, 24},
        default_scrollback: 1000
      ])
    )

    # Create test buffer
    {:ok, buffer} = Raxol.Terminal.Buffer.Manager.create_buffer(
      Keyword.get(opts, :buffer_opts, [
        type: :standard,
        size: {80, 24},
        scrollback: 1000
      ])
    )

    # Setup metrics if enabled
    metrics_state = if Keyword.get(opts, :enable_metrics, true) do
      Raxol.Test.MetricsHelper.setup_metrics_test(
        Keyword.get(opts, :metrics_opts, [])
      )
    end

    %{
      manager: manager,
      buffer: buffer,
      metrics: metrics_state
    }
  end

  @doc """
  Cleans up the buffer test environment.

  ## Parameters
    * `state` - The test state returned by `setup_buffer_test/1`
  """
  def cleanup_buffer_test(state) do
    Raxol.Terminal.Buffer.Manager.stop(state.manager)
    if state.metrics do
      Raxol.Test.MetricsHelper.cleanup_metrics_test(state.metrics)
    end
  end

  @doc """
  Creates a test buffer with the specified options.

  ## Parameters
    * `manager` - The buffer manager
    * `opts` - Buffer creation options

  ## Returns
    * `{:ok, buffer}` - The created buffer
    * `{:error, reason}` - If buffer creation fails

  ## Examples
      iex> create_test_buffer(manager, type: :standard, size: {80, 24})
      {:ok, buffer}
  """
  def create_test_buffer(manager, opts \\ []) do
    Raxol.Terminal.Buffer.Manager.create_buffer(
      Keyword.merge([
        type: :standard,
        size: {80, 24},
        scrollback: 1000
      ], opts)
    )
  end

  @doc """
  Writes test data to a buffer.

  ## Parameters
    * `buffer` - The target buffer
    * `data` - The data to write
    * `opts` - Write options

  ## Returns
    * `:ok` - If the write was successful
    * `{:error, reason}` - If the write failed

  ## Examples
      iex> write_test_data(buffer, "Hello, World!")
      :ok
  """
  def write_test_data(buffer, data, opts \\ []) do
    Raxol.Terminal.Buffer.Manager.write(buffer, data, opts)
  end

  @doc """
  Reads test data from a buffer.

  ## Parameters
    * `buffer` - The source buffer
    * `opts` - Read options

  ## Returns
    * `{:ok, data}` - The read data
    * `{:error, reason}` - If the read failed

  ## Examples
      iex> read_test_data(buffer)
      {:ok, "Hello, World!"}
  """
  def read_test_data(buffer, opts \\ []) do
    Raxol.Terminal.Buffer.Manager.read(buffer, opts)
  end

  @doc """
  Verifies buffer content.

  ## Parameters
    * `buffer` - The buffer to verify
    * `expected_content` - The expected content
    * `opts` - Verification options

  ## Returns
    * `:ok` - If the content matches
    * `{:error, reason}` - If the content doesn't match

  ## Examples
      iex> verify_buffer_content(buffer, "Hello, World!")
      :ok
  """
  def verify_buffer_content(buffer, expected_content, opts \\ []) do
    case read_test_data(buffer, opts) do
      {:ok, ^expected_content} -> :ok
      {:ok, actual_content} -> {:error, {:unexpected_content, actual_content}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Performs a test buffer operation and records metrics.

  ## Parameters
    * `buffer` - The target buffer
    * `operation` - The operation to perform
    * `opts` - Operation options

  ## Returns
    * `:ok` - If the operation was successful
    * `{:error, reason}` - If the operation failed

  ## Examples
      iex> perform_test_operation(buffer, :write, data: "Hello, World!")
      :ok
  """
  def perform_test_operation(buffer, operation, opts \\ []) do
    start_time = System.monotonic_time(:millisecond)

    result = case operation do
      :write -> write_test_data(buffer, Keyword.get(opts, :data, ""), opts)
      :read -> read_test_data(buffer, opts)
      :clear -> Raxol.Terminal.Buffer.Manager.clear(buffer, opts)
      :resize -> Raxol.Terminal.Buffer.Manager.resize(buffer, Keyword.get(opts, :size, {80, 24}), opts)
      _ -> {:error, :invalid_operation}
    end

    if result == :ok or match?({:ok, _}, result) do
      duration = System.monotonic_time(:millisecond) - start_time
      Raxol.Test.MetricsHelper.record_test_metric(
        "buffer_operation",
        :performance,
        duration,
        tags: %{operation: operation}
      )
    end

    result
  end

  @doc """
  Creates a test buffer with specific content.

  ## Parameters
    * `manager` - The buffer manager
    * `content` - The initial content
    * `opts` - Buffer creation options

  ## Returns
    * `{:ok, buffer}` - The created buffer with content
    * `{:error, reason}` - If buffer creation or content writing fails

  ## Examples
      iex> create_test_buffer_with_content(manager, "Hello, World!")
      {:ok, buffer}
  """
  def create_test_buffer_with_content(manager, content, opts \\ []) do
    with {:ok, buffer} <- create_test_buffer(manager, opts),
         :ok <- write_test_data(buffer, content, opts) do
      {:ok, buffer}
    end
  end

  @doc """
  Waits for buffer content to match expected value.

  ## Parameters
    * `buffer` - The buffer to check
    * `expected_content` - The expected content
    * `opts` - Wait options
      * `:timeout` - Maximum time to wait (default: 1000ms)
      * `:check_interval` - Interval between checks (default: 100ms)

  ## Returns
    * `:ok` - If the content matches
    * `{:error, :timeout}` - If the content doesn't match within the timeout

  ## Examples
      iex> wait_for_buffer_content(buffer, "Hello, World!", timeout: 2000)
      :ok
  """
  def wait_for_buffer_content(buffer, expected_content, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    check_interval = Keyword.get(opts, :check_interval, 100)
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + timeout

    wait_for_buffer_content_loop(buffer, expected_content, opts, check_interval, end_time)
  end

  defp wait_for_buffer_content_loop(buffer, expected_content, opts, check_interval, end_time) do
    case verify_buffer_content(buffer, expected_content, opts) do
      :ok -> :ok
      {:error, _} ->
        if System.monotonic_time(:millisecond) >= end_time do
          {:error, :timeout}
        else
          Process.sleep(check_interval)
          wait_for_buffer_content_loop(buffer, expected_content, opts, check_interval, end_time)
        end
    end
  end
end
