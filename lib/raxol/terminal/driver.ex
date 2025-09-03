defmodule Raxol.Terminal.Driver do
  @moduledoc """
  Handles raw terminal input/output and event generation.

  Responsibilities:
  - Setting terminal mode (raw, echo)
  - Reading input events via termbox2_nif NIF
  - Parsing input events into `Raxol.Core.Events.Event` structs
  - Detecting terminal resize events
  - Sending parsed events to the `Dispatcher`
  - Restoring terminal state on exit
  """
  use GenServer
  @behaviour Raxol.Terminal.Driver.Behaviour

  require Raxol.Core.Runtime.Log
  # Import Bitwise for bitwise operations
  # import Bitwise

  alias Raxol.Core.Events.Event

  # Check if termbox2_nif is available at compile time
  @termbox2_available Code.ensure_loaded?(:termbox2_nif)

  # Add import for real_tty? from TerminalUtils
  import Raxol.Terminal.TerminalUtils, only: [real_tty?: 0]

  # Constants for retry logic
  @max_init_retries 3
  # ms
  @init_retry_delay 1000

  # Allow nil initially
  @type dispatcher_pid :: pid() | nil
  @type original_stty :: String.t()
  @type termbox_state :: :uninitialized | :initialized | :failed

  defmodule State do
    @moduledoc false
    defstruct dispatcher_pid: nil,
              original_stty: nil,
              termbox_state: :uninitialized,
              init_retries: 0
  end

  # --- Public API ---

  @doc """
  Starts the GenServer.
  """
  # Allow nil or pid
  def start_link(dispatcher_pid) do
    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] start_link called for dispatcher: #{inspect(dispatcher_pid)}"
    )

    GenServer.start_link(__MODULE__, dispatcher_pid, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

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

    state = %State{
      dispatcher_pid: dispatcher_pid,
      original_stty: output,
      termbox_state: :uninitialized,
      init_retries: 0
    }

    # Initialize terminal in raw mode only if attached to a TTY
    if Mix.env() != :test do
      if real_tty?() do
        Raxol.Core.Runtime.Log.debug(
          "[TerminalDriver] TTY detected, calling Termbox2Nif.tb_init()..."
        )

        _ =
          if @termbox2_available,
            do: apply(:termbox2_nif, :tb_init, []),
            else: :ok
      else
        Raxol.Core.Runtime.Log.warning_with_context(
          "Not attached to a TTY. Skipping Termbox2Nif.tb_init(). Terminal features will be disabled.",
          %{}
        )
      end

      {:ok, state}
    else
      Raxol.Core.Runtime.Log.info(
        "[Driver] Test environment detected, sending driver_ready event"
      )

      if dispatcher_pid do
        send(dispatcher_pid, {:driver_ready, self()})
        # Send initial resize event for test environment
        Raxol.Core.Runtime.Log.info(
          "[Driver] Sending initial resize event to dispatcher_pid: #{inspect(dispatcher_pid)}"
        )

        send_initial_resize_event(dispatcher_pid)
      else
        Raxol.Core.Runtime.Log.warning_with_context(
          "[Driver] No dispatcher_pid provided, skipping driver_ready and initial resize event",
          %{}
        )
      end

      # In test mode, set termbox_state to :initialized so we can handle test events
      state = %{state | termbox_state: :initialized}
      {:ok, state}
    end
  end

  # --- GenServer handle_info callbacks ---

  def handle_info(:retry_init, %{init_retries: retries} = state)
      when retries < @max_init_retries do
    case initialize_termbox() do
      :ok ->
        Raxol.Core.Runtime.Log.info("Successfully initialized termbox on retry")
        {:noreply, %{state | termbox_state: :initialized}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to initialize termbox on retry #{retries + 1}: #{inspect(reason)}"
        )

        Process.send_after(self(), :retry_init, @init_retry_delay)
        {:noreply, %{state | init_retries: retries + 1}}
    end
  end

  def handle_info(:retry_init, state) do
    Raxol.Core.Runtime.Log.error(
      "Failed to initialize termbox after #{@max_init_retries} attempts. Terminal features will be disabled."
    )

    {:noreply, state}
  end

  def handle_info(
        {:termbox_event, event_map},
        %{termbox_state: :initialized, dispatcher_pid: dispatcher_pid} = state
      ) do
    Raxol.Core.Runtime.Log.debug(
      "Received termbox event: #{inspect(event_map)}"
    )

    case translate_termbox_event(event_map) do
      {:ok, %Event{} = event} ->
        # Only send if dispatcher_pid is known
        if dispatcher_pid do
          if Mix.env() == :test do
            Raxol.Core.Runtime.Log.debug(
              "[Driver] Sending event in test mode: #{inspect(event)} to #{inspect(dispatcher_pid)}"
            )

            send(dispatcher_pid, {:"$gen_cast", {:dispatch, event}})
          else
            GenServer.cast(dispatcher_pid, {:dispatch, event})
          end
        end

        {:noreply, state}

      :ignore ->
        # Event type we don't care about
        Raxol.Core.Runtime.Log.debug(
          "[Driver] Ignoring termbox event: #{inspect(event_map)}"
        )

        {:noreply, state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Failed to translate termbox event: #{inspect(reason)}. Event: #{inspect(event_map)}",
          %{}
        )

        {:noreply, state}
    end
  end

  def handle_info({:termbox_event, _event_map}, state) do
    # Ignore events if termbox is not initialized
    {:noreply, state}
  end

  def handle_info({:termbox_error, reason}, state) do
    Raxol.Core.Runtime.Log.error(
      "Received termbox error: #{inspect(reason)}. Attempting recovery..."
    )

    case state.termbox_state do
      :initialized -> handle_termbox_recovery(reason, state)
      _ -> {:stop, {:termbox_error, reason}, state}
    end
  end

  def handle_info({:register_dispatcher, pid}, state) when is_pid(pid) do
    Raxol.Core.Runtime.Log.info("Registering dispatcher PID: #{inspect(pid)}")
    # Send initial size event now that we have the PID
    send_initial_resize_event(pid)
    {:noreply, %{state | dispatcher_pid: pid}}
  end

  def handle_info({:test_input, input_data}, %{dispatcher_pid: nil} = state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Received test input before dispatcher registration: #{inspect(input_data)}",
      %{}
    )

    {:noreply, state}
  end

  def handle_info({:test_input, input_data}, state) do
    # Construct a basic event. Tests might need more specific event types later.
    # We need to parse the input_data into something the MockApp expects.
    Raxol.Core.Runtime.Log.debug(
      "[TerminalDriver.handle_cast - :test_input] Received input_data: #{inspect(input_data)}, state: #{inspect(state)}"
    )

    event = parse_test_input(input_data)

    Raxol.Core.Runtime.Log.debug(
      "[TerminalDriver.handle_cast - :test_input] Parsed event: #{inspect(event)}"
    )

    Raxol.Core.Runtime.Log.debug(
      "[TEST] Dispatching simulated event: #{inspect(event)}"
    )

    GenServer.cast(state.dispatcher_pid, {:dispatch, event})
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, state}
  end

  def handle_info(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "#{__MODULE__} received unhandled message: #{inspect(unhandled_message)}",
      %{}
    )

    {:noreply, state}
  end

  # Forward cast messages to handle_info for test_input
  def handle_cast({:test_input, input_data}, state) do
    handle_info({:test_input, input_data}, state)
  end

  defp handle_termbox_recovery(reason, state) do
    case if @termbox2_available,
           do: apply(:termbox2_nif, :tb_shutdown, []),
           else: :ok do
      :ok ->
        case initialize_termbox() do
          :ok ->
            Raxol.Core.Runtime.Log.info(
              "Successfully recovered from termbox error"
            )

            {:noreply, state}

          {:error, init_reason} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to recover from termbox error: #{inspect(init_reason)}"
            )

            {:stop, {:termbox_error, reason}, state}
        end

      _ ->
        {:stop, {:termbox_error, reason}, state}
    end
  end

  def terminate(_reason, %{termbox_state: :initialized} = _state) do
    Raxol.Core.Runtime.Log.info("Terminal Driver terminating.")
    # Only attempt shutdown if not in test environment
    if Mix.env() != :test do
      if real_tty?() do
        _ =
          if @termbox2_available,
            do: apply(:termbox2_nif, :tb_shutdown, []),
            else: :ok
      end
    end

    :ok
  end

  def terminate(_reason, _state) do
    Raxol.Core.Runtime.Log.info(
      "Terminal Driver terminating (not initialized)."
    )

    :ok
  end

  @doc """
  Processes a terminal title change event.
  """
  def process_title_change(title, state) when is_binary(title) do
    if Mix.env() != :test and real_tty?() do
      _ =
        if @termbox2_available,
          do: apply(:termbox2_nif, :tb_set_title, [title]),
          else: :ok
    end

    {:noreply, state}
  end

  @doc """
  Processes a terminal position change event.
  """
  def process_position_change(x, y, state)
      when is_integer(x) and is_integer(y) do
    if Mix.env() != :test and real_tty?() do
      _ =
        if @termbox2_available,
          do: apply(:termbox2_nif, :tb_set_position, [x, y]),
          else: :ok
    end

    {:noreply, state}
  end

  # --- Private Helpers ---

  defp initialize_termbox do
    case if @termbox2_available, do: apply(:termbox2_nif, :tb_init, []), else: 0 do
      0 -> :ok
      -1 -> {:error, :init_failed}
      other -> {:error, {:unexpected_result, other}}
    end
  end

  defp get_terminal_size do
    determine_terminal_size()
  end

  defp determine_terminal_size do
    if Mix.env() == :test do
      {:ok, 80, 24}
    else
      if real_tty?() do
        get_termbox_size()
      else
        stty_size_fallback()
      end
    end
  end

  defp get_termbox_size do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      width =
        if @termbox2_available,
          do: apply(:termbox2_nif, :tb_width, []),
          else: 80

      height =
        if @termbox2_available,
          do: apply(:termbox2_nif, :tb_height, []),
          else: 24

      if width > 0 and height > 0 do
        {:ok, width, height}
      else
        stty_size_fallback()
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, _reason} -> stty_size_fallback()
    end
  end

  defp stty_size_fallback do
    case System.cmd("stty", ["size"]) do
      {output, 0} ->
        [height, width] = String.split(String.trim(output), " ")
        {:ok, String.to_integer(width), String.to_integer(height)}

      _ ->
        {:ok, 80, 24}
    end
  end

  defp send_initial_resize_event(dispatcher_pid) do
    # Keep this as it provides an immediate size on startup
    {:ok, width, height} = get_terminal_size()
    Raxol.Core.Runtime.Log.info("Initial terminal size: #{width}x#{height}")
    event = %Event{type: :resize, data: %{width: width, height: height}}

    # In test mode, send directly to the test process
    if Mix.env() == :test do
      Raxol.Core.Runtime.Log.info(
        "[Driver] Sending resize event in test mode: #{inspect(event)}"
      )

      send(dispatcher_pid, {:"$gen_cast", {:dispatch, event}})
    else
      GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  # --- Event translation from rrex_termbox v2.0.1 NIF ---
  defp translate_termbox_event(event_map) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
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
          # Translate rrex_termbox mouse button codes and potentially event types
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
    end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
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
    translate_key_or_char(data, char_code, key_code)
  end

  defp translate_key_or_char(data, char_code, key_code) when char_code > 0 do
    Map.put(data, :char, <<char_code::utf8>>)
  end

  defp translate_key_or_char(data, _char_code, 65), do: Map.put(data, :key, :up)
  defp translate_key_or_char(data, _char_code, 66), do: Map.put(data, :key, :down)
  defp translate_key_or_char(data, _char_code, 67), do: Map.put(data, :key, :right)
  defp translate_key_or_char(data, _char_code, 68), do: Map.put(data, :key, :left)
  defp translate_key_or_char(data, _char_code, 265), do: Map.put(data, :key, :f1)
  defp translate_key_or_char(data, _char_code, 266), do: Map.put(data, :key, :f2)
  defp translate_key_or_char(data, _char_code, _key_code), do: Map.put(data, :key, :unknown)

  # Helper for mouse button translation
  defp translate_mouse_button(btn_code) do
    # Based on test simulation (button: 0 -> left?)
    # Actual mapping depends on rrex_termbox v2.0.1 constants/values
    case btn_code do
      # Based on test expectations: 0=left, 1=right, 2=middle
      0 -> :left
      1 -> :right
      2 -> :middle
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
          "[TerminalDriver.parse_test_input] Unhandled test input: #{inspect(input_data)}",
          %{}
        )

        # Return a generic event or handle error as appropriate
        %Event{type: :unknown_test_input, data: %{raw: input_data}}
    end
  end
end
