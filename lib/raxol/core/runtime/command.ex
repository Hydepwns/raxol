defmodule Raxol.Core.Runtime.Command do
  @moduledoc """
  Provides a way to handle side effects in a pure functional way.

  Commands are used to describe side effects that should be performed by the
  runtime system. This keeps the application's update function pure while still
  allowing necessary side effects to occur.

  ## Types of Commands

  * `:none` - No side effect
  * `:task` - Asynchronous task that will send a message when complete
  * `:batch` - Multiple commands to be executed in sequence
  * `:delay` - Delayed message delivery
  * `:broadcast` - Send a message to all components
  * `:system` - System-level operations (file, network, etc.)
  * `:quit` - Signals the runtime to quit
  * `:clipboard_write` - Write text to the system clipboard
  * `:clipboard_read` - Request text from the system clipboard (will result in a message)
  * `:notify` - Send a system notification

  ## Examples

      # No side effect
      Command.none()

      # Run an async task
      Command.task(fn ->
        # Do something expensive
        result = expensive_operation()
        {:operation_complete, result}
      end)

      # Multiple commands
      Command.batch([
        Command.task(fn -> {:fetch_data, api_call()} end),
        Command.delay(:refresh, 1000)
      ])

      # Delayed message
      Command.delay(:timeout, 5000)

      # Broadcast to all components
      Command.broadcast(:data_updated)

      # System operation
      Command.system(:file_write, path: "data.txt", content: "Hello")

      # Signal the runtime to quit
      Command.quit()

      # Write to clipboard
      Command.clipboard_write("Copied text")

      # Read from clipboard (expects a {:clipboard_content, text} message later)
      Command.clipboard_read()

      # Send notification
      Command.notify("Task Complete", "Your background job finished.")
  """

  require Raxol.Core.Runtime.Log

  @type t :: %__MODULE__{
          type:
            :none
            | :task
            | :batch
            | :delay
            | :broadcast
            | :system
            | :quit
            | :clipboard_write
            | :clipboard_read
            | :notify,
          data: term()
        }

  defstruct [:type, :data]

  @doc """
  Creates a new command. This is the low-level constructor, prefer using
  the specific command constructors unless you need custom behavior.
  """
  def new(type, data \\ nil) do
    %__MODULE__{type: type, data: data}
  end

  @doc """
  Returns a command that does nothing.
  """
  def none, do: new(:none)

  @doc """
  Creates a command that will execute the given function asynchronously.
  The function should return a message that will be sent back to the update
  function when the task completes.
  """
  def task(fun) when is_function(fun, 0) do
    new(:task, fun)
  end

  @doc """
  Creates a command that will execute multiple commands in sequence.
  """
  def batch(commands) when is_list(commands) do
    new(:batch, commands)
  end

  @doc """
  Creates a command that will send a message after the specified delay
  in milliseconds.
  """
  def delay(msg, delay_ms) when is_integer(delay_ms) and delay_ms >= 0 do
    new(:delay, {msg, delay_ms})
  end

  @doc """
  Creates a command that will broadcast a message to all components.
  """
  def broadcast(msg) do
    new(:broadcast, msg)
  end

  @doc """
  Creates a command for system-level operations like file I/O or network
  requests. The operation type and options specify what should be done.
  """
  def system(operation, opts \\ []) do
    new(:system, {operation, opts})
  end

  @doc """
  Returns a command that signals the runtime to quit.
  """
  def quit, do: new(:quit)

  @doc """
  Creates a command to write text to the system clipboard.
  """
  def clipboard_write(text) when is_binary(text) do
    new(:clipboard_write, text)
  end

  @doc """
  Creates a command to read text from the system clipboard.
  This will eventually result in a `{:command_result, {:clipboard_content, content}}`
  message being sent back to the application's update function.
  """
  def clipboard_read do
    new(:clipboard_read)
  end

  @doc """
  Creates a command to send a system notification.
  """
  def notify(title, body) when is_binary(title) and is_binary(body) do
    new(:notify, {title, body})
  end

  @doc """
  Maps a function over a command's result message. This is useful for
  namespacing messages or transforming them before they reach the update
  function.

  ## Example

      # Transform the task's result message
      Command.task(fn -> {:data, fetch_data()} end)
      |> Command.map(fn {:data, result} -> {:processed_data, process(result)} end)
  """
  def map(%__MODULE__{type: :task, data: fun} = cmd, mapper)
      when is_function(mapper, 1) do
    mapped_fun = fn ->
      fun.() |> mapper.()
    end

    %{cmd | data: mapped_fun}
  end

  def map(%__MODULE__{type: :batch, data: commands} = cmd, mapper) do
    mapped_commands = Enum.map(commands, &map(&1, mapper))
    %{cmd | data: mapped_commands}
  end

  def map(%__MODULE__{type: :delay, data: {msg, delay}} = cmd, mapper) do
    %{cmd | data: {mapper.(msg), delay}}
  end

  def map(%__MODULE__{type: :broadcast, data: msg} = cmd, mapper) do
    %{cmd | data: mapper.(msg)}
  end

  def map(cmd, _), do: cmd

  @doc """
  Executes a command within the given context. This is used by the runtime
  system and should not be called directly by applications.
  """
  def execute(%__MODULE__{} = command, context) do
    Raxol.Core.Runtime.Log.debug(
      "[Command.execute] Executing command: #{inspect(command)} with context: #{inspect(context)}"
    )

    execute_command_type(command.type, command.data, context)
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:none, _data, _context), do: :ok

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:task, fun, context) do
    Task.start(fn ->
      result = fun.()
      send(context.pid, {:command_result, result})
    end)
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:batch, commands, context) do
    Enum.each(commands, &execute(&1, context))
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:delay, {msg, delay}, context) do
    Process.send_after(context.pid, {:command_result, msg}, delay)
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:broadcast, msg, _context) do
    Raxol.Core.Runtime.Events.Dispatcher.broadcast(:broadcast_event, msg)
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:system, {operation, opts}, context) do
    execute_system_operation(operation, opts, context)
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:quit, _data, context) do
    Raxol.Core.Runtime.Log.debug(
      "[Command.execute] Matched :quit. Sending :quit_runtime to #{inspect(context.runtime_pid)}"
    )

    send(context.runtime_pid, :quit_runtime)
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:clipboard_write, text, context) do
    GenServer.cast(
      Raxol.Core.Plugins.Core.ClipboardPlugin,
      {:handle_command, :clipboard_write,
       Raxol.Core.Plugins.Core.ClipboardPlugin, [text], context.pid}
    )
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:clipboard_read, _data, context) do
    GenServer.cast(
      Raxol.Core.Plugins.Core.ClipboardPlugin,
      {:handle_command, :clipboard_read,
       Raxol.Core.Plugins.Core.ClipboardPlugin, [], context.pid}
    )
  end

  @spec execute_command_type(any(), any(), any()) :: any()
  defp execute_command_type(:notify, {title, body}, context) do
    GenServer.cast(
      Raxol.Core.Plugins.Core.NotificationPlugin,
      {:handle_command, :notify, Raxol.Core.Plugins.Core.NotificationPlugin,
       [title, body], context.pid}
    )
  end

  # Private helper for system operations
  @spec execute_system_operation(any(), keyword(), any()) :: any()
  defp execute_system_operation(operation, opts, context) do
    case operation do
      :file_write ->
        case File.write(opts[:path], opts[:content]) do
          :ok ->
            send(context.pid, {:command_result, {:file_write, :ok}})

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "System command file_write failed",
              reason,
              nil,
              %{operation: :file_write, opts: opts, context: context}
            )

            send(context.pid, {:command_result, {:file_write_error, reason}})
        end

      :file_read ->
        case File.read(opts[:path]) do
          {:ok, content} ->
            send(context.pid, {:command_result, {:file_read, content}})

          {:error, reason} ->
            send(context.pid, {:command_result, {:file_read_error, reason}})
        end

      # Add more system operations as needed
      _ ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Unhandled system operation",
          operation,
          nil,
          %{operation: operation, opts: opts, context: context}
        )
    end
  end
end
