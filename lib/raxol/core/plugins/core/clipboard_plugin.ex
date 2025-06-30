defmodule Raxol.Core.Plugins.Core.ClipboardPlugin do
  import Raxol.Guards

  @moduledoc """
  Provides clipboard read/write commands and delegates to a configured system clipboard implementation.
  """

  @behaviour Raxol.Core.Plugins.Core.ClipboardPluginBehaviour

  @impl true
  def init(opts) do
    # Use the configured clipboard implementation or default to Raxol.System.Clipboard
    clipboard_impl = Keyword.get(opts, :clipboard_impl, Raxol.System.Clipboard)
    {:ok, %{clipboard_impl: clipboard_impl}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  @impl true
  def get_commands do
    [
      {:clipboard_write, :handle_clipboard_command, 2},
      {:clipboard_read, :handle_clipboard_command, 1}
    ]
  end

  @impl true
  def handle_command(
        :clipboard_write,
        [content],
        %{clipboard_impl: clipboard_impl} = state
      )
      when binary?(content) do
    case clipboard_impl.copy(content) do
      :ok ->
        {:ok, "Content copied to clipboard"}

      {:error, reason} ->
        {:error, "Failed to write to clipboard: #{inspect(reason)}"}
    end
  end

  def handle_command(
        :clipboard_read,
        [],
        %{clipboard_impl: clipboard_impl} = state
      ) do
    case clipboard_impl.paste() do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error, "Failed to read from clipboard: #{inspect(reason)}"}
    end
  end

  def handle_command(:clipboard_write, _args, state) do
    {:error, "Invalid arguments for clipboard_write command"}
  end

  def handle_command(:clipboard_read, _args, state) do
    {:error, "Invalid arguments for clipboard_read command"}
  end

  @doc """
  Handles clipboard commands with a simplified interface.
  """
  @spec handle_clipboard_command(list(), map()) ::
          {:ok, map(), any()} | {:error, any(), map()}
  def handle_clipboard_command([content], state) when binary?(content) do
    # Handle clipboard_write with content
    handle_command(:clipboard_write, [content], state)
  end

  def handle_clipboard_command(_args, state) do
    {:error, :unhandled_clipboard_command, state}
  end

  @doc """
  Handles clipboard read command (arity 1 - just state).
  """
  @spec handle_clipboard_command(map()) ::
          {:ok, map(), any()} | {:error, any(), map()}
  def handle_clipboard_command(state) do
    # Handle clipboard_read with no content
    handle_command(:clipboard_read, [], state)
  end

  @doc """
  Enables the clipboard plugin.
  """
  @spec enable(map()) :: {:ok, map()}
  def enable(state) do
    {:ok, state}
  end

  @doc """
  Disables the clipboard plugin.
  """
  @spec disable(map()) :: {:ok, map()}
  def disable(state) do
    {:ok, state}
  end

  @doc """
  Filters events for the clipboard plugin.
  """
  @spec filter_event(any(), map()) :: {:ok, any(), map()}
  def filter_event(event, state) do
    {:ok, event, state}
  end
end
