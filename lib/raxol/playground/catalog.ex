defmodule Raxol.Playground.Catalog do
  @moduledoc """
  Component catalog for the Raxol Playground.

  Contains all available components with their examples, default props,
  and documentation.
  """

  @doc """
  Loads all available components.
  """
  def load_components do
    [
      # Text Components
      %{
        id: "text",
        name: "Text",
        category: :text,
        description: "Basic text display component",
        module: Raxol.UI.Text,
        default_props: %{
          content: "Hello, Raxol!",
          style: %{color: :default}
        },
        prop_types: %{
          content: :string,
          style: :map
        },
        examples: [
          %{
            name: "Basic Text",
            props: %{content: "Simple text display"}
          },
          %{
            name: "Colored Text",
            props: %{content: "Colored text", style: %{color: :blue}}
          },
          %{
            name: "Bold Text",
            props: %{content: "Bold text", style: %{bold: true}}
          }
        ]
      },
      %{
        id: "heading",
        name: "Heading",
        category: :text,
        description: "Heading component with levels",
        module: Raxol.UI.Heading,
        default_props: %{
          content: "Heading Text",
          level: 1
        },
        prop_types: %{
          content: :string,
          level: :integer
        },
        examples: [
          %{
            name: "H1",
            props: %{content: "Level 1 Heading", level: 1}
          },
          %{
            name: "H2",
            props: %{content: "Level 2 Heading", level: 2}
          },
          %{
            name: "H3",
            props: %{content: "Level 3 Heading", level: 3}
          }
        ]
      },
      %{
        id: "label",
        name: "Label",
        category: :text,
        description: "Label component for forms",
        module: Raxol.UI.Label,
        default_props: %{
          text: "Label:",
          for: "input"
        },
        prop_types: %{
          text: :string,
          for: :string
        },
        examples: [
          %{
            name: "Basic Label",
            props: %{text: "Username:"}
          },
          %{
            name: "Required Field",
            props: %{text: "Email:", required: true}
          }
        ]
      },

      # Input Components
      %{
        id: "text_input",
        name: "Text Input",
        category: :input,
        description: "Single-line text input field",
        module: Raxol.UI.TextInput,
        default_props: %{
          value: "",
          placeholder: "Enter text...",
          width: 30
        },
        default_state: %{
          value: "",
          cursor_position: 0
        },
        prop_types: %{
          value: :string,
          placeholder: :string,
          width: :integer,
          disabled: :boolean
        },
        examples: [
          %{
            name: "Basic Input",
            props: %{placeholder: "Type here..."}
          },
          %{
            name: "With Default Value",
            props: %{value: "Default text", placeholder: "Enter text"}
          },
          %{
            name: "Disabled Input",
            props: %{value: "Can't edit", disabled: true}
          }
        ]
      },
      %{
        id: "text_area",
        name: "Text Area",
        category: :input,
        description: "Multi-line text input",
        module: Raxol.UI.TextArea,
        default_props: %{
          value: "",
          placeholder: "Enter multiple lines...",
          rows: 5,
          cols: 40
        },
        default_state: %{
          value: "",
          cursor_position: {0, 0}
        },
        prop_types: %{
          value: :string,
          placeholder: :string,
          rows: :integer,
          cols: :integer
        },
        examples: [
          %{
            name: "Basic Text Area",
            props: %{rows: 3, cols: 30}
          },
          %{
            name: "With Content",
            props: %{
              value: "Line 1\nLine 2\nLine 3",
              rows: 5,
              cols: 40
            }
          }
        ]
      },
      %{
        id: "select",
        name: "Select Dropdown",
        category: :input,
        description: "Dropdown selection component",
        module: Raxol.UI.Select,
        default_props: %{
          options: ["Option 1", "Option 2", "Option 3"],
          selected: nil,
          placeholder: "Choose an option"
        },
        default_state: %{
          selected_index: 0,
          is_open: false
        },
        prop_types: %{
          options: :list,
          selected: :any,
          placeholder: :string
        },
        examples: [
          %{
            name: "Basic Select",
            props: %{
              options: ["Red", "Green", "Blue"],
              placeholder: "Select a color"
            }
          },
          %{
            name: "With Default",
            props: %{
              options: ["Small", "Medium", "Large"],
              selected: "Medium"
            }
          }
        ]
      },

      # Interactive Components
      %{
        id: "button",
        name: "Button",
        category: :interactive,
        description: "Clickable button component",
        module: Raxol.UI.Button,
        default_props: %{
          label: "Click Me",
          variant: :primary
        },
        prop_types: %{
          label: :string,
          variant: :atom,
          disabled: :boolean
        },
        examples: [
          %{
            name: "Primary Button",
            props: %{label: "Submit", variant: :primary}
          },
          %{
            name: "Secondary Button",
            props: %{label: "Cancel", variant: :secondary}
          },
          %{
            name: "Danger Button",
            props: %{label: "Delete", variant: :danger}
          },
          %{
            name: "Disabled Button",
            props: %{label: "Disabled", disabled: true}
          }
        ]
      },
      %{
        id: "checkbox",
        name: "Checkbox",
        category: :interactive,
        description: "Checkbox input component",
        module: Raxol.UI.Checkbox,
        default_props: %{
          label: "Check me",
          checked: false
        },
        default_state: %{
          checked: false
        },
        prop_types: %{
          label: :string,
          checked: :boolean,
          disabled: :boolean
        },
        examples: [
          %{
            name: "Unchecked",
            props: %{label: "Option 1", checked: false}
          },
          %{
            name: "Checked",
            props: %{label: "Option 2", checked: true}
          },
          %{
            name: "Disabled",
            props: %{label: "Can't change", checked: true, disabled: true}
          }
        ]
      },
      %{
        id: "radio",
        name: "Radio Button",
        category: :interactive,
        description: "Radio button group component",
        module: Raxol.UI.RadioGroup,
        default_props: %{
          options: ["Option A", "Option B", "Option C"],
          selected: nil
        },
        default_state: %{
          selected: nil
        },
        prop_types: %{
          options: :list,
          selected: :string
        },
        examples: [
          %{
            name: "Basic Radio Group",
            props: %{
              options: ["Yes", "No", "Maybe"],
              selected: "Yes"
            }
          }
        ]
      },
      %{
        id: "toggle",
        name: "Toggle Switch",
        category: :interactive,
        description: "Toggle switch component",
        module: Raxol.UI.Toggle,
        default_props: %{
          label: "Enable feature",
          enabled: false
        },
        default_state: %{
          enabled: false
        },
        prop_types: %{
          label: :string,
          enabled: :boolean
        },
        examples: [
          %{
            name: "Off State",
            props: %{label: "Dark Mode", enabled: false}
          },
          %{
            name: "On State",
            props: %{label: "Notifications", enabled: true}
          }
        ]
      },

      # Layout Components
      %{
        id: "box",
        name: "Box",
        category: :layout,
        description: "Container with borders and padding",
        module: Raxol.UI.Box,
        default_props: %{
          title: nil,
          border: :single,
          padding: 1,
          width: nil,
          height: nil
        },
        prop_types: %{
          title: :string,
          border: :atom,
          padding: :integer,
          width: :integer,
          height: :integer
        },
        examples: [
          %{
            name: "Simple Box",
            props: %{border: :single, padding: 1}
          },
          %{
            name: "Box with Title",
            props: %{title: "Settings", border: :double, padding: 2}
          },
          %{
            name: "Rounded Box",
            props: %{border: :rounded, padding: 1}
          }
        ]
      },
      %{
        id: "flex",
        name: "Flex Container",
        category: :layout,
        description: "Flexible layout container",
        module: Raxol.UI.Flex,
        default_props: %{
          direction: :horizontal,
          gap: 1,
          align: :start,
          justify: :start
        },
        prop_types: %{
          direction: :atom,
          gap: :integer,
          align: :atom,
          justify: :atom
        },
        examples: [
          %{
            name: "Horizontal Flex",
            props: %{direction: :horizontal, gap: 2}
          },
          %{
            name: "Vertical Flex",
            props: %{direction: :vertical, gap: 1}
          },
          %{
            name: "Centered Content",
            props: %{align: :center, justify: :center}
          }
        ]
      },
      %{
        id: "grid",
        name: "Grid Layout",
        category: :layout,
        description: "Grid-based layout container",
        module: Raxol.UI.Grid,
        default_props: %{
          columns: 3,
          rows: nil,
          gap: 1
        },
        prop_types: %{
          columns: :integer,
          rows: :integer,
          gap: :integer
        },
        examples: [
          %{
            name: "3-Column Grid",
            props: %{columns: 3, gap: 1}
          },
          %{
            name: "2x2 Grid",
            props: %{columns: 2, rows: 2, gap: 2}
          }
        ]
      },
      %{
        id: "tabs",
        name: "Tab Container",
        category: :layout,
        description: "Tabbed interface component",
        module: Raxol.UI.Tabs,
        default_props: %{
          tabs: [
            %{id: "tab1", label: "Tab 1"},
            %{id: "tab2", label: "Tab 2"},
            %{id: "tab3", label: "Tab 3"}
          ],
          active_tab: "tab1"
        },
        default_state: %{
          active_tab: "tab1"
        },
        prop_types: %{
          tabs: :list,
          active_tab: :string
        },
        examples: [
          %{
            name: "Basic Tabs",
            props: %{
              tabs: [
                %{id: "home", label: "Home"},
                %{id: "profile", label: "Profile"},
                %{id: "settings", label: "Settings"}
              ]
            }
          }
        ]
      },

      # Data Display Components
      %{
        id: "table",
        name: "Table",
        category: :data,
        description: "Data table component",
        module: Raxol.UI.Table,
        default_props: %{
          headers: ["ID", "Name", "Status"],
          rows: [
            ["1", "Item 1", "Active"],
            ["2", "Item 2", "Inactive"]
          ],
          border: true
        },
        prop_types: %{
          headers: :list,
          rows: :list,
          border: :boolean
        },
        examples: [
          %{
            name: "Basic Table",
            props: %{
              headers: ["Name", "Age", "City"],
              rows: [
                ["Alice", "30", "New York"],
                ["Bob", "25", "San Francisco"],
                ["Charlie", "35", "Chicago"]
              ]
            }
          }
        ]
      },
      %{
        id: "list",
        name: "List",
        category: :data,
        description: "List display component",
        module: Raxol.UI.List,
        default_props: %{
          items: ["Item 1", "Item 2", "Item 3"],
          ordered: false,
          marker: "•"
        },
        prop_types: %{
          items: :list,
          ordered: :boolean,
          marker: :string
        },
        examples: [
          %{
            name: "Unordered List",
            props: %{
              items: ["First item", "Second item", "Third item"],
              marker: "•"
            }
          },
          %{
            name: "Ordered List",
            props: %{
              items: ["Step 1", "Step 2", "Step 3"],
              ordered: true
            }
          }
        ]
      },
      %{
        id: "progress_bar",
        name: "Progress Bar",
        category: :data,
        description: "Progress indicator component",
        module: Raxol.UI.ProgressBar,
        default_props: %{
          value: 50,
          max: 100,
          width: 30,
          show_percentage: true
        },
        prop_types: %{
          value: :number,
          max: :number,
          width: :integer,
          show_percentage: :boolean
        },
        examples: [
          %{
            name: "50% Progress",
            props: %{value: 50, max: 100}
          },
          %{
            name: "Full Progress",
            props: %{value: 100, max: 100}
          },
          %{
            name: "Custom Width",
            props: %{value: 75, max: 100, width: 50}
          }
        ]
      },
      %{
        id: "spinner",
        name: "Loading Spinner",
        category: :data,
        description: "Animated loading indicator",
        module: Raxol.UI.Spinner,
        default_props: %{
          text: "Loading...",
          style: :dots
        },
        prop_types: %{
          text: :string,
          style: :atom
        },
        examples: [
          %{
            name: "Dots Spinner",
            props: %{text: "Loading...", style: :dots}
          },
          %{
            name: "Line Spinner",
            props: %{text: "Processing...", style: :line}
          },
          %{
            name: "Circle Spinner",
            props: %{text: "Please wait...", style: :circle}
          }
        ]
      },

      # Special Components
      %{
        id: "modal",
        name: "Modal Dialog",
        category: :special,
        description: "Modal overlay component",
        module: Raxol.UI.Modal,
        default_props: %{
          title: "Modal Title",
          visible: true,
          closable: true,
          width: 40,
          height: 20
        },
        prop_types: %{
          title: :string,
          visible: :boolean,
          closable: :boolean,
          width: :integer,
          height: :integer
        },
        examples: [
          %{
            name: "Basic Modal",
            props: %{
              title: "Confirmation",
              visible: true
            }
          },
          %{
            name: "Large Modal",
            props: %{
              title: "Details",
              width: 60,
              height: 30
            }
          }
        ]
      },
      %{
        id: "tooltip",
        name: "Tooltip",
        category: :special,
        description: "Tooltip/popover component",
        module: Raxol.UI.Tooltip,
        default_props: %{
          text: "Tooltip text",
          position: :top,
          visible: true
        },
        prop_types: %{
          text: :string,
          position: :atom,
          visible: :boolean
        },
        examples: [
          %{
            name: "Top Tooltip",
            props: %{text: "Help text", position: :top}
          },
          %{
            name: "Bottom Tooltip",
            props: %{text: "Info", position: :bottom}
          }
        ]
      }
    ]
  end

  @doc """
  Gets a component by ID.
  """
  def get_component(catalog, component_id) do
    Enum.find(catalog, &(&1.id == component_id))
  end

  @doc """
  Filters components by category.
  """
  def filter_by_category(catalog, category) do
    Enum.filter(catalog, &(&1.category == category))
  end

  @doc """
  Gets all categories.
  """
  def get_categories(catalog) do
    catalog
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Searches components by name or description.
  """
  def search(catalog, query) do
    lower_query = String.downcase(query)

    Enum.filter(catalog, fn component ->
      String.contains?(String.downcase(component.name), lower_query) ||
        String.contains?(String.downcase(component.description), lower_query)
    end)
  end
end
