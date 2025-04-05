defmodule Raxol.Terminal.Input.InputBuffer do
  @moduledoc """
  Handles input buffering for the terminal emulator.
  Provides functionality for storing, retrieving, and manipulating input data.
  """

  @type t :: %__MODULE__{
    contents: String.t(),
    max_size: non_neg_integer(),
    overflow_mode: :truncate | :error | :wrap
  }

  defstruct [
    :contents,
    :max_size,
    :overflow_mode
  ]

  @doc """
  Creates a new input buffer with default values.
  """
  def new(max_size \\ 1024, overflow_mode \\ :truncate) do
    %__MODULE__{
      contents: "",
      max_size: max_size,
      overflow_mode: overflow_mode
    }
  end

  @doc """
  Appends data to the buffer.
  """
  def append(%__MODULE__{} = buffer, data) when is_binary(data) do
    new_contents = buffer.contents <> data
    
    if String.length(new_contents) <= buffer.max_size do
      %{buffer | contents: new_contents}
    else
      case buffer.overflow_mode do
        :truncate -> 
          %{buffer | contents: String.slice(new_contents, 0, buffer.max_size)}
        :error -> 
          buffer
        :wrap -> 
          %{buffer | contents: String.slice(new_contents, -buffer.max_size..-1)}
      end
    end
  end

  @doc """
  Prepends data to the buffer.
  """
  def prepend(%__MODULE__{} = buffer, data) when is_binary(data) do
    new_contents = data <> buffer.contents
    
    if String.length(new_contents) <= buffer.max_size do
      %{buffer | contents: new_contents}
    else
      case buffer.overflow_mode do
        :truncate -> 
          %{buffer | contents: String.slice(new_contents, 0, buffer.max_size)}
        :error -> 
          buffer
        :wrap -> 
          %{buffer | contents: String.slice(new_contents, -buffer.max_size..-1)}
      end
    end
  end

  @doc """
  Sets the buffer contents.
  """
  def set_contents(%__MODULE__{} = buffer, contents) when is_binary(contents) do
    if String.length(contents) <= buffer.max_size do
      %{buffer | contents: contents}
    else
      case buffer.overflow_mode do
        :truncate -> 
          %{buffer | contents: String.slice(contents, 0, buffer.max_size)}
        :error -> 
          buffer
        :wrap -> 
          %{buffer | contents: String.slice(contents, -buffer.max_size..-1)}
      end
    end
  end

  @doc """
  Gets the buffer contents.
  """
  def get_contents(%__MODULE__{} = buffer) do
    buffer.contents
  end

  @doc """
  Clears the buffer.
  """
  def clear(%__MODULE__{} = buffer) do
    %{buffer | contents: ""}
  end

  @doc """
  Checks if the buffer is empty.
  """
  def empty?(%__MODULE__{} = buffer) do
    buffer.contents == ""
  end

  @doc """
  Gets the current size of the buffer.
  """
  def size(%__MODULE__{} = buffer) do
    String.length(buffer.contents)
  end

  @doc """
  Gets the maximum size of the buffer.
  """
  def max_size(%__MODULE__{} = buffer) do
    buffer.max_size
  end

  @doc """
  Sets the maximum size of the buffer.
  """
  def set_max_size(%__MODULE__{} = buffer, max_size) when is_integer(max_size) and max_size > 0 do
    %{buffer | max_size: max_size}
  end

  @doc """
  Sets the overflow mode of the buffer.
  """
  def set_overflow_mode(%__MODULE__{} = buffer, mode) when mode in [:truncate, :error, :wrap] do
    %{buffer | overflow_mode: mode}
  end

  @doc """
  Gets the overflow mode of the buffer.
  """
  def overflow_mode(%__MODULE__{} = buffer) do
    buffer.overflow_mode
  end

  @doc """
  Removes the last character from the buffer.
  """
  def backspace(%__MODULE__{} = buffer) do
    if String.length(buffer.contents) > 0 do
      %{buffer | contents: String.slice(buffer.contents, 0, -2)}
    else
      buffer
    end
  end

  @doc """
  Removes the first character from the buffer.
  """
  def delete_first(%__MODULE__{} = buffer) do
    if String.length(buffer.contents) > 0 do
      %{buffer | contents: String.slice(buffer.contents, 1..-1//1)}
    else
      buffer
    end
  end

  @doc """
  Inserts a character at the specified position.
  """
  def insert_at(%__MODULE__{} = buffer, position, char) when is_binary(char) do
    if String.length(char) == 1 and position <= String.length(buffer.contents) do
      new_contents = 
        String.slice(buffer.contents, 0, position) <> 
        char <> 
        String.slice(buffer.contents, position..-1)
      
      %{buffer | contents: new_contents}
    else
      buffer
    end
  end

  @doc """
  Replaces a character at the specified position.
  """
  def replace_at(%__MODULE__{} = buffer, position, char) when is_binary(char) do
    if String.length(char) == 1 and position <= String.length(buffer.contents) do
      new_contents = 
        String.slice(buffer.contents, 0, position) <> 
        char <> 
        String.slice(buffer.contents, position + 1..-1)
      
      %{buffer | contents: new_contents}
    else
      buffer
    end
  end
end 