# Placeholder for Table Component Definition

alias Raxol.Docs.ComponentCatalog.{Component, Example, Property}

%Component{
  id: :table,
  name: "Table",
  module: Raxol.UI.Components.Table, # Assuming module path
  description: "Displays tabular data.",
  examples: [
    %Example{
      id: :basic,
      title: "Basic Usage",
      description: "Displaying simple data.",
      code: ~S'''
      columns = [%{id: :name, label: "Name"}, %{id: :role, label: "Role"}]
      data = [%{name: "Alice", role: "Admin"}, %{name: "Bob", role: "User"}]
      view do
        table(columns: columns, data: data, row_key: :name)
      end
      '''
      # preview_fn: fn props -> ... end
    }
  ],
  properties: [
    %Property{name: :columns, type: :list, required: true},
    %Property{name: :data, type: :list, required: true},
    %Property{name: :row_key, type: :atom, required: true},
    %Property{name: :on_row_click, type: :any, default_value: nil}
    # Add other props like styling, sorting, selection
  ],
  tags: ["data", "display", "collection", "grid"]
}
