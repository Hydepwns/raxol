defmodule Raxol.StdioInterface do
  @moduledoc """
  Handles JSON communication over stdio for integration with external tools like VS Code extensions.

  Reads JSON messages from stdin, decodes them, and forwards them to the target process (Runtime).
  Receives messages from the target process, encodes them to JSON, and writes them to stdout.
  """
  use GenServer
  require Logger

  # Make sure Jason is added to deps
  alias Jason

  @type target_pid :: pid()
  @type state :: %{target_pid: target_pid()}

  # --- Client API ---

  @spec start_link(target_pid :: target_pid()) :: GenServer.on_start()
  def start_link(target_pid) when is_pid(target_pid) do
    GenServer.start_link(__MODULE__, target_pid, name: __MODULE__)
  end

  @doc """
  Sends a message to be encoded as JSON and written to stdout.
  """
  @spec send_message(message :: map()) :: :ok | {:error, any()}
  def send_message(message) when is_map(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end

  @doc """
  Sends a log message to the extension with proper JSON formatting.
  This prevents raw log messages from being interpreted as JSON by the extension.
  """
  @spec send_log(level :: atom(), message :: String.t()) ::
          :ok | {:error, any()}
  def send_log(level, message)
      when level in [:debug, :info, :warning, :error] and is_binary(message) do
    log_message = %{
      type: "log",
      payload: %{
        level: Atom.to_string(level),
        message: message
      }
    }

    send_message(log_message)
  end

  @doc """
  Sends a UI update message to the extension with changes to render.
  """
  @spec send_ui_update(update :: map()) :: :ok | {:error, any()}
  def send_ui_update(update) when is_map(update) do
    ui_message = %{
      type: "ui_update",
      payload: update
    }

    send_message(ui_message)
  end

  # --- Server Callbacks ---

  @impl true
  def init(target_pid) do
    Logger.info("[StdioInterface] Initializing...")

    # Add error handling for stdin reading
    spawn_link(fn ->
      try do
        read_stdin_loop(self())
      catch
        kind, reason ->
          Logger.error(
            "[StdioInterface] Error in stdin reader: #{inspect(kind)}, #{inspect(reason)}"
          )

          Process.exit(self(), {:stdin_reader_error, reason})
      end
    end)

    Logger.info("[StdioInterface] Stdin reader task started.")
    {:ok, %{target_pid: target_pid}}
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    Logger.debug(
      "[StdioInterface] Received message to send: #{inspect(message)}"
    )

    # Make sure message has the right shape (type and payload)
    message =
      if Map.has_key?(message, :type) and Map.has_key?(message, :payload) do
        message
      else
        # Convert any non-standard message to a structured format
        %{
          type: Map.get(message, :type, "unknown"),
          payload: Map.get(message, :payload, message)
        }
      end

    # Convert any atom keys to strings before encoding
    message_with_string_keys = stringify_keys(message)

    # Encode the message to JSON and write to stdout with a newline delimiter
    case Jason.encode(message_with_string_keys) do
      {:ok, json_string} ->
        # Add a marker to help the extension identify JSON messages
        marked_json = "RAXOL-JSON-BEGIN#{json_string}RAXOL-JSON-END\n"
        IO.write(:stdio, marked_json)
        Logger.debug("[StdioInterface] Wrote message to stdout: #{json_string}")

      {:error, reason} ->
        Logger.error(
          "[StdioInterface] Failed to encode message to JSON: #{inspect(reason)}. Message: #{inspect(message)}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:stdin_line, line}, state) do
    # Check for JSON marker (if extension has been updated to use them)
    line = String.trim(line)

    Logger.debug("[StdioInterface] Received line from stdin: #{inspect(line)}")

    # Skip empty lines
    if String.length(line) == 0 do
      {:noreply, state}
    else
      # Attempt to decode the JSON line
      case Jason.decode(line) do
        {:ok, decoded_message} when is_map(decoded_message) ->
          Logger.debug(
            "[StdioInterface] Decoded message: #{inspect(decoded_message)}"
          )

          # Basic validation (expecting 'type' and 'payload')
          if Map.has_key?(decoded_message, "type") and
               Map.has_key?(decoded_message, "payload") do
            # Convert keys to atoms for easier handling in Elixir
            message_with_atom_keys = %{
              type: String.to_atom(decoded_message["type"]),
              payload: decoded_message["payload"]
            }

            Logger.debug(
              "[StdioInterface] Forwarding message to target: #{inspect(message_with_atom_keys)}"
            )

            # Forward the decoded message to the target process (Runtime)
            GenServer.cast(
              state.target_pid,
              {:stdio_message, message_with_atom_keys}
            )
          else
            Logger.warning(
              "[StdioInterface] Received invalid message format (missing type/payload): #{inspect(decoded_message)}"
            )
          end

        {:error, reason} ->
          Logger.warning(
            "[StdioInterface] Failed to decode JSON from stdin: #{inspect(reason)}. Line: #{inspect(line)}"
          )

        # This is likely just logging output from another source, so don't treat it as an error

        _other ->
          Logger.warning(
            "[StdioInterface] Received non-map JSON from stdin: #{inspect(line)}"
          )
      end

      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:stdin_closed}, state) do
    Logger.info("[StdioInterface] Stdin stream closed.")
    # Notify the target process that stdin closed
    GenServer.cast(state.target_pid, {:stdio_closed})
    {:noreply, state}
  end

  # --- Private Helper Functions ---

  # Reads lines from stdin and sends them to the GenServer process
  defp read_stdin_loop(server_pid) do
    IO.stream(:stdio, :line)
    |> Stream.each(fn line ->
      send(server_pid, {:stdin_line, line})
    end)
    # Consume the stream
    |> Stream.run()

    # Send a message indicating stdin closed when the stream ends
    send(server_pid, {:stdin_closed})
    Logger.info("[StdioInterface] read_stdin_loop finished.")
  rescue
    e ->
      Logger.error(
        "[StdioInterface] Error in read_stdin_loop: #{inspect(e)}\n#{inspect(System.stacktrace())}"
      )

      send(server_pid, {:stdin_error, e})
  end

  # Recursively convert map keys from atoms to strings
  defp stringify_keys(term) when is_map(term) do
    term
    |> Enum.map(fn {k, v} -> {to_string(k), stringify_keys(v)} end)
    |> Enum.into(%{})
  end

  defp stringify_keys(term) when is_list(term) do
    Enum.map(term, &stringify_keys/1)
  end

  defp stringify_keys(term), do: term
end
