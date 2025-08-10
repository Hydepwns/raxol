defmodule Mix.Tasks.Raxol.Tutorial do
  @moduledoc """
  Launches the Raxol interactive tutorial system.

  ## Usage

      mix raxol.tutorial               # Start tutorial system
      mix raxol.tutorial list           # List available tutorials
      mix raxol.tutorial start <id>     # Start specific tutorial
      mix raxol.tutorial --help         # Show help

  ## Examples

      mix raxol.tutorial
      mix raxol.tutorial start getting_started
      mix raxol.tutorial list

  ## Options

    * `--no-color` - Disable colored output
    * `--progress` - Show progress for all tutorials
  """

  use Mix.Task

  @shortdoc "Launch Raxol interactive tutorials"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    Application.ensure_all_started(:raxol)

    case parse_args(args) do
      {:help} ->
        show_help()

      {:list} ->
        list_tutorials()

      {:start, tutorial_id} ->
        start_tutorial(tutorial_id)

      {:progress} ->
        show_progress()

      {:interactive} ->
        start_interactive_mode()

      {:error, message} ->
        Mix.shell().error(message)
        show_help()
    end
  end

  defp parse_args([]), do: {:interactive}
  defp parse_args(["--help"]), do: {:help}
  defp parse_args(["list"]), do: {:list}
  defp parse_args(["start", id]), do: {:start, id}
  defp parse_args(["--progress"]), do: {:progress}
  defp parse_args(_), do: {:error, "Invalid arguments"}

  defp show_help do
    Mix.shell().info(@moduledoc)
  end

  defp list_tutorials do
    Mix.shell().info("Loading tutorials...")

    {:ok, _} = Raxol.Tutorials.Runner.start_link()
    {:ok, output} = Raxol.Tutorials.Runner.list_tutorials()

    Mix.shell().info(output)
  end

  defp start_tutorial(tutorial_id) do
    Mix.shell().info("Starting tutorial: #{tutorial_id}")

    {:ok, _} = Raxol.Tutorials.Runner.start_link()

    case Raxol.Tutorials.Runner.start_tutorial(tutorial_id) do
      {:ok, output} ->
        Mix.shell().info(output)
        tutorial_loop()

      {:error, reason} ->
        Mix.shell().error("Failed to start tutorial: #{reason}")
    end
  end

  defp show_progress do
    {:ok, _} = Raxol.Tutorials.Runner.start_link()
    {:ok, output} = Raxol.Tutorials.Runner.show_progress()
    Mix.shell().info(output)
  end

  defp start_interactive_mode do
    Mix.shell().info("""

    #{IO.ANSI.cyan()}╔════════════════════════════════════════════╗
    ║     Raxol Interactive Tutorial System      ║
    ╚════════════════════════════════════════════╝#{IO.ANSI.reset()}

    Starting interactive mode...
    """)

    {:ok, _} = Raxol.Tutorials.Runner.start_link()

    tutorial_loop()
  end

  defp tutorial_loop do
    command =
      Mix.shell().prompt("\n#{IO.ANSI.green()}tutorial>#{IO.ANSI.reset()} ")
      |> String.trim()
      |> String.split(" ", parts: 2)

    case command do
      ["exit"] ->
        Mix.shell().info("Goodbye! Happy coding with Raxol!")
        :ok

      ["quit"] ->
        Mix.shell().info("Goodbye! Happy coding with Raxol!")
        :ok

      ["list"] ->
        {:ok, output} = Raxol.Tutorials.Runner.list_tutorials()
        Mix.shell().info(output)
        tutorial_loop()

      ["start", id] ->
        case Raxol.Tutorials.Runner.start_tutorial(id) do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["next"] ->
        case Raxol.Tutorials.Runner.next_step() do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["prev"] ->
        case Raxol.Tutorials.Runner.previous_step() do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["show"] ->
        case Raxol.Tutorials.Runner.show_current() do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["run"] ->
        case Raxol.Tutorials.Runner.run_example() do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["submit" | rest] ->
        code = Enum.join(rest, " ")

        case Raxol.Tutorials.Runner.submit_solution(code) do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["hint"] ->
        case Raxol.Tutorials.Runner.get_hint() do
          {:ok, output} ->
            Mix.shell().info(output)

          {:error, reason} ->
            Mix.shell().error("Error: #{reason}")
        end

        tutorial_loop()

      ["progress"] ->
        {:ok, output} = Raxol.Tutorials.Runner.show_progress()
        Mix.shell().info(output)
        tutorial_loop()

      ["help"] ->
        show_interactive_help()
        tutorial_loop()

      [""] ->
        tutorial_loop()

      _ ->
        Mix.shell().error(
          "Unknown command. Type 'help' for available commands."
        )

        tutorial_loop()
    end
  end

  defp show_interactive_help do
    Mix.shell().info("""

    #{IO.ANSI.bright()}Available Commands:#{IO.ANSI.reset()}

      #{IO.ANSI.green()}list#{IO.ANSI.reset()}              - Show all available tutorials
      #{IO.ANSI.green()}start <id>#{IO.ANSI.reset()}        - Start a tutorial by ID
      #{IO.ANSI.green()}next#{IO.ANSI.reset()}              - Go to the next step
      #{IO.ANSI.green()}prev#{IO.ANSI.reset()}              - Go to the previous step
      #{IO.ANSI.green()}show#{IO.ANSI.reset()}              - Show current step again
      #{IO.ANSI.green()}run#{IO.ANSI.reset()}               - Run the example code
      #{IO.ANSI.green()}submit <code>#{IO.ANSI.reset()}     - Submit your solution
      #{IO.ANSI.green()}hint#{IO.ANSI.reset()}              - Get a hint for current exercise
      #{IO.ANSI.green()}progress#{IO.ANSI.reset()}          - Show your progress
      #{IO.ANSI.green()}help#{IO.ANSI.reset()}              - Show this help message
      #{IO.ANSI.green()}exit#{IO.ANSI.reset()}              - Exit the tutorial system

    #{IO.ANSI.bright()}Tutorial IDs:#{IO.ANSI.reset()}
      - getting_started
      - component_deep_dive
      - terminal_emulation (coming soon)
      - building_apps (coming soon)
    """)
  end
end
