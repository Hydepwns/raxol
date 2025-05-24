---
title: SelectList Component
description: Documentation for the SelectList component in Raxol
date: 2025-05-06
author: Raxol Team
section: components
tags: [components, inputs, selectlist, ui]
---

# SelectList Component

The `SelectList` component provides a selectable list of options for users to choose from. It supports single or multiple selection, search/filtering capabilities, keyboard navigation, and pagination.

## Features

- Single or multiple selection modes
- Robust keyboard navigation
- Search and filtering capabilities
- Pagination support for large lists
- Stateful scroll position
- Accessibility support
- Customizable theming

## Basic Usage

Here's a simple example of a SelectList with basic options:

```elixir
options = [
  {"Apple", :apple},
  {"Banana", :banana},
  {"Cherry", :cherry}
]

%{
  type: Raxol.UI.Components.Input.SelectList,
  id: :fruit_selector,
  assigns: %{
    options: options,
    label: "Select a fruit:",
    on_select: {:select_fruit},
    max_height: 10
  }
}
```

## Properties

| Property            | Type                    | Default                  | Description                                                                               |
| ------------------- | ----------------------- | ------------------------ | ----------------------------------------------------------------------------------------- |
| `options`           | `[{String.t(), any()}]` | (required)               | List of options to display. Each option is a tuple with a label (string) and value (any). |
| `label`             | `String.t()`            | `nil`                    | Optional label displayed above the list.                                                  |
| `on_select`         | `(any() -> any())`      | `nil`                    | Callback when an option is selected. Receives the value of the selected option.           |
| `on_cancel`         | `(-> any())`            | `nil`                    | Callback when selection is canceled (e.g., when Escape is pressed).                       |
| `on_change`         | `(any() -> any())`      | `nil`                    | Callback when selection changes without confirming.                                       |
| `on_focus`          | `(integer() -> any())`  | `nil`                    | Callback when focus changes to a different option. Receives the index.                    |
| `theme`             | `map()`                 | `%{}`                    | Custom theme overrides for this component.                                                |
| `max_height`        | `integer()`             | `nil`                    | Maximum height for the component. If not provided, will display all options.              |
| `enable_search`     | `boolean()`             | `false`                  | Whether to enable the search box.                                                         |
| `multiple`          | `boolean()`             | `false`                  | Enable multiple selection mode.                                                           |
| `searchable_fields` | `list(atom())`          | `nil`                    | When values are maps, specifies which fields to search in addition to the label.          |
| `placeholder`       | `String.t()`            | `"Type to search..."`    | Placeholder text for the search box.                                                      |
| `empty_message`     | `String.t()`            | `"No options available"` | Message to show when no options match the search.                                         |
| `show_pagination`   | `boolean()`             | `false`                  | Whether to show pagination controls.                                                      |
| `page_size`         | `integer()`             | `10`                     | Number of items per page when pagination is enabled.                                      |

## Usage Examples

### Multiple Selection

```elixir
user_options = Enum.map(users, fn user ->
  {"#{user.name} (#{user.role})", user.id}
end)

%{
  type: Raxol.UI.Components.Input.SelectList,
  id: :user_selector,
  assigns: %{
    options: user_options,
    label: "Select users:",
    on_select: {:select_users},
    max_height: 12,
    multiple: true
  }
}
```

### Search and Filtering

```elixir
%{
  type: Raxol.UI.Components.Input.SelectList,
  id: :search_users,
  assigns: %{
    options: user_options,
    label: "Find users:",
    on_select: {:select_user},
    max_height: 12,
    enable_search: true,
    searchable_fields: [:name, :email],
    placeholder: "Search by name or email..."
  }
}
```

### Pagination

```elixir
%{
  type: Raxol.UI.Components.Input.SelectList,
  id: :country_selector,
  assigns: %{
    options: country_options,
    label: "Select a country:",
    on_select: {:select_country},
    max_height: 12,
    page_size: 8,
    show_pagination: true
  }
}
```

## Keyboard Navigation

The `SelectList` component supports the following keyboard interactions:

| Key           | Action                                                   |
| ------------- | -------------------------------------------------------- |
| Arrow Up/Down | Navigate between options                                 |
| Page Up/Down  | Move by page size                                        |
| Home/End      | Jump to first/last option                                |
| Enter         | Confirm selection                                        |
| Escape        | Cancel or clear search                                   |
| Space         | Toggle selection (in multiple mode)                      |
| Tab           | Switch between search box and list (when search enabled) |
| Typing        | Incremental search (when list has focus)                 |
| Backspace     | Delete characters from search (when search has focus)    |

## Showcase

For a complete demonstration of all SelectList features, see the showcase example:

```elixir
alias Raxol.Examples.SelectListShowcase

Raxol.run(SelectListShowcase)
```

## Event Handling

When an option is selected, the `on_select` callback is called with the value of the selected option. In multiple selection mode, you'll need to handle toggling options on your own.

Example event handler:

```elixir
def handle_event({:select_fruit, fruit_value}, _props, state) do
  {%{state | selected_fruit: fruit_value}, []}
end

def handle_event({:select_user, user_id}, _props, state) do
  if state.multiple_selected |> Enum.member?(user_id) do
    # Remove from selection
    {%{state | multiple_selected: state.multiple_selected |> Enum.reject(&(&1 == user_id))}, []}
  else
    # Add to selection
    {%{state | multiple_selected: [user_id | state.multiple_selected]}, []}
  end
end
```

## Theming

The `SelectList` component can be styled using the following theme properties:

```elixir
theme = %{
  select_list: %{
    label_fg: :cyan,
    option_fg: :white,
    option_bg: :black,
    focused_fg: :black,
    focused_bg: :cyan,
    selected_fg: :black,
    selected_bg: :green,
    search_fg: :white,
    search_bg: :blue,
    search_placeholder_fg: :gray,
    empty_fg: :gray,
    pagination_fg: :white,
    pagination_bg: :blue
  }
}
```

## Accessibility

The SelectList component supports accessibility features:

- Full keyboard navigation
- High contrast mode (automatically detected from Accessibility module)
- Clear focus indicators
- Search functionality helps users quickly find options

## Implementation Notes

- The component automatically handles scrolling to keep the focused option visible.
- When filtering is enabled, only the filtered options are displayed.
- In multiple selection mode, Space toggles selection without closing the list.
- Type-ahead search is available even without a dedicated search box.
- Pagination controls are available for very large lists.
