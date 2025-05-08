alias Raxol.Docs.ComponentCatalog.{Component, Example, Property}

%Component{
  id: :text_input,
  name: "Text Input",
  # Assuming UI component is preferred
  module: Raxol.UI.Components.Input.TextInput,
  # Basic description, introspection will add more
  description: "A flexible text input component.",
  examples: [
    # Add examples later
  ],
  properties: [
    # Properties will be added by introspection
    # Example expected props: :value, :on_change, :placeholder, :type, :disabled
  ],
  tags: ["input", "form", "text"]
}
