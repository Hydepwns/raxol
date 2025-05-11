# Table Component

## Overview

The Table component is a powerful, flexible component for displaying tabular data with features like sorting, filtering, pagination, and custom styling.

## Basic Usage

```elixir
# Basic table with default options
{:ok, state} = Table.init(%{
  id: :my_table,
  columns: [
    %{header: "ID", key: :id, width: 4, align: :right},
    %{header: "Name", key: :name, width: 10, align: :left},
    %{header: "Age", key: :age, width: 5, align: :center}
  ],
  data: [
    %{id: 1, name: "Alice", age: 25},
    %{id: 2, name: "Bob", age: 30}
  ]
})
```

## Column Configuration

### Column Properties

- `header`: Display text for the column header
- `key`: Atom or function to access data
- `width`: Fixed width or `:auto`
- `align`: `:left`, `:right`, or `:center`
- `format`: Function to format cell values

Example:

```elixir
columns = [
  %{
    header: "ID",
    key: :id,
    width: 4,
    align: :right,
    format: &String.Chars.to_string/1
  },
  %{
    header: "Full Name",
    key: fn row -> "#{row.first} #{row.last}" end,
    width: 20,
    align: :left,
    format: & &1
  }
]
```

## Features

### Pagination

Enable pagination with options:

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  options: %{
    paginate: true,
    page_size: 10
  }
})
```

### Sorting

Enable sorting with options:

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  options: %{
    sortable: true
  }
})
```

### Filtering

Enable search/filtering with options:

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  options: %{
    searchable: true
  }
})
```

## Styling

### Border Styles

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  border: :single  # or :double, :none
})
```

### Row Styling

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  striped: true,
  row_style: fn row_index, row_data ->
    if row_data.status == "stable", do: [bg: :bright_black]
  end
})
```

### Header Styling

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  header_style: [:bold]
})
```

## Event Handling

### Keyboard Navigation

The table component handles these keyboard events:

- Arrow keys for row navigation
- Page Up/Down for page navigation
- Enter for row selection

### Mouse Events

- Click for row selection
- Click on header for sorting

## Performance Considerations

1. **Large Datasets**

   - Use pagination for large datasets
   - Implement virtual scrolling for very large datasets
   - Consider data windowing techniques

2. **Rendering Optimization**
   - Minimize state updates
   - Use efficient data structures
   - Implement proper cleanup

## Testing

### Unit Tests

Test individual features:

```elixir
describe "Table Features" do
  test "initializes with default options" do
    {:ok, state} = Table.init(%{
      id: :test_table,
      columns: columns,
      data: data
    })

    assert state.options == %{
      paginate: false,
      searchable: false,
      sortable: false,
      page_size: 10
    }
  end

  test "handles empty data" do
    {:ok, state} = Table.init(%{
      columns: columns,
      data: []
    })

    view = Table.render(state)
    assert view.type == :border
    [header | rows] = get_in(view, [:children, Access.at(0)])
    assert length(rows) == 0
  end
end
```

### Integration Tests

Test component interactions:

```elixir
describe "Table Integration" do
  test "combines with other components" do
    # Create table with embedded components
    columns = [
      %{
        header: "Chart",
        key: :data,
        width: 20,
        format: fn data ->
          Chart.new(
            type: :sparkline,
            data: data,
            width: 20
          )
        end
      }
    ]

    # Test rendering and interaction
  end
end
```

## Best Practices

1. **Column Design**

   - Keep column widths reasonable
   - Use appropriate alignment
   - Implement efficient formatters

2. **Data Management**

   - Use efficient data structures
   - Implement proper pagination
   - Handle empty states

3. **Performance**

   - Minimize re-renders
   - Use efficient sorting/filtering
   - Implement proper cleanup

4. **Accessibility**
   - Provide keyboard navigation
   - Use semantic markup
   - Support screen readers

## Common Patterns

### Dynamic Updates

```elixir
# Update table data
{:ok, updated_state} = Table.update({:set_data, new_data}, state)

# Update specific row
{:ok, updated_state} = Table.update({:update_row, row_id, new_data}, state)

# Update column configuration
{:ok, updated_state} = Table.update({:set_columns, new_columns}, state)
```

### Custom Cell Rendering

```elixir
columns = [
  %{
    header: "Status",
    key: :status,
    width: 8,
    align: :center,
    format: fn
      :up -> View.text("↑", fg: :green)
      :down -> View.text("↓", fg: :red)
      :stable -> View.text("→", fg: :yellow)
    end
  }
]
```

### Row Selection

```elixir
{:ok, state} = Table.init(%{
  # ... other props ...
  selectable: true,
  selected: 0  # Index of selected row
})
```
