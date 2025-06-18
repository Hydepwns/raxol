defmodule Raxol.Terminal.FormattingManager do
  @moduledoc """
  Manages the terminal text formatting.
  """

  defstruct style: %{}

  @type t :: %__MODULE__{
          style: map()
        }

  @doc """
  Gets the current style.
  """
  @spec get_style(t()) :: map()
  def get_style(state) do
    state.style
  end

  @doc """
  Updates the style.
  """
  @spec update_style(t(), map()) :: t()
  def update_style(state, style) do
    %{state | style: style}
  end

  @doc """
  Sets the given attribute in the style.
  """
  @spec set_attribute(t(), atom()) :: t()
  def set_attribute(state, attribute) do
    %{state | style: Map.put(state.style, attribute, true)}
  end

  @doc """
  Resets the given attribute in the style.
  """
  @spec reset_attribute(t(), atom()) :: t()
  def reset_attribute(state, attribute) do
    %{state | style: Map.delete(state.style, attribute)}
  end

  @doc """
  Sets the foreground color in the style.
  """
  @spec set_foreground(t(), atom()) :: t()
  def set_foreground(state, color) do
    %{state | style: Map.put(state.style, :fg, color)}
  end

  @doc """
  Sets the background color in the style.
  """
  @spec set_background(t(), atom()) :: t()
  def set_background(state, color) do
    %{state | style: Map.put(state.style, :bg, color)}
  end

  @doc """
  Resets all attributes in the style.
  """
  @spec reset_all_attributes(t()) :: t()
  def reset_all_attributes(state) do
    %{state | style: %{}}
  end

  @doc """
  Gets the foreground color from the style.
  """
  @spec get_foreground(t()) :: atom()
  def get_foreground(state) do
    Map.get(state.style, :fg, :default)
  end

  @doc """
  Gets the background color from the style.
  """
  @spec get_background(t()) :: atom()
  def get_background(state) do
    Map.get(state.style, :bg, :default)
  end

  @doc """
  Checks if the given attribute is set in the style.
  """
  @spec attribute_set?(t(), atom()) :: boolean()
  def attribute_set?(state, attribute) do
    Map.get(state.style, attribute, false)
  end

  @doc """
  Gets the set attributes from the style.
  """
  @spec get_set_attributes(t()) :: list()
  def get_set_attributes(state) do
    Enum.filter(state.style, fn {_, value} -> value end)
  end
end
