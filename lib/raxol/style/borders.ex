defmodule Raxol.Style.Borders do
  @moduledoc """
  Defines border properties for terminal UI elements.
  """

  @type t :: %__MODULE__{
          style: :none | :solid | :double | :dashed | :dotted,
          width: integer(),
          color: term(),
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
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Merges two border structs, with the second overriding the first.
  """
  def merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override)
  end

  def merge(base, override) do
    base = if is_map(base), do: base, else: %{}
    override = if is_map(override), do: override, else: %{}
    Map.merge(base, override)
  end
end
