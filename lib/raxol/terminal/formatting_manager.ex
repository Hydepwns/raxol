defmodule Raxol.Terminal.FormattingManager do
  @moduledoc """
  Deprecated: Use `Raxol.Terminal.Format` instead.

  This module is maintained for backward compatibility only.
  """

  # Note: @deprecated removed because it triggers warnings on struct usage within
  # the module itself. The @moduledoc documents the deprecation instead.

  alias Raxol.Terminal.Format

  defstruct style: %{}

  @type t :: %__MODULE__{style: map()}

  @doc false
  def get_style(%__MODULE__{style: style}), do: style

  @doc false
  def update_style(%__MODULE__{} = state, style), do: %{state | style: style}

  @doc false
  def set_attribute(%__MODULE__{} = state, attribute) do
    %{state | style: Map.put(state.style, attribute, true)}
  end

  @doc false
  def reset_attribute(%__MODULE__{} = state, attribute) do
    %{state | style: Map.delete(state.style, attribute)}
  end

  @doc false
  def set_foreground(%__MODULE__{} = state, color) do
    %{state | style: Map.put(state.style, :fg, color)}
  end

  @doc false
  def set_background(%__MODULE__{} = state, color) do
    %{state | style: Map.put(state.style, :bg, color)}
  end

  @doc false
  def reset_all_attributes(%__MODULE__{} = state), do: %{state | style: %{}}

  @doc false
  def get_foreground(%__MODULE__{style: style}),
    do: Map.get(style, :fg, :default)

  @doc false
  def get_background(%__MODULE__{style: style}),
    do: Map.get(style, :bg, :default)

  @doc false
  def attribute_set?(%__MODULE__{style: style}, attribute) do
    Map.get(style, attribute, false)
  end

  @doc false
  def get_set_attributes(%__MODULE__{style: style}) do
    Enum.filter(style, fn {_, value} -> value end)
  end

  # Bridge to new module for new code
  @doc """
  Creates a new Format state. Use `Raxol.Terminal.Format.new/0` directly.
  """
  def new_format, do: Format.new()
end
