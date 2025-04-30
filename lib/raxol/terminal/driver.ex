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

  require Logger

  alias Raxol.Core.Events.Event
  # Use ExTermbox instead of :rrex_termbox
  alias ExTermbox

  @type dispatcher_pid :: pid() | nil # Allow nil initially
  @type original_stty :: String.t()

  defmodule State do
    @moduledoc false
    defstruct dispatcher_pid: nil,
              original_stty: nil
  end

  # --- Public API ---

  @doc "Starts the Terminal Driver process."
  @spec start_link(dispatcher_pid()) :: GenServer.on_start() # Spec updated implicitly by type change
  def start_link(dispatcher_pid) do # Allow nil or pid
    Logger.info("[#{__MODULE__}] start_link called for dispatcher: #{inspect(dispatcher_pid)}")
    GenServer.start_link(__MODULE__, dispatcher_pid, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(dispatcher_pid) do # dispatcher_pid can be nil here
    Logger.info("[#{__MODULE__}] init starting...")
    Process.flag(:trap_exit, true)

    # Start rrex_termbox NIF, which will send events to self()
    Logger.debug("[#{__MODULE__}] Initializing rrex_termbox...")
    case ExTermbox.init(owner: self()) do
      {:ok, _tb_pid} ->
        Logger.info("[#{__MODULE__}] rrex_termbox initialized successfully.")

        # Send initial size event (still useful)
        Logger.debug("[#{__MODULE__}] Sending initial resize event...")
        # Only send if dispatcher_pid is known
        if dispatcher_pid, do: send_initial_resize_event(dispatcher_pid)

        Logger.info("[#{__MODULE__}] init completed successfully.")
        {:ok, %State{dispatcher_pid: dispatcher_pid, original_stty: nil}}

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Failed to initialize rrex_termbox: #{inspect(reason)}. Halting init.")
        {:stop, {:termbox_init_failed, reason}}
    end
  end

  @impl true
  def handle_info({:system_event, _pid, :sigwinch}, state) do
    Logger.debug("Ignoring legacy :system_event :sigwinch message.")
    {:noreply, state} # Keep the function clause but make it do nothing
  end

  # --- Handle events from rrex_termbox NIF ---
  @impl true
  def handle_info({:termbox_event, event_map}, state) do
    Logger.debug("Received termbox event: #{inspect(event_map)}")
    case translate_termbox_event(event_map) do
      {:ok, %Event{} = event} ->
        # Only send if dispatcher_pid is known
        if state.dispatcher_pid, do: GenServer.cast(state.dispatcher_pid, {:dispatch, event})
      :ignore ->
        # Event type we don't care about or couldn't translate
        :ok
      {:error, reason} ->
        Logger.warning("Failed to translate termbox event: #{inspect(reason)}. Event: #{inspect(event_map)}")
    end
    {:noreply, state}
  end

  # --- Handle rrex_termbox errors ---
  @impl true
  def handle_info({:termbox_error, reason}, state) do
    Logger.error("Received termbox error: #{inspect(reason)}. Stopping driver.")
    {:stop, {:termbox_error, reason}, state}
  end

  # --- Handle dispatcher registration ---
  @impl true
  def handle_cast({:register_dispatcher, pid}, state) when is_pid(pid) do
    Logger.info("Registering dispatcher PID: #{inspect(pid)}")
    # Send initial size event now that we have the PID
    send_initial_resize_event(pid)
    {:noreply, %{state | dispatcher_pid: pid}}
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("Terminal Driver terminating.")
    # Ensure rrex_termbox is shut down
    _ = ExTermbox.shutdown()
    :ok
  end

  # --- Private Helpers ---

  defp get_terminal_size do
    # Try to get size from rrex_termbox first
    with {:ok, width} <- ExTermbox.width(),
         {:ok, height} <- ExTermbox.height() do
      {:ok, width, height}
    else
      _ ->
        # Fall back to stty if rrex_termbox fails
        try do
          output = String.trim(:os.cmd("stty size"))
          case String.split(output) do
            [rows, cols] ->
              {:ok, String.to_integer(cols), String.to_integer(rows)}
            _ ->
              Logger.warning("Unexpected output from 'stty size': #{inspect(output)}")
              {:error, :invalid_format}
          end
        catch
          type, reason ->
            Logger.error("Error getting terminal size via 'stty size': #{type}: #{inspect(reason)}")
            Logger.error(Exception.format_stacktrace(__STACKTRACE__))
            {:error, reason}
        end
    end
  end

  defp send_initial_resize_event(dispatcher_pid) do
    # Keep this as it provides an immediate size on startup
    case get_terminal_size() do
      {:ok, width, height} ->
        Logger.info("Initial terminal size: #{width}x#{height}")
        event = %Event{type: :resize, data: %{width: width, height: height}}
        GenServer.cast(dispatcher_pid, {:dispatch, event})
      {:error, reason} ->
        Logger.warning("Failed to get initial terminal size (#{inspect(reason)}). Using default 80x24.")
        default_width = 80
        default_height = 24
        event = %Event{type: :resize, data: %{width: default_width, height: default_height}}
        GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  # --- Event translation from rrex_termbox v2.0.1 NIF ---
  defp translate_termbox_event(event_map) do
    # Handle event structure from rrex_termbox v2.0.1 NIF
    case event_map do
      %{type: :key, key: key_code, char: char_code, mod: mod_code} ->
        # Translate key_code, char_code, mod_code to Raxol's key event format
        # Maps rrex_termbox key constants/chars to Raxol atoms/structs
        translated_key = translate_key(key_code, char_code, mod_code)
        event = %Event{type: :key, data: translated_key}
        {:ok, event}

      %{type: :resize, width: w, height: h} ->
        event = %Event{type: :resize, data: %{width: w, height: h}}
        {:ok, event}

      %{type: :mouse, x: x, y: y, button: btn_code} ->
        # Translate rrex_termbox mouse button codes and potentially event types (press, release, move)
        event = %Event{type: :mouse, data: %{x: x, y: y, button: translate_mouse_button(btn_code)}}
        {:ok, event}

      # Add cases for other event types rrex_termbox might send

      _other ->
        # Logger.debug("Ignoring unknown termbox event type: #{inspect(event_map)}")
        :ignore
    end
  catch
    # Catch potential errors during translation
    type, reason -> {:error, {type, reason, Exception.format_stacktrace(__STACKTRACE__)}}
  end

  # Helper for key translation
  defp translate_key(key_code, char_code, mod_code) do
    # Actual implementation depends on rrex_termbox v2.0.1 constants/values
    # Maps raw codes to Raxol's expected format e.g. %{key: :up, char: nil, shift: false, ...}
    %{raw_key: key_code, raw_char: char_code, raw_mod: mod_code, key: :unknown, char: nil, alt: false, ctrl: false, shift: false, meta: false} # Basic structure
  end

  # Helper for mouse button translation
  defp translate_mouse_button(_btn_code) do
    # Actual implementation depends on rrex_termbox v2.0.1 constants/values
    # Map to Raxol's expected mouse button representation (e.g., :left, :right, :middle, :wheel_up, :wheel_down)
    :unknown # Placeholder
  end
end
