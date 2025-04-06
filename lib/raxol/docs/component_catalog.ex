defmodule Raxol.Docs.ComponentCatalog do
  @moduledoc """
  Visual component catalog for Raxol documentation.

  This module provides a comprehensive catalog of all UI components
  available in Raxol, with visual examples, code snippets, and interactive
  customization capabilities.

  Features:
  * Categorized components listing
  * Live examples with code snippets
  * Interactive property customization
  * Accessibility information
  * Related components suggestions
  * Search functionality
  """

  # Component category
  defmodule Category do
    @moduledoc false
    defstruct [
      :id,
      :name,
      :description,
      :components
    ]
  end

  # Component entry
  defmodule Component do
    @moduledoc false
    defstruct [
      :id,
      :name,
      :module,
      :description,
      :examples,
      :properties,
      :accessibility,
      :related_components,
      :tags,
      :metadata
    ]
  end

  # Component example
  defmodule Example do
    @moduledoc false
    defstruct [
      :id,
      :title,
      :description,
      :code,
      :preview_fn,
      :customizable_props
    ]
  end

  # Property definition
  defmodule Property do
    @moduledoc false
    defstruct [
      :name,
      :type,
      :description,
      :default_value,
      :required,
      :options,
      :examples
    ]
  end

  # Process dictionary key for catalog state
  @catalog_key :raxol_component_catalog

  @doc """
  Initializes the component catalog.
  """
  def init do
    catalog = build_catalog()
    Process.put(@catalog_key, catalog)
    :ok
  end

  @doc """
  Lists all component categories.
  """
  def list_categories do
    catalog = get_catalog()
    Map.values(catalog)
  end

  @doc """
  Gets a specific category by ID.
  """
  def get_category(category_id) do
    catalog = get_catalog()
    Map.get(catalog, category_id)
  end

  @doc """
  Lists all components in a specific category.
  """
  def list_components(category_id) do
    catalog = get_catalog()

    case Map.get(catalog, category_id) do
      nil -> []
      category -> category.components
    end
  end

  @doc """
  Gets a specific component by ID.
  """
  def get_component(component_id) do
    catalog = get_catalog()

    Enum.find_value(catalog, fn {_, category} ->
      Enum.find(category.components, fn component ->
        component.id == component_id
      end)
    end)
  end

  @doc """
  Searches for components based on a query.
  """
  def search(query) do
    catalog = get_catalog()
    query_downcase = String.downcase(query)

    # Search in all categories and components
    Enum.flat_map(catalog, fn {_, category} ->
      Enum.filter(category.components, fn component ->
        # Search in name, description, and tags
        String.contains?(String.downcase(component.name), query_downcase) ||
        String.contains?(String.downcase(component.description), query_downcase) ||
        Enum.any?(component.tags, fn tag ->
          String.contains?(String.downcase(tag), query_downcase)
        end)
      end)
    end)
  end

  @doc """
  Renders a component example.
  """
  def render_example(component_id, example_id, custom_props \\ %{}) do
    component = get_component(component_id)

    if component do
      example = Enum.find(component.examples, fn example ->
        example.id == example_id
      end)

      if example do
        # Call the preview function with custom props
        example.preview_fn.(custom_props)
      else
        {:error, "Example not found"}
      end
    else
      {:error, "Component not found"}
    end
  end

  @doc """
  Gets usage statistics for components.
  """
  def get_usage_stats do
    # This would typically be gathered from actual usage data
    %{
      most_used: [
        "button",
        "panel",
        "text_input",
        "dropdown",
        "table"
      ],
      recently_added: [
        "color_picker",
        "accordion",
        "progress_bar",
        "tabs",
        "toast"
      ],
      trending: [
        "card",
        "sidebar",
        "form",
        "modal",
        "menu"
      ]
    }
  end

  @doc """
  Generates code snippets for a component with the given properties.
  """
  def generate_code_snippet(component_id, props \\ %{}) do
    component = get_component(component_id)

    if component do
      module_name = component.module |> to_string() |> String.replace("Elixir.", "")

      # Generate props string
      props_str = props
                  |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
                  |> Enum.join(", ")

      # Basic snippet for simple components
      """
      #{module_name}.#{component.id}(#{if props_str != "", do: props_str})
      """
    else
      {:error, "Component not found"}
    end
  end

  @doc """
  Gets accessibility information for a component.
  """
  def get_accessibility_info(component_id) do
    component = get_component(component_id)

    if component do
      component.accessibility
    else
      {:error, "Component not found"}
    end
  end

  @doc """
  Suggests related components.
  """
  def suggest_related_components(component_id) do
    component = get_component(component_id)

    if component do
      # Get the related component IDs
      related_ids = component.related_components

      # Fetch the actual components
      related_ids
      |> Enum.map(&get_component/1)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  # Private helpers

  defp get_catalog do
    Process.get(@catalog_key) || build_catalog()
  end

  defp build_catalog do
    # Basic components
    basic_components = [
      %Component{
        id: "button",
        name: "Button",
        module: Raxol.Components.Button,
        description: "A standard button component for triggering actions.",
        examples: [
          %Example{
            id: "basic",
            title: "Basic Button",
            description: "A simple button with default styling.",
            code: "Components.button(\"Click me\")",
            preview_fn: fn props ->
              Raxol.Components.Button.new(props[:label] || "Click me", Map.drop(props, [:label]))
            end,
            customizable_props: [
              %Property{name: :label, type: :string, description: "Button text", default_value: "Click me"},
              %Property{name: :on_click, type: :function, description: "Function called when clicked", default_value: nil},
              %Property{name: :disabled, type: :boolean, description: "Whether the button is disabled", default_value: false},
              %Property{name: :style, type: :atom, description: "Button style", default_value: :primary, options: [:primary, :secondary, :success, :danger, :warning, :info]}
            ]
          },
          %Example{
            id: "icon_button",
            title: "Icon Button",
            description: "A button with an icon.",
            code: "Components.button(\"Save\", icon: :save)",
            preview_fn: fn props ->
              Raxol.Components.Button.new(props[:label] || "Save", Map.merge(%{icon: props[:icon] || :save}, Map.drop(props, [:label, :icon])))
            end,
            customizable_props: [
              %Property{name: :label, type: :string, description: "Button text", default_value: "Save"},
              %Property{name: :icon, type: :atom, description: "Icon to display", default_value: :save, options: [:save, :delete, :edit, :add, :cancel, :search]}
            ]
          }
        ],
        properties: [
          %Property{name: :label, type: :string, description: "Text to display on the button", required: true},
          %Property{name: :on_click, type: :function, description: "Function called when the button is clicked", required: false},
          %Property{name: :disabled, type: :boolean, description: "Whether the button is disabled", default_value: false, required: false},
          %Property{name: :style, type: :atom, description: "Button style variant", default_value: :primary, options: [:primary, :secondary, :success, :danger, :warning, :info], required: false},
          %Property{name: :icon, type: :atom, description: "Icon to display next to the text", required: false},
          %Property{name: :icon_position, type: :atom, description: "Position of the icon", default_value: :left, options: [:left, :right], required: false},
          %Property{name: :size, type: :atom, description: "Button size", default_value: :medium, options: [:small, :medium, :large], required: false},
          %Property{name: :full_width, type: :boolean, description: "Whether the button should take full width", default_value: false, required: false},
          %Property{name: :id, type: :string, description: "Unique identifier for the button", required: false}
        ],
        accessibility: %{
          role: "button",
          aria_attributes: ["aria-disabled", "aria-pressed", "aria-expanded"],
          keyboard_support: ["Enter", "Space"],
          screen_reader_text: "Announces the button label when focused",
          high_contrast: "Uses high-contrast styles when high-contrast mode is enabled",
          best_practices: [
            "Use clear and concise labels",
            "Avoid using generic labels like 'Click here'",
            "Use appropriate button styles to indicate purpose"
          ]
        },
        related_components: ["link_button", "icon_button", "dropdown_button"],
        tags: ["input", "interactive", "action", "basic"],
        metadata: %{
          added_in_version: "0.1.0",
          last_updated: "0.1.2"
        }
      },
      %Component{
        id: "text_input",
        name: "Text Input",
        module: Raxol.Components.TextInput,
        description: "A text input field for single-line text input.",
        examples: [
          %Example{
            id: "basic",
            title: "Basic Text Input",
            description: "A simple text input with default styling.",
            code: "Components.text_input(placeholder: \"Enter your name\")",
            preview_fn: fn props ->
              # Assuming ExampleComponent.TextInput.render exists and handles props
              # Placeholder: Render the props map for now
              # ExampleComponent.TextInput.render(props, do: [IO.inspect(props, label: "TextInput Props")])
              Raxol.Components.TextInput.new(props) # Use new/1 instead of text_input/1
            end,
            customizable_props: [
              %Property{name: :value, type: :string, description: "Current input value", default_value: ""},
              %Property{name: :placeholder, type: :string, description: "Placeholder text", default_value: "Enter your name"},
              %Property{name: :disabled, type: :boolean, description: "Whether the input is disabled", default_value: false}
            ]
          }
        ],
        properties: [
          %Property{name: :value, type: :string, description: "Current value of the input", required: false},
          %Property{name: :placeholder, type: :string, description: "Placeholder text when input is empty", required: false},
          %Property{name: :on_change, type: :function, description: "Function called when the value changes", required: false},
          %Property{name: :on_submit, type: :function, description: "Function called when Enter is pressed", required: false},
          %Property{name: :disabled, type: :boolean, description: "Whether the input is disabled", default_value: false, required: false},
          %Property{name: :type, type: :atom, description: "Input type", default_value: :text, options: [:text, :password, :number, :email], required: false},
          %Property{name: :id, type: :string, description: "Unique identifier for the input", required: false},
          %Property{name: :label, type: :string, description: "Label for the input", required: false},
          %Property{name: :error, type: :string, description: "Error message to display", required: false}
        ],
        accessibility: %{
          role: "textbox",
          aria_attributes: ["aria-disabled", "aria-required", "aria-invalid", "aria-describedby"],
          keyboard_support: ["Tab", "Shift+Tab", "Enter"],
          screen_reader_text: "Announces the input label, placeholder, and current value",
          high_contrast: "Uses high-contrast styles when high-contrast mode is enabled",
          best_practices: [
            "Always provide a label",
            "Use placeholder text as supplementary information, not as a replacement for labels",
            "Provide clear error messages when validation fails"
          ]
        },
        related_components: ["textarea", "number_input", "password_input", "form"],
        tags: ["input", "interactive", "form", "basic"],
        metadata: %{
          added_in_version: "0.1.0",
          last_updated: "0.1.2"
        }
      }
    ]

    # Layout components
    layout_components = [
      %Component{
        id: "panel",
        name: "Panel",
        module: Raxol.Components.Panel,
        description: "A container component for grouping related UI elements.",
        examples: [
          %Example{
            id: "basic",
            title: "Basic Panel",
            description: "A simple panel with default styling.",
            code: """
            Components.panel do
              Components.title("Panel Title")
              Components.text("Panel content goes here.")
            end
            """,
            preview_fn: fn props ->
              # Raxol.Components.Panel.panel(props, do: [
              #   Raxol.Components.Title.title(props[:title] || "Panel Title"),
              #   Raxol.Components.Text.text(props[:content] || "Panel content goes here.")
              # ])
              # Placeholder until components are confirmed available
              IO.inspect(props, label: "Panel Props")
            end,
            customizable_props: [
              %Property{name: :title, type: :string, description: "Panel title", default_value: "Panel Title"},
              %Property{name: :style, type: :atom, description: "Panel style", default_value: :default, options: [:default, :primary, :secondary, :bordered, :none]}
            ]
          }
        ],
        properties: [
          %Property{name: :title, type: :string, description: "Title of the panel", required: false},
          %Property{name: :style, type: :atom, description: "Panel style variant", default_value: :default, options: [:default, :primary, :secondary, :bordered, :none], required: false},
          %Property{name: :padding, type: :atom, description: "Padding inside the panel", default_value: :medium, options: [:none, :small, :medium, :large], required: false},
          %Property{name: :border, type: :boolean, description: "Whether to show a border", default_value: true, required: false},
          %Property{name: :shadow, type: :boolean, description: "Whether to show a shadow", default_value: false, required: false},
          %Property{name: :id, type: :string, description: "Unique identifier for the panel", required: false}
        ],
        accessibility: %{
          role: "region",
          aria_attributes: ["aria-labelledby"],
          keyboard_support: [],
          screen_reader_text: "If a title is provided, it will be announced as the region label",
          high_contrast: "Uses high-contrast styles when high-contrast mode is enabled",
          best_practices: [
            "Always provide a title for the panel",
            "Group related content within panels",
            "Use consistent styling for similar panels"
          ]
        },
        related_components: ["card", "box", "container", "grid"],
        tags: ["layout", "container", "grouping", "structure"],
        metadata: %{
          added_in_version: "0.1.0",
          last_updated: "0.1.1"
        }
      }
    ]

    # Build the complete catalog
    %{
      "basic" => %Category{
        id: "basic",
        name: "Basic Components",
        description: "Fundamental UI components for building interfaces",
        components: basic_components
      },
      "layout" => %Category{
        id: "layout",
        name: "Layout Components",
        description: "Components for structuring and organizing content",
        components: layout_components
      }
      # More categories would be defined here
    }
  end
end
