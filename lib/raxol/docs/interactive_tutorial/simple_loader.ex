defmodule Raxol.Docs.InteractiveTutorial.SimpleLoader do
  @moduledoc """
  Simple tutorial loader that creates tutorials from code.
  """

  alias Raxol.Docs.InteractiveTutorial.Models.{Tutorial, Step}

  @doc """
  Loads predefined tutorials.
  """
  def load_tutorials do
    [
      getting_started_tutorial(),
      component_deep_dive_tutorial(),
      terminal_emulation_tutorial()
    ]
  end

  defp getting_started_tutorial do
    %Tutorial{
      id: "getting_started",
      title: "Getting Started with Raxol",
      description: "Learn the basics of Raxol terminal framework",
      tags: ["basics", "introduction", "setup"],
      difficulty: :beginner,
      estimated_time: 15,
      prerequisites: [],
      steps: [
        %Step{
          id: "architecture_overview",
          title: "Understanding the Architecture",
          content: """
          Raxol is built with a modular architecture consisting of:

          - Terminal Emulator: Handles ANSI escape sequences
          - Component System: React-style components for UIs
          - Event System: Manages keyboard and mouse events
          - Rendering Pipeline: Efficient rendering with caching
          """,
          example_code: """
          defmodule MyApp do
            use Raxol.Application
            
            def init(_args) do
              {:ok, %{counter: 0}}
            end
            
            def render(state) do
              Raxol.UI.view do
                Raxol.UI.text("Counter: \#{state.counter}")
                Raxol.UI.button("Increment", on_click: :increment)
              end
            end
          end
          """,
          exercise: %{
            description: "Create a simple counter application"
          },
          validation: fn code ->
            String.contains?(code, "counter") &&
              String.contains?(code, "increment")
          end,
          hints: [
            "Use Raxol.UI.button/2 for interactive buttons",
            "Handle events with handle_event/2",
            "Update state immutably"
          ],
          next_steps: ["components_basics"],
          interactive_elements: []
        },
        %Step{
          id: "components_basics",
          title: "Working with Components",
          content: """
          Raxol provides a rich set of built-in components:

          - Text Components: text, label, heading
          - Input Components: text_input, text_area, select
          - Layout Components: box, flex, grid
          - Interactive Components: button, checkbox, radio
          """,
          example_code: """
          defmodule TodoList do
            use Raxol.Component
            
            def render(state, _props) do
              Raxol.UI.box(border: :single) do
                Raxol.UI.heading("Todo List")
                Raxol.UI.text_input(value: state.input)
                Raxol.UI.list(state.todos)
              end
            end
          end
          """,
          exercise: %{
            description: "Build a todo list component"
          },
          validation: nil,
          hints: [
            "Use Raxol.UI.list/2 to render lists",
            "Store todos as a list of maps",
            "Use Raxol.UI.checkbox/2 for completion status"
          ],
          next_steps: [],
          interactive_elements: []
        }
      ],
      metadata: %{}
    }
  end

  defp component_deep_dive_tutorial do
    %Tutorial{
      id: "component_deep_dive",
      title: "Deep Dive into Raxol Components",
      description: "In-depth exploration of Raxol's component architecture",
      tags: ["components", "lifecycle", "state", "props"],
      difficulty: :intermediate,
      estimated_time: 25,
      prerequisites: ["getting_started"],
      steps: [
        %Step{
          id: "component_lifecycle",
          title: "Understanding Component Lifecycle",
          content: """
          Raxol components follow a predictable lifecycle:

          1. Initialization: Component is created and mounted
          2. Rendering: Component generates UI
          3. Updates: State or props change trigger re-renders
          4. Cleanup: Component is unmounted
          """,
          example_code: """
          defmodule LifecycleDemo do
            use Raxol.Component
            
            @impl true
            def init(props) do
              timer_ref = :timer.send_interval(1000, self(), :tick)
              {:ok, %{timer_ref: timer_ref, counter: 0}}
            end
            
            @impl true
            def terminate(_reason, state) do
              :timer.cancel(state.timer_ref)
              :ok
            end
          end
          """,
          exercise: nil,
          validation: nil,
          hints: ["Track lifecycle events in state"],
          next_steps: [],
          interactive_elements: []
        }
      ],
      metadata: %{}
    }
  end

  defp terminal_emulation_tutorial do
    %Tutorial{
      id: "terminal_emulation",
      title: "Terminal Emulation and ANSI Sequences",
      description: "Master Raxol's terminal emulation features",
      tags: ["terminal", "ansi", "escape-sequences"],
      difficulty: :intermediate,
      estimated_time: 20,
      prerequisites: ["getting_started"],
      steps: [
        %Step{
          id: "ansi_basics",
          title: "ANSI Escape Sequence Fundamentals",
          content: """
          ANSI escape sequences control terminal display:

          - ESC[: Control Sequence Introducer (CSI)
          - SGR: Select Graphic Rendition (colors, styles)
          - Cursor Control: Movement and positioning
          - Screen Control: Clearing, scrolling
          """,
          example_code: """
          # Basic colors
          IO.puts("\\e[31mRed text\\e[0m")
          IO.puts("\\e[32mGreen text\\e[0m")
          IO.puts("\\e[34mBlue text\\e[0m")
          """,
          exercise: %{
            description: "Create a color gradient using 256-color mode"
          },
          validation: nil,
          hints: [
            "Use \\e[38;5;NUMBERm for foreground colors where NUMBER is 0-255",
            "Colors 232-255 are grayscale"
          ],
          next_steps: [],
          interactive_elements: []
        }
      ],
      metadata: %{}
    }
  end
end
