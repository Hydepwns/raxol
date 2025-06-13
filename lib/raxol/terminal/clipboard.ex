defmodule Raxol.Terminal.Clipboard do
  @moduledoc """
  Provides a high-level interface for clipboard operations.
  """

  alias Raxol.Terminal.Clipboard.Manager

  @doc """
  Copies content to the clipboard.
  """
  @spec copy(String.t(), String.t()) :: :ok
  def copy(content, format \\ "text") do
    Manager.copy(content, format)
  end

  @doc """
  Pastes content from the clipboard.
  """
  @spec paste(String.t()) :: {:ok, String.t()} | {:error, :empty_clipboard}
  def paste(format \\ "text") do
    Manager.paste(format)
  end

  @doc """
  Clears the clipboard.
  """
  @spec clear() :: :ok
  def clear do
    Manager.clear()
  end
end
