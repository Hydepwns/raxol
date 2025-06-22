defmodule Raxol.Style.Borders do
  import Raxol.Guards

  @moduledoc """
  Defines border properties for terminal UI elements.
  """

  @type t :: %__MODULE__{
          style: :none | :solid | :double | :dashed | :dotted,
          width: integer(),
          color: Color.t(),
          radius: integer()
        }

  defstruct style: :none,
            width: 0,
            color: nil,
            radius: 0

  @doc """
  Creates a new border with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new border with the specified values.
  """
  def new(attrs) when map?(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Merges two border structs, with the second overriding the first.
  """
  def merge(base, override) when map?(base) and map?(override) do
    Map.merge(base, override)
  end

  def merge(base, override) do
    base = if map?(base), do: base, else: %{}
    override = if map?(override), do: override, else: %{}
    Map.merge(base, override)
  end
end
