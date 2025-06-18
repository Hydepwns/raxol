defmodule Raxol.Terminal.ClipboardBehaviour do
  @moduledoc """
  Defines the behaviour for clipboard operations in the terminal.

  This behaviour specifies the callbacks that must be implemented by any module
  that wants to handle clipboard operations in the terminal emulator.
  """

  @doc """
  Gets the current content of the clipboard.

  Returns `{:ok, content}` on success, or `{:error, reason}` on failure.
  """
  @callback get_content(clipboard :: term()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Sets the content of the clipboard.

  Returns `{:ok, updated_clipboard}` on success, or `{:error, reason}` on failure.
  """
  @callback set_content(clipboard :: term(), content :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Gets the current selection content.

  Returns `{:ok, content}` on success, or `{:error, reason}` on failure.
  """
  @callback get_selection(clipboard :: term()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Sets the selection content.

  Returns `{:ok, updated_clipboard}` on success, or `{:error, reason}` on failure.
  """
  @callback set_selection(clipboard :: term(), content :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Clears the clipboard content.

  Returns `{:ok, updated_clipboard}` on success, or `{:error, reason}` on failure.
  """
  @callback clear(clipboard :: term()) :: {:ok, term()} | {:error, term()}
end
