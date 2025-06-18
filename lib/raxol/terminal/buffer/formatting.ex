defmodule Raxol.Terminal.Buffer.Formatting do
  @moduledoc """
  Manages text formatting state and operations for the screen buffer.
  This module handles text attributes, colors, and style management.
  """

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
          bold: boolean(),
          dim: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          hidden: boolean(),
          strikethrough: boolean(),
          foreground:
            {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil,
          background:
            {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
        }

  defstruct [
    :bold,
    :dim,
    :italic,
    :underline,
    :blink,
    :reverse,
    :hidden,
    :strikethrough,
    :foreground,
    :background
  ]

  @doc """
  Initializes a new formatting state with default values.
  """
  @spec init() :: t()
  def init do
    %__MODULE__{
      bold: false,
      dim: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false,
      hidden: false,
      strikethrough: false,
      foreground: nil,
      background: nil
    }
  end

  @doc """
  Gets the current style.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The current style map.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Formatting.get_style(buffer)
      %{bold: false, dim: false, italic: false, underline: false, blink: false, reverse: false, hidden: false, strikethrough: false, foreground: nil, background: nil}
  """
  @spec get_style(ScreenBuffer.t()) :: t()
  def get_style(buffer) do
    buffer.formatting_state
  end

  @doc """
  Updates the style with new attributes.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `style` - The new style map

  ## Returns

  The updated screen buffer with new style.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.update_style(buffer, %{bold: true})
      iex> Formatting.get_style(buffer)
      %{bold: true, ...}
  """
  @spec update_style(ScreenBuffer.t(), map()) :: ScreenBuffer.t()
  def update_style(buffer, style) do
    new_formatting_state = Map.merge(buffer.formatting_state, style)
    %{buffer | formatting_state: new_formatting_state}
  end

  @doc """
  Sets a specific attribute.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `attribute` - The attribute to set (:bold, :dim, :italic, etc.)

  ## Returns

  The updated screen buffer with the attribute set.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.set_attribute(buffer, :bold)
      iex> Formatting.attribute_set?(buffer, :bold)
      true
  """
  @spec set_attribute(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def set_attribute(buffer, attribute) do
    new_formatting_state = %{buffer.formatting_state | attribute => true}
    %{buffer | formatting_state: new_formatting_state}
  end

  @doc """
  Resets a specific attribute.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `attribute` - The attribute to reset (:bold, :dim, :italic, etc.)

  ## Returns

  The updated screen buffer with the attribute reset.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.reset_attribute(buffer, :bold)
      iex> Formatting.attribute_set?(buffer, :bold)
      false
  """
  @spec reset_attribute(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def reset_attribute(buffer, attribute) do
    new_formatting_state = %{buffer.formatting_state | attribute => false}
    %{buffer | formatting_state: new_formatting_state}
  end

  @doc """
  Sets the foreground color.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `color` - The RGB color tuple {r, g, b}

  ## Returns

  The updated screen buffer with new foreground color.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.set_foreground(buffer, {255, 0, 0})
      iex> Formatting.get_foreground(buffer)
      {255, 0, 0}
  """
  @spec set_foreground(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
        ) :: ScreenBuffer.t()
  def set_foreground(buffer, color) do
    new_formatting_state = %{buffer.formatting_state | foreground: color}
    %{buffer | formatting_state: new_formatting_state}
  end

  @doc """
  Sets the background color.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `color` - The RGB color tuple {r, g, b}

  ## Returns

  The updated screen buffer with new background color.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.set_background(buffer, {0, 0, 255})
      iex> Formatting.get_background(buffer)
      {0, 0, 255}
  """
  @spec set_background(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
        ) :: ScreenBuffer.t()
  def set_background(buffer, color) do
    new_formatting_state = %{buffer.formatting_state | background: color}
    %{buffer | formatting_state: new_formatting_state}
  end

  @doc """
  Resets all attributes to their default values.

  ## Parameters

  * `buffer` - The screen buffer to modify

  ## Returns

  The updated screen buffer with all attributes reset.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.reset_all(buffer)
      iex> Formatting.get_style(buffer)
      %{bold: false, dim: false, italic: false, underline: false, blink: false, reverse: false, hidden: false, strikethrough: false, foreground: nil, background: nil}
  """
  @spec reset_all(ScreenBuffer.t()) :: ScreenBuffer.t()
  def reset_all(buffer) do
    %{buffer | formatting_state: init()}
  end

  @doc """
  Gets the current foreground color.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The current foreground color or nil if not set.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Formatting.get_foreground(buffer)
      nil
  """
  @spec get_foreground(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def get_foreground(buffer) do
    buffer.formatting_state.foreground
  end

  @doc """
  Gets the current background color.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The current background color or nil if not set.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Formatting.get_background(buffer)
      nil
  """
  @spec get_background(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def get_background(buffer) do
    buffer.formatting_state.background
  end

  @doc """
  Checks if a specific attribute is set.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `attribute` - The attribute to check

  ## Returns

  A boolean indicating if the attribute is set.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Formatting.attribute_set?(buffer, :bold)
      false
  """
  @spec attribute_set?(ScreenBuffer.t(), atom()) :: boolean()
  def attribute_set?(buffer, attribute) do
    Map.get(buffer.formatting_state, attribute, false)
  end

  @doc """
  Gets all currently set attributes.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A list of set attributes.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Formatting.set_attribute(buffer, :bold)
      iex> Formatting.get_set_attributes(buffer)
      [:bold]
  """
  @spec get_set_attributes(ScreenBuffer.t()) :: list(atom())
  def get_set_attributes(buffer) do
    buffer.formatting_state
    |> Map.to_list()
    |> Enum.filter(fn {_key, value} -> value == true end)
    |> Enum.map(fn {key, _value} -> key end)
  end
end
