defmodule Raxol.Style.Layout do
  @moduledoc """
  Defines layout properties for terminal UI elements.
  """

  @type t :: %__MODULE__{
    padding: {integer(), integer(), integer(), integer()},
    margin: {integer(), integer(), integer(), integer()},
    width: integer() | :auto,
    height: integer() | :auto,
    alignment: :left | :center | :right,
    overflow: :visible | :hidden | :scroll
  }

  defstruct padding: {0, 0, 0, 0},
            margin: {0, 0, 0, 0},
            width: :auto,
            height: :auto,
            alignment: :left,
            overflow: :visible

  @doc """
  Creates a new layout with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new layout with the specified values.
  """
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end
end 