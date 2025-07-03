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
    {:ok, manager} =
      Raxol.Terminal.Buffer.Manager.start_link(
        Keyword.get(opts, :manager_opts,
          max_buffers: 10,
          default_size: {80, 24},
          default_scrollback: 1000
        )
      )

    # Create test buffer
    buffer =
      Raxol.Terminal.Buffer.Manager.initialize_buffers(
        manager,
        80,
        24,
        Keyword.get(opts, :buffer_opts,
          type: :standard,
          size: {80, 24},
          scrollback: 1000
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
    GenServer.stop(state.manager)

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
    Raxol.Terminal.Buffer.Manager.initialize_buffers(
      manager,
      80,
      24,
      Keyword.get(opts, :buffer_opts,
        type: :standard,
        size: {80, 24},
        scrollback: 1000
      )
    )
  end

  @doc """
  Writes test data to the buffer.

  ## Parameters
    * `buffer` - The buffer to write to
    * `data` - The data to write
    * `opts` - Write options

  ## Returns
    * `{:ok, buffer}` - The updated buffer
    * `{:error, reason}` - If write fails

  ## Examples
      iex> write_test_data(buffer, "Hello, World!")
      :ok
  """
  def write_test_data(manager, data, opts \\ []) do
    Raxol.Terminal.Buffer.Manager.write(manager, data, opts)
  end

  @doc """
  Reads test data from the buffer.

  ## Parameters
    * `buffer` - The buffer to read from
    * `opts` - Read options

  ## Returns
    * `{:ok, data}` - The read data
    * `{:error, reason}` - If read fails

  ## Examples
      iex> read_test_data(buffer)
      {:ok, "Hello, World!"}
  """
  def read_test_data(manager, opts \\ []) do
    Raxol.Terminal.Buffer.Manager.read(manager, opts)
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
  def verify_buffer_content(manager, expected_content, opts \\ []) do
    case read_test_data(manager, opts) do
      {:ok, ^expected_content} -> :ok
      {:ok, actual_content} -> {:error, {:unexpected_content, actual_content}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Performs a test operation on the buffer.

  ## Parameters
    * `buffer` - The buffer to operate on
    * `operation` - The operation to perform
    * `opts` - Operation options

  ## Returns
    * `{:ok, buffer}` - The updated buffer
    * `{:error, reason}` - If operation fails

  ## Examples
      iex> perform_test_operation(buffer, :write, data: "Hello, World!")
      :ok
  """
  def perform_test_operation(manager, operation, opts \\ []) do
    case operation do
      :clear ->
        Raxol.Terminal.Buffer.Manager.clear_damage(manager)

      :resize ->
        Raxol.Terminal.Buffer.Manager.resize(
          manager,
          Keyword.get(opts, :size, {80, 24}),
          opts
        )

      _ ->
        {:error, :invalid_operation}
    end
  end
end
