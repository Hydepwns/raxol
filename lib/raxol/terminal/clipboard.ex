defmodule Raxol.Terminal.Clipboard do
  @moduledoc """
  Handles clipboard operations for the terminal emulator.

  This module provides functionality for:
  - Copying text to the system clipboard
  - Pasting text from the system clipboard
  - Managing clipboard history
  """

  @type t :: %__MODULE__{
          history: list(String.t()),
          history_limit: non_neg_integer(),
          enabled: boolean()
        }

  defstruct [
    :history,
    :history_limit,
    :enabled
  ]

  @doc """
  Creates a new clipboard manager with default values.
  """
  @spec new(non_neg_integer()) :: t()
  def new(history_limit \\ 100) do
    %__MODULE__{
      history: [],
      history_limit: history_limit,
      enabled: true
    }
  end

  @doc """
  Copies text to the system clipboard and adds it to the history.
  """
  @spec copy(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def copy(%__MODULE__{} = clipboard, text) when is_binary(text) do
    if clipboard.enabled do
      case set_system_clipboard(text) do
        :ok ->
          new_history =
            [text | clipboard.history]
            |> Enum.take(clipboard.history_limit)

          {:ok, %{clipboard | history: new_history}}

        error ->
          error
      end
    else
      {:ok, clipboard}
    end
  end

  @doc """
  Retrieves text from the system clipboard.
  """
  @spec paste(t()) :: {:ok, String.t(), t()} | {:error, String.t()}
  def paste(%__MODULE__{} = clipboard) do
    if clipboard.enabled do
      case get_system_clipboard() do
        {:ok, text} ->
          {:ok, text, clipboard}

        error ->
          error
      end
    else
      {:error, "Clipboard is disabled"}
    end
  end

  @doc """
  Gets the clipboard history.
  """
  @spec get_history(t()) :: list(String.t())
  def get_history(%__MODULE__{} = clipboard) do
    clipboard.history
  end

  @doc """
  Clears the clipboard history.
  """
  @spec clear_history(t()) :: t()
  def clear_history(%__MODULE__{} = clipboard) do
    %{clipboard | history: []}
  end

  @doc """
  Enables or disables clipboard operations.
  """
  @spec set_enabled(t(), boolean()) :: t()
  def set_enabled(%__MODULE__{} = clipboard, enabled)
      when is_boolean(enabled) do
    %{clipboard | enabled: enabled}
  end

  @doc """
  Checks if clipboard operations are enabled.
  """
  @spec enabled?(t()) :: boolean()
  def enabled?(%__MODULE__{} = clipboard) do
    clipboard.enabled
  end

  # Private functions

  defp set_system_clipboard(text) do
    case :os.type() do
      {:unix, :darwin} ->
        case System.cmd("pbcopy", [], input: text) do
          {_, 0} -> :ok
          {error, _} -> {:error, "Failed to copy to clipboard: #{error}"}
        end

      {:unix, _} ->
        case System.cmd("xclip", ["-selection", "clipboard"], input: text) do
          {_, 0} -> :ok
          {error, _} -> {:error, "Failed to copy to clipboard: #{error}"}
        end

      {:win32, _} ->
        case System.cmd("clip", [], input: text) do
          {_, 0} -> :ok
          {error, _} -> {:error, "Failed to copy to clipboard: #{error}"}
        end
    end
  end

  defp get_system_clipboard do
    case :os.type() do
      {:unix, :darwin} ->
        case System.cmd("pbpaste", []) do
          {output, 0} -> {:ok, output}
          {error, _} -> {:error, "Failed to paste from clipboard: #{error}"}
        end

      {:unix, _} ->
        case System.cmd("xclip", ["-selection", "clipboard", "-o"]) do
          {output, 0} -> {:ok, output}
          {error, _} -> {:error, "Failed to paste from clipboard: #{error}"}
        end

      {:win32, _} ->
        # Windows doesn't have a direct paste command, so we can't implement this
        {:error, "Paste from clipboard not supported on Windows"}
    end
  end
end
