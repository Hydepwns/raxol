defmodule Raxol.Terminal.Colors do
  @moduledoc """
  Manages terminal colors and color-related operations.
  """

  
  @type color :: String.t()
  @type t :: %__MODULE__{
          foreground: color(),
          background: color(),
          cursor_color: color(),
          selection_foreground: color(),
          selection_background: color()
        }

  defstruct foreground: "#000000",
            background: "#FFFFFF",
            cursor_color: "#000000",
            selection_foreground: "#FFFFFF",
            selection_background: "#0000FF"

  @doc """
  Gets the current foreground color.
  """
  @spec get_foreground(t()) :: color()
  def get_foreground(%__MODULE__{} = colors) do
    colors.foreground
  end

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(t(), color()) :: t()
  def set_foreground(%__MODULE__{} = colors, color) when is_binary(color) do
    %{colors | foreground: color}
  end

  @doc """
  Gets the current background color.
  """
  @spec get_background(t()) :: color()
  def get_background(%__MODULE__{} = colors) do
    colors.background
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(t(), color()) :: t()
  def set_background(%__MODULE__{} = colors, color) when is_binary(color) do
    %{colors | background: color}
  end

  @doc """
  Gets the current cursor color.
  """
  @spec get_cursor_color(t()) :: color()
  def get_cursor_color(%__MODULE__{} = colors) do
    colors.cursor_color
  end

  @doc """
  Sets the cursor color.
  """
  @spec set_cursor_color(t(), color()) :: t()
  def set_cursor_color(%__MODULE__{} = colors, color) when is_binary(color) do
    %{colors | cursor_color: color}
  end

  @doc """
  Gets the current selection foreground color.
  """
  @spec get_selection_foreground(t()) :: color()
  def get_selection_foreground(%__MODULE__{} = colors) do
    colors.selection_foreground
  end

  @doc """
  Sets the selection foreground color.
  """
  @spec set_selection_foreground(t(), color()) :: t()
  def set_selection_foreground(%__MODULE__{} = colors, color)
      when is_binary(color) do
    %{colors | selection_foreground: color}
  end

  @doc """
  Gets the current selection background color.
  """
  @spec get_selection_background(t()) :: color()
  def get_selection_background(%__MODULE__{} = colors) do
    colors.selection_background
  end

  @doc """
  Sets the selection background color.
  """
  @spec set_selection_background(t(), color()) :: t()
  def set_selection_background(%__MODULE__{} = colors, color)
      when is_binary(color) do
    %{colors | selection_background: color}
  end

  @doc """
  Resets the foreground color to default.
  """
  @spec reset_foreground(t()) :: {:ok, t()}
  def reset_foreground(%__MODULE__{} = colors) do
    {:ok, %{colors | foreground: "#000000"}}
  end

  @doc """
  Resets the background color to default.
  """
  @spec reset_background(t()) :: {:ok, t()}
  def reset_background(%__MODULE__{} = colors) do
    {:ok, %{colors | background: "#FFFFFF"}}
  end

  @doc """
  Resets the cursor color to default.
  """
  @spec reset_cursor_color(t()) :: {:ok, t()}
  def reset_cursor_color(%__MODULE__{} = colors) do
    {:ok, %{colors | cursor_color: "#000000"}}
  end

  @doc """
  Resets the selection foreground color to default.
  """
  @spec reset_selection_foreground(t()) :: {:ok, t()}
  def reset_selection_foreground(%__MODULE__{} = colors) do
    {:ok, %{colors | selection_foreground: "#FFFFFF"}}
  end

  @doc """
  Resets the selection background color to default.
  """
  @spec reset_selection_background(t()) :: {:ok, t()}
  def reset_selection_background(%__MODULE__{} = colors) do
    {:ok, %{colors | selection_background: "#0000FF"}}
  end
end
