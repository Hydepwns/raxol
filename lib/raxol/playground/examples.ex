defmodule Raxol.Playground.Examples do
  @moduledoc """
  Interactive examples and guided tours for the Raxol Playground.

  This module provides preset examples and interactive tutorials that showcase
  different component capabilities and use cases.
  """

  @doc """
  Gets all available examples organized by category.
  """
  def get_examples do
    %{
      beginner: [
        hello_world_example(),
        button_variations_example(),
        text_styling_example()
      ],
      intermediate: [
        form_components_example(),
        layout_patterns_example(),
        data_display_example()
      ],
      advanced: [
        interactive_dashboard_example(),
        custom_themes_example(),
        component_composition_example()
      ],
      showcase: [
        complete_ui_example(),
        responsive_design_example(),
        animation_demo_example()
      ]
    }
  end

  @doc """
  Runs an interactive example by ID.
  """
  def run_example(example_id) do
    examples = get_all_examples()

    case Enum.find(examples, &(&1.id == example_id)) do
      nil ->
        {:error, "Example not found: #{example_id}"}

      example ->
        run_interactive_example(example)
    end
  end

  @doc """
  Lists all available examples.
  """
  def list_examples do
    get_examples()
    |> Enum.map(fn {category, examples} ->
      {category, Enum.map(examples, &Map.take(&1, [:id, :title, :description]))}
    end)
    |> Map.new()
  end

  # Beginner Examples

  defp hello_world_example do
    %{
      id: "hello_world",
      title: "Hello World",
      description: "Your first Raxol component",
      difficulty: :beginner,
      estimated_time: 2,
      component_id: "text",
      initial_props: %{content: "Hello, Raxol!"},
      steps: [
        %{
          instruction:
            "This is a basic text component displaying 'Hello, Raxol!'",
          action: :preview
        },
        %{
          instruction: "Let's change the text color to blue",
          action: {:set_prop, :style, %{color: :blue}}
        },
        %{
          instruction: "Now make it bold",
          action: {:set_prop, :style, %{color: :blue, bold: true}}
        },
        %{
          instruction: "Perfect! You've styled your first component.",
          action: :complete
        }
      ]
    }
  end

  defp button_variations_example do
    %{
      id: "button_variations",
      title: "Button Variations",
      description: "Explore different button styles and variants",
      difficulty: :beginner,
      estimated_time: 5,
      component_id: "button",
      initial_props: %{label: "Click Me"},
      steps: [
        %{
          instruction:
            "Here's a default button. Let's explore different variants.",
          action: :preview
        },
        %{
          instruction: "Change to a primary button",
          action: {:set_prop, :variant, :primary}
        },
        %{
          instruction: "Try a danger button for destructive actions",
          action: {:set_prop, :variant, :danger}
        },
        %{
          instruction: "Secondary buttons are great for less important actions",
          action: {:set_prop, :variant, :secondary}
        },
        %{
          instruction: "You can also disable buttons",
          action: {:set_prop, :disabled, true}
        },
        %{
          instruction: "Great! You've learned about button variants.",
          action: :complete
        }
      ]
    }
  end

  defp text_styling_example do
    %{
      id: "text_styling",
      title: "Text Styling",
      description: "Learn various text styling options",
      difficulty: :beginner,
      estimated_time: 4,
      component_id: "text",
      initial_props: %{content: "Styleable Text"},
      steps: [
        %{
          instruction: "Let's explore different text styling options",
          action: :preview
        },
        %{
          instruction: "Make the text red and bold",
          action: {:set_prop, :style, %{color: :red, bold: true}}
        },
        %{
          instruction: "Add italics to the mix",
          action: {:set_prop, :style, %{color: :red, bold: true, italic: true}}
        },
        %{
          instruction: "Underline can be added too",
          action:
            {:set_prop, :style,
             %{color: :red, bold: true, italic: true, underline: true}}
        },
        %{
          instruction: "You've mastered text styling!",
          action: :complete
        }
      ]
    }
  end

  # Intermediate Examples

  defp form_components_example do
    %{
      id: "form_components",
      title: "Form Components",
      description: "Build interactive forms with various input types",
      difficulty: :intermediate,
      estimated_time: 10,
      sequence: [
        %{
          component_id: "text_input",
          props: %{placeholder: "Enter your name", width: 25},
          instruction: "Text inputs are perfect for single-line data entry"
        },
        %{
          component_id: "text_area",
          props: %{placeholder: "Enter your message", rows: 4, cols: 30},
          instruction: "Text areas handle multi-line input"
        },
        %{
          component_id: "select",
          props: %{
            options: ["Red", "Green", "Blue"],
            placeholder: "Choose a color"
          },
          instruction: "Dropdowns let users select from predefined options"
        },
        %{
          component_id: "checkbox",
          props: %{label: "I agree to the terms", checked: false},
          instruction: "Checkboxes are great for boolean choices"
        }
      ]
    }
  end

  defp layout_patterns_example do
    %{
      id: "layout_patterns",
      title: "Layout Patterns",
      description: "Master Raxol's layout system with boxes, flex, and grid",
      difficulty: :intermediate,
      estimated_time: 8,
      sequence: [
        %{
          component_id: "box",
          props: %{title: "Welcome", border: :single, padding: 2},
          instruction: "Boxes create containers with borders and padding"
        },
        %{
          component_id: "flex",
          props: %{direction: :horizontal, gap: 2},
          instruction: "Flex layouts arrange items horizontally or vertically"
        },
        %{
          component_id: "grid",
          props: %{columns: 3, gap: 1},
          instruction: "Grids create structured layouts with rows and columns"
        }
      ]
    }
  end

  defp data_display_example do
    %{
      id: "data_display",
      title: "Data Display",
      description: "Present data with tables, lists, and progress indicators",
      difficulty: :intermediate,
      estimated_time: 12,
      sequence: [
        %{
          component_id: "table",
          props: %{
            headers: ["Name", "Age", "City"],
            rows: [
              ["Alice", "30", "New York"],
              ["Bob", "25", "San Francisco"],
              ["Charlie", "35", "Chicago"]
            ]
          },
          instruction: "Tables organize data in rows and columns"
        },
        %{
          component_id: "list",
          props: %{
            items: ["First item", "Second item", "Third item"],
            ordered: false,
            marker: "•"
          },
          instruction: "Lists display items in sequence"
        },
        %{
          component_id: "progress_bar",
          props: %{value: 75, max: 100, width: 30},
          instruction: "Progress bars show completion status"
        }
      ]
    }
  end

  # Advanced Examples

  defp interactive_dashboard_example do
    %{
      id: "interactive_dashboard",
      title: "Interactive Dashboard",
      description: "Build a complete dashboard with multiple components",
      difficulty: :advanced,
      estimated_time: 20,
      composition: true,
      components: [
        %{
          component_id: "heading",
          props: %{content: "System Dashboard", level: 1},
          position: {0, 0}
        },
        %{
          component_id: "box",
          props: %{title: "Server Status", border: :double},
          position: {0, 2}
        },
        %{
          component_id: "progress_bar",
          props: %{value: 85, max: 100, width: 25},
          position: {2, 4}
        },
        %{
          component_id: "table",
          props: %{
            headers: ["Service", "Status", "Uptime"],
            rows: [
              ["API", "Running", "99.9%"],
              ["Database", "Running", "99.8%"],
              ["Cache", "Warning", "98.1%"]
            ]
          },
          position: {0, 6}
        }
      ]
    }
  end

  defp custom_themes_example do
    %{
      id: "custom_themes",
      title: "Custom Themes",
      description: "Learn to create and apply custom themes",
      difficulty: :advanced,
      estimated_time: 15,
      component_id: "button",
      initial_props: %{label: "Themed Button"},
      themes: [
        %{name: "Ocean", colors: %{primary: :cyan, background: :blue}},
        %{name: "Forest", colors: %{primary: :green, background: :black}},
        %{name: "Sunset", colors: %{primary: :red, background: :yellow}}
      ],
      steps: [
        %{
          instruction: "Let's explore custom theming with this button",
          action: :preview
        },
        %{
          instruction: "Apply the Ocean theme",
          action: {:apply_theme, "Ocean"}
        },
        %{
          instruction: "Switch to the Forest theme",
          action: {:apply_theme, "Forest"}
        },
        %{
          instruction: "Try the Sunset theme",
          action: {:apply_theme, "Sunset"}
        }
      ]
    }
  end

  defp component_composition_example do
    %{
      id: "component_composition",
      title: "Component Composition",
      description: "Combine multiple components into complex UIs",
      difficulty: :advanced,
      estimated_time: 18,
      composition: true,
      instruction: "Learn to combine components for rich user interfaces",
      layout: :form,
      components: [
        %{
          component_id: "heading",
          props: %{content: "User Registration", level: 2}
        },
        %{
          component_id: "text_input",
          props: %{placeholder: "Full Name", width: 30}
        },
        %{
          component_id: "text_input",
          props: %{placeholder: "Email Address", width: 30}
        },
        %{
          component_id: "text_area",
          props: %{placeholder: "Bio (optional)", rows: 3, cols: 30}
        },
        %{
          component_id: "checkbox",
          props: %{label: "Subscribe to newsletter", checked: true}
        },
        %{
          component_id: "button",
          props: %{label: "Create Account", variant: :primary}
        }
      ]
    }
  end

  # Showcase Examples

  defp complete_ui_example do
    %{
      id: "complete_ui",
      title: "Complete UI Showcase",
      description:
        "A full-featured interface demonstrating all component types",
      difficulty: :advanced,
      estimated_time: 25,
      showcase: true,
      layout: :dashboard,
      sections: [
        %{
          title: "Navigation",
          components: [
            %{
              component_id: "tabs",
              props: %{
                tabs: [
                  %{id: "home", label: "Home"},
                  %{id: "profile", label: "Profile"},
                  %{id: "settings", label: "Settings"}
                ],
                active_tab: "home"
              }
            }
          ]
        },
        %{
          title: "Content",
          components: [
            %{
              component_id: "heading",
              props: %{content: "Welcome Dashboard", level: 1}
            },
            %{
              component_id: "text",
              props: %{content: "Monitor your system status and metrics"}
            },
            %{
              component_id: "progress_bar",
              props: %{value: 78, max: 100, width: 40}
            }
          ]
        },
        %{
          title: "Data",
          components: [
            %{
              component_id: "table",
              props: %{
                headers: ["Metric", "Current", "Target", "Status"],
                rows: [
                  ["CPU Usage", "45%", "< 80%", "✓"],
                  ["Memory", "67%", "< 85%", "✓"],
                  ["Storage", "89%", "< 90%", "⚠"],
                  ["Network", "12%", "< 70%", "✓"]
                ]
              }
            }
          ]
        }
      ]
    }
  end

  defp responsive_design_example do
    %{
      id: "responsive_design",
      title: "Responsive Design",
      description: "Create layouts that adapt to different terminal sizes",
      difficulty: :advanced,
      estimated_time: 15,
      responsive: true,
      breakpoints: [
        %{width: 40, layout: :mobile},
        %{width: 80, layout: :tablet},
        %{width: 120, layout: :desktop}
      ]
    }
  end

  defp animation_demo_example do
    %{
      id: "animation_demo",
      title: "Animation Demo",
      description: "Showcase animated components and transitions",
      difficulty: :advanced,
      estimated_time: 10,
      animated: true,
      components: [
        %{
          component_id: "spinner",
          props: %{text: "Loading data...", style: :dots}
        },
        %{
          component_id: "progress_bar",
          props: %{value: 0, max: 100, animated: true}
        }
      ]
    }
  end

  # Helper Functions

  defp get_all_examples do
    get_examples()
    |> Enum.flat_map(fn {_category, examples} -> examples end)
  end

  defp run_interactive_example(example) do
    IO.puts("""

    #{IO.ANSI.bright()}🎯 #{example.title}#{IO.ANSI.reset()}
    #{String.duplicate("─", String.length(example.title) + 5)}

    #{example.description}

    #{IO.ANSI.light_black()}Difficulty: #{example.difficulty} | Estimated time: #{example.estimated_time} minutes#{IO.ANSI.reset()}

    Press Enter to start...
    """)

    IO.gets("")

    case example do
      %{steps: steps} ->
        run_step_by_step_example(example, steps)

      %{sequence: sequence} ->
        run_sequence_example(example, sequence)

      %{composition: true} ->
        run_composition_example(example)

      _ ->
        run_simple_example(example)
    end
  end

  defp run_step_by_step_example(example, steps) do
    # Select the initial component
    Raxol.Playground.select_component(example.component_id)

    if Map.has_key?(example, :initial_props) do
      Raxol.Playground.update_props(example.initial_props)
    end

    Enum.with_index(steps, 1)
    |> Enum.each(fn {step, index} ->
      IO.puts(
        "\n#{IO.ANSI.bright()}Step #{index}:#{IO.ANSI.reset()} #{step.instruction}"
      )

      case step.action do
        :preview ->
          {:ok, preview} = Raxol.Playground.get_preview()
          IO.puts("\n#{preview}")

        {:set_prop, prop, value} ->
          Raxol.Playground.update_props(%{prop => value})
          {:ok, preview} = Raxol.Playground.get_preview()
          IO.puts("\n#{preview}")

        :complete ->
          IO.puts("\n#{IO.ANSI.green()}✨ Example completed!#{IO.ANSI.reset()}")

        _ ->
          :ok
      end

      if step.action != :complete do
        IO.gets("\nPress Enter to continue...")
      end
    end)
  end

  defp run_sequence_example(_example, sequence) do
    Enum.with_index(sequence, 1)
    |> Enum.each(fn {step, index} ->
      IO.puts(
        "\n#{IO.ANSI.bright()}Component #{index}: #{String.capitalize(to_string(step.component_id))}#{IO.ANSI.reset()}"
      )

      IO.puts("#{step.instruction}")

      Raxol.Playground.select_component(step.component_id)
      Raxol.Playground.update_props(step.props)

      {:ok, preview} = Raxol.Playground.get_preview()
      IO.puts("\n#{preview}")

      if index < length(sequence) do
        IO.gets("\nPress Enter to continue...")
      end
    end)

    IO.puts("\n#{IO.ANSI.green()}✨ Sequence completed!#{IO.ANSI.reset()}")
  end

  defp run_composition_example(example) do
    IO.puts(
      "\n#{IO.ANSI.bright()}Building composed interface...#{IO.ANSI.reset()}\n"
    )

    example.components
    |> Enum.with_index(1)
    |> Enum.each(fn {component, index} ->
      IO.puts(
        "#{IO.ANSI.cyan()}[#{index}] #{String.capitalize(to_string(component.component_id))}#{IO.ANSI.reset()}"
      )

      Raxol.Playground.select_component(component.component_id)
      Raxol.Playground.update_props(component.props)

      {:ok, preview} = Raxol.Playground.get_preview()
      IO.puts(preview)
      IO.puts("")
    end)

    IO.puts(
      "#{IO.ANSI.green()}✨ Composition example completed!#{IO.ANSI.reset()}"
    )
  end

  defp run_simple_example(example) do
    if Map.has_key?(example, :component_id) do
      Raxol.Playground.select_component(example.component_id)

      if Map.has_key?(example, :initial_props) do
        Raxol.Playground.update_props(example.initial_props)
      end

      {:ok, preview} = Raxol.Playground.get_preview()
      IO.puts("\n#{preview}")
    end

    IO.puts("\n#{IO.ANSI.green()}✨ Example completed!#{IO.ANSI.reset()}")
  end
end
