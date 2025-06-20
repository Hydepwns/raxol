defmodule Raxol.Terminal.MemoryManager do
  @moduledoc """
  Manages memory usage and limits for the terminal emulator.
  """

  use GenServer

  @type t :: %__MODULE__{
          max_memory: non_neg_integer(),
          current_memory: non_neg_integer(),
          memory_limit: non_neg_integer()
        }

  defstruct [
    # 1MB default
    max_memory: 1024 * 1024,
    current_memory: 0,
    # 1MB default
    memory_limit: 1024 * 1024
  ]

  # Client API

  @doc """
  Starts the memory manager process.
  """
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets the current memory usage.
  """
  def get_memory_usage(memory_manager) do
    GenServer.call(memory_manager, :get_memory_usage)
  end

  @doc """
  Updates memory usage for the given state.
  """
  def update_usage(state) do
    current_memory = calculate_memory_usage(state)
    %{state | memory_usage: current_memory}
  end

  @doc """
  Checks if the current memory usage is within limits.
  """
  def within_limits?(memory_manager, state) do
    GenServer.call(memory_manager, {:within_limits, state})
  end

  @doc """
  Checks if scrolling is needed based on memory usage.
  """
  def should_scroll?(memory_manager, state) do
    GenServer.call(memory_manager, {:should_scroll, state})
  end

  @doc """
  Checks and cleans up memory if needed.
  """
  def check_and_cleanup(state) do
    current_memory = calculate_memory_usage(state)

    if current_memory > state.memory_limit do
      # Perform cleanup
      cleanup_memory(state)
    else
      state
    end
  end

  @doc """
  Estimates memory usage for the given state.
  Returns the estimated memory usage in bytes.
  """
  def estimate_memory_usage(state) do
    calculate_memory_usage(state)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:within_limits, state}, _from, memory_manager) do
    current_memory = calculate_memory_usage(state)
    within_limits = current_memory <= memory_manager.memory_limit
    {:reply, within_limits, %{memory_manager | current_memory: current_memory}}
  end

  @impl true
  def handle_call({:should_scroll, state}, _from, memory_manager) do
    current_memory = calculate_memory_usage(state)
    should_scroll = current_memory > memory_manager.memory_limit * 0.8
    {:reply, should_scroll, %{memory_manager | current_memory: current_memory}}
  end

  @impl true
  def handle_call(:get_memory_usage, _from, memory_manager) do
    {:reply, memory_manager.current_memory, memory_manager}
  end

  # Private Functions

  defp calculate_memory_usage(state) do
    # Calculate memory usage from various components
    buffer_usage = calculate_buffer_usage(state)
    scrollback_usage = calculate_scrollback_usage(state)
    other_usage = calculate_other_usage(state)

    buffer_usage + scrollback_usage + other_usage
  end

  defp calculate_buffer_usage(state) do
    case state do
      %{buffer: buffer} when not is_nil(buffer) ->
        Raxol.Terminal.Buffer.MemoryManager.calculate_buffer_usage(buffer)

      _ ->
        0
    end
  end

  defp calculate_scrollback_usage(state) do
    case state do
      %{scrollback: scrollback} when not is_nil(scrollback) ->
        Raxol.Terminal.Buffer.MemoryManager.calculate_buffer_usage(scrollback)

      _ ->
        0
    end
  end

  defp calculate_other_usage(state) do
    # Calculate memory usage for other terminal components
    style_usage = byte_size(:erlang.term_to_binary(state.style || %{}))

    charset_usage =
      byte_size(:erlang.term_to_binary(state.charset_state || %{}))

    mode_usage = byte_size(:erlang.term_to_binary(state.mode_manager || %{}))
    cursor_usage = byte_size(:erlang.term_to_binary(state.cursor || %{}))

    style_usage + charset_usage + mode_usage + cursor_usage
  end

  defp cleanup_memory(state) do
    # Trim scrollback history to reduce memory usage
    case state do
      %{scrollback: scrollback} when not is_nil(scrollback) ->
        trimmed_scrollback =
          Raxol.Terminal.Buffer.MemoryManager.trim_scrollback(scrollback)

        %{state | scrollback: trimmed_scrollback}

      _ ->
        state
    end
  end
end
