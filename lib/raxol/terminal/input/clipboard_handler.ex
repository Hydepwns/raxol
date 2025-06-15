defmodule Raxol.Terminal.Input.ClipboardHandler do
  @moduledoc """
  Handles clipboard operations for the terminal emulator.
  """

  alias Raxol.System.Clipboard
  alias Raxol.Terminal.Input.CoreHandler

  @doc """
  Handles clipboard paste operation.
  """
  @spec handle_paste(CoreHandler.t()) ::
          {:ok, CoreHandler.t()} | {:error, any()}
  def handle_paste(%CoreHandler{} = handler) do
    case Clipboard.paste() do
      {:ok, text} ->
        new_buffer =
          CoreHandler.insert_text(handler.buffer, handler.cursor_position, text)

        new_position = handler.cursor_position + String.length(text)
        {:ok, %{handler | buffer: new_buffer, cursor_position: new_position}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard copy operation.
  (Currently copies the entire buffer)
  """
  @spec handle_copy(CoreHandler.t()) :: {:ok, CoreHandler.t()} | {:error, any()}
  def handle_copy(%CoreHandler{} = handler) do
    case Clipboard.copy(handler.buffer) do
      :ok ->
        {:ok, handler}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard cut operation.
  (Currently cuts the entire buffer)
  """
  @spec handle_cut(CoreHandler.t()) :: {:ok, CoreHandler.t()} | {:error, any()}
  def handle_cut(%CoreHandler{} = handler) do
    case Clipboard.copy(handler.buffer) do
      :ok ->
        {:ok,
         %{
           handler
           | buffer: "",
             cursor_position: 0
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
