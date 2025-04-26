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
    GenServer.start_link(__MODULE__, dispatcher_pid, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(dispatcher_pid) do
    Logger.info("Terminal Driver initializing...")
    # Set process to trap exit signals to ensure cleanup
    Process.flag(:trap_exit, true)
    # Subscribe to SIGWINCH for resize events
    :ok = :erlang.system_monitor(self(), [:sigwinch])

    original_stty = configure_terminal()
    # Subscribe to receive stdin data as messages
    :ok =
      :erlang.port_command(System.group_leader(), [
        :controlling_process,
        self(),
        2
      ])

    # Query initial terminal size and send event
    send_initial_resize_event(dispatcher_pid)

    {:ok, %State{dispatcher_pid: dispatcher_pid, original_stty: original_stty}}
  end

  @impl true
  def handle_info(
        {:io_request, _from, _reply_as,
         {:get_chars, _encoding, _group_leader, n}},
        state
      ) do
    # Request more characters when stdin is ready
    # Logger.debug("Requesting #{n} chars from stdin")
    req_id = make_ref()
    {:reply, req_id, {:get_chars, :unicode, System.group_leader(), n}}
    {:noreply, state}
  end

  @impl true
  def handle_info({:io_reply, _ref, data}, state) when is_binary(data) do
    # Logger.debug("Received data: #{inspect(data)}")
    # Process raw input data
    new_state = parse_and_dispatch_input(data, state)
    {:noreply, new_state}
  end

  # Handle SIGWINCH signal for terminal resize
  @impl true
  def handle_signal(:sigwinch, _from, state) do
    Logger.debug("Received SIGWINCH signal, querying new size.")

    case IO.ioctl(:stdio, :winsize) do
      {:ok, {height, width}} ->
        send_event(
          %Event{type: :resize, data: %{height: height, width: width}},
          state.dispatcher_pid
        )

      {:error, reason} ->
        Logger.error(
          "Failed to get terminal size after SIGWINCH: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  # Handle process termination (including abnormal exit)
  @impl true
  def terminate(reason, state) do
    Logger.info("Terminal Driver terminating. Reason: #{inspect(reason)}")
    restore_terminal(state.original_stty)
    :ok
  end

  # --- Private Helpers ---

  defp configure_terminal do
    # Get current settings
    {original_stty, 0} = System.cmd("stty", ["-g"])
    original_stty = String.trim(original_stty)
    Logger.debug("Original stty settings: #{original_stty}")

    # Set raw mode, disable echo
    System.cmd("stty", ["raw", "-echo"])
    Logger.info("Terminal set to raw -echo mode.")
    original_stty
  end

  defp restore_terminal(original_stty) when is_binary(original_stty) do
    Logger.info("Restoring terminal settings...")
    # Restore original settings
    {_output, status} = System.cmd("stty", [original_stty])
    if status != 0, do: Logger.error("Failed to restore terminal settings!")
    :ok
  end

  defp send_initial_resize_event(dispatcher_pid) do
    case IO.ioctl(:stdio, :winsize) do
      {:ok, {height, width}} ->
        send_event(
          %Event{type: :resize, data: %{height: height, width: width}},
          dispatcher_pid
        )

      {:error, reason} ->
        Logger.error("Failed to get initial terminal size: #{inspect(reason)}")
        # Default size if query fails? Or let the application handle it?
        # For now, just log the error.
    end
  end

  defp parse_and_dispatch_input(data, state) do
    buffer = state.input_buffer <> data
    parse_loop(buffer, state.dispatcher_pid, [])
  end

  # Loop through the buffer, parsing known sequences using case for pattern matching
  defp parse_loop(buffer, dispatcher_pid, events) do
    case buffer do
      # --- Standard ANSI Key Sequences ---
      "\e[A" <> rest -> # Arrow Up
        event = %Event{type: :key, data: %{key: :up}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[B" <> rest -> # Arrow Down
        event = %Event{type: :key, data: %{key: :down}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[C" <> rest -> # Arrow Right
        event = %Event{type: :key, data: %{key: :right}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[D" <> rest -> # Arrow Left
        event = %Event{type: :key, data: %{key: :left}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[H" <> rest -> # Home (often equivalent to \e[1~)
        event = %Event{type: :key, data: %{key: :home}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[F" <> rest -> # End (often equivalent to \e[4~)
        event = %Event{type: :key, data: %{key: :end}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[1~" <> rest -> # Home (XTerm)
        event = %Event{type: :key, data: %{key: :home}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[3~" <> rest -> # Delete
        event = %Event{type: :key, data: %{key: :delete}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[4~" <> rest -> # End (XTerm)
        event = %Event{type: :key, data: %{key: :end}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[5~" <> rest -> # Page Up
        event = %Event{type: :key, data: %{key: :page_up}}
        parse_loop(rest, dispatcher_pid, [event | events])

      "\e[6~" <> rest -> # Page Down
        event = %Event{type: :key, data: %{key: :page_down}}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Function Keys (Common VT/XTerm) ---
      "\eOP" <> rest -> # F1
        event = %Event{type: :key, data: %{key: :f1}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\eOQ" <> rest -> # F2
        event = %Event{type: :key, data: %{key: :f2}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\eOR" <> rest -> # F3
        event = %Event{type: :key, data: %{key: :f3}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\eOS" <> rest -> # F4
        event = %Event{type: :key, data: %{key: :f4}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[15~" <> rest -> # F5
        event = %Event{type: :key, data: %{key: :f5}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[17~" <> rest -> # F6
        event = %Event{type: :key, data: %{key: :f6}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[18~" <> rest -> # F7
        event = %Event{type: :key, data: %{key: :f7}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[19~" <> rest -> # F8
        event = %Event{type: :key, data: %{key: :f8}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[20~" <> rest -> # F9
        event = %Event{type: :key, data: %{key: :f9}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[21~" <> rest -> # F10
        event = %Event{type: :key, data: %{key: :f10}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[23~" <> rest -> # F11
        event = %Event{type: :key, data: %{key: :f11}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[24~" <> rest -> # F12
        event = %Event{type: :key, data: %{key: :f12}}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Modified Keys (Ctrl + Arrow example) ---
      "\e[1;5A" <> rest -> # Ctrl+Up
        event = %Event{type: :key, data: %{key: :up, ctrl: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;5B" <> rest -> # Ctrl+Down
        event = %Event{type: :key, data: %{key: :down, ctrl: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;5C" <> rest -> # Ctrl+Right
        event = %Event{type: :key, data: %{key: :right, ctrl: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;5D" <> rest -> # Ctrl+Left
        event = %Event{type: :key, data: %{key: :left, ctrl: true}}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Shift + Arrow Keys ---
      "\e[1;2A" <> rest -> # Shift+Up
        event = %Event{type: :key, data: %{key: :up, shift: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;2B" <> rest -> # Shift+Down
        event = %Event{type: :key, data: %{key: :down, shift: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;2C" <> rest -> # Shift+Right
        event = %Event{type: :key, data: %{key: :right, shift: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;2D" <> rest -> # Shift+Left
        event = %Event{type: :key, data: %{key: :left, shift: true}}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Alt/Meta Key Sequences ---
      # Common: ESC followed by a character
      <<27, char_code::utf8, rest::binary>>
        when char_code != ?[ and char_code != ?O -> # Avoid consuming start of other sequences
          char = <<char_code::utf8>>
          # Treat as Alt + character
          event = %Event{type: :key, data: %{key: :char, char: char, alt: true}}
          parse_loop(rest, dispatcher_pid, [event | events])
      # Less common but possible: ESC [ 1 ; 3 Sequence (like Alt+Up)
      "\e[1;3A" <> rest -> # Alt+Up
        event = %Event{type: :key, data: %{key: :up, alt: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;3B" <> rest -> # Alt+Down
        event = %Event{type: :key, data: %{key: :down, alt: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;3C" <> rest -> # Alt+Right
        event = %Event{type: :key, data: %{key: :right, alt: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[1;3D" <> rest -> # Alt+Left
        event = %Event{type: :key, data: %{key: :left, alt: true}}
        parse_loop(rest, dispatcher_pid, [event | events])
      # Add more Alt sequences as needed (e.g., Alt+Home, Alt+F1, etc.)

      # --- Focus Events ---
      "\e[I" <> rest -> # Focus In
        event = %Event{type: :focus_in}
        parse_loop(rest, dispatcher_pid, [event | events])
      "\e[O" <> rest -> # Focus Out
        event = %Event{type: :focus_out}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Bracketed Paste Mode ---
      "\e[200~" <> rest -> # Paste Start
        case parse_bracketed_paste(rest) do
          {:ok, pasted_text, remaining} ->
            event = %Event{type: :paste, data: %{text: pasted_text}}
            parse_loop(remaining, dispatcher_pid, [event | events])
          {:error, :incomplete} -> # Missing end sequence
            # Keep the buffer including the start sequence
            Enum.reverse(events) |> Enum.each(&send_event(&1, dispatcher_pid))
            %State{input_buffer: "\e[200~" <> rest}
        end

      # --- Tab / Backtab ---
      "\e[Z" <> rest -> # Shift+Tab (Backtab)
        event = %Event{type: :key, data: %{key: :back_tab}}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Mouse Events (VT200 format: \e[M Cb Cx Cy) ---
      # Note: Cx and Cy are char codes = coord + 32
      <<27, 91, 77, cb, cx, cy, rest::binary>> -> # \e[M
        x = cx - 32
        y = cy - 32
        {button, action, mods} = parse_vt200_mouse_button(cb)
        event = %Event{type: :mouse, data: %{button: button, action: action, x: x, y: y} |> Map.merge(mods)}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Mouse Events (SGR format: \e[<Cb;Cx;Cy(M|m)) ---
      # Note: M = press, m = release
      <<27, 91, 60, rest::binary>> -> # \e[<
        case parse_sgr_mouse(rest) do
          {:ok, event_data, remaining} ->
             event = %Event{type: :mouse, data: event_data}
             parse_loop(remaining, dispatcher_pid, [event | events])
          {:error, _reason} -> # Incomplete or invalid SGR sequence
            # Keep the buffer, dispatch previous events
            Enum.reverse(events) |> Enum.each(&send_event(&1, dispatcher_pid))
            %State{input_buffer: "\e[<" <> rest} # Put back the partial sequence
        end

      # --- Standalone Escape Key ---
      # Must come *after* sequences starting with ESC
      # Need to check if the *next* char is not part of a known sequence.
      # This simple check assumes ESC alone is sent, or followed by non-sequence char.
      <<27, next_char, rest::binary>> when next_char != ?[ and next_char != ?O ->
        event = %Event{type: :key, data: %{key: :esc}}
        # Reprocess buffer starting from next_char
        parse_loop(<<next_char, rest::binary>>, dispatcher_pid, [event | events])

      # --- Basic Control Characters (using ASCII codes) ---
      <<ctrl_code, rest::binary>> when ctrl_code >= 1 and ctrl_code <= 26 -> # Ctrl+A to Ctrl+Z
        char = <<ctrl_code + 96>> # 'a' is 97, Ctrl+A is 1 -> 1 + 96 = 97
        event = %Event{type: :key, data: %{key: :char, char: char, ctrl: true}}
        parse_loop(rest, dispatcher_pid, [event | events])

      <<9>> <> rest -> # Tab
        event = %Event{type: :key, data: %{key: :tab}}
        parse_loop(rest, dispatcher_pid, [event | events])

      <<13>> <> rest -> # Enter (Carriage Return)
        event = %Event{type: :key, data: %{key: :enter}}
        parse_loop(rest, dispatcher_pid, [event | events])

      <<8>> <> rest -> # Backspace (Ctrl+H)
        event = %Event{type: :key, data: %{key: :backspace}}
        parse_loop(rest, dispatcher_pid, [event | events])
      <<127>> <> rest -> # Backspace (DEL)
        event = %Event{type: :key, data: %{key: :backspace}}
        parse_loop(rest, dispatcher_pid, [event | events])

      # --- Printable Characters ---
      <<char_code::utf8, rest::binary>> ->
        key = <<char_code::utf8>>
        # Simple check for printable ASCII range (excluding DEL)
        # TODO: Expand for full Unicode printable character check if needed
        if char_code >= 32 and char_code != 127 do
          event = %Event{type: :key, data: %{key: :char, char: key}}
          parse_loop(rest, dispatcher_pid, [event | events])
        else
          # Handle other non-printable or unhandled control chars
          Logger.debug("Unhandled control character: #{char_code}")
          parse_loop(rest, dispatcher_pid, events) # Pass rest, not original buffer
        end

      # --- Buffer Empty or Incomplete Sequence ---
      "" ->
        # End of buffer, dispatch collected events in reverse order
        Enum.reverse(events) |> Enum.each(&send_event(&1, dispatcher_pid))
        # Return empty buffer in state
        %State{input_buffer: ""}

      # Buffer contains data, but no match (likely incomplete sequence or unhandled)
      _ ->
        # Keep the buffer for the next data chunk
        # Dispatch any events collected before hitting the incomplete sequence
        Enum.reverse(events) |> Enum.each(&send_event(&1, dispatcher_pid))
        %State{input_buffer: buffer}
    end
  end

  # --- SGR Mouse Parsing Helper ---
  # Parses \e[<Cb;Cx;Cy(M|m)
  defp parse_sgr_mouse(buffer) do
    case Regex.run(~r/^(\d+);(\d+);(\d+)([Mm])/, buffer, capture: :all_but_first)
    do
      [cb_str, cx_str, cy_str, type] ->
        cb = String.to_integer(cb_str)
        x = String.to_integer(cx_str)
        y = String.to_integer(cy_str)
        action = if type == "M", do: :press, else: :release
        {button, mods} = parse_sgr_mouse_button(cb)

        # Calculate the length of the matched sequence to find the remaining buffer
        matched_length = String.length(cb_str) + String.length(cx_str) + String.length(cy_str) + 3 # for ;, ;, M/m
        remaining = String.slice(buffer, matched_length..-1)

        event_data = %{button: button, action: action, x: x, y: y} |> Map.merge(mods)
        {:ok, event_data, remaining}
      _ ->
        {:error, :invalid_format}
    end
  end

  # Helper to decode SGR button code
  defp parse_sgr_mouse_button(cb) do
    button_code = cb &&& 3 # Low bits for button (0=L, 1=M, 2=R, 3=Release? No, button is preserved)
    mods_code = cb &&& (4 + 8 + 16) # Shift, Alt, Ctrl bits
    scroll_code = cb &&& 64 # Scroll bit

    button =
      cond do
        scroll_code == 64 -> :wheel # Scroll events override button bits
        button_code == 0 -> :left
        button_code == 1 -> :middle
        button_code == 2 -> :right
        true -> :unknown # Should not happen for standard presses
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
    button_code = cb &&& 3 # Low bits for button (0=L, 1=M, 2=R, 3=Release)
    mods_code = cb &&& (4 + 8 + 16) # Shift, Alt, Ctrl bits (Note: Alt often not reported)
    scroll_code = cb &&& 64 # Scroll bit

    {button, action} =
      cond do
        scroll_code == 64 and button_code == 0 -> {:wheel, :scroll_up}
        scroll_code == 64 and button_code == 1 -> {:wheel, :scroll_down}
        button_code == 0 -> {:left, :press}
        button_code == 1 -> {:middle, :press}
        button_code == 2 -> {:right, :press}
        button_code == 3 -> {:none, :release} # Release doesn't specify button
        true -> {:unknown, :unknown}
      end

    mods = %{
      shift: (mods_code &&& 4) != 0,
      alt: (mods_code &&& 8) != 0, # Often unreliable in VT200
      ctrl: (mods_code &&& 16) != 0
    }

    {button, action, mods}
  end

  defp send_event(event, dispatcher_pid) do
    send(dispatcher_pid, {:terminal_event, event})
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
