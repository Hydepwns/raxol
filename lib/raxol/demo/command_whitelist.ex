defmodule Raxol.Demo.CommandWhitelist do
  @moduledoc """
  Command registry for demo terminal. Only whitelisted commands are executed.
  Validates input and blocks anything not explicitly registered.
  """

  @max_input_size 1024

  @type command_result ::
          {:ok, String.t()}
          | {:error, String.t()}
          | {:animate, (term() -> term())}
          | {:exit, String.t()}

  @doc """
  Executes a command if it's whitelisted. Returns error for unknown commands.
  """
  @spec execute(String.t()) :: command_result()
  def execute(input) when byte_size(input) > @max_input_size do
    {:error, "Input too large (max #{@max_input_size} bytes)"}
  end

  def execute(input) do
    input
    |> String.trim()
    |> parse_command()
    |> dispatch()
  end

  @doc """
  Returns list of available commands for help display.
  """
  @spec available_commands() :: [{String.t(), String.t()}]
  def available_commands do
    [
      {"help", "List available commands"},
      {"demo", "*** FULL SHOWCASE with particles & animations ***"},
      {"demo colors", "ANSI color palette showcase"},
      {"demo components", "UI component gallery"},
      {"demo emulation", "VT100/ANSI escape sequence demo"},
      {"theme <name>", "Switch theme (dracula, nord, monokai, solarized)"},
      {"clear", "Clear screen"},
      {"exit", "End session"}
    ]
  end

  defp parse_command(""), do: {:empty, []}

  defp parse_command(input) do
    case String.split(input, ~r/\s+/, parts: 2) do
      [cmd] -> {String.downcase(cmd), []}
      [cmd, args] -> {String.downcase(cmd), String.split(args)}
    end
  end

  defp dispatch({:empty, _}), do: {:ok, ""}

  defp dispatch({"help", _args}) do
    Raxol.Demo.DemoHandler.help()
  end

  defp dispatch({"demo", args}) do
    case args do
      [] ->
        {:animate, &Raxol.Demo.Animations.run_showcase/1}

      ["colors" | _] ->
        Raxol.Demo.DemoHandler.demo_colors()

      ["components" | _] ->
        Raxol.Demo.DemoHandler.demo_components()

      ["emulation" | _] ->
        Raxol.Demo.DemoHandler.demo_emulation()

      [unknown | _] ->
        {:error, "Unknown demo: #{unknown}. Try: colors, components, emulation"}
    end
  end

  defp dispatch({"theme", args}) do
    case args do
      [name | _] ->
        Raxol.Demo.DemoHandler.set_theme(name)

      [] ->
        {:error,
         "Usage: theme <name>. Available: dracula, nord, monokai, solarized"}
    end
  end

  defp dispatch({"clear", _args}) do
    {:ok, "\e[2J\e[H"}
  end

  defp dispatch({"exit", _args}) do
    {:exit, "Goodbye! Thanks for trying Raxol.\r\n"}
  end

  defp dispatch({cmd, _args}) do
    {:error, "Unknown command: #{cmd}. Type 'help' for available commands."}
  end
end
