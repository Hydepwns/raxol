defmodule Raxol.UI.Layout.ListScrollContent do
  @moduledoc """
  Default ScrollContent adapter that wraps a plain list.

  Provides backwards compatibility -- existing Viewport usage with a list
  of children works unchanged by wrapping the list in this adapter.
  """

  @behaviour Raxol.UI.Layout.ScrollContent

  defstruct [:items]

  @type t :: %__MODULE__{items: [map()]}

  @doc "Wraps a list of elements as a ScrollContent source."
  @spec new([map()]) :: t()
  def new(items) when is_list(items), do: %__MODULE__{items: items}

  @impl true
  def total_count(%__MODULE__{items: items}), do: length(items)

  @impl true
  def slice(%__MODULE__{items: items}, offset, count) do
    Enum.slice(items, offset, count)
  end

  @impl true
  def item_height(_state, _index), do: 1
end
