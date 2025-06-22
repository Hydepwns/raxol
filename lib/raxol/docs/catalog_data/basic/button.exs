# Defining structs inline requires aliasing
alias Raxol.Docs.ComponentCatalog.{Component, Example}
# Also need view helper for preview_fn
import Raxol.View.Elements

%Component{
  id: "button",
  name: "Button",
  module: Raxol.UI.Components.Input.Button,
  description: "A standard button component for triggering actions.",
  examples: [
    %Example{
      id: "basic",
      title: "Basic Button",
      description: "A simple button with default styling.",
      code: """
      view do
        button(content: "Click me")
      end
      """,
      preview_fn: fn props ->
        label = props[:label] || "Click me"
        dsl_props = Map.drop(props, [:label]) |> Keyword.new()

        view do
          button(content: label, opts: dsl_props)
        end
      end,
      customizable_props: [
        %Property{
          name: :label,
          type: :string,
          description: "Button text",
          default_value: "Click me"
        },
        %Property{
          name: :on_click,
          type: :function,
          description: "Function called when clicked",
          default_value: nil
        },
        %Property{
          name: :disabled,
          type: :boolean,
          description: "Whether the button is disabled",
          default_value: false
        },
        %Property{
          name: :style,
          type: :atom,
          description: "Button style",
          default_value: :primary,
          options: [
            :primary,
            :secondary,
            :success,
            :danger,
            :warning,
            :info
          ]
        }
      ]
    },
    %Example{
      id: "icon_button",
      title: "Icon Button",
      description: "A button with an icon.",
      code: """
      view do
        button(content: "Save", icon: :save)
      end
      """,
      preview_fn: fn props ->
        label = props[:label] || "Save"
        icon = props[:icon] || :save
        dsl_props = Map.drop(props, [:label, :icon]) |> Keyword.new()

        view do
          button(content: label, icon: icon, opts: dsl_props)
        end
      end,
      customizable_props: [
        %Property{
          name: :label,
          type: :string,
          description: "Button text",
          default_value: "Save"
        },
        %Property{
          name: :icon,
          type: :atom,
          description: "Icon to display",
          default_value: :save,
          options: [:save, :delete, :edit, :add, :cancel, :search]
        }
      ]
    }
  ],
  properties: [
    %Property{
      name: :label,
      type: :string,
      required: true
    },
    %Property{
      name: :on_click,
      type: :function,
      required: false
    },
    %Property{
      name: :disabled,
      type: :boolean,
      default_value: false,
      required: false
    },
    %Property{
      name: :style,
      type: :atom,
      default_value: :primary,
      options: [:primary, :secondary, :success, :danger, :warning, :info],
      required: false
    },
    %Property{
      name: :icon,
      type: :atom,
      required: false
    },
    %Property{
      name: :icon_position,
      type: :atom,
      default_value: :left,
      options: [:left, :right],
      required: false
    },
    %Property{
      name: :size,
      type: :atom,
      default_value: :medium,
      options: [:small, :medium, :large],
      required: false
    },
    %Property{
      name: :full_width,
      type: :boolean,
      default_value: false,
      required: false
    },
    %Property{
      name: :id,
      type: :string,
      required: false
    }
  ],
  accessibility: %{
    role: "button",
    aria_attributes: ["aria-disabled", "aria-pressed", "aria-expanded"],
    keyboard_support: ["Enter", "Space"],
    screen_reader_text: "Announces the button label when focused",
    high_contrast:
      "Uses high-contrast styles when high-contrast mode is enabled",
    best_practices: [
      "Use clear and concise labels",
      "Avoid using generic labels like \"Click here\"",
      "Use appropriate button styles to indicate purpose"
    ]
  },
  related_components: ["link_button", "icon_button", "dropdown_button"],
  tags: ["input", "interactive", "action", "basic"],
  metadata: %{
    added_in_version: "0.1.0",
    last_updated: "0.1.2"
  }
}
