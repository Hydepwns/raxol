defmodule Raxol.Terminal.Driver do
  @moduledoc """
  Handles raw terminal input/output and event generation.

  Responsibilities:
  - Setting terminal mode (raw, echo)
  - Reading raw input bytes from stdin
  - Parsing input bytes into `Raxol.Core.Events.Event` structs
  - Detecting terminal resize events
  - Sending parsed events to the `Dispatcher`
  - Restoring terminal state on exit
  """
  use GenServer

  require Logger

  alias Raxol.Core.Events.Event
  # TODO: Add alias for an ANSI escape code parser if needed

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
    # Remove manual SIGWINCH handling - rely on Termbox resize events
    # Logger.debug("[#{__MODULE__}] Subscribing to system_monitor :sigwinch...")
    # :ok = :erlang.system_monitor(self(), [:sigwinch])
    # Logger.debug("[#{__MODULE__}] Setting OS signal handler for :sigwinch...")
    # :ok = :os.set_signal(:sigwinch, :deliver)

    # Remove manual stty saving - rely on Termbox init/shutdown
    # Logger.debug("[#{__MODULE__}] Saving original terminal settings (stty -g)...")
    # case save_original_stty() do
      # {:ok, original_stty} ->
        # Logger.debug("[#{__MODULE__}] Original stty saved.")

    # Start ExTermbox Port process, sending events to self()
    Logger.debug("[#{__MODULE__}] Initializing ExTermbox...")
    case ExTermbox.init(owner: self()) do # Assuming init/1 takes owner: pid()
      {:ok, _port_handler_pid} ->
        Logger.info("[#{__MODULE__}] ExTermbox initialized successfully.")

        # Send initial size event (still useful)
        Logger.debug("[#{__MODULE__}] Sending initial resize event...")
        # Only send if dispatcher_pid is known
        if dispatcher_pid, do: send_initial_resize_event(dispatcher_pid)

        Logger.info("[#{__MODULE__}] init completed successfully.")
        # Store nil for original_stty as we are not saving it anymore
        {:ok, %State{dispatcher_pid: dispatcher_pid, original_stty: nil}}

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Failed to initialize ExTermbox: #{inspect(reason)}. Halting init.")
        # restore_stty(original_stty) # No need to restore if not saved
        {:stop, {:termbox_init_failed, reason}}
    end

      # {:error, reason} -> # This block belongs to save_original_stty case
      #  Logger.error("[#{__MODULE__}] Failed to get original stty settings: #{inspect(reason)}. Halting init.")
      #  {:stop, {:terminal_setup_failed, reason}}
    # end # End of save_original_stty case
  end

  @impl true
  def handle_info({:system_event, _pid, :sigwinch}, state) do
    # Remove this handler - rely on Termbox resize events via {:termbox_event, ...}
    # Logger.debug("Received SIGWINCH signal, querying new size.")
    # case get_terminal_size() do # This helper might still be useful or need adjustment
    #   {:ok, width, height} ->
    #     Logger.info("Terminal resized via SIGWINCH to: #{width}x#{height}")
    #     event = %Event{type: :resize, data: %{width: width, height: height}}
    #     # Only send if dispatcher_pid is known
    #     if state.dispatcher_pid, do: GenServer.cast(state.dispatcher_pid, {:dispatch, event})
    #     {:noreply, state}
    #   {:error, reason} ->
    #     Logger.error("Failed to get terminal size after SIGWINCH: #{inspect(reason)}")
    #     {:noreply, state}
    # end
    Logger.debug("Ignoring legacy :system_event :sigwinch message.")
    {:noreply, state} # Keep the function clause but make it do nothing
  end

  # --- NEW: Handle events from ExTermbox Port ---
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
  # --- END NEW ---

  # --- NEW: Handle termbox errors ---
  @impl true
  def handle_info({:termbox_error, reason}, state) do
    Logger.error("Received termbox error: #{inspect(reason)}. Stopping driver.")
    {:stop, {:termbox_error, reason}, state}
  end
  # --- END NEW ---

  # --- NEW: Handle dispatcher registration ---
  @impl true
  def handle_cast({:register_dispatcher, pid}, state) when is_pid(pid) do
    Logger.info("Registering dispatcher PID: #{inspect(pid)}")
    # Send initial size event now that we have the PID
    send_initial_resize_event(pid)
    {:noreply, %{state | dispatcher_pid: pid}}
  end
  # --- END NEW ---

  @impl true
  def terminate(_reason, _state) do
    Logger.info("Terminal Driver terminating.")
    # Ensure ExTermbox is shut down
    # Logger.debug("Shutting down ExTermbox...")
    # ExTermbox.shutdown() # Removed: Assume port closes when owner terminates
    # Logger.debug("Restoring original terminal settings.")
    # restore_stty(state.original_stty) # Remove restore call
    :ok
  end

  # --- Private Helpers ---

  defp get_terminal_size do
    # This function might still be useful for the initial size or SIGWINCH,
    # but ExTermbox might provide size updates too via {:termbox_event, ...}
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

  # --- NEW: Placeholder for translating termbox events ---
  defp translate_termbox_event(event_map) do
    # Placeholder logic - Needs actual event_map structure from rrex_termbox 1.1.0
    # Example based on common patterns:
    case event_map do
      %{type: :key, key: key_code, char: char_code, mod: mod_code} ->
        # TODO: Translate key_code, char_code, mod_code to Raxol's key event format
        # Example: Map termbox key constants/chars to Raxol atoms/structs
        translated_key = translate_key(key_code, char_code, mod_code)
        event = %Event{type: :key, data: translated_key}
        {:ok, event}

      %{type: :resize, width: w, height: h} ->
        event = %Event{type: :resize, data: %{width: w, height: h}}
        {:ok, event}

      %{type: :mouse, x: x, y: y, button: btn_code} ->
         # TODO: Translate termbox mouse button codes and potentially event types (press, release, move)
        event = %Event{type: :mouse, data: %{x: x, y: y, button: translate_mouse_button(btn_code)}}
        {:ok, event}

      # Add cases for other event types termbox might send (e.g., paste?)

      _other ->
        # Logger.debug("Ignoring unknown termbox event type: #{inspect(event_map)}")
        :ignore
    end
  catch
    # Catch potential errors during translation
    type, reason -> {:error, {type, reason, Exception.format_stacktrace(__STACKTRACE__)}}
  end

  # Placeholder helper for key translation
  defp translate_key(key_code, char_code, mod_code) do
    # Actual implementation depends heavily on termbox constants/values
    # This needs to map raw codes to Raxol's expected format e.g. %{key: :up, char: nil, shift: false, ...}
     %{raw_key: key_code, raw_char: char_code, raw_mod: mod_code, key: :unknown, char: nil, alt: false, ctrl: false, shift: false, meta: false} # Basic structure
  end

   # Placeholder helper for mouse button translation
  defp translate_mouse_button(_btn_code) do
     # Actual implementation depends heavily on termbox constants/values
     # Map to Raxol's expected mouse button representation (e.g., :left, :right, :middle, :wheel_up, :wheel_down)
    :unknown # Placeholder
  end
  # --- END NEW ---
end
