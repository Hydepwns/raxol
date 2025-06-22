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
      :clipboard_write,
      :clipboard_read
    ]
  end

  @impl true
  def handle_command(
        :clipboard_write,
        [content],
        %{clipboard_impl: clipboard_impl} = _state
      )
      when binary?(content) do
    case clipboard_impl.copy(content) do
      :ok ->
        {:ok, "Content copied to clipboard"}

      {:error, reason} ->
        {:error, "Failed to copy to clipboard: #{inspect(reason)}"}
    end
  end

  def handle_command(
        :clipboard_read,
        [],
        %{clipboard_impl: clipboard_impl} = _state
      ) do
    case clipboard_impl.paste() do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error, "Failed to read from clipboard: #{inspect(reason)}"}
    end
  end

  def handle_command(:clipboard_write, _args, _state) do
    {:error, "Invalid arguments for clipboard_write command"}
  end

  def handle_command(:clipboard_read, _args, _state) do
    {:error, "Invalid arguments for clipboard_read command"}
  end

  @doc """
  Handles clipboard commands with a simplified interface.
  """
  @spec handle_clipboard_command(atom(), map()) :: {:ok, any()} | {:error, String.t()}
  def handle_clipboard_command(command, state) when command in [:clipboard_write, :clipboard_read] do
    case command do
      :clipboard_write ->
        handle_command(:clipboard_write, [""], state)

      :clipboard_read ->
        handle_command(:clipboard_read, [], state)
    end
  end

  def handle_clipboard_command(_command, _state) do
    {:error, "Unknown clipboard command"}
  end
end
