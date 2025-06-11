defmodule Raxol.Terminal.Input.Buffer do
  @moduledoc """
  Handles input buffering and sequence detection for the terminal emulator.
  Manages partial input sequences and ensures complete events are processed.
  """

  use GenServer
  alias Raxol.Terminal.Input.{Processor, Event}

  # Client API

  @doc """
  Starts the input buffer process.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Feeds input data into the buffer.
  """
  @spec feed_input(pid(), String.t()) :: :ok
  def feed_input(pid \\ __MODULE__, data) when is_binary(data) do
    GenServer.cast(pid, {:feed_input, data})
  end

  @doc """
  Registers a callback function to be called when a complete event is detected.
  """
  @spec register_callback(pid(), (Event.t() -> any())) :: :ok
  def register_callback(pid \\ __MODULE__, callback) when is_function(callback, 1) do
    GenServer.call(pid, {:register_callback, callback})
  end

  @doc """
  Clears the input buffer.
  """
  @spec clear_buffer(pid()) :: :ok
  def clear_buffer(pid \\ __MODULE__) do
    GenServer.call(pid, :clear_buffer)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{
      buffer: "",
      callback: nil,
      timeout: 100, # milliseconds
      timer: nil
    }}
  end

  @impl true
  def handle_cast({:feed_input, data}, state) do
    # Cancel any existing timer
    if state.timer, do: Process.cancel_timer(state.timer)

    # Add new data to buffer
    new_buffer = state.buffer <> data

    # Try to process complete sequences
    {processed_buffer, events} = process_buffer(new_buffer)

    # Call callback for each complete event
    if state.callback do
      Enum.each(events, state.callback)
    end

    # Set timer for partial sequences
    timer = if processed_buffer != "" do
      Process.send_after(self(), :process_partial, state.timeout)
    end

    {:noreply, %{state | buffer: processed_buffer, timer: timer}}
  end

  @impl true
  def handle_call({:register_callback, callback}, _from, state) do
    {:reply, :ok, %{state | callback: callback}}
  end

  @impl true
  def handle_call(:clear_buffer, _from, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    {:reply, :ok, %{state | buffer: "", timer: nil}}
  end

  @impl true
  def handle_info(:process_partial, state) do
    # Process any remaining data in the buffer
    {processed_buffer, events} = process_buffer(state.buffer)

    # Call callback for any complete events
    if state.callback do
      Enum.each(events, state.callback)
    end

    {:noreply, %{state | buffer: processed_buffer, timer: nil}}
  end

  # Private functions

  defp process_buffer(buffer) do
    case Processor.process_input(buffer) do
      {:ok, event} ->
        {"", [event]}
      {:error, :invalid_input} ->
        # Try to find a complete sequence
        case find_complete_sequence(buffer) do
          {:ok, sequence, rest} ->
            case Processor.process_input(sequence) do
              {:ok, event} -> {rest, [event]}
              _ -> {buffer, []}
            end
          :error ->
            {buffer, []}
        end
      _ ->
        {buffer, []}
    end
  end

  defp find_complete_sequence(buffer) do
    cond do
      # Regular character
      String.length(buffer) == 1 ->
        {:ok, buffer, ""}

      # Escape sequence
      String.starts_with?(buffer, "\e[") ->
        case find_sequence_end(buffer) do
          {:ok, end_pos} ->
            sequence = binary_part(buffer, 0, end_pos + 1)
            rest = binary_part(buffer, end_pos + 1, byte_size(buffer) - end_pos - 1)
            {:ok, sequence, rest}
          :error ->
            :error
        end

      # Unknown sequence
      true ->
        :error
    end
  end

  defp find_sequence_end(<<?\e, ?[, rest::binary>>) do
    find_sequence_end(rest, 2)
  end

  defp find_sequence_end(buffer, offset) do
    case :binary.matches(buffer, "M") do
      [{pos, 1}] -> {:ok, pos + offset}
      [] -> :error
    end
  end
end
