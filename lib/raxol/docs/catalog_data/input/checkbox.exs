# Placeholder for Checkbox Component Definition
# This file should return a %Raxol.Docs.ComponentCatalog.Component{} struct

alias Raxol.Docs.ComponentCatalog.{Component, Example}

%Component{
  id: :checkbox,
  name: "Checkbox",
  # Assuming this is the component module
  module: Raxol.UI.Components.Checkbox,
  description: "A checkbox input element.",
  examples: [
    %Example{
      id: :basic,
      title: "Basic Usage",
      description: "A simple checkbox.",
      code: ~S'""
      view do
        checkbox(label: "Accept Terms")
      end
      ""'
      # preview_fn: fn props -> ... end # Add preview function later
    }
  ],
  properties: [
    %Property{name: :label, type: :string},
    %Property{name: :checked, type: :boolean, default_value: false},
    %Property{name: :disabled, type: :boolean, default_value: false}
    # Add other relevant properties
  ],
  tags: ["input", "form", "boolean"]
  # accessibility: %{...}, # Add accessibility info later
  # related_components: [:radio_button] # Add related components later
}
