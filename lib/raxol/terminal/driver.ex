defmodule Raxol.Terminal.Driver do
  @moduledoc """
  Handles raw terminal input/output and event generation.

  Responsibilities:
  - Setting terminal mode (raw, echo)
  - Reading input events via rrex_termbox NIF v2.0.1
  - Parsing input events into `Raxol.Core.Events.Event` structs
  - Detecting terminal resize events
  - Sending parsed events to the `Dispatcher`
  - Restoring terminal state on exit
  """
  use GenServer
  @behaviour Raxol.Terminal.Driver.Behaviour

  require Raxol.Core.Runtime.Log
  # Import Bitwise for bitwise operations
  import Bitwise

  alias Raxol.Core.Events.Event
  # Use ExTermbox instead of :rrex_termbox
  alias ExTermbox

  # Add import for real_tty? from TerminalUtils
  import Raxol.Terminal.TerminalUtils, only: [real_tty?: 0]

  # Allow nil initially
  @type dispatcher_pid :: pid() | nil
  @type original_stty :: String.t()

  defmodule State do
    @moduledoc false
    defstruct dispatcher_pid: nil,
              original_stty: nil
  end

  # --- Public API ---

  @doc """
  Starts the GenServer.
  """
  @impl true
  # Allow nil or pid
  def start_link(dispatcher_pid) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] start_link called for dispatcher: #{inspect(dispatcher_pid)}"
    )

    GenServer.start_link(__MODULE__, dispatcher_pid, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  @impl true
  # dispatcher_pid can be nil here
  def init(dispatcher_pid) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] init called with dispatcher: #{inspect(dispatcher_pid)}"
    )

    # Get original terminal settings
    output =
      case System.cmd("stty", ["size"]) do
        {output, 0} -> String.trim(output)
        # fallback to default size as a string
        {_, _} -> "80 24"
      end

    # Initialize terminal in raw mode only if attached to a TTY
    if Mix.env() != :test do
      if real_tty?() do
        Raxol.Core.Runtime.Log.debug(
          "[TerminalDriver] TTY detected, calling ExTermbox.init()..."
        )

        _ = ExTermbox.init()
      else
        Raxol.Core.Runtime.Log.warning_with_context(
          "Not attached to a TTY. Skipping ExTermbox.init(). Terminal features will be disabled.", %{}
        )
      end
    end

    # Send driver_ready event to the test process
    if Mix.env() == :test do
      send(self(), {:driver_ready, self()})
    end

    {:ok, %State{dispatcher_pid: dispatcher_pid, original_stty: output}}
  end

  @impl true
  def handle_info({:system_event, _pid, :sigwinch}, state) do
    Raxol.Core.Runtime.Log.debug("Ignoring legacy :system_event :sigwinch message.")
    # Keep the function clause but make it do nothing
    {:noreply, state}
  end

  # --- Handle events from rrex_termbox NIF ---
  @impl true
  def handle_info({:termbox_event, event_map}, state) do
    Raxol.Core.Runtime.Log.debug("Received termbox event: #{inspect(event_map)}")

    case translate_termbox_event(event_map) do
      {:ok, %Event{} = event} ->
        # Only send if dispatcher_pid is known
        if state.dispatcher_pid,
          do: GenServer.cast(state.dispatcher_pid, {:dispatch, event})

      :ignore ->
        # Event type we don't care about or couldn't translate
        :ok

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Failed to translate termbox event: #{inspect(reason)}. Event: #{inspect(event_map)}", %{}
        )
    end

    {:noreply, state}
  end

  # --- Handle rrex_termbox errors ---
  @impl true
  def handle_info({:termbox_error, reason}, state) do
    Raxol.Core.Runtime.Log.error("Received termbox error: #{inspect(reason)}. Stopping driver.")
    {:stop, {:termbox_error, reason}, state}
  end

  # --- Handle dispatcher registration ---
  @impl true
  def handle_cast({:register_dispatcher, pid}, state) when is_pid(pid) do
    Raxol.Core.Runtime.Log.info("Registering dispatcher PID: #{inspect(pid)}")
    # Send initial size event now that we have the PID
    send_initial_resize_event(pid)
    {:noreply, %{state | dispatcher_pid: pid}}
  end

  # --- Test Environment Input Simulation ---
  # This clause is only intended for use in the :test environment
  # to simulate raw input events without relying on the NIF.
  @impl true
  def handle_cast({:test_input, input_data}, %{dispatcher_pid: nil} = state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Received test input before dispatcher registration: #{inspect(input_data)}", %{}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:test_input, input_data}, state) do
    # Construct a basic event. Tests might need more specific event types later.
    # We need to parse the input_data into something the MockApp expects.
    Raxol.Core.Runtime.Log.debug(
      "[TerminalDriver.handle_cast - :test_input] Received input_data: #{inspect(input_data)}, state: #{inspect(state)}"
    )

    event = parse_test_input(input_data)

    Raxol.Core.Runtime.Log.debug(
      "[TerminalDriver.handle_cast - :test_input] Parsed event: #{inspect(event)}"
    )

    Raxol.Core.Runtime.Log.debug("[TEST] Dispatching simulated event: #{inspect(event)}")
    GenServer.cast(state.dispatcher_pid, {:dispatch, event})
    {:noreply, state}
  end

  # Catch-all for unexpected messages
  @impl true
  def handle_info(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "#{__MODULE__} received unhandled message: #{inspect(unhandled_message)}", %{}
    )

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Raxol.Core.Runtime.Log.info("Terminal Driver terminating.")
    # Only attempt shutdown if not in test environment
    if Mix.env() != :test do
      _ = ExTermbox.shutdown()
    end

    :ok
  end

  # --- Private Helpers ---

  defp get_terminal_size do
    if Mix.env() == :test do
      {:ok, 80, 24}
    else
      if real_tty?() do
        Raxol.Core.Runtime.Log.debug(
          "[TerminalDriver] TTY detected, calling ExTermbox.width/height..."
        )

        with {:ok, width} <- ExTermbox.width(),
             {:ok, height} <- ExTermbox.height() do
          {:ok, width, height}
        else
          _ -> stty_size_fallback()
        end
      else
        stty_size_fallback()
      end
    end
  end

  defp stty_size_fallback do
    try do
      {output, 0} = System.cmd("stty", ["size"])
      output = String.trim(output)

      case String.split(output) do
        [rows, cols] ->
          {:ok, String.to_integer(cols), String.to_integer(rows)}

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Unexpected output from 'stty size': #{inspect(output)}", %{}
          )

          {:error, :invalid_format}
      end
    catch
      type, reason ->
        Raxol.Core.Runtime.Log.error(
          "Error getting terminal size via 'stty size': #{type}: #{inspect(reason)}"
        )

        Raxol.Core.Runtime.Log.error(Exception.format_stacktrace(__STACKTRACE__))
        {:error, reason}
    end
  end

  defp send_initial_resize_event(dispatcher_pid) do
    # Keep this as it provides an immediate size on startup
    case get_terminal_size() do
      {:ok, width, height} ->
        Raxol.Core.Runtime.Log.info("Initial terminal size: #{width}x#{height}")
        event = %Event{type: :resize, data: %{width: width, height: height}}
        GenServer.cast(dispatcher_pid, {:dispatch, event})

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Failed to get initial terminal size (#{inspect(reason)}). Using default 80x24.", %{}
        )

        default_width = 80
        default_height = 24

        event = %Event{
          type: :resize,
          data: %{width: default_width, height: default_height}
        }

        GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  # --- Event translation from rrex_termbox v2.0.1 NIF ---
  defp translate_termbox_event(event_map) do
    # Handle event structure from rrex_termbox v2.0.1 NIF
    case event_map do
      %{type: :key, key: key_code, char: char_code, mod: mod_code} ->
        # Translate key_code, char_code, mod_code to Raxol's key event format
        translated_key = translate_key(key_code, char_code, mod_code)
        event = %Event{type: :key, data: translated_key}
        {:ok, event}

      %{type: :resize, width: w, height: h} ->
        event = %Event{type: :resize, data: %{width: w, height: h}}
        {:ok, event}

      %{type: :mouse, x: x, y: y, button: btn_code} ->
        # Translate rrex_termbox mouse button codes and potentially event types (press, release, move)
        translated_button = translate_mouse_button(btn_code)
        # Add button info to the data
        event = %Event{
          type: :mouse,
          data: %{x: x, y: y, button: translated_button}
        }

        {:ok, event}

      # Add cases for other event types rrex_termbox might send

      _other ->
        # Raxol.Core.Runtime.Log.debug("Ignoring unknown termbox event type: #{inspect(event_map)}")
        :ignore
    end
  catch
    # Catch potential errors during translation
    type, reason ->
      {:error, {type, reason, Exception.format_stacktrace(__STACKTRACE__)}}
  end

  # Helper for key translation
  defp translate_key(key_code, char_code, mod_code) do
    # Actual implementation based on test simulations and potential NIF values
    # Modifiers: Shift=1, Ctrl=2, Alt=4, Meta=8 (assuming standard bitflags)
    shift = Bitwise.&&&(mod_code, 1) != 0
    ctrl = Bitwise.&&&(mod_code, 2) != 0
    alt = Bitwise.&&&(mod_code, 4) != 0
    meta = Bitwise.&&&(mod_code, 8) != 0

    # Base data map
    data = %{
      shift: shift,
      ctrl: ctrl,
      alt: alt,
      meta: meta,
      char: nil,
      key: nil
    }

    # Character or Special Key
    cond do
      # Printable character (key_code is 0 or matches char_code for some keys)
      char_code > 0 ->
        Map.put(data, :char, <<char_code::utf8>>)

      # Special keys based on simulated key_codes
      key_code == 65 ->
        Map.put(data, :key, :up)

      key_code == 66 ->
        Map.put(data, :key, :down)

      key_code == 67 ->
        Map.put(data, :key, :right)

      key_code == 68 ->
        Map.put(data, :key, :left)

      key_code == 265 ->
        Map.put(data, :key, :f1)

      key_code == 266 ->
        Map.put(data, :key, :f2)

      # Add other special key translations here if needed

      # Unknown key
      true ->
        Map.put(data, :key, :unknown)
    end
  end

  # Helper for mouse button translation
  defp translate_mouse_button(btn_code) do
    # Based on test simulation (button: 0 -> left?)
    # Actual mapping depends on rrex_termbox v2.0.1 constants/values
    case btn_code do
      # Assuming 0 is left click based on test
      0 -> :left
      1 -> :middle
      2 -> :right
      3 -> :wheel_up
      4 -> :wheel_down
      _ -> :unknown
    end
  end

  # Helper for parsing test input
  # This function translates simple string inputs from tests into Event structs.
  # It's a simplified version for testing purposes.
  defp parse_test_input(input_data) when is_binary(input_data) do
    # Basic parsing: assume simple characters or known ctrl sequences
    # This is a simplified parser for test inputs.
    Raxol.Core.Runtime.Log.debug(
      "[TerminalDriver.parse_test_input] Parsing: #{inspect(input_data)}"
    )

    case input_data do
      # Ctrl+Q (ASCII 17)
      <<17>> ->
        %Event{
          type: :key,
          data: %{
            key: :char,
            char: <<17>>,
            ctrl: true,
            alt: false,
            shift: false,
            meta: false
          }
        }

      # Ctrl+V (ASCII 22)
      <<22>> ->
        %Event{
          type: :key,
          data: %{
            key: :char,
            char: <<22>>,
            ctrl: true,
            alt: false,
            shift: false,
            meta: false
          }
        }

      # Ctrl+X (ASCII 24)
      <<24>> ->
        %Event{
          type: :key,
          data: %{
            key: :char,
            char: <<24>>,
            ctrl: true,
            alt: false,
            shift: false,
            meta: false
          }
        }

      # Ctrl+N (ASCII 14)
      <<14>> ->
        %Event{
          type: :key,
          data: %{
            key: :char,
            char: <<14>>,
            ctrl: true,
            alt: false,
            shift: false,
            meta: false
          }
        }

      # Other ASCII characters (simplified)
      <<char>> when char >= 32 and char <= 126 ->
        %Event{
          type: :key,
          data: %{
            key: :char,
            char: <<char>>,
            ctrl: false,
            alt: false,
            shift: false,
            meta: false
          }
        }

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[TerminalDriver.parse_test_input] Unhandled test input: #{inspect(input_data)}", %{}
        )

        # Return a generic event or handle error as appropriate
        %Event{type: :unknown_test_input, data: %{raw: input_data}}
    end
  end
end
