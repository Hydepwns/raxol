# `Raxol.Core.Accessibility.Metadata`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/accessibility/metadata.ex#L1)

Handles accessibility metadata for UI elements and component styles.

# `get_accessible_name`

Get the accessible name for an element.

## Parameters

* `element` - The element to get the accessible name for

## Returns

* The accessible name as a string, or nil if not found

## Examples

    iex> Metadata.get_accessible_name("search_button")
    "Search"

# `get_component_hint`

# `get_component_style`

Get style settings for a component type.

## Parameters

* `component_type` - Atom representing the component type

## Returns

* The style map for the component type, or empty map if not found

## Examples

    iex> Metadata.get_component_style(:button)
    %{background: :blue}

# `get_element_metadata`

Get metadata for an element.

## Parameters

* `element_id` - Unique identifier for the element

## Returns

* The metadata map for the element, or `nil` if not found

## Examples

    iex> Metadata.get_element_metadata("search_button")
    %{label: "Search"}

# `register_component_style`

Register style settings for a component type.

## Parameters

* `component_type` - Atom representing the component type
* `style` - Style map to associate with the component type

## Examples

    iex> Metadata.register_component_style(:button, %{background: :blue})
    :ok

# `register_element_metadata`

Register metadata for an element to be used for accessibility features.

## Parameters

* `element_id` - Unique identifier for the element
* `metadata` - Metadata to associate with the element

## Examples

    iex> Metadata.register_element_metadata("search_button", %{label: "Search"})
    :ok

---

*Consult [api-reference.md](api-reference.md) for complete listing*
