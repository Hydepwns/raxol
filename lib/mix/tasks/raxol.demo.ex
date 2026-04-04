defmodule Mix.Tasks.Raxol.Demo do
  @moduledoc """
  Runs built-in Raxol demo applications.

  ## Usage

      mix raxol.demo              # Interactive demo picker
      mix raxol.demo counter      # Simple counter
      mix raxol.demo todo         # Todo list
      mix raxol.demo dashboard    # Live BEAM dashboard
      mix raxol.demo showcase     # Component showcase
      mix raxol.demo --list       # List available demos

  ## Demos

    * `counter`   - Simple counter with +/- keys and buttons
    * `todo`      - Todo list with add/delete/toggle and input modes
    * `dashboard` - Live BEAM dashboard with scheduler, memory, process stats
    * `showcase`  - Interactive component showcase with 5 tabbed sections
  """

  use Mix.Task

  @shortdoc "Run built-in Raxol demo applications"

  @demos [
    {"counter", Raxol.Demo.Counter, "Simple counter with +/- keys and buttons"},
    {"todo", Raxol.Demo.Todo,
     "Todo list with add/delete/toggle and input modes"},
    {"dashboard", Raxol.Demo.Dashboard,
     "Live BEAM dashboard with scheduler, memory, process stats"},
    {"showcase", Raxol.Demo.Showcase,
     "Interactive component showcase with 5 tabbed sections"}
  ]

  @demo_names Enum.map(@demos, &elem(&1, 0))

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: [list: :boolean]) do
      {opts, [], _} ->
        if Keyword.get(opts, :list, false) do
          print_list()
        else
          prompt_and_run()
        end

      {_opts, [name], _} ->
        launch(name)

      _ ->
        print_usage()
    end
  end

  defp launch(name) do
    case Enum.find(@demos, fn {n, _, _} -> n == name end) do
      {_, module, _} ->
        Mix.Task.run("app.start")

        Mix.shell().info([:green, "Starting #{name} demo...", :reset])
        Mix.shell().info("Press 'q' or Ctrl+C to quit.\n")

        {:ok, pid} = Raxol.start_link(module, [])
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        end

      nil ->
        Mix.shell().error("Unknown demo: #{name}")
        Mix.shell().error("Available: #{Enum.join(@demo_names, ", ")}")
    end
  end

  defp prompt_and_run do
    print_demo_menu()

    answer =
      Mix.shell().prompt(
        "Pick a demo [#{Enum.join(@demo_names, "/")}] (default: counter)"
      )
      |> String.trim()
      |> String.downcase()

    launch(resolve_demo_name(answer))
  end

  defp print_demo_menu do
    Mix.shell().info("")
    Mix.shell().info([:bright, "Available demos:", :reset])

    for {{name, _, desc}, idx} <- Enum.with_index(@demos, 1) do
      Mix.shell().info("  #{idx}. #{String.pad_trailing(name, 12)} #{desc}")
    end
  end

  defp resolve_demo_name(""), do: "counter"

  defp resolve_demo_name(n) when n in ["1", "2", "3", "4"],
    do: Enum.at(@demo_names, String.to_integer(n) - 1)

  defp resolve_demo_name(n) when n in @demo_names, do: n

  defp resolve_demo_name(_) do
    Mix.shell().info([:yellow, "Unknown demo, using counter.", :reset])
    "counter"
  end

  defp print_list do
    Mix.shell().info([:bright, "Available demos:", :reset])
    Mix.shell().info("")

    for {name, _, desc} <- @demos do
      label = String.pad_trailing(name, 12)
      Mix.shell().info(["  ", :cyan, label, :reset, desc])
    end

    Mix.shell().info("")
    Mix.shell().info("Usage: mix raxol.demo NAME")
  end

  defp print_usage do
    Mix.shell().error("Usage: mix raxol.demo [NAME]")
    Mix.shell().error("")
    Mix.shell().error("Run without arguments for interactive picker.")
    Mix.shell().error("Run with --list to see available demos.")
  end
end
