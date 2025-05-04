defmodule Raxol.Terminal.InputHandler do
  @moduledoc """
  Handles input processing for the terminal emulator.

  This module is responsible for processing input from stdin and other sources,
  managing the input buffer, and handling special keys and combinations.

  Note: When running in certain environments, stdin may be excluded from Credo analysis
  due to how it's processed. This is expected behavior and doesn't affect functionality.
  """

  # alias Raxol.Terminal.Clipboard # Removed - Use Raxol.System.Clipboard directly
  alias Raxol.System.Clipboard # Alias the correct module
  # alias Raxol.Terminal.SpecialKeys # Unused
  # alias Raxol.Core.Events.Event # Unused

  @type t :: %__MODULE__{
          buffer: String.t(),
          cursor_position: non_neg_integer(),
          # clipboard: Clipboard.t(), # Removed
          tab_completion: map(),
          tab_completion_index: non_neg_integer(),
          tab_completion_matches: list(String.t())
        }

  defstruct [
    :buffer,
    :cursor_position,
    # :clipboard, # Removed
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
      # clipboard: Clipboard.new(), # Removed
      tab_completion: %{},
      tab_completion_index: 0,
      tab_completion_matches: []
    }
  end

  @doc """
  Handles clipboard paste operation.
  """
  @spec handle_paste(t()) :: {:ok, t()} | {:error, any()}
  def handle_paste(%__MODULE__{} = handler) do
    case Clipboard.paste() do # Call Raxol.System.Clipboard.paste/0
      {:ok, text} ->
        new_buffer = insert_text(handler.buffer, handler.cursor_position, text)
        new_position = handler.cursor_position + String.length(text)
        {:ok, %{handler | buffer: new_buffer, cursor_position: new_position}}

      {:error, reason} ->
        {:error, reason} # Pass through error
    end
  end

  @doc """
  Handles clipboard copy operation.
  (Currently copies the entire buffer)
  """
  @spec handle_copy(t()) :: {:ok, t()} | {:error, any()}
  def handle_copy(%__MODULE__{} = handler) do
    case Clipboard.copy(handler.buffer) do # Call Raxol.System.Clipboard.copy/1
      :ok ->
        {:ok, handler} # Return handler unchanged on success
      {:error, reason} ->
        {:error, reason} # Pass through error
    end
  end

  @doc """
  Handles clipboard cut operation.
  (Currently cuts the entire buffer)
  """
  @spec handle_cut(t()) :: {:ok, t()} | {:error, any()}
  def handle_cut(%__MODULE__{} = handler) do
    with :ok <- Clipboard.copy(handler.buffer), # Call Raxol.System.Clipboard.copy/1
         new_buffer = "",
         new_position = 0 do
      {:ok,
       %{
         handler
         | buffer: new_buffer,
           cursor_position: new_position
         # No clipboard state to update
       }}
    else
      {:error, reason} -> {:error, reason}
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
