# Placeholder for SelectList Component Definition

alias Raxol.Docs.ComponentCatalog.{Component, Example, Property}

%Component{
  id: :select_list,
  name: "Select List",
  module: Raxol.UI.Components.SelectList, # Assuming module path
  description: "A dropdown list for selecting one option from many.",
  examples: [
    %Example{
      id: :basic,
      title: "Basic Usage",
      description: "A simple select list.",
      code: ~S'''
      options = [{"Option 1", "opt1"}, {"Option 2", "opt2"}]
      view do
        select_list(options: options)
      end
      '''
      # preview_fn: fn props -> ... end
    }
  ],
  properties: [
    %Property{name: :options, type: :list, required: true},
    %Property{name: :selected, type: :any, default_value: nil},
    %Property{name: :disabled, type: :boolean, default_value: false}
    # Add other props like on_change
  ],
  tags: ["input", "form", "select", "dropdown"]
}
