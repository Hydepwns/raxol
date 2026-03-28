defmodule Raxol.Terminal.OutputBuffer do
  @moduledoc """
  Simple output buffer implementation for terminal output.
  """

  @type t :: String.t()

  @doc """
  Writes a string to the output buffer.
  """
  @spec write(t(), String.t()) :: t()
  def write(buffer, string) do
    buffer <> string
  end

  @doc """
  Writes a string to the output buffer with a newline.
  """
  @spec writeln(t(), String.t()) :: t()
  def writeln(buffer, string) do
    buffer <> string <> "\n"
  end

  @doc """
  Flushes the output buffer.
  """
  @spec flush(t()) :: {:ok, t()}
  def flush(buffer) do
    {:ok, buffer}
  end

  @doc """
  Clears the output buffer.
  """
  @spec clear(t()) :: t()
  def clear(_buffer) do
    ""
  end

  @doc """
  Gets the current output buffer content.
  """
  @spec get_content(t()) :: String.t()
  def get_content(buffer) do
    buffer
  end

  @doc """
  Sets the output buffer content.
  """
  @spec set_content(t(), String.t()) :: t()
  def set_content(_buffer, content) do
    content
  end

  @doc """
  Gets the output buffer size.
  """
  @spec get_size(t()) :: non_neg_integer()
  def get_size(buffer) do
    String.length(buffer)
  end

  @doc """
  Checks if the output buffer is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(buffer) do
    buffer == ""
  end

  @doc """
  Sets the output buffer mode.
  """
  @spec set_mode(t(), atom()) :: t()
  def set_mode(buffer, _mode) do
    buffer
  end

  @doc """
  Gets the current output buffer mode.
  """
  @spec get_mode(t()) :: atom()
  def get_mode(_buffer) do
    :normal
  end

  @doc """
  Sets the output buffer encoding.
  """
  @spec set_encoding(t(), String.t()) :: t()
  def set_encoding(buffer, _encoding) do
    buffer
  end

  @doc """
  Gets the current output buffer encoding.
  """
  @spec get_encoding(t()) :: String.t()
  def get_encoding(_buffer) do
    "utf-8"
  end
end
