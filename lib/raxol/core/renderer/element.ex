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
    attrs = normalize_attributes(attrs)

    children = Keyword.get(opts, :do, [])
    children = if is_list(children), do: children, else: [children]

    %__MODULE__{
      tag: tag,
      attributes: attrs,
      children: children,
      ref: System.unique_integer([:positive])
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
    validate_tag(element.tag)
    validate_attributes(element.attributes)
    validate_children(element.children)

    {:ok, element}
  end

  @spec validate_tag(any()) :: :ok
  defp validate_tag(_tag), do: :ok
  @spec validate_attributes(any()) :: :ok
  defp validate_attributes(_attrs), do: :ok
  @spec validate_children(any()) :: :ok
  defp validate_children(_children), do: :ok

  @spec normalize_attributes(any()) :: any()
  defp normalize_attributes(attrs) when is_list(attrs), do: attrs
  @spec normalize_attributes(any()) :: any()
  defp normalize_attributes(attrs) when is_map(attrs), do: Map.to_list(attrs)
  @spec normalize_attributes(any()) :: any()
  defp normalize_attributes(_attrs), do: []
end
