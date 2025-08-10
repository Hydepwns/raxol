defmodule Mix.Tasks.Raxol.Examples do
  @moduledoc """
  Run Raxol example applications.

  ## Usage

      mix raxol.examples <example_name>

  ## Available Examples

  - `showcase` - Interactive component showcase
  - `todo` - Todo list application
  - `dashboard` - Real-time dashboard
  - `editor` - Text editor with syntax highlighting
  - `chat` - Terminal chat application
  - `file_browser` - File system browser

  ## Options

  - `--list` - List all available examples
  - `--theme` - Set theme (dark/light)
  - `--width` - Set terminal width
  - `--height` - Set terminal height

  ## Examples

      # Run the component showcase
      mix raxol.examples showcase
      
      # Run todo app with light theme
      mix raxol.examples todo --theme light
      
      # Run dashboard with custom dimensions
      mix raxol.examples dashboard --width 120 --height 40
      
      # List all examples
      mix raxol.examples --list
  """

  use Mix.Task

  @examples %{
    "showcase" => {Raxol.Examples.Showcase, "Interactive component showcase"},
    "todo" => {Raxol.Examples.TodoApp, "Todo list application"},
    "dashboard" => {Raxol.Examples.Dashboard, "Real-time monitoring dashboard"},
    "editor" => {Raxol.Examples.Editor, "Text editor with syntax highlighting"},
    "chat" => {Raxol.Examples.Chat, "Terminal chat application"},
    "file_browser" => {Raxol.Examples.FileBrowser, "File system browser"}
  }

  @shortdoc "Run Raxol example applications"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        switches: [
          list: :boolean,
          theme: :string,
          width: :integer,
          height: :integer,
          help: :boolean
        ]
      )

    cond do
      opts[:help] ->
        Mix.shell().info(@moduledoc)

      opts[:list] ->
        list_examples()

      length(args) == 0 ->
        Mix.shell().error(
          "No example specified. Use --list to see available examples."
        )

        Mix.shell().info("\nUsage: mix raxol.examples <example_name>")
        list_examples()

      true ->
        run_example(hd(args), opts)
    end
  end

  defp list_examples do
    Mix.shell().info("\nAvailable examples:\n")

    @examples
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, {_module, description}} ->
      Mix.shell().info("  #{String.pad_trailing(name, 15)} - #{description}")
    end)

    Mix.shell().info("\nRun an example with: mix raxol.examples <name>")
  end

  defp run_example(name, opts) do
    case Map.get(@examples, name) do
      {module, _description} ->
        Mix.shell().info("Starting #{name} example...")

        # Start the application if not already started
        Application.ensure_all_started(:raxol)

        # Configure options
        config = build_config(opts)

        # Start the example application
        case Raxol.start_app(module, %{}, config) do
          {:ok, _pid} ->
            Mix.shell().info("#{name} is running. Press Ctrl+C to exit.")
            # Keep the process alive
            Process.sleep(:infinity)

          {:error, reason} ->
            Mix.shell().error("Failed to start #{name}: #{inspect(reason)}")
        end

      nil ->
        Mix.shell().error("Unknown example: #{name}")
        Mix.shell().info("\nUse --list to see available examples.")
    end
  end

  defp build_config(opts) do
    config = []

    config =
      if opts[:theme] do
        [{:theme, String.to_atom(opts[:theme])} | config]
      else
        config
      end

    config =
      if opts[:width] do
        [{:width, opts[:width]} | config]
      else
        config
      end

    config =
      if opts[:height] do
        [{:height, opts[:height]} | config]
      else
        config
      end

    config
  end
end
