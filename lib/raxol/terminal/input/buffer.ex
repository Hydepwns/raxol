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

  @impl GenServer
  def init(opts) do
    max_size = Keyword.get(opts, :max_size, 1024)
    {:ok, new(max_size)}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:add_event, event}, state) do
    case add(state, event) do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:feed_input, input}, state) do
    case process_input(state, input) do
      {:ok, new_state} ->
        # Callback is already completed synchronously in process_input
        # Now schedule delayed stop
        Process.send_after(self(), :delayed_stop, 10)
        {:noreply, new_state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_cast({:register_callback, callback}, state) do
    {:noreply, %{state | callback: callback}}
  end

  @impl GenServer
  def handle_cast(:clear_buffer, state) do
    # Clear buffer first, then schedule delayed stop
    Process.send_after(self(), :delayed_stop, 10)
    {:noreply, clear(state)}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    # Timeout reached, schedule delayed stop
    Process.send_after(self(), :delayed_stop, 10)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:delayed_stop, state) do
    {:stop, :normal, state}
  end

  @doc """
  Creates a new input buffer with the given size.
  """
  def new(max_size) when is_integer(max_size) and max_size > 0 do
    %{
      buffer: [],
      max_size: max_size,
      current_size: 0,
      callback: nil,
      # String buffer for partial sequences
      input_buffer: ""
    }
  end

  @doc """
  Adds an event to the input buffer.
  """
  def add(buffer, event) do
    if buffer.current_size >= buffer.max_size do
      {:error, :buffer_full}
    else
      new_buffer = %{
        buffer
        | buffer: buffer.buffer ++ [event],
          current_size: buffer.current_size + 1
      }

      {:ok, new_buffer}
    end
  end

  @doc """
  Gets the current buffer contents.
  """
  def get_contents(buffer) do
    buffer.buffer
  end

  @doc """
  Clears the input buffer.
  """
  def clear(buffer) do
    %{buffer | buffer: [], current_size: 0}
  end

  # Private functions

  defp process_input(state, input) do
    # Parse the input and create appropriate events
    case parse_input_sequence(state, input) do
      {:ok, events, new_state} ->
        case new_state.callback do
          nil ->
            {:ok, new_state}

          callback ->
            try do
              # Call callback for each event synchronously
              # This ensures the callback completes before we schedule the delayed stop
              Enum.each(events, fn event ->
                callback.(event)
              end)

              {:ok, new_state}
            rescue
              _ -> {:ok, new_state}
            end
        end

      {:buffer, new_state} ->
        # Partial sequence, buffer it and don't call callback yet
        {:ok, new_state}

      {:error, _reason} ->
        {:ok, state}
    end
  end

  defp parse_input_sequence(state, input) do
    # If we have buffered input, combine it with new input
    combined_input = state.input_buffer <> input

    case parse_events_recursive(combined_input, []) do
      {:ok, events, remaining} ->
        # If there's remaining input, buffer it
        new_state =
          if remaining != "",
            do: %{state | input_buffer: remaining},
            else: %{state | input_buffer: ""}

        {:ok, events, new_state}

      {:buffer, remaining} ->
        # Partial sequence, buffer the remaining input
        {:buffer, %{state | input_buffer: remaining}}

      {:error, _reason} ->
        {:error, :parse_error}
    end
  end

  defp parse_events_recursive("", events) do
    {:ok, events, ""}
  end

  defp parse_events_recursive(input, events) do
    case parse_next_event(input) do
      {:ok, event, remaining_input} ->
        parse_events_recursive(remaining_input, events ++ [event])

      {:buffer, remaining_input} ->
        # Partial sequence, buffer it
        {:buffer, remaining_input}

      {:error, _reason} ->
        # If we can't parse the current input, try to parse it as a single character
        case parse_single_character(input) do
          {:ok, event, remaining_input} ->
            parse_events_recursive(remaining_input, events ++ [event])

          {:error, _reason} ->
            # If we still can't parse, skip the first character and continue
            if String.length(input) > 0 do
              parse_events_recursive(String.slice(input, 1..-1//1), events)
            else
              {:ok, events, ""}
            end
        end
    end
  end

  defp parse_next_event(input) do
    cond do
      # Mouse sequence: \e[0;0;10;20M
      String.match?(input, ~r/^\e\[(\d+);(\d+);(\d+);(\d+)M/) ->
        [_, button_code, action_code, x, y] =
          Regex.run(~r/^\e\[(\d+);(\d+);(\d+);(\d+)M/, input)

        button =
          case button_code do
            "0" -> :left
            "1" -> :middle
            "2" -> :right
            _ -> :left
          end

        action =
          case action_code do
            "0" -> :press
            "1" -> :release
            "2" -> :move
            _ -> :press
          end

        event = %Raxol.Terminal.Input.Event.MouseEvent{
          button: button,
          action: action,
          x: String.to_integer(x),
          y: String.to_integer(y)
        }

        sequence_length =
          String.length("\e[#{button_code};#{action_code};#{x};#{y}M")

        remaining = String.slice(input, sequence_length..-1//1)
        {:ok, event, remaining}

      # Key sequence with 3 parameters: \e[1;2;5A (Ctrl+Shift+A)
      String.match?(input, ~r/^\e\[(\d+);(\d+);(\d+)([A-Z])/) ->
        [_, param1, param2, param3, key] =
          Regex.run(~r/^\e\[(\d+);(\d+);(\d+)([A-Z])/, input)

        modifiers = parse_modifiers([param1, param2, param3])

        event = %Raxol.Terminal.Input.Event.KeyEvent{
          key: key,
          modifiers: modifiers
        }

        sequence_length =
          String.length("\e[#{param1};#{param2};#{param3}#{key}")

        remaining = String.slice(input, sequence_length..-1//1)
        {:ok, event, remaining}

      # Key sequence with 2 parameters: \e[2;5A (Shift+Ctrl+A)
      String.match?(input, ~r/^\e\[(\d+);(\d+)([A-Z])/) ->
        [_, modifier_code, key_code, key] =
          Regex.run(~r/^\e\[(\d+);(\d+)([A-Z])/, input)

        modifiers = parse_modifiers([modifier_code, key_code])

        event = %Raxol.Terminal.Input.Event.KeyEvent{
          key: key,
          modifiers: modifiers
        }

        sequence_length = String.length("\e[#{modifier_code};#{key_code}#{key}")
        remaining = String.slice(input, sequence_length..-1//1)
        {:ok, event, remaining}

      # Incomplete escape sequence: just ESC or ESC + [
      input == "\e" or String.starts_with?(input, "\e[") ->
        {:buffer, input}

      # Single character (non-control character)
      String.length(input) >= 1 and
          not String.match?(String.first(input), ~r/[\x00-\x1F]/) ->
        char = String.first(input)
        event = %Raxol.Terminal.Input.Event.KeyEvent{key: char, modifiers: []}
        remaining = String.slice(input, 1..-1//1)
        {:ok, event, remaining}

      # Control character or escape sequence start
      String.length(input) >= 1 ->
        {:error, :unrecognized_sequence}
    end
  end

  defp parse_single_character(input) do
    if String.length(input) >= 1 do
      char = String.first(input)
      event = %Raxol.Terminal.Input.Event.KeyEvent{key: char, modifiers: []}
      remaining = String.slice(input, 1..-1//1)
      {:ok, event, remaining}
    else
      {:error, :empty_input}
    end
  end

  defp parse_modifiers(params) do
    modifiers =
      Enum.reduce(params, [], fn param, acc ->
        case param do
          "1" -> acc ++ [:shift]
          "2" -> acc ++ [:shift]
          "3" -> acc ++ [:alt]
          "4" -> acc ++ [:shift, :alt]
          "5" -> acc ++ [:ctrl]
          "6" -> acc ++ [:shift, :ctrl]
          "7" -> acc ++ [:alt, :ctrl]
          "8" -> acc ++ [:shift, :alt, :ctrl]
          _ -> acc
        end
      end)

    # Remove duplicates and sort in the order [:shift, :ctrl, :alt]
    order = %{shift: 0, ctrl: 1, alt: 2}
    modifiers |> Enum.uniq() |> Enum.sort_by(&Map.get(order, &1, 99))
  end
end
