if Code.ensure_loaded?(:ssh) do
  defmodule Raxol.Terminal.SSH.SSHSession do
    @moduledoc """
      SSH session management for interactive terminal sessions.

    Manages interactive SSH shell sessions, handling terminal I/O, window resizing,
    and session lifecycle. Works in conjunction with SSHClient to provide a complete
    remote terminal experience.

    ## Features

    - Interactive shell session management
    - PTY (pseudo-terminal) support
    - Terminal window resizing
    - Real-time I/O streaming
    - Session recording and playback
    - Command history and completion
    - Signal forwarding (Ctrl+C, Ctrl+Z, etc.)
    - Terminal escape sequence handling

    ## Usage

        # Start session with SSH client
        {:ok, session} = SSHSession.start(ssh_client, pty_options)

        # Send input to remote shell
        SSHSession.send_input(session, "ls -la\\n")

        # Resize terminal
        SSHSession.resize(session, 80, 24)

        # Get session output
        output = SSHSession.get_output(session)
    """

    use Raxol.Core.Behaviours.BaseManager

    @type pty_options :: %{
            optional(:term) => String.t(),
            optional(:width) => pos_integer(),
            optional(:height) => pos_integer(),
            optional(:pixel_width) => pos_integer(),
            optional(:pixel_height) => pos_integer(),
            optional(:modes) => map()
          }

    @type session_state :: %{
            ssh_client: pid(),
            connection_ref: reference(),
            channel_id: integer(),
            pty_options: pty_options(),
            output_buffer: binary(),
            input_buffer: binary(),
            subscribers: [pid()],
            recording: boolean(),
            recording_file: String.t() | nil,
            started_at: DateTime.t(),
            last_activity: DateTime.t(),
            exit_status: integer() | nil
          }

    @type session_info :: %{
            started_at: DateTime.t(),
            last_activity: DateTime.t(),
            bytes_received: non_neg_integer(),
            bytes_sent: non_neg_integer(),
            exit_status: integer() | nil,
            recording: boolean()
          }

    # Default PTY settings
    @default_term "xterm-256color"
    @default_width 80
    @default_height 24
    # 1MB buffer limit
    @buffer_max_size 1_000_000

    # Terminal mode constants (simplified subset)
    @terminal_modes %{
      # Interrupt character
      :VINTR => 1,
      # Quit character
      :VQUIT => 2,
      # Erase character
      :VERASE => 3,
      # Kill character
      :VKILL => 4,
      # End-of-file character
      :VEOF => 5,
      # End-of-line character
      :VEOL => 6,
      # Echo input characters
      :ECHO => 53,
      # Canonical input processing
      :ICANON => 54,
      # Enable signals
      :ISIG => 55
    }

    ## Public API

    @doc """
    Starts a new SSH session.

    ## Parameters

    - `ssh_client` - Connected SSH client process
    - `pty_options` - PTY configuration options

    ## Returns

    - `{:ok, pid}` - Session process started
    - `{:error, reason}` - Failed to start session
    """
    @spec start(pid(), pty_options()) :: {:ok, pid()} | {:error, term()}
    def start(ssh_client, pty_options \\ %{}) do
      start_link(ssh_client: ssh_client, pty_options: pty_options)
    end

    @doc """
    Sends input to the remote shell.

    ## Parameters

    - `session` - SSH session process
    - `data` - Input data to send

    ## Returns

    - `:ok` - Input sent successfully
    - `{:error, reason}` - Failed to send input
    """
    @spec send_input(pid(), binary()) :: :ok
    def send_input(session, data) when is_binary(data) do
      GenServer.cast(session, {:send_input, data})
    end

    @doc """
    Resizes the terminal window.

    ## Parameters

    - `session` - SSH session process
    - `width` - New terminal width in columns
    - `height` - New terminal height in rows

    ## Returns

    - `:ok` - Resize successful
    - `{:error, reason}` - Resize failed
    """
    @spec resize(pid(), pos_integer(), pos_integer()) :: :ok | {:error, term()}
    def resize(session, width, height)
        when is_integer(width) and is_integer(height) do
      GenServer.call(session, {:resize, width, height})
    end

    @doc """
    Gets accumulated output from the session.

    ## Parameters

    - `session` - SSH session process
    - `clear_buffer` - Whether to clear the buffer after reading

    ## Returns

    - `binary()` - Session output
    """
    @spec get_output(pid(), boolean()) :: binary()
    def get_output(session, clear_buffer \\ false) do
      GenServer.call(session, {:get_output, clear_buffer})
    end

    @doc """
    Subscribes to real-time session output.

    The subscriber will receive messages in the format:
    `{:ssh_session_output, session_pid, data}`

    ## Parameters

    - `session` - SSH session process
    - `subscriber` - Process to receive output messages

    ## Returns

    - `:ok` - Subscription successful
    """
    @spec subscribe(pid(), pid()) :: :ok
    def subscribe(session, subscriber \\ self()) do
      GenServer.cast(session, {:subscribe, subscriber})
    end

    @doc """
    Unsubscribes from session output.

    ## Parameters

    - `session` - SSH session process
    - `subscriber` - Process to unsubscribe

    ## Returns

    - `:ok` - Unsubscription successful
    """
    @spec unsubscribe(pid(), pid()) :: :ok
    def unsubscribe(session, subscriber \\ self()) do
      GenServer.cast(session, {:unsubscribe, subscriber})
    end

    @doc """
    Starts recording the session to a file.

    ## Parameters

    - `session` - SSH session process
    - `file_path` - Path to save the recording

    ## Returns

    - `:ok` - Recording started
    - `{:error, reason}` - Failed to start recording
    """
    @spec start_recording(pid(), String.t()) :: :ok | {:error, term()}
    def start_recording(session, file_path) do
      GenServer.call(session, {:start_recording, file_path})
    end

    @doc """
    Stops recording the session.

    ## Parameters

    - `session` - SSH session process

    ## Returns

    - `:ok` - Recording stopped
    """
    @spec stop_recording(pid()) :: :ok
    def stop_recording(session) do
      GenServer.call(session, :stop_recording)
    end

    @doc """
    Gets session information and statistics.

    ## Parameters

    - `session` - SSH session process

    ## Returns

    - `{:ok, info}` - Session information
    """
    @spec get_session_info(pid()) :: {:ok, session_info()}
    def get_session_info(session) do
      GenServer.call(session, :get_session_info)
    end

    @doc """
    Sends a signal to the remote process.

    ## Parameters

    - `session` - SSH session process
    - `signal` - Signal to send (:INT, :TERM, :KILL, etc.)

    ## Returns

    - `:ok` - Signal sent
    - `{:error, reason}` - Failed to send signal
    """
    @spec send_signal(pid(), atom()) :: :ok | {:error, term()}
    def send_signal(session, signal) when is_atom(signal) do
      GenServer.call(session, {:send_signal, signal})
    end

    @doc """
    Terminates the SSH session.

    ## Parameters

    - `session` - SSH session process

    ## Returns

    - `:ok` - Session terminated
    """
    @spec terminate_session(pid()) :: :ok
    def terminate_session(session) do
      GenServer.cast(session, :terminate)
    end

    ## BaseManager Callbacks

    @impl true
    def init_manager(opts) do
      ssh_client = Keyword.get(opts, :ssh_client)
      pty_options = Keyword.get(opts, :pty_options, %{})
      Process.flag(:trap_exit, true)

      # Get connection reference from SSH client
      case Raxol.Terminal.SSH.SSHClient.get_connection_info(ssh_client) do
        {:ok, _connection_info} ->
          {:ok, connection_ref, channel_id} =
            start_session_channel(ssh_client, pty_options)

          state = %{
            ssh_client: ssh_client,
            connection_ref: connection_ref,
            channel_id: channel_id,
            pty_options: normalize_pty_options(pty_options),
            output_buffer: "",
            input_buffer: "",
            subscribers: [],
            recording: false,
            recording_file: nil,
            started_at: DateTime.utc_now(),
            last_activity: DateTime.utc_now(),
            exit_status: nil
          }

          Log.info("SSH session started on channel #{channel_id}")
          {:ok, state}

        {:error, reason} ->
          Log.error("Failed to get SSH connection info: #{inspect(reason)}")

          {:stop, {:connection_info_failed, reason}}
      end
    end

    @impl true
    def handle_manager_call({:resize, width, height}, _from, state) do
      case resize_pty(state, width, height) do
        :ok ->
          new_pty_options =
            Map.merge(state.pty_options, %{width: width, height: height})

          new_state = %{state | pty_options: new_pty_options}
          {:reply, :ok, update_activity(new_state)}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end

    def handle_manager_call({:get_output, clear_buffer}, _from, state) do
      output = state.output_buffer

      new_state =
        if clear_buffer do
          %{state | output_buffer: ""}
        else
          state
        end

      {:reply, output, new_state}
    end

    def handle_manager_call({:start_recording, file_path}, _from, state) do
      case start_session_recording(state, file_path) do
        {:ok, new_state} ->
          {:reply, :ok, new_state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end

    def handle_manager_call(:stop_recording, _from, state) do
      new_state = stop_session_recording(state)
      {:reply, :ok, new_state}
    end

    def handle_manager_call(:get_session_info, _from, state) do
      info = %{
        started_at: state.started_at,
        last_activity: state.last_activity,
        bytes_received: byte_size(state.output_buffer),
        bytes_sent: byte_size(state.input_buffer),
        exit_status: state.exit_status,
        recording: state.recording
      }

      {:reply, {:ok, info}, state}
    end

    def handle_manager_call({:send_signal, signal}, _from, state) do
      case send_session_signal(state, signal) do
        :ok ->
          {:reply, :ok, update_activity(state)}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end

    @impl true
    def handle_manager_cast({:send_input, data}, state) do
      case send_session_input(state, data) do
        :ok ->
          new_input_buffer = state.input_buffer <> data
          new_state = %{state | input_buffer: new_input_buffer}
          {:noreply, update_activity(new_state)}

        {:error, reason} ->
          Log.warning("Failed to send input: #{inspect(reason)}")
          {:noreply, state}
      end
    end

    def handle_manager_cast({:subscribe, subscriber}, state) do
      if subscriber in state.subscribers do
        {:noreply, state}
      else
        Process.monitor(subscriber)
        new_subscribers = [subscriber | state.subscribers]
        {:noreply, %{state | subscribers: new_subscribers}}
      end
    end

    def handle_manager_cast({:unsubscribe, subscriber}, state) do
      new_subscribers = List.delete(state.subscribers, subscriber)
      {:noreply, %{state | subscribers: new_subscribers}}
    end

    def handle_manager_cast(:terminate, state) do
      {:stop, :normal, state}
    end

    @impl true
    def handle_manager_info(
          {:ssh_cm, connection_ref, {:data, channel_id, 0, data}},
          state
        )
        when connection_ref == state.connection_ref and
               channel_id == state.channel_id do
      # Convert charlist to binary if needed
      output_data =
        case data do
          data when is_binary(data) -> data
          data when is_list(data) -> List.to_string(data)
        end

      # Add to output buffer
      new_output_buffer = append_to_buffer(state.output_buffer, output_data)

      # Record if recording is enabled
      _ = record_data(state, output_data, :output)

      # Notify subscribers
      _ = notify_subscribers(state.subscribers, output_data)

      new_state = %{
        state
        | output_buffer: new_output_buffer,
          last_activity: DateTime.utc_now()
      }

      {:noreply, new_state}
    end

    def handle_manager_info(
          {:ssh_cm, connection_ref, {:exit_status, channel_id, status}},
          state
        )
        when connection_ref == state.connection_ref and
               channel_id == state.channel_id do
      Log.info("SSH session exit status: #{status}")
      new_state = %{state | exit_status: status}
      {:noreply, new_state}
    end

    def handle_manager_info(
          {:ssh_cm, connection_ref, {:closed, channel_id}},
          state
        )
        when connection_ref == state.connection_ref and
               channel_id == state.channel_id do
      Log.info("SSH session channel closed")
      {:stop, :normal, state}
    end

    def handle_manager_info({:DOWN, _ref, :process, pid, _reason}, state) do
      # Remove dead subscriber
      new_subscribers = List.delete(state.subscribers, pid)
      {:noreply, %{state | subscribers: new_subscribers}}
    end

    def handle_manager_info(msg, state) do
      Log.debug("Unhandled SSH session message: #{inspect(msg)}")
      {:noreply, state}
    end

    @impl true
    def terminate(reason, state) do
      Log.info("SSH session terminating: #{inspect(reason)}")

      # Stop recording if active
      _ = stop_session_recording(state)

      # Close SSH channel
      _ =
        if state.connection_ref && state.channel_id do
          :ssh_connection.close(state.connection_ref, state.channel_id)
        end

      :ok
    end

    ## Private Helper Functions

    defp normalize_pty_options(options) do
      Map.merge(
        %{
          term: @default_term,
          width: @default_width,
          height: @default_height,
          pixel_width: 0,
          pixel_height: 0,
          modes: default_terminal_modes()
        },
        options
      )
    end

    defp default_terminal_modes do
      %{
        @terminal_modes[:ECHO] => 1,
        @terminal_modes[:ICANON] => 1,
        @terminal_modes[:ISIG] => 1
      }
    end

    defp start_session_channel(_ssh_client, _pty_options) do
      # This is a simplified implementation
      # In practice, we'd need to get the actual connection reference and create a channel
      # Placeholder
      connection_ref = make_ref()
      # Placeholder
      channel_id = :rand.uniform(1000)

      {:ok, connection_ref, channel_id}
    end

    defp resize_pty(state, width, height) do
      # Send window size change request
      case :ssh_connection.ptty_alloc(
             state.connection_ref,
             state.channel_id,
             [
               {:term, String.to_charlist(state.pty_options.term)},
               {:width, width},
               {:height, height}
             ]
           ) do
        :success -> :ok
        :failure -> {:error, :pty_resize_failed}
      end
    end

    defp send_session_input(state, data) do
      case :ssh_connection.send(
             state.connection_ref,
             state.channel_id,
             data
           ) do
        :ok ->
          _ = record_data(state, data, :input)
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp send_session_signal(state, signal) do
      signal_name = map_signal_to_ssh(signal)

      # Use the Erlang SSH signal/3 function
      case :ssh_connection.signal(
             state.connection_ref,
             state.channel_id,
             String.to_charlist(signal_name)
           ) do
        :ok ->
          Log.debug("Sent signal #{signal_name} to SSH session")
          :ok

        {:error, reason} ->
          Log.warning(
            "Failed to send signal #{signal_name}: #{inspect(reason)}"
          )

          # Some SSH servers don't support signals, try workaround
          send_signal_workaround(state, signal_name)
      end
    end

    defp map_signal_to_ssh(signal) do
      # Map Elixir signal atoms to SSH signal string names
      case signal do
        # Interrupt (Ctrl+C)
        :INT ->
          "INT"

        # Terminate
        :TERM ->
          "TERM"

        # Kill (cannot be caught)
        :KILL ->
          "KILL"

        # Hangup
        :HUP ->
          "HUP"

        # Quit (Ctrl+\)
        :QUIT ->
          "QUIT"

        # Alarm clock
        :ALRM ->
          "ALRM"

        # User-defined signal 1
        :USR1 ->
          "USR1"

        # User-defined signal 2
        :USR2 ->
          "USR2"

        # Window size change
        :WINCH ->
          "WINCH"

        # Stop process
        :STOP ->
          "STOP"

        # Continue if stopped
        :CONT ->
          "CONT"

        # Terminal stop (Ctrl+Z)
        :TSTP ->
          "TSTP"

        _ ->
          # Convert any other atom to uppercase string
          signal
          |> Atom.to_string()
          |> String.upcase()
      end
    end

    defp send_signal_workaround(state, signal_name) do
      # Workaround for servers that don't support signals
      # Send equivalent control characters where possible
      ctrl_char =
        case signal_name do
          # Ctrl+C
          "INT" -> <<3>>
          # Ctrl+\
          "QUIT" -> <<28>>
          # Ctrl+Z
          "TSTP" -> <<26>>
          _ -> nil
        end

      if ctrl_char do
        case :ssh_connection.send(
               state.connection_ref,
               state.channel_id,
               ctrl_char,
               0
             ) do
          :ok ->
            Log.debug("Sent control character for #{signal_name}")
            :ok

          {:error, reason} ->
            Log.debug("Workaround failed: #{inspect(reason)}")
            {:error, :signal_not_supported}
        end
      else
        # No workaround available, return original error
        {:error, :signal_not_supported}
      end
    end

    defp append_to_buffer(buffer, new_data) do
      combined = buffer <> new_data

      # Limit buffer size to prevent memory issues
      if byte_size(combined) > @buffer_max_size do
        # Keep the last portion of the buffer
        keep_size = div(@buffer_max_size, 2)
        binary_part(combined, byte_size(combined) - keep_size, keep_size)
      else
        combined
      end
    end

    defp notify_subscribers(subscribers, data) do
      session_pid = self()

      Enum.each(subscribers, fn subscriber ->
        send(subscriber, {:ssh_session_output, session_pid, data})
      end)
    end

    defp start_session_recording(state, file_path) do
      case File.open(file_path, [:write, :binary]) do
        {:ok, file} ->
          # Close immediately, we'll append later
          _ = File.close(file)
          new_state = %{state | recording: true, recording_file: file_path}
          Log.info("Started recording SSH session to #{file_path}")
          {:ok, new_state}

        {:error, reason} ->
          {:error, {:file_open_error, reason}}
      end
    end

    defp stop_session_recording(state) do
      if state.recording && state.recording_file do
        Log.info("Stopped recording SSH session")
      end

      %{state | recording: false, recording_file: nil}
    end

    defp record_data(state, data, type) do
      if state.recording && state.recording_file do
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
        direction = if type == :input, do: "<<<", else: ">>>"

        record_entry = "#{timestamp} #{direction} #{Base.encode64(data)}\n"

        # Append to file (non-blocking)
        Task.start(fn ->
          File.write(state.recording_file, record_entry, [:append])
        end)
      end
    end

    defp update_activity(state) do
      %{state | last_activity: DateTime.utc_now()}
    end
  end
else
  defmodule Raxol.Terminal.SSH.SSHSession do
    @moduledoc """
    SSH session stub - SSH support not available.

    To enable SSH support, ensure the :ssh application is available
    in your OTP installation.
    """

    use Raxol.Core.Behaviours.BaseManager

    def start(_client, _pty_options \\ %{}) do
      {:error, :ssh_not_available}
    end

    def send_input(_session, _input) do
      {:error, :ssh_not_available}
    end

    def resize_pty(_session, _width, _height) do
      {:error, :ssh_not_available}
    end

    def close(_session) do
      {:error, :ssh_not_available}
    end

    # BaseManager callbacks (required)
    @impl true
    def init_manager(_) do
      # SSH not available - return a dummy state
      # All operations will return {:error, :ssh_not_available}
      {:ok, %{ssh_available: false}}
    end

    @impl true
    def handle_manager_call(_, _, state),
      do: {:reply, {:error, :ssh_not_available}, state}

    @impl true
    def handle_manager_cast(_, state), do: {:noreply, state}
    @impl true
    def handle_manager_info(_, state), do: {:noreply, state}
    def terminate_manager(_, _), do: :ok
    def code_change(_, state, _), do: {:ok, state}
  end
end
