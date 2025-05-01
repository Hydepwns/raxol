defmodule Raxol.Core.Plugins.Core.ClipboardPlugin do
  @moduledoc """
  Core plugin providing clipboard read/write commands.
  Delegates to the configured system clipboard implementation.
  """

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  require Logger

  # Define default state and expected options
  defstruct clipboard_impl: Raxol.System.Clipboard # Default to real implementation

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(opts) do
    # Allow overriding the clipboard implementation for testing
    clipboard_impl = Keyword.get(opts, :clipboard_impl, Raxol.System.Clipboard)
    state = %__MODULE__{
      clipboard_impl: clipboard_impl
    }
    Logger.info("Clipboard Plugin initialized.")
    {:ok, state}
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def get_commands() do
    [
      # Command name (atom), Function name (atom), Arity
      # CommandHelper will call Module.function(args, state)
      {:clipboard_write, :handle_clipboard_command, 2},
      {:clipboard_read, :handle_clipboard_command, 1}
    ]
  end

  # Specific clauses are now the primary implementation

  # Central internal handler for :clipboard_write
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(:clipboard_write, [content], state) when is_binary(content) do
    Logger.debug("ClipboardPlugin: Writing to clipboard via #{inspect(state.clipboard_impl)}...")
    # Call the configured implementation
    case state.clipboard_impl.copy(content) do
      :ok ->
        {:ok, state, :clipboard_write_ok} # Return simple success atom
      {:error, reason} ->
        Logger.error("ClipboardPlugin: Failed to write to clipboard: #{inspect(reason)}")
        {:error, {:clipboard_write_failed, reason}, state}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(:clipboard_read, [], state) do
    Logger.debug("ClipboardPlugin: Reading from clipboard via #{inspect(state.clipboard_impl)}...")
    # Call the configured implementation
    case state.clipboard_impl.paste() do
      {:ok, content} ->
         {:ok, state, {:clipboard_content, content}} # Return content tuple
      {:error, reason} ->
         Logger.error("ClipboardPlugin: Failed to read from clipboard: #{inspect(reason)}")
        {:error, {:clipboard_read_failed, reason}, state}
    end
  end

  # Add back the catch-all clause for handle_command
  @impl Raxol.Core.Runtime.Plugins.Plugin
  def handle_command(command, args, state) do
    Logger.warning("ClipboardPlugin received unhandled/invalid command: #{inspect command} with args: #{inspect args}")
    {:error, :unhandled_clipboard_command, state}
  end

  def terminate(_state) do
    Logger.info("Clipboard Plugin terminated.")
    :ok
  end

  # Add terminate/2 implementation matching the behaviour
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

  # Remove the helper function comment block as it's no longer relevant here
  # --- Helper for Manager ---
  # ...
end
