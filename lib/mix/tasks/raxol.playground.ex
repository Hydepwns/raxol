defmodule Mix.Tasks.Raxol.Playground do
  @moduledoc """
  Launches the Raxol Component Playground.

  The playground provides an interactive environment for exploring, testing,
  and generating code for Raxol components.

  ## Usage

      mix raxol.playground               # Start playground
      mix raxol.playground --help        # Show help
      mix raxol.playground --web         # Start web version (experimental)
      mix raxol.playground --demo        # Run demonstration

  ## Examples

      # Basic playground
      mix raxol.playground
      
      # Start with specific component selected
      mix raxol.playground --component button
      
      # Start in demo mode
      mix raxol.playground --demo

  ## Options

    * `--component <id>` - Start with specific component selected
    * `--theme <name>` - Start with specific theme (dark, light, default)
    * `--web` - Start web interface (experimental)
    * `--port <port>` - Web server port (default: 4444)
    * `--demo` - Run interactive demonstration
    * `--examples` - Show example components only
    * `--help` - Show help information
  """

  use Mix.Task

  @shortdoc "Launch the Raxol component playground"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    Application.ensure_all_started(:raxol)

    case parse_args(args) do
      {:help} ->
        show_help()

      {:demo} ->
        run_demo()

      {:examples} ->
        show_examples()

      {:web, opts} ->
        start_web_playground(opts)

      {:playground, opts} ->
        start_playground(opts)

      {:error, message} ->
        Mix.shell().error(message)
        show_help()
    end
  end

  defp parse_args(args) do
    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          help: :boolean,
          demo: :boolean,
          examples: :boolean,
          web: :boolean,
          port: :integer,
          component: :string,
          theme: :string
        ]
      )

    cond do
      invalid != [] ->
        {:error, "Invalid options: #{inspect(invalid)}"}

      opts[:help] ->
        {:help}

      opts[:demo] ->
        {:demo}

      opts[:examples] ->
        {:examples}

      opts[:web] ->
        web_opts = [
          port: opts[:port] || 4444,
          component: opts[:component],
          theme: opts[:theme]
        ]

        {:web, web_opts}

      true ->
        playground_opts = [
          component: opts[:component],
          theme: opts[:theme]
        ]

        {:playground, playground_opts}
    end
  end

  defp show_help do
    Mix.shell().info(@moduledoc)
  end

  defp start_playground(opts) do
    component_id = Keyword.get(opts, :component)
    theme = Keyword.get(opts, :theme, :default)

    Mix.shell().info("""

    #{IO.ANSI.cyan()}🎨 Starting Raxol Component Playground...#{IO.ANSI.reset()}

    """)

    case Raxol.Playground.launch() do
      :ok ->
        # Auto-select component if specified
        if component_id do
          case Raxol.Playground.select_component(component_id) do
            {:ok, _preview} ->
              Mix.shell().info("Auto-selected component: #{component_id}")

            {:error, reason} ->
              Mix.shell().error(
                "Could not select component '#{component_id}': #{reason}"
              )
          end
        end

        # Set theme if specified
        if theme != :default do
          Raxol.Playground.switch_theme(theme)
        end

      {:error, reason} ->
        Mix.shell().error("Failed to start playground: #{reason}")
    end
  end

  defp start_web_playground(opts) do
    port = Keyword.get(opts, :port, 4444)

    Mix.shell().info("""

    #{IO.ANSI.cyan()}🌐 Starting Raxol Playground Web Interface...#{IO.ANSI.reset()}

    Server will start on http://localhost:#{port}
    """)

    case Raxol.Playground.launch(port: port, web: true) do
      :ok ->
        Mix.shell().info("Playground web server started successfully!")

        # Keep the server running
        receive do
          :shutdown -> :ok
        end

      {:error, reason} ->
        Mix.shell().error("Failed to start web server: #{reason}")
    end
  end

  defp run_demo do
    Mix.shell().info("""

    #{IO.ANSI.cyan()}🎭 Raxol Playground Interactive Demo#{IO.ANSI.reset()}

    This demo will show you the key features of the component playground.

    Press Enter to continue through each step...
    """)

    Mix.shell().prompt("")

    {:ok, _} = Raxol.Playground.start_link()

    # Demo Step 1: Show catalog
    Mix.shell().info("""

    #{IO.ANSI.bright()}Step 1: Component Catalog#{IO.ANSI.reset()}

    The playground contains a comprehensive catalog of Raxol components:
    """)

    catalog = Raxol.Playground.get_catalog()
    display_demo_catalog(catalog)

    Mix.shell().prompt("\nPress Enter to continue...")

    # Demo Step 2: Select and preview a component
    Mix.shell().info("""

    #{IO.ANSI.bright()}Step 2: Live Preview#{IO.ANSI.reset()}

    Let's select a button component and see the live preview:
    """)

    case Raxol.Playground.select_component("button") do
      {:ok, preview} ->
        Mix.shell().info("\n#{preview}")

      {:error, reason} ->
        Mix.shell().error("Demo error: #{reason}")
    end

    Mix.shell().prompt("\nPress Enter to continue...")

    # Demo Step 3: Update properties
    Mix.shell().info("""

    #{IO.ANSI.bright()}Step 3: Dynamic Properties#{IO.ANSI.reset()}

    Now let's update the button properties and see the changes:
    """)

    case Raxol.Playground.update_props(%{label: "Demo Button", variant: :danger}) do
      {:ok, preview} ->
        Mix.shell().info("\n#{preview}")

      {:error, reason} ->
        Mix.shell().error("Demo error: #{reason}")
    end

    Mix.shell().prompt("\nPress Enter to continue...")

    # Demo Step 4: Code generation
    Mix.shell().info("""

    #{IO.ANSI.bright()}Step 4: Code Generation#{IO.ANSI.reset()}

    The playground can generate ready-to-use Elixir code:
    """)

    case Raxol.Playground.export_code() do
      {:ok, code} ->
        Mix.shell().info("""

        #{IO.ANSI.light_black()}```elixir#{IO.ANSI.reset()}
        #{code}
        #{IO.ANSI.light_black()}```#{IO.ANSI.reset()}
        """)

      {:error, reason} ->
        Mix.shell().error("Demo error: #{reason}")
    end

    Mix.shell().prompt("\nPress Enter to continue...")

    # Demo Step 5: Theme switching
    Mix.shell().info("""

    #{IO.ANSI.bright()}Step 5: Theme Support#{IO.ANSI.reset()}

    Components can be previewed with different themes:
    """)

    case Raxol.Playground.switch_theme(:dark) do
      {:ok, preview} ->
        Mix.shell().info("Dark theme preview:\n#{preview}")

      _ ->
        Mix.shell().info("Theme switched to dark")
    end

    Mix.shell().info("""

    #{IO.ANSI.green()}✨ Demo Complete!#{IO.ANSI.reset()}

    You've seen the key features of the Raxol Component Playground:

    • 📚 Comprehensive component catalog
    • 👀 Live preview with real-time updates  
    • ⚙️  Dynamic property editing
    • 📝 Automatic code generation
    • 🎨 Theme support
    • 🔧 Interactive development environment

    Run 'mix raxol.playground' to start the full interactive playground!
    """)
  end

  defp show_examples do
    Mix.shell().info("""

    #{IO.ANSI.bright()}🎯 Raxol Component Examples#{IO.ANSI.reset()}

    Here are some example components you can try in the playground:
    """)

    examples = [
      %{
        category: "Text Components",
        examples: [
          "mix raxol.playground --component text",
          "mix raxol.playground --component heading",
          "mix raxol.playground --component label"
        ]
      },
      %{
        category: "Interactive Components",
        examples: [
          "mix raxol.playground --component button",
          "mix raxol.playground --component checkbox",
          "mix raxol.playground --component toggle"
        ]
      },
      %{
        category: "Layout Components",
        examples: [
          "mix raxol.playground --component box",
          "mix raxol.playground --component flex",
          "mix raxol.playground --component grid"
        ]
      },
      %{
        category: "Data Components",
        examples: [
          "mix raxol.playground --component table",
          "mix raxol.playground --component list",
          "mix raxol.playground --component progress_bar"
        ]
      }
    ]

    Enum.each(examples, fn %{category: category, examples: example_list} ->
      Mix.shell().info("\n#{IO.ANSI.cyan()}#{category}:#{IO.ANSI.reset()}")

      Enum.each(example_list, fn example ->
        Mix.shell().info("  #{IO.ANSI.green()}#{example}#{IO.ANSI.reset()}")
      end)
    end)

    Mix.shell().info("""

    #{IO.ANSI.yellow()}Tip:#{IO.ANSI.reset()} You can also start the playground without arguments and use the 'list' command to browse all available components.
    """)
  end

  defp display_demo_catalog(catalog) do
    categories =
      catalog
      |> Enum.group_by(& &1.category)
      # Show first 3 categories for demo
      |> Enum.take(3)

    Enum.each(categories, fn {category, components} ->
      Mix.shell().info("\n#{IO.ANSI.cyan()}#{category}:#{IO.ANSI.reset()}")

      components
      # Show first 3 components per category
      |> Enum.take(3)
      |> Enum.each(fn comp ->
        Mix.shell().info(
          "  #{IO.ANSI.green()}#{comp.id}#{IO.ANSI.reset()} - #{comp.description}"
        )
      end)
    end)
  end
end
