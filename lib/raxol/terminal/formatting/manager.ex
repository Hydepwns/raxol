defmodule Raxol.Terminal.Formatting.Manager do
  @moduledoc """
  Manages text formatting for the terminal.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.TextFormatting

  @type t :: %__MODULE__{
          style: TextFormatting.text_style(),
          attributes: list(atom()),
          foreground: TextFormatting.color(),
          background: TextFormatting.color()
        }

  defstruct [:style, :attributes, :foreground, :background]

  @doc """
  Creates a new text formatting state.
  """
  @spec new() :: TextFormatting.text_style()
  def new do
    TextFormatting.new()
  end

  @doc """
  Gets the current text style.
  """
  @spec get_style(EmulatorStruct.t()) :: TextFormatting.text_style()
  def get_style(emulator) do
    emulator.style
  end

  @doc """
  Updates the text style.
  """
  @spec update_style(EmulatorStruct.t(), TextFormatting.text_style()) :: EmulatorStruct.t()
  def update_style(emulator, style) do
    %{emulator | style: style}
  end

  @doc """
  Sets a text attribute.
  """
  @spec set_attribute(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def set_attribute(emulator, attribute) do
    attributes = [attribute | emulator.style.attributes]
    style = %{emulator.style | attributes: attributes}
    %{emulator | style: style}
  end

  @doc """
  Resets a text attribute.
  """
  @spec reset_attribute(EmulatorStruct.t(), atom()) :: EmulatorStruct.t()
  def reset_attribute(emulator, attribute) do
    attributes = Enum.reject(emulator.style.attributes, &(&1 == attribute))
    style = %{emulator.style | attributes: attributes}
    %{emulator | style: style}
  end

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(EmulatorStruct.t(), TextFormatting.color()) :: EmulatorStruct.t()
  def set_foreground(emulator, color) do
    style = %{emulator.style | foreground: color}
    %{emulator | style: style}
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(EmulatorStruct.t(), TextFormatting.color()) :: EmulatorStruct.t()
  def set_background(emulator, color) do
    style = %{emulator.style | background: color}
    %{emulator | style: style}
  end

  @doc """
  Resets all text attributes.
  """
  @spec reset_all_attributes(EmulatorStruct.t()) :: EmulatorStruct.t()
  def reset_all_attributes(emulator) do
    style = %{emulator.style |
      attributes: [],
      foreground: :default,
      background: :default
    }
    %{emulator | style: style}
  end

  @doc """
  Gets the current foreground color.
  """
  @spec get_foreground(EmulatorStruct.t()) :: TextFormatting.color()
  def get_foreground(emulator) do
    emulator.style.foreground
  end

  @doc """
  Gets the current background color.
  """
  @spec get_background(EmulatorStruct.t()) :: TextFormatting.color()
  def get_background(emulator) do
    emulator.style.background
  end

  @doc """
  Checks if an attribute is set.
  """
  @spec attribute_set?(EmulatorStruct.t(), atom()) :: boolean()
  def attribute_set?(emulator, attribute) do
    attribute in emulator.style.attributes
  end

  @doc """
  Gets all set attributes.
  """
  @spec get_set_attributes(EmulatorStruct.t()) :: list(atom())
  def get_set_attributes(emulator) do
    emulator.style.attributes
  end
end
