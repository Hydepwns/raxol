defmodule Mix.Tasks.Raxol.New do
  @moduledoc """
  Generates a new Raxol TUI application.

  ## Usage

      mix raxol.new my_app

  When run without flags, an interactive prompt guides you through setup.
  Pass flags to skip prompts.

  ## Options

    * `--module` - The main module name (default: derived from app name)
    * `--sup` - Generate an OTP application with a supervision tree
    * `--ssh` - Include SSH server boilerplate for remote access
    * `--liveview` - Include Phoenix LiveView bridge for browser rendering
    * `--template` - Starter template: `counter` (default), `blank`, `todo`, `dashboard`
    * `--ci` - Generate GitHub Actions CI workflow
    * `--no-test` - Skip generating test files
    * `--install` - Run `mix deps.get`, compile, and test after generation
    * `--list` - Show available templates with descriptions

  ## Examples

      mix raxol.new dashboard
      mix raxol.new my_tui --module MyTUI
      mix raxol.new my_app --sup --template todo --ci
      mix raxol.new my_app --ssh --install
      mix raxol.new --list
  """

  use Mix.Task

  @compile {:no_warn_undefined, Mix.Raxol.Templates}
  @compile {:no_warn_undefined, Mix.Raxol.Generator}

  alias Mix.Raxol.{Generator, Templates}

  @shortdoc "Generate a new Raxol TUI application"

  @raxol_version Mix.Project.config()[:version]

  @switches [
    module: :string,
    no_test: :boolean,
    sup: :boolean,
    ssh: :boolean,
    liveview: :boolean,
    template: :string,
    install: :boolean,
    list: :boolean,
    ci: :boolean
  ]

  @templates Templates.templates()

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: @switches) do
      {opts, [], _} ->
        if Keyword.get(opts, :list, false) do
          Templates.print_template_list()
        else
          print_usage()
        end

      {opts, [name], _} ->
        if Keyword.get(opts, :list, false) do
          Templates.print_template_list()
        else
          opts = maybe_prompt_interactive(opts)
          template = Keyword.get(opts, :template, "counter")

          if template not in @templates do
            Mix.raise(
              "Unknown template: #{template}. Available: #{Enum.join(@templates, ", ")}"
            )
          end

          Generator.generate(
            name,
            Keyword.put(opts, :template, template),
            @raxol_version
          )
        end

      _ ->
        print_usage()
    end
  end

  # ---------------------------------------------------------------------------
  # Interactive prompts
  # ---------------------------------------------------------------------------

  defp maybe_prompt_interactive(opts) do
    has_flags =
      Keyword.has_key?(opts, :template) or
        Keyword.has_key?(opts, :sup) or
        Keyword.has_key?(opts, :ssh) or
        Keyword.has_key?(opts, :liveview) or
        Keyword.has_key?(opts, :ci)

    if has_flags do
      opts
    else
      prompt_all(opts)
    end
  end

  defp prompt_all(opts) do
    opts
    |> Templates.prompt_template()
    |> prompt_yes_no(:sup, "Generate OTP supervision tree?")
    |> prompt_yes_no(:ssh, "Include SSH server?")
    |> prompt_yes_no(:liveview, "Include LiveView bridge?")
    |> prompt_yes_no(:ci, "Generate GitHub Actions CI?")
  end

  defp prompt_yes_no(opts, key, question) do
    if Keyword.has_key?(opts, key) do
      opts
    else
      answer =
        Mix.shell().prompt("#{question} [y/N]")
        |> String.trim()
        |> String.downcase()

      Keyword.put(opts, key, answer in ~w(y yes))
    end
  end

  # ---------------------------------------------------------------------------
  # Usage
  # ---------------------------------------------------------------------------

  defp print_usage do
    Mix.shell().error("Usage: mix raxol.new APP_NAME [options]")
    Mix.shell().error("")
    Mix.shell().error("Options:")

    Mix.shell().error(
      "  --module NAME      Module name (default: derived from app name)"
    )

    Mix.shell().error(
      "  --sup              Generate OTP application with supervision tree"
    )

    Mix.shell().error("  --ssh              Include SSH server boilerplate")
    Mix.shell().error("  --liveview         Include Phoenix LiveView bridge")

    Mix.shell().error(
      "  --template NAME    Starter template: #{Enum.join(@templates, ", ")}"
    )

    Mix.shell().error(
      "  --ci               Generate GitHub Actions CI workflow"
    )

    Mix.shell().error("  --no-test          Skip test files")

    Mix.shell().error(
      "  --install          Run mix deps.get + compile + test after generation"
    )

    Mix.shell().error(
      "  --list             Show available templates with descriptions"
    )

    Mix.shell().error("")
    Mix.shell().error("Example: mix raxol.new my_app --sup --template todo")
  end
end
