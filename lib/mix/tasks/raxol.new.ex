defmodule Mix.Tasks.Raxol.New do
  @moduledoc """
  Generates a new Raxol TUI application.

  ## Usage

      mix raxol.new my_app

  This creates a new directory `my_app/` with a working TEA application
  that you can run immediately:

      cd my_app
      mix deps.get
      mix run lib/my_app.ex

  ## Options

    * `--module` - The main module name (default: derived from app name)
    * `--no-test` - Skip generating test files

  ## Examples

      mix raxol.new dashboard
      mix raxol.new my_tui --module MyTUI
  """

  use Mix.Task

  @shortdoc "Generate a new Raxol TUI application"

  @raxol_version Mix.Project.config()[:version]

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: [module: :string, no_test: :boolean]) do
      {opts, [name], _} ->
        generate(name, opts)

      _ ->
        Mix.shell().error("Usage: mix raxol.new APP_NAME [--module MODULE]")
        Mix.shell().error("Example: mix raxol.new my_app")
    end
  end

  defp generate(name, opts) do
    path = Path.expand(name)
    app = validate_app_name!(Path.basename(path))
    module = opts[:module] || Macro.camelize(app)
    skip_test = Keyword.get(opts, :no_test, false)

    if File.exists?(path) do
      Mix.raise("Directory #{path} already exists")
    end

    Mix.shell().info("Creating #{name}...")

    File.mkdir_p!(path)
    File.mkdir_p!(Path.join(path, "lib"))

    unless skip_test do
      File.mkdir_p!(Path.join(path, "test"))
    end

    write_file(path, "mix.exs", mix_exs(app, module))
    write_file(path, ".formatter.exs", formatter())
    write_file(path, ".gitignore", gitignore())
    write_file(path, "lib/#{app}.ex", app_module(app, module))

    unless skip_test do
      write_file(path, "test/test_helper.exs", test_helper())
      write_file(path, "test/#{app}_test.exs", app_test(app, module))
    end

    Mix.shell().info("")
    Mix.shell().info("Your Raxol app is ready!")
    Mix.shell().info("")
    Mix.shell().info("    cd #{name}")
    Mix.shell().info("    mix deps.get")
    Mix.shell().info("    mix run lib/#{app}.ex")
    Mix.shell().info("")
    Mix.shell().info("Press '+'/'-' to change the count, 'q' to quit.")
  end

  defp validate_app_name!(name) do
    unless name =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise(
        "App name must start with a lowercase letter and contain only " <>
          "lowercase letters, numbers, and underscores. Got: #{name}"
      )
    end

    if name in ~w(raxol elixir mix test lib) do
      Mix.raise("App name #{name} is reserved")
    end

    name
  end

  defp write_file(path, filename, content) do
    filepath = Path.join(path, filename)
    File.write!(filepath, content)
    Mix.shell().info("  * creating #{filename}")
  end

  defp mix_exs(app, module) do
    """
    defmodule #{module}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{app},
          version: "0.1.0",
          elixir: "~> 1.17",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      def application do
        [
          extra_applications: [:logger]
        ]
      end

      defp deps do
        [
          {:raxol, "~> #{@raxol_version}"}
        ]
      end
    end
    """
  end

  defp formatter do
    """
    [
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
    ]
    """
  end

  defp gitignore do
    """
    /_build/
    /deps/
    /doc/
    *.beam
    .fetch
    erl_crash.dump
    """
  end

  defp app_module(app, module) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TUI application using The Elm Architecture (TEA).

      Run with: mix run lib/#{app}.ex
      \"\"\"

      use Raxol.Core.Runtime.Application

      @impl true
      def init(_context) do
        %{count: 0}
      end

      @impl true
      def update(message, model) do
        case message do
          :increment ->
            {%{model | count: model.count + 1}, []}

          :decrement ->
            {%{model | count: model.count - 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "+"}} ->
            {%{model | count: model.count + 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "-"}} ->
            {%{model | count: model.count - 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
            {model, [command(:quit)]}

          _ ->
            {model, []}
        end
      end

      @impl true
      def view(model) do
        column style: %{padding: 1, gap: 1, align_items: :center} do
          [
            text("#{module}", style: [:bold]),
            box style: %{padding: 1, border: :single, width: 20, justify_content: :center} do
              text("Count: \#{model.count}", style: [:bold])
            end,
            row style: %{gap: 1} do
              [
                button("+", on_click: :increment),
                button("-", on_click: :decrement)
              ]
            end,
            text("Press '+'/'-' or click buttons. 'q' to quit.")
          ]
        end
      end

      @impl true
      def subscribe(_model), do: []
    end

    {:ok, pid} = Raxol.start_link(#{module}, [])
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
    """
  end

  defp test_helper do
    """
    ExUnit.start()
    """
  end

  defp app_test(_app, module) do
    """
    defmodule #{module}Test do
      use ExUnit.Case

      test "init returns initial state" do
        assert #{module}.init(%{}) == %{count: 0}
      end

      test "update handles increment" do
        model = %{count: 0}
        assert {%{count: 1}, []} = #{module}.update(:increment, model)
      end

      test "update handles decrement" do
        model = %{count: 5}
        assert {%{count: 4}, []} = #{module}.update(:decrement, model)
      end

      test "update ignores unknown messages" do
        model = %{count: 0}
        assert {%{count: 0}, []} = #{module}.update(:unknown, model)
      end
    end
    """
  end
end
