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

  alias Raxol.Core.Runtime.Log
  use Raxol.Core.Behaviours.BaseManager

  require Logger
  require Raxol.Core.Runtime.Log
  # Import Bitwise for bitwise operations
  # import Bitwise

  alias Raxol.Core.Events.Event
  alias Raxol.Terminal.ANSI.InputParser
  alias Raxol.Terminal.IOTerminal

  # Check if termbox2_nif is available at compile time
  @termbox2_available Code.ensure_loaded?(:termbox2_nif)

  import Raxol.Terminal.TerminalUtils, only: [has_terminal_device?: 0]

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
              init_retries: 0,
              io_terminal_state: nil,
              input_buffer: <<>>,
              flush_timer: nil
  end

  # --- Public API ---

  @doc """
  Returns the current terminal backend being used.

  ## Examples

      iex> Raxol.Terminal.Driver.backend()
      :termbox2_nif

      iex> Raxol.Terminal.Driver.backend()
      :io_terminal
  """
  # The spec covers both possible return values across platforms.
  # On any given compilation, only one branch is reachable due to
  # @termbox2_available being a compile-time constant.
  @dialyzer {:nowarn_function, backend: 0}
  @spec backend() :: :termbox2_nif | :io_terminal
  def backend do
    if @termbox2_available, do: :termbox2_nif, else: :io_terminal
  end

  # BaseManager provides start_link/1 and start_link/2 automatically
  # We can override if needed but the dispatcher_pid is passed as init argument

  # --- BaseManager Callbacks ---

  @impl true
  def init_manager(opts) do
    # Extract dispatcher_pid from opts - handle both keyword list and raw value
    dispatcher_pid = extract_dispatcher_pid(opts)

    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] init called with dispatcher: #{inspect(dispatcher_pid)}"
    )

    # Get original terminal settings using Erlang IO (no subprocess needed)
    output =
      case {:io.rows(), :io.columns()} do
        {{:ok, rows}, {:ok, cols}} -> "#{rows} #{cols}"
        _ -> "80 24"
      end

    state = %State{
      dispatcher_pid: dispatcher_pid,
      original_stty: output,
      termbox_state: :uninitialized,
      init_retries: 0
    }

    # Initialize terminal in raw mode only if attached to a TTY.
    # Use has_terminal_device?() instead of real_tty?() because the latter
    # relies on :io.columns() which fails in -noshell mode (mix run).
    tty_detected = has_terminal_device?()

    case {Mix.env(), tty_detected, dispatcher_pid} do
      {:test, _, nil} ->
        Raxol.Core.Runtime.Log.info(
          "[Driver] Test environment detected, sending driver_ready event"
        )

        Raxol.Core.Runtime.Log.warning_with_context(
          "[Driver] No dispatcher_pid provided, skipping driver_ready and initial resize event",
          %{}
        )

        state = %{state | termbox_state: :initialized}
        {:ok, state}

      {:test, _, pid} ->
        Raxol.Core.Runtime.Log.info(
          "[Driver] Test environment detected, sending driver_ready event"
        )

        send(pid, {:driver_ready, self()})

        Raxol.Core.Runtime.Log.info(
          "[Driver] Sending initial resize event to dispatcher_pid: #{inspect(pid)}"
        )

        send_initial_resize_event(pid)
        state = %{state | termbox_state: :initialized}
        {:ok, state}

      {_, _, nil} ->
        # No dispatcher — this is the Application supervisor's placeholder Driver.
        # Don't set up the terminal; the Lifecycle's Driver will do that.
        Raxol.Core.Runtime.Log.info(
          "[TerminalDriver] No dispatcher, skipping terminal setup."
        )

        {:ok, state}

      {_, true, _} ->
        Raxol.Core.Runtime.Log.info(
          "[TerminalDriver] TTY detected, initializing ANSI terminal..."
        )

        # Save original TTY settings via /dev/tty (System.cmd pipes stdin,
        # so we must redirect from /dev/tty for stty to affect the real terminal)
        original_stty =
          case :os.cmd(~c"stty -g < /dev/tty 2>/dev/null") do
            settings when is_list(settings) ->
              settings |> List.to_string() |> String.trim()

            _ ->
              nil
          end

        # Raw mode on the actual terminal: no echo, no line buffering, no signals
        :os.cmd(~c"stty raw -echo -icanon -isig < /dev/tty 2>/dev/null")

        # Suppress Logger console output so it doesn't corrupt the TUI
        Logger.configure(level: :none)

        # Enter alternate screen, hide cursor
        IO.write("\e[?1049h\e[?25l")

        # Reset mouse tracking (may be left over from a crashed session)
        IO.write("\e[?1003l\e[?1006l\e[?1000l")

        # Enable SGR mouse mode (button events + SGR extended coordinates)
        IO.write("\e[?1000h\e[?1006h")

        # Enable terminal modes: focus reporting, bracketed paste
        IO.write("\e[?1004h\e[?2004h")

        # Send initial resize event if we have a dispatcher
        if dispatcher_pid, do: send_initial_resize_event(dispatcher_pid)

        # Activate prim_tty reader for input. In -noshell mode, prim_tty
        # was initialized with tty => false, so the reader gets no select
        # notifications. start_stdin_reader triggers reinit with tty => true
        # and sets up trace interception of the reader's output.
        start_stdin_reader(self())

        state = %{
          state
          | termbox_state: :initialized,
            original_stty: original_stty,
            io_terminal_state: %{
              input_reader: Process.whereis(:user_drv_reader),
              tty_fd: nil,
              tty_port: nil
            }
        }

        {:ok, state}

      {_, false, _} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Not attached to a TTY. Skipping Termbox2Nif.tb_init(). Terminal features will be disabled.",
          %{}
        )

        {:ok, state}
    end
  end

  # --- BaseManager handle_info callbacks ---

  @impl true
  def handle_manager_info(:retry_init, %{init_retries: retries} = state)
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

  @impl true
  def handle_manager_info(:retry_init, state) do
    Raxol.Core.Runtime.Log.error(
      "Failed to initialize termbox after #{@max_init_retries} attempts. Terminal features will be disabled."
    )

    {:noreply, state}
  end

  @impl true
  def handle_manager_info(
        {:termbox_event, event_map},
        %{termbox_state: :initialized, dispatcher_pid: dispatcher_pid} = state
      ) do
    Raxol.Core.Runtime.Log.debug(
      "Received termbox event: #{inspect(event_map)}"
    )

    case translate_termbox_event(event_map) do
      {:ok, %Event{} = event} ->
        # Only send if dispatcher_pid is known
        case dispatcher_pid do
          nil -> :ok
          pid -> send_event_to_dispatcher(pid, event)
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

  @impl true
  def handle_manager_info({:termbox_event, _event_map}, state) do
    # Ignore events if termbox is not initialized
    {:noreply, state}
  end

  @impl true
  def handle_manager_info({:termbox_error, reason}, state) do
    Raxol.Core.Runtime.Log.error(
      "Received termbox error: #{inspect(reason)}. Attempting recovery..."
    )

    case state.termbox_state do
      :initialized -> handle_termbox_recovery(reason, state)
      _ -> {:stop, {:termbox_error, reason}, state}
    end
  end

  @impl true
  def handle_manager_info({:register_dispatcher, pid}, state)
      when is_pid(pid) do
    Raxol.Core.Runtime.Log.info("Registering dispatcher PID: #{inspect(pid)}")
    # Send initial size event now that we have the PID
    send_initial_resize_event(pid)
    {:noreply, %{state | dispatcher_pid: pid}}
  end

  @impl true
  def handle_manager_info(
        {:test_input, input_data},
        %{dispatcher_pid: nil} = state
      ) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Received test input before dispatcher registration: #{inspect(input_data)}",
      %{}
    )

    {:noreply, state}
  end

  @impl true
  def handle_manager_info({:test_input, input_data}, state) do
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

  @impl true
  def handle_manager_info({:EXIT, _pid, _reason}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_manager_info({:raw_input, data}, state) when is_binary(data) do
    buffer = state.input_buffer <> data

    _ = if state.flush_timer, do: Process.cancel_timer(state.flush_timer)

    if incomplete_escape?(buffer) do
      timer = Process.send_after(self(), :flush_input_buffer, 50)
      {:noreply, %{state | input_buffer: buffer, flush_timer: timer}}
    else
      flush_buffer(%{state | input_buffer: buffer, flush_timer: nil})
    end
  end

  # Trace messages from prim_tty reader — intercept input data
  @impl true
  def handle_manager_info(
        {:trace, _reader, :send, {_ref, {:data, data}}, _to},
        state
      ) do
    binary =
      cond do
        is_binary(data) -> data
        is_list(data) -> IO.iodata_to_binary(data)
        true -> <<>>
      end

    if byte_size(binary) > 0 do
      buffer = state.input_buffer <> binary

      _ = if state.flush_timer, do: Process.cancel_timer(state.flush_timer)

      if incomplete_escape?(buffer) do
        timer = Process.send_after(self(), :flush_input_buffer, 50)
        {:noreply, %{state | input_buffer: buffer, flush_timer: timer}}
      else
        flush_buffer(%{state | input_buffer: buffer, flush_timer: nil})
      end
    else
      {:noreply, state}
    end
  end

  # Ignore other trace messages from the reader (signals, receives, etc.)
  @impl true
  def handle_manager_info({:trace, _pid, :send, _msg, _to}, state) do
    {:noreply, state}
  end

  # Port data — accumulate and parse (buffering handles split escape sequences)
  @impl true
  def handle_manager_info({port, {:data, data}}, state) when is_port(port) do
    buffer = state.input_buffer <> data

    # Cancel any pending flush timer
    _ = if state.flush_timer, do: Process.cancel_timer(state.flush_timer)

    # If the buffer ends with an incomplete escape sequence, wait for more bytes.
    # Otherwise, dispatch immediately.
    if incomplete_escape?(buffer) do
      timer = Process.send_after(self(), :flush_input_buffer, 50)
      {:noreply, %{state | input_buffer: buffer, flush_timer: timer}}
    else
      flush_buffer(%{state | input_buffer: buffer, flush_timer: nil})
    end
  end

  # Flush timer fired — dispatch whatever we have
  @impl true
  def handle_manager_info(:flush_input_buffer, state) do
    flush_buffer(%{state | flush_timer: nil})
  end

  # Port closed
  @impl true
  def handle_manager_info({port, :eof}, state) when is_port(port) do
    {:noreply, state}
  end

  @impl true
  def handle_manager_info({port, {:exit_status, _status}}, state)
      when is_port(port) do
    {:noreply, state}
  end

  @impl true
  def handle_manager_info(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "#{__MODULE__} received unhandled message: #{inspect(unhandled_message)}",
      %{}
    )

    {:noreply, state}
  end

  defp dispatch_raw_input(data, state) do
    events = InputParser.parse(data)

    Enum.each(events, fn event ->
      case state.dispatcher_pid do
        nil -> :ok
        pid -> send_event_to_dispatcher(pid, event)
      end
    end)

    {:noreply, state}
  end

  # Forward cast messages to handle_info for test_input
  @impl true
  def handle_manager_cast({:test_input, input_data}, state) do
    handle_manager_info({:test_input, input_data}, state)
  end

  # Private helper to extract dispatcher_pid from init opts
  defp extract_dispatcher_pid(opts) when is_list(opts) do
    Keyword.get(opts, :dispatcher_pid)
  end

  defp extract_dispatcher_pid(pid) when is_pid(pid), do: pid
  defp extract_dispatcher_pid(_), do: nil

  defp handle_termbox_recovery(reason, state) do
    case terminate_termbox() do
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

  def terminate(_reason, %{termbox_state: :initialized} = state) do
    Raxol.Core.Runtime.Log.info("Terminal Driver terminating.")

    # Kill the stdin reader process
    case get_in(state, [
           Access.key(:io_terminal_state),
           Access.key(:input_reader)
         ]) do
      pid when is_pid(pid) ->
        Process.exit(pid, :shutdown)

      _ ->
        :ok
    end

    # Close tty port if open
    case get_in(state, [
           Access.key(:io_terminal_state),
           Access.key(:tty_port)
         ]) do
      port when is_port(port) ->
        try do
          Port.close(port)
        catch
          _, _ -> :ok
        end

      _ ->
        :ok
    end

    # Only attempt shutdown if not in test environment
    _ =
      case {Mix.env(), has_terminal_device?()} do
        {:test, _} ->
          :ok

        {_, false} ->
          :ok

        {_, true} ->
          # Disable terminal modes before restoring
          IO.write("\e[?1000l\e[?1006l\e[?1004l\e[?2004l")
          # Restore terminal: show cursor, leave alternate screen
          IO.write("\e[?25h\e[?1049l")
          :io.setopts(:standard_io, echo: true)

          # Restore original TTY settings (OS-level via /dev/tty)
          case state.original_stty do
            stty when is_binary(stty) and byte_size(stty) > 0 ->
              :os.cmd(String.to_charlist("stty #{stty} < /dev/tty 2>/dev/null"))

            _ ->
              :os.cmd(~c"stty sane < /dev/tty 2>/dev/null")
          end

          # Restore Logger output
          Logger.configure(level: :debug)
          :ok
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
    _ =
      case {Mix.env(), has_terminal_device?()} do
        {:test, _} ->
          :ok

        {_, false} ->
          :ok

        {_, true} ->
          _ =
            if @termbox2_available do
              :termbox2_nif.tb_set_title(title)
            else
              0
            end
      end

    {:noreply, state}
  end

  @doc """
  Processes a terminal position change event.
  """
  def process_position_change(x, y, state)
      when is_integer(x) and is_integer(y) do
    _ =
      case {Mix.env(), has_terminal_device?()} do
        {:test, _} ->
          :ok

        {_, false} ->
          :ok

        {_, true} ->
          _ =
            if @termbox2_available do
              :termbox2_nif.tb_set_position(x, y)
            else
              0
            end
      end

    {:noreply, state}
  end

  # --- Input reader ---
  # In -noshell mode (mix run), prim_tty is initialized with tty => false,
  # so its reader process never receives select notifications. We trigger
  # reinit via user_drv:start_shell, then trace-intercept the reader's
  # data messages.
  defp start_stdin_reader(_driver_pid) do
    # In -noshell mode, user_drv initializes prim_tty with tty => false,
    # so the NIF never sets up the terminal fd for select notifications.
    # The reader process exists but is blocked waiting for events that
    # never arrive.
    #
    # Fix: call user_drv:start_shell to trigger prim_tty:reinit with
    # tty => true, which activates the terminal fd. Then trace the
    # reader to intercept input data before it reaches user_drv.
    reader = Process.whereis(:user_drv_reader)
    user_drv = Process.whereis(:user_drv)

    if user_drv do
      # Activate the terminal fd by triggering prim_tty reinit.
      try do
        :gen_statem.call(
          user_drv,
          {:start_shell, %{initial_shell: {__MODULE__, :noop_shell, []}}}
        )
      catch
        _, _ -> :ok
      end
    end

    if reader do
      # Trace the reader's sends to intercept data before user_drv
      # forwards it. The reader sends {ref, {:data, bytes}} to user_drv.
      :erlang.trace(reader, true, [:send])
    end

    # Return nil — no spawned reader pid to track. Input arrives via
    # trace messages in handle_manager_info.
    nil
  end

  @doc false
  def noop_shell, do: :ok

  # --- Input buffering ---
  # Escape sequences may span multiple messages, so we buffer until complete.

  # Returns true if the buffer contains an ESC that hasn't been completed yet.
  defp incomplete_escape?(<<>>), do: false

  defp incomplete_escape?(buffer) do
    # Find the last ESC byte
    case :binary.matches(buffer, <<27>>) do
      [] ->
        false

      matches ->
        {last_esc_pos, _} = List.last(matches)

        tail =
          binary_part(buffer, last_esc_pos, byte_size(buffer) - last_esc_pos)

        # A bare ESC or ESC followed by [ but no terminal byte yet
        incomplete_csi?(tail)
    end
  end

  # ESC alone (more bytes expected)
  defp incomplete_csi?(<<27>>), do: true
  # ESC [ but no final byte (letters A-Z, a-z, ~)
  defp incomplete_csi?(<<27, 91, rest::binary>>),
    do: not has_csi_terminator?(rest)

  # ESC O but no function key letter
  defp incomplete_csi?(<<27, 79>>), do: true
  defp incomplete_csi?(_), do: false

  defp has_csi_terminator?(<<>>), do: false

  defp has_csi_terminator?(data) do
    # CSI terminates with a byte in 64..126 range (@A-Z[\]^_`a-z{|}~)
    last = :binary.last(data)
    last >= 64 and last <= 126
  end

  defp flush_buffer(%{input_buffer: <<>>} = state), do: {:noreply, state}

  defp flush_buffer(state) do
    dispatch_raw_input(state.input_buffer, %{state | input_buffer: <<>>})
  end

  # --- Private Helpers ---

  defp send_event_to_dispatcher(dispatcher_pid, event) do
    case Mix.env() do
      :test ->
        Raxol.Core.Runtime.Log.debug(
          "[Driver] Sending event in test mode: #{inspect(event)} to #{inspect(dispatcher_pid)}"
        )

        send(dispatcher_pid, {:"$gen_cast", {:dispatch, event}})

      _ ->
        GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  defp call_termbox_init do
    if @termbox2_available do
      :termbox2_nif.tb_init()
    else
      0
    end
  end

  defp terminate_termbox do
    if @termbox2_available do
      :termbox2_nif.tb_shutdown()
    else
      # Shutdown IOTerminal if it was initialized
      IOTerminal.shutdown()
      0
    end
  end

  defp get_termbox_width do
    if @termbox2_available do
      :termbox2_nif.tb_width()
    else
      # Use IOTerminal for size detection
      case IOTerminal.get_terminal_size() do
        {:ok, {width, _height}} -> width
        _ -> 80
      end
    end
  end

  defp get_termbox_height do
    if @termbox2_available do
      :termbox2_nif.tb_height()
    else
      # Use IOTerminal for size detection
      case IOTerminal.get_terminal_size() do
        {:ok, {_width, height}} -> height
        _ -> 24
      end
    end
  end

  defp initialize_termbox do
    case call_termbox_init() do
      0 ->
        :ok

      -1 ->
        {:error, :init_failed}
        # NIF only returns 0 or -1
    end
  end

  defp get_terminal_size do
    determine_terminal_size()
  end

  defp determine_terminal_size do
    case {Mix.env(), has_terminal_device?()} do
      {:test, _} -> {:ok, 80, 24}
      {_, true} -> get_termbox_size()
      {_, false} -> stty_size_fallback()
    end
  end

  defp get_termbox_size do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      width = get_termbox_width()
      height = get_termbox_height()

      case width > 0 and height > 0 do
        true -> {:ok, width, height}
        false -> stty_size_fallback()
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, _reason} -> stty_size_fallback()
    end
  end

  defp stty_size_fallback do
    case {:io.columns(), :io.rows()} do
      {{:ok, cols}, {:ok, rows}} ->
        {:ok, cols, rows}

      _ ->
        # In -noshell mode, :io.columns/rows fail. Use stty via /dev/tty.
        case :os.cmd(~c"stty size < /dev/tty 2>/dev/null") do
          result when is_list(result) ->
            str = List.to_string(result) |> String.trim()

            case String.split(str) do
              [rows_s, cols_s] ->
                rows = String.to_integer(rows_s)
                cols = String.to_integer(cols_s)

                if rows > 0 and cols > 0,
                  do: {:ok, cols, rows},
                  else: {:ok, 80, 24}

              _ ->
                {:ok, 80, 24}
            end

          _ ->
            {:ok, 80, 24}
        end
    end
  end

  defp send_initial_resize_event(dispatcher_pid) do
    # Keep this as it provides an immediate size on startup
    {:ok, width, height} = get_terminal_size()
    Raxol.Core.Runtime.Log.info("Initial terminal size: #{width}x#{height}")
    event = %Event{type: :resize, data: %{width: width, height: height}}

    # In test mode, send directly to the test process
    case Mix.env() do
      :test ->
        Raxol.Core.Runtime.Log.info(
          "[Driver] Sending resize event in test mode: #{inspect(event)}"
        )

        send(dispatcher_pid, {:"$gen_cast", {:dispatch, event}})

      _ ->
        GenServer.cast(dispatcher_pid, {:dispatch, event})
    end
  end

  # --- Event translation from rrex_termbox v2.0.1 NIF ---
  defp translate_termbox_event(event_map) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           translate_event_map(event_map)
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

  defp translate_key_or_char(data, char_code, _key_code) when char_code > 0 do
    Map.put(data, :char, <<char_code::utf8>>)
  end

  defp translate_key_or_char(data, _char_code, 65), do: Map.put(data, :key, :up)

  defp translate_key_or_char(data, _char_code, 66),
    do: Map.put(data, :key, :down)

  defp translate_key_or_char(data, _char_code, 67),
    do: Map.put(data, :key, :right)

  defp translate_key_or_char(data, _char_code, 68),
    do: Map.put(data, :key, :left)

  defp translate_key_or_char(data, _char_code, 265),
    do: Map.put(data, :key, :f1)

  defp translate_key_or_char(data, _char_code, 266),
    do: Map.put(data, :key, :f2)

  defp translate_key_or_char(data, _char_code, _key_code),
    do: Map.put(data, :key, :unknown)

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

  defp parse_test_input(input_data) when is_binary(input_data) do
    Raxol.Core.Runtime.Log.debug(
      "[TerminalDriver.parse_test_input] Parsing: #{inspect(input_data)}"
    )

    case InputParser.parse(input_data) do
      [event | _] -> event
      [] -> %Event{type: :unknown_test_input, data: %{raw: input_data}}
    end
  end

  defp translate_event_map(event_map) do
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
  end
end
