defmodule Raxol.Core.Plugins.Core.ClipboardPlugin do
  @moduledoc """
  Core plugin responsible for handling clipboard operations (:clipboard_write, :clipboard_read).
  """

  require Logger

  @behaviour Raxol.Core.Runtime.Plugins.Plugin

  @impl Raxol.Core.Runtime.Plugins.Plugin
  def init(_config) do
    Logger.info("Clipboard Plugin initialized.")
    # No specific state needed for now
    {:ok, %{}}
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

  @impl Raxol.Core.Runtime.Plugins.Plugin
  # Consolidate command handling into one function as per behaviour best practice
  def handle_command(command_name, args, state) do
    handle_clipboard_command(command_name, args, state)
  end

  # Central internal handler
  defp handle_clipboard_command(:clipboard_write, [content], state) when is_binary(content) do
    Logger.debug("ClipboardPlugin: Writing to clipboard...")
    case Clipboard.copy(content) do
      :ok ->
        {:ok, state, :clipboard_write_ok} # Return simple success atom
      {:error, reason} ->
        Logger.error("ClipboardPlugin: Failed to write to clipboard: #{inspect(reason)}")
        {:error, {:clipboard_write_failed, reason}, state}
    end
  end

  defp handle_clipboard_command(:clipboard_read, [], state) do
    Logger.debug("ClipboardPlugin: Reading from clipboard...")
    case Clipboard.paste() do
      {:ok, content} ->
         {:ok, state, {:clipboard_content, content}} # Return content tuple
      {:error, reason} ->
         Logger.error("ClipboardPlugin: Failed to read from clipboard: #{inspect(reason)}")
        {:error, {:clipboard_read_failed, reason}, state}
    end
  end

  # Catch-all for incorrect args or unknown commands directed here
  defp handle_clipboard_command(command, args, state) do
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
