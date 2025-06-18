# Placeholder for TextField Component Definition

alias Raxol.Docs.ComponentCatalog.{Component, Example, Property}

%Component{
  id: :text_field,
  name: "Text Field",
  # Assuming module path
  module: Raxol.UI.Components.TextField,
  description: "A single-line text input field.",
  examples: [
    %Example{
      id: :basic,
      title: "Basic Usage",
      description: "A simple text input.",
      code: ~S'""
      view do
        text_field(placeholder: "Enter your name")
      end
      ""'
      # preview_fn: fn props -> ... end
    }
  ],
  properties: [
    %Property{name: :value, type: :string},
    %Property{name: :placeholder, type: :string, default_value: ""},
    %Property{name: :disabled, type: :boolean, default_value: false},
    %Property{name: :type, type: :atom, default_value: :text}
    # Add other props like on_change, on_blur etc.
  ],
  tags: ["input", "form", "text"]
}
