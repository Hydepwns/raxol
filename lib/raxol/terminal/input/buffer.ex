defmodule Raxol.Terminal.Input.Buffer do
  @moduledoc """
  Manages input buffering for the terminal emulator.
  """

  use GenServer

  # Client API

  @doc """
  Starts the input buffer.
  """
  @spec start_link() :: GenServer.on_start()
  def start_link do
    start_link([])
  end

  @doc """
  Starts the input buffer with options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @doc """
  Feeds input to the buffer for the given process.
  """
  def feed_input(pid, input) do
    GenServer.cast(pid, {:feed_input, input})
  end

  @doc """
  Registers a callback for the input buffer process.
  """
  def register_callback(pid, callback) do
    GenServer.cast(pid, {:register_callback, callback})
  end

  @doc """
  Clears the input buffer for the given process.
  """
  def clear_buffer(pid) do
    GenServer.cast(pid, :clear_buffer)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    max_buffer_size = Keyword.get(opts, :max_buffer_size, 1024)
    callback_timeout = Keyword.get(opts, :callback_timeout, 50)

    {:ok,
     %{
       buffer: "",
       max_buffer_size: max_buffer_size,
       callback: nil,
       callback_timeout: callback_timeout,
       timer_ref: nil
     }}
  end

  @impl true
  def handle_cast({:feed_input, input}, state) do
    updated_buffer = state.buffer <> input
    truncated_buffer = truncate_buffer(updated_buffer, state.max_buffer_size)

    new_state = %{state | buffer: truncated_buffer}

    case state.callback do
      nil ->
        {:noreply, new_state}

      callback when is_function(callback, 1) ->
        # Reset timer if it exists
        new_state_with_timer = cancel_existing_timer(new_state)

        # Start new timer
        timer_ref =
          Process.send_after(self(), :flush_callback, state.callback_timeout)

        {:noreply, %{new_state_with_timer | timer_ref: timer_ref}}
    end
  end

  @impl true
  def handle_cast({:register_callback, callback}, state) do
    {:noreply, %{state | callback: callback}}
  end

  @impl true
  def handle_cast(:clear_buffer, state) do
    new_state = cancel_existing_timer(%{state | buffer: ""})
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:flush_callback, state) do
    case {state.callback, state.buffer} do
      {callback, buffer} when is_function(callback, 1) and buffer != "" ->
        try do
          callback.(buffer)
        rescue
          error ->
            # Log error but continue
            require Logger
            Logger.error("Input buffer callback error: #{inspect(error)}")
        end

        {:noreply, %{state | buffer: "", timer_ref: nil}}

      _ ->
        {:noreply, %{state | timer_ref: nil}}
    end
  end

  # Private helpers

  defp truncate_buffer(buffer, max_size) when byte_size(buffer) > max_size do
    binary_part(buffer, byte_size(buffer) - max_size, max_size)
  end

  defp truncate_buffer(buffer, _max_size), do: buffer

  defp cancel_existing_timer(%{timer_ref: nil} = state), do: state

  defp cancel_existing_timer(%{timer_ref: timer_ref} = state) do
    Process.cancel_timer(timer_ref)
    %{state | timer_ref: nil}
  end
end
