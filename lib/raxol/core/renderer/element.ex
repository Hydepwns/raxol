defmodule Raxol.Core.Renderer.Element do
  @moduledoc """
  Defines the core element structure for the rendering system.

  Elements are the building blocks of Raxol's UI system. Each element
  represents a renderable component with:
  * A tag identifying its type
  * Attributes controlling its appearance and behavior
  * Optional children forming a tree structure
  """

  @type t :: %__MODULE__{
    tag: atom(),
    attributes: [{atom(), term()}],
    children: [t()],
    ref: reference() | nil,
    content: term(),
    style: map()
  }

  defstruct tag: nil,
            attributes: [],
            children: [],
            ref: nil,
            content: nil,
            style: %{}

  @doc """
  Creates a new element with the given tag and attributes.
  """
  def new(tag, attrs, opts \\ []) do
    children = Keyword.get(opts, :do, [])
    children = if is_list(children), do: children, else: [children]

    %__MODULE__{
      tag: tag,
      attributes: attrs,
      children: children,
      ref: make_ref()
    }
  end

  @doc """
  Updates an element's attributes while preserving its structure.
  """
  def update_attrs(%__MODULE__{} = element, attrs) do
    %{element | attributes: attrs}
  end

  @doc """
  Adds children to an existing element.
  """
  def add_children(%__MODULE__{} = element, children) when is_list(children) do
    %{element | children: element.children ++ children}
  end

  @doc """
  Validates that an element tree follows the component rules.
  """
  def validate(%__MODULE__{} = element) do
    with :ok <- validate_tag(element.tag),
         :ok <- validate_attributes(element.attributes),
         :ok <- validate_children(element.children) do
      {:ok, element}
    end
  end

  # Private validation functions to be implemented
  defp validate_tag(_tag), do: :ok
  defp validate_attributes(_attrs), do: :ok
  defp validate_children(_children), do: :ok
end 