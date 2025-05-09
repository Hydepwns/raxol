defmodule Raxol.Core.Plugins.Core.ClipboardPlugin do
  @moduledoc """
  Core plugin providing clipboard read/write commands.
  Delegates to the configured system clipboard implementation.
  """

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  # Define default state and expected options
  # Default to real implementation
  defstruct clipboard_impl: Raxol.System.Clipboard

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(plugin_config) do
    # Allow overriding the clipboard implementation for testing
    # TRY AVOIDING Keyword.get to see if it's the source of the FunctionClauseError
    clipboard_impl_from_config = Keyword.get(plugin_config, :clipboard_impl)

    clipboard_impl =
      if clipboard_impl_from_config,
        do: clipboard_impl_from_config,
        else: Raxol.System.Clipboard

    state = %__MODULE__{
      clipboard_impl: clipboard_impl
    }

    Logger.info("Clipboard Plugin initialized.")
    {:ok, state}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def get_commands() do
    [
      # Command name (atom), Function name (atom from Plugin behaviour), Arity of args list for that command
      # This command will pass a list with 1 arg to handle_command/3
      {:clipboard_write, :handle_command, 1},
      # This command will pass an empty list to handle_command/3
      {:clipboard_read, :handle_command, 0}
    ]
  end

  # NEW: Implement the single handle_command/3 as required by the Plugin behaviour
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(:clipboard_write, [content], state)
      when is_binary(content) do
    Logger.debug(
      "ClipboardPlugin: Writing to clipboard via #{inspect(state.clipboard_impl)}..."
    )

    # Call the configured implementation
    case state.clipboard_impl.copy(content) do
      :ok ->
        {:ok, state, {:ok, :clipboard_write_ok}}

      {:error, reason} ->
        Logger.error(
          "ClipboardPlugin: Failed to write to clipboard: #{inspect(reason)}"
        )

        {:error, {:clipboard_write_failed, reason}, state}
    end
  end

  # Arity 0 means args is []
  def handle_command(:clipboard_read, [], state) do
    Logger.debug(
      "[ClipboardPlugin] Reading from clipboard via #{inspect(state.clipboard_impl)}..."
    )

    # Call the configured implementation
    case state.clipboard_impl.paste() do
      {:ok, content} ->
        {:ok, state, {:ok, content}}

      {:error, reason} ->
        Logger.error(
          "[ClipboardPlugin] Failed to read from clipboard: #{inspect(reason)}"
        )

        {:error, {:clipboard_read_failed, reason}, state}
    end
  end

  # Catch-all for unknown commands or mismatched arities handled by this plugin's handle_command/3
  def handle_command(command_name, args, state) do
    Logger.warning(
      "ClipboardPlugin received unexpected command '#{command_name}' with args: #{inspect(args)}"
    )

    {:error, {:unknown_plugin_command, command_name, args}, state}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def terminate(_reason, _state) do
    Logger.info("Clipboard Plugin terminated (Behaviour callback).")
    :ok
  end

  # Add default implementations for optional callbacks
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def enable(state), do: {:ok, state}

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def disable(state), do: {:ok, state}

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def filter_event(event, state), do: {:ok, event, state}
end
