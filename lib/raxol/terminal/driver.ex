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

  import Bitwise

  require Logger

  alias Raxol.Core.Events.Event
  # TODO: Add alias for an ANSI escape code parser if needed

  @type dispatcher_pid :: pid()
  @type original_stty :: String.t()

  defmodule State do
    @moduledoc false
    defstruct dispatcher_pid: nil,
              original_stty: nil,
              # Buffer for partial ANSI sequences
              input_buffer: ""
  end

  # --- Public API ---

  @doc "Starts the Terminal Driver process."
  @spec start_link(dispatcher_pid()) :: GenServer.on_start()
  def start_link(dispatcher_pid) when is_pid(dispatcher_pid) do
    Logger.info("[#{__MODULE__}] start_link called for dispatcher: #{inspect(dispatcher_pid)}")
    GenServer.start_link(__MODULE__, dispatcher_pid, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(dispatcher_pid) do
    Logger.info("[#{__MODULE__}] init starting...")
    # Set process to trap exit signals to ensure cleanup
    Logger.debug("[#{__MODULE__}] Setting trap_exit flag...")
    Process.flag(:trap_exit, true)
    # Subscribe to SIGWINCH for resize events
    Logger.debug("[#{__MODULE__}] Subscribing to system_monitor :sigwinch...")
    :ok = :erlang.system_monitor(self(), [:sigwinch])

    # Register for SIGWINCH signals
    Logger.debug("[#{__MODULE__}] Setting OS signal handler for :sigwinch...")
    :ok = :os.set_signal(:sigwinch, :deliver)

    # Save original terminal settings and set raw mode
    Logger.debug("[#{__MODULE__}] Configuring terminal (stty raw)...")
    case configure_terminal() do
      {:ok, original_stty} ->
        Logger.debug("[#{__MODULE__}] Terminal configured. Original stty saved.")
        # Subscribe to receive stdin data as messages using standard IO configuration
        Logger.debug("[#{__MODULE__}] Setting stdio opts [:raw, encoding: :unicode, :binary]...")
        :ok = :io.setopts(:stdio, [:raw, {:encoding, :unicode}, :binary])

        # Send initial size event
        Logger.debug("[#{__MODULE__}] Sending initial resize event...")
        send_initial_resize_event(dispatcher_pid)

        Logger.info("[#{__MODULE__}] init completed successfully.")
        {:ok, %State{dispatcher_pid: dispatcher_pid, original_stty: original_stty}}

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Failed to configure terminal: #{inspect(reason)}. Halting init.")
        {:stop, {:terminal_setup_failed, reason}} # Stop the GenServer if terminal setup fails
    end
  end

  @impl true
  def handle_info({:system_event, _pid, :sigwinch}, state) do
    Logger.debug("Received SIGWINCH signal, querying new size.")

    case get_terminal_size() do
      {:ok, width, height} ->
        Logger.info("Terminal resized to: #{width}x#{height}")
        # Dispatch resize event directly to Dispatcher
        event = %Event{type: :resize, data: %{width: width, height: height}}
        GenServer.cast(state.dispatcher_pid, {:dispatch, event})
        {:noreply, state}
      {:error, reason} ->
        Logger.error("Failed to get terminal size after SIGWINCH: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:io_request, _from, _reply_as, {:put_chars, :unicode, chars}}, %State{original_stty: _stty} = state) do
    # TODO: Proper handling of different charsets
    # Replace undefined IO.put_chars with IO.write
    IO.write(:stdio, chars)
    {:reply, {:ok, []}, state}
  end

  @impl true
  def handle_info({:io_reply, _ref, _res}, state) do
    # Ignore io_replies we didn't explicitly handle
    {:noreply, state}
  end

  # Handle standard input
  @impl true
  def handle_info({:io, :stdio, data}, state) when is_binary(data) do
    # Logger.debug("Received data: #{inspect data}")
    # Process raw input data
    new_buffer = state.input_buffer <> data
    {remaining_buffer, dispatched_state} = parse_and_dispatch_input(new_buffer, state)
    {:noreply, %{dispatched_state | input_buffer: remaining_buffer}}
  end

  # Handle process termination (including abnormal exit)
  @impl true
  def terminate(_reason, state) do
    Logger.info("Terminal Driver terminating. Restoring original settings.")
    restore_stty(state.original_stty)
    :ok
  end

  # --- Private Helpers ---

  defp configure_terminal do
    # Use ~c"" for charlist
    original_stty = String.trim(:os.cmd(~c"stty -g"))

    # Use :os.cmd for consistency and simplicity, returns output directly
    # This bypasses the {:ok, output} tuple from System.cmd and the type warning
    stty_raw_output = :os.cmd(~c"stty raw -echo -isig min 0 time 0")
    # Basic check if the command itself failed (though :os.cmd doesn't give exit status easily)
    if String.contains?(stty_raw_output, "invalid argument") do
        Logger.error("Failed to set terminal to raw mode. stty output: #{stty_raw_output}")
      {:error, :stty_failed}
    else
      Logger.debug("Terminal set to raw mode.")
      {:ok, original_stty}
    end
  end

  defp restore_stty(original_stty) do
    # Use :os.cmd for consistency
    stty_restore_output = :os.cmd(~c"stty " ++ original_stty)
     if String.contains?(stty_restore_output, "invalid argument") do
       Logger.error("Failed to restore terminal settings. stty output: #{stty_restore_output}")
       {:error, :stty_failed}
     else
       Logger.debug("Terminal settings restored.")
      :ok
     end
  end

  defp get_terminal_size do
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

  # Updated parse_and_dispatch_input to return remaining buffer and state
  defp parse_and_dispatch_input(buffer, state) do
    {remaining_buffer, events} = parse_loop(buffer, [])

    # Dispatch events in reverse order (as they were prepended)
    Enum.reverse(events) |> Enum.each(fn event ->
      # Logger.debug("Dispatching event: #{inspect event.type}")
      GenServer.cast(state.dispatcher_pid, {:dispatch, event})
    end)

    {remaining_buffer, state} # Return remaining buffer and unchanged state for now
  end

  # Updated parse_loop to return remaining buffer and collected events
  defp parse_loop(buffer, events) do
    case buffer do
      # --- Standard ANSI Key Sequences ---
      # Arrow Up
      "\e[A" <> rest ->
        event = %Event{type: :key, data: %{key: :up}}
        parse_loop(rest, [event | events])

      # Arrow Down
      "\e[B" <> rest ->
        event = %Event{type: :key, data: %{key: :down}}
        parse_loop(rest, [event | events])

      # Arrow Right
      "\e[C" <> rest ->
        event = %Event{type: :key, data: %{key: :right}}
        parse_loop(rest, [event | events])

      # Arrow Left
      "\e[D" <> rest ->
        event = %Event{type: :key, data: %{key: :left}}
        parse_loop(rest, [event | events])

      # Home (often equivalent to \e[1~)
      "\e[H" <> rest ->
        event = %Event{type: :key, data: %{key: :home}}
        parse_loop(rest, [event | events])

      # End (often equivalent to \e[4~)
      "\e[F" <> rest ->
        event = %Event{type: :key, data: %{key: :end}}
        parse_loop(rest, [event | events])

      # Home (XTerm)
      "\e[1~" <> rest ->
        event = %Event{type: :key, data: %{key: :home}}
        parse_loop(rest, [event | events])

      # Delete
      "\e[3~" <> rest ->
        event = %Event{type: :key, data: %{key: :delete}}
        parse_loop(rest, [event | events])

      # End (XTerm)
      "\e[4~" <> rest ->
        event = %Event{type: :key, data: %{key: :end}}
        parse_loop(rest, [event | events])

      # Page Up
      "\e[5~" <> rest ->
        event = %Event{type: :key, data: %{key: :page_up}}
        parse_loop(rest, [event | events])

      # Page Down
      "\e[6~" <> rest ->
        event = %Event{type: :key, data: %{key: :page_down}}
        parse_loop(rest, [event | events])

      # --- Function Keys (Common VT/XTerm) ---
      # F1
      "\eOP" <> rest ->
        event = %Event{type: :key, data: %{key: :f1}}
        parse_loop(rest, [event | events])

      # F2
      "\eOQ" <> rest ->
        event = %Event{type: :key, data: %{key: :f2}}
        parse_loop(rest, [event | events])

      # F3
      "\eOR" <> rest ->
        event = %Event{type: :key, data: %{key: :f3}}
        parse_loop(rest, [event | events])

      # F4
      "\eOS" <> rest ->
        event = %Event{type: :key, data: %{key: :f4}}
        parse_loop(rest, [event | events])

      # F5
      "\e[15~" <> rest ->
        event = %Event{type: :key, data: %{key: :f5}}
        parse_loop(rest, [event | events])

      # F6
      "\e[17~" <> rest ->
        event = %Event{type: :key, data: %{key: :f6}}
        parse_loop(rest, [event | events])

      # F7
      "\e[18~" <> rest ->
        event = %Event{type: :key, data: %{key: :f7}}
        parse_loop(rest, [event | events])

      # F8
      "\e[19~" <> rest ->
        event = %Event{type: :key, data: %{key: :f8}}
        parse_loop(rest, [event | events])

      # F9
      "\e[20~" <> rest ->
        event = %Event{type: :key, data: %{key: :f9}}
        parse_loop(rest, [event | events])

      # F10
      "\e[21~" <> rest ->
        event = %Event{type: :key, data: %{key: :f10}}
        parse_loop(rest, [event | events])

      # F11
      "\e[23~" <> rest ->
        event = %Event{type: :key, data: %{key: :f11}}
        parse_loop(rest, [event | events])

      # F12
      "\e[24~" <> rest ->
        event = %Event{type: :key, data: %{key: :f12}}
        parse_loop(rest, [event | events])

      # --- Modified Keys (Ctrl + Arrow example) ---
      # Ctrl+Up
      "\e[1;5A" <> rest ->
        event = %Event{type: :key, data: %{key: :up, ctrl: true}}
        parse_loop(rest, [event | events])

      # Ctrl+Down
      "\e[1;5B" <> rest ->
        event = %Event{type: :key, data: %{key: :down, ctrl: true}}
        parse_loop(rest, [event | events])

      # Ctrl+Right
      "\e[1;5C" <> rest ->
        event = %Event{type: :key, data: %{key: :right, ctrl: true}}
        parse_loop(rest, [event | events])

      # Ctrl+Left
      "\e[1;5D" <> rest ->
        event = %Event{type: :key, data: %{key: :left, ctrl: true}}
        parse_loop(rest, [event | events])

      # --- Shift + Arrow Keys ---
      # Shift+Up
      "\e[1;2A" <> rest ->
        event = %Event{type: :key, data: %{key: :up, shift: true}}
        parse_loop(rest, [event | events])

      # Shift+Down
      "\e[1;2B" <> rest ->
        event = %Event{type: :key, data: %{key: :down, shift: true}}
        parse_loop(rest, [event | events])

      # Shift+Right
      "\e[1;2C" <> rest ->
        event = %Event{type: :key, data: %{key: :right, shift: true}}
        parse_loop(rest, [event | events])

      # Shift+Left
      "\e[1;2D" <> rest ->
        event = %Event{type: :key, data: %{key: :left, shift: true}}
        parse_loop(rest, [event | events])

      # --- Alt/Meta Key Sequences ---
      # Common: ESC followed by a character
      # Avoid consuming start of other sequences
      <<27, char_code::utf8, rest::binary>>
      when char_code != ?[ and char_code != ?O ->
        char = <<char_code::utf8>>
        # Treat as Alt + character
        event = %Event{type: :key, data: %{key: :char, char: char, alt: true}}
        parse_loop(rest, [event | events])

      # Less common but possible: ESC [ 1 ; 3 Sequence (like Alt+Up)
      # Alt+Up
      "\e[1;3A" <> rest ->
        event = %Event{type: :key, data: %{key: :up, alt: true}}
        parse_loop(rest, [event | events])

      # Alt+Down
      "\e[1;3B" <> rest ->
        event = %Event{type: :key, data: %{key: :down, alt: true}}
        parse_loop(rest, [event | events])

      # Alt+Right
      "\e[1;3C" <> rest ->
        event = %Event{type: :key, data: %{key: :right, alt: true}}
        parse_loop(rest, [event | events])

      # Alt+Left
      "\e[1;3D" <> rest ->
        event = %Event{type: :key, data: %{key: :left, alt: true}}
        parse_loop(rest, [event | events])

      # Add more Alt sequences as needed (e.g., Alt+Home, Alt+F1, etc.)

      # --- Focus Events ---
      # Focus In
      "\e[I" <> rest ->
        event = %Event{type: :focus_in}
        parse_loop(rest, [event | events])

      # Focus Out
      "\e[O" <> rest ->
        event = %Event{type: :focus_out}
        parse_loop(rest, [event | events])

      # --- Bracketed Paste Mode ---
      # Paste Start
      "\e[200~" <> rest ->
        case parse_bracketed_paste(rest) do
          {:ok, pasted_text, remaining} ->
            event = %Event{type: :paste, data: %{text: pasted_text}}
            parse_loop(remaining, [event | events])

          # Missing end sequence
          {:error, :incomplete} ->
            # Keep the buffer including the start sequence
            {buffer, events}
        end

      # --- Tab / Backtab ---
      # Shift+Tab (Backtab)
      "\e[Z" <> rest ->
        event = %Event{type: :key, data: %{key: :back_tab}}
        parse_loop(rest, [event | events])

      # --- Mouse Events (VT200 format: \e[M Cb Cx Cy) ---
      # Note: Cx and Cy are char codes = coord + 32
      # \e[M
      <<27, 91, 77, cb, cx, cy, rest::binary>> ->
        x = cx - 32
        y = cy - 32
        {button, action, mods} = parse_vt200_mouse_button(cb)

        event = %Event{
          type: :mouse,
          data: %{button: button, action: action, x: x, y: y} |> Map.merge(mods)
        }

        parse_loop(rest, [event | events])

      # --- Mouse Events (SGR format: \e[<Cb;Cx;Cy(M|m)) ---
      # Note: M = press, m = release
      # \e[<
      <<27, 91, 60, rest::binary>> ->
        case parse_sgr_mouse(rest) do
          {:ok, event_data, remaining} ->
            event = %Event{type: :mouse, data: event_data}
            parse_loop(remaining, [event | events])

          # Incomplete or invalid SGR sequence
          {:error, _reason} ->
            # Keep the buffer, dispatch previous events
            {buffer, events}
        end

      # --- Standalone Escape Key ---
      # Must come *after* sequences starting with ESC
      # Need to check if the *next* char is not part of a known sequence.
      # This simple check assumes ESC alone is sent, or followed by non-sequence char.
      <<27, next_char, rest::binary>> when next_char != ?[ and next_char != ?O ->
        event = %Event{type: :key, data: %{key: :esc}}
        # Reprocess buffer starting from next_char
        parse_loop(<<next_char, rest::binary>>, [event | events])

      # --- Basic Control Characters (using ASCII codes) ---
      # Ctrl+A to Ctrl+Z
      <<ctrl_code, rest::binary>> when ctrl_code >= 1 and ctrl_code <= 26 ->
        # 'a' is 97, Ctrl+A is 1 -> 1 + 96 = 97
        char = <<ctrl_code + 96>>
        event = %Event{type: :key, data: %{key: :char, char: char, ctrl: true}}
        parse_loop(rest, [event | events])

      # Tab
      <<9>> <> rest ->
        event = %Event{type: :key, data: %{key: :tab}}
        parse_loop(rest, [event | events])

      # Enter (Carriage Return)
      <<13>> <> rest ->
        event = %Event{type: :key, data: %{key: :enter}}
        parse_loop(rest, [event | events])

      # Backspace (Ctrl+H)
      <<8>> <> rest ->
        event = %Event{type: :key, data: %{key: :backspace}}
        parse_loop(rest, [event | events])

      # Backspace (DEL)
      <<127>> <> rest ->
        event = %Event{type: :key, data: %{key: :backspace}}
        parse_loop(rest, [event | events])

      # --- Printable Characters ---
      <<char_code::utf8, rest::binary>> ->
        key = <<char_code::utf8>>
        # Simple check for printable ASCII range (excluding DEL)
        # TODO: Expand for full Unicode printable character check if needed
        if char_code >= 32 and char_code != 127 do
          event = %Event{type: :key, data: %{key: :char, char: key}}
          parse_loop(rest, [event | events])
        else
          # Handle other non-printable or unhandled control chars
          Logger.debug("Unhandled control character: #{char_code}")
          # Pass rest, not original buffer
          parse_loop(rest, events)
        end

      # --- Buffer Empty or Incomplete Sequence ---
      "" ->
        # End of buffer, dispatch collected events in reverse order
        {"", events}

      # Buffer contains data, but no match (likely incomplete sequence or unhandled)
      _ ->
        # Keep the buffer for the next data chunk
        {buffer, events}
    end
  end

  # --- SGR Mouse Parsing Helper ---
  # Parses \e[<Cb;Cx;Cy(M|m)
  defp parse_sgr_mouse(buffer) do
    case Regex.run(~r/^(\d+);(\d+);(\d+)([Mm])/, buffer,
           capture: :all_but_first
         ) do
      [cb_str, cx_str, cy_str, type] ->
        cb = String.to_integer(cb_str)
        x = String.to_integer(cx_str)
        y = String.to_integer(cy_str)
        action = if type == "M", do: :press, else: :release
        {button, mods} = parse_sgr_mouse_button(cb)

        # Calculate the length of the matched sequence to find the remaining buffer
        # for ;, ;, M/m
        matched_length =
          String.length(cb_str) + String.length(cx_str) + String.length(cy_str) +
            3

        remaining = String.slice(buffer, matched_length..-1)

        event_data =
          %{button: button, action: action, x: x, y: y} |> Map.merge(mods)

        {:ok, event_data, remaining}

      _ ->
        {:error, :invalid_format}
    end
  end

  # Helper to decode SGR button code
  defp parse_sgr_mouse_button(cb) do
    # Low bits for button (0=L, 1=M, 2=R, 3=Release? No, button is preserved)
    button_code = cb &&& 3
    # Shift, Alt, Ctrl bits
    mods_code = cb &&& 4 + 8 + 16
    # Scroll bit
    scroll_code = cb &&& 64

    button =
      cond do
        # Scroll events override button bits
        scroll_code == 64 -> :wheel
        button_code == 0 -> :left
        button_code == 1 -> :middle
        button_code == 2 -> :right
        # Should not happen for standard presses
        true -> :unknown
      end

    mods = %{
      shift: (mods_code &&& 4) != 0,
      alt: (mods_code &&& 8) != 0,
      ctrl: (mods_code &&& 16) != 0
    }

    {button, mods}
  end

  # --- VT200 Mouse Parsing Helper ---
  # Parses Cb byte
  defp parse_vt200_mouse_button(cb) do
    # Low bits for button (0=L, 1=M, 2=R, 3=Release)
    button_code = cb &&& 3
    # Shift, Alt, Ctrl bits (Note: Alt often not reported)
    mods_code = cb &&& 4 + 8 + 16
    # Scroll bit
    scroll_code = cb &&& 64

    {button, action} =
      cond do
        scroll_code == 64 and button_code == 0 -> {:wheel, :scroll_up}
        scroll_code == 64 and button_code == 1 -> {:wheel, :scroll_down}
        button_code == 0 -> {:left, :press}
        button_code == 1 -> {:middle, :press}
        button_code == 2 -> {:right, :press}
        # Release doesn't specify button
        button_code == 3 -> {:none, :release}
        true -> {:unknown, :unknown}
      end

    mods = %{
      shift: (mods_code &&& 4) != 0,
      # Often unreliable in VT200
      alt: (mods_code &&& 8) != 0,
      ctrl: (mods_code &&& 16) != 0
    }

    {button, action, mods}
  end

  # --- Bracketed Paste Parsing Helper ---
  defp parse_bracketed_paste(buffer) do
    end_sequence = "\e[201~"

    case String.split(buffer, end_sequence, parts: 2) do
      [pasted_text, remaining] ->
        {:ok, pasted_text, remaining}

      # Only one part means end sequence not found
      [_pasted_text_so_far] ->
        {:error, :incomplete}
    end
  end
end
