defmodule Raxol.Terminal.InputHandler do
  @moduledoc """
  Handles input processing for the terminal emulator.

  This module is responsible for processing input from stdin and other sources,
  managing the input buffer, and handling special keys and combinations.

  Note: When running in certain environments, stdin may be excluded from Credo analysis
  due to how it's processed. This is expected behavior and doesn't affect functionality.
  """

  alias Raxol.Terminal.Clipboard
  # alias Raxol.Terminal.SpecialKeys # Unused
  # alias Raxol.Core.Events.Event # Unused

  @type t :: %__MODULE__{
          buffer: String.t(),
          cursor_position: non_neg_integer(),
          clipboard: Clipboard.t(),
          tab_completion: map(),
          tab_completion_index: non_neg_integer(),
          tab_completion_matches: list(String.t())
        }

  defstruct [
    :buffer,
    :cursor_position,
    :clipboard,
    :tab_completion,
    :tab_completion_index,
    :tab_completion_matches
  ]

  @doc """
  Creates a new input handler with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      buffer: "",
      cursor_position: 0,
      clipboard: Clipboard.new(),
      tab_completion: %{},
      tab_completion_index: 0,
      tab_completion_matches: []
    }
  end

  @doc """
  Handles clipboard paste operation.
  """
  @spec handle_paste(t()) :: {:ok, t()} | {:error, String.t()}
  def handle_paste(%__MODULE__{} = handler) do
    case Clipboard.paste(handler.clipboard) do
      {:ok, text, new_clipboard} ->
        new_buffer = insert_text(handler.buffer, handler.cursor_position, text)
        new_position = handler.cursor_position + String.length(text)

        {:ok,
         %{
           handler
           | buffer: new_buffer,
             cursor_position: new_position,
             clipboard: new_clipboard
         }}

      error ->
        error
    end
  end

  @doc """
  Handles clipboard copy operation.
  """
  @spec handle_copy(t()) :: {:ok, t()} | {:error, String.t()}
  def handle_copy(%__MODULE__{} = handler) do
    case Clipboard.copy(handler.clipboard, handler.buffer) do
      {:ok, new_clipboard} ->
        {:ok, %{handler | clipboard: new_clipboard}}

      error ->
        error
    end
  end

  @doc """
  Handles clipboard cut operation.
  """
  @spec handle_cut(t()) :: {:ok, t()} | {:error, String.t()}
  def handle_cut(%__MODULE__{} = handler) do
    with {:ok, new_clipboard} <-
           Clipboard.copy(handler.clipboard, handler.buffer),
         new_buffer = "",
         new_position = 0 do
      {:ok,
       %{
         handler
         | buffer: new_buffer,
           cursor_position: new_position,
           clipboard: new_clipboard
       }}
    end
  end

  @doc """
  Inserts text at the specified position in the buffer.
  """
  @spec insert_text(String.t(), non_neg_integer(), String.t()) :: String.t()
  def insert_text(buffer, position, text) do
    before_text = String.slice(buffer, 0, position)
    after_text = String.slice(buffer, position..-1//1)
    before_text <> text <> after_text
  end
end
