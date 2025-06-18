defmodule Raxol.Terminal.Clipboard.Store do
  @moduledoc '''
  Manages clipboard content storage and retrieval.
  '''

  defstruct [:content, :format, :timestamp]

  @type t :: %__MODULE__{
          content: String.t(),
          format: String.t(),
          timestamp: integer()
        }

  @doc '''
  Creates a new clipboard store entry.
  '''
  @spec new(String.t(), String.t()) :: t()
  def new(content, format) do
    %__MODULE__{
      content: content,
      format: format,
      timestamp: System.system_time(:millisecond)
    }
  end

  @doc '''
  Gets the content from a store entry.
  '''
  @spec get_content(t()) :: String.t()
  def get_content(%__MODULE__{content: content}), do: content

  @doc '''
  Gets the format from a store entry.
  '''
  @spec get_format(t()) :: String.t()
  def get_format(%__MODULE__{format: format}), do: format

  @doc '''
  Gets the timestamp from a store entry.
  '''
  @spec get_timestamp(t()) :: integer()
  def get_timestamp(%__MODULE__{timestamp: timestamp}), do: timestamp

  @doc '''
  Updates the content of a store entry.
  '''
  @spec update_content(t(), String.t()) :: t()
  def update_content(store, content) do
    %{store | content: content, timestamp: System.system_time(:millisecond)}
  end

  @doc '''
  Updates the format of a store entry.
  '''
  @spec update_format(t(), String.t()) :: t()
  def update_format(store, format) do
    %{store | format: format, timestamp: System.system_time(:millisecond)}
  end

  @doc '''
  Checks if a store entry is expired.
  '''
  @spec expired?(t(), integer()) :: boolean()
  def expired?(%__MODULE__{timestamp: timestamp}, max_age) do
    System.system_time(:millisecond) - timestamp > max_age
  end
end
