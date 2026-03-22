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

  @template_descriptions %{
    "counter" => "Interactive counter with buttons and keyboard shortcuts",
    "blank" => "Minimal skeleton with just quit handling",
    "todo" => "Todo list with add/delete/toggle and input modes",
    "dashboard" => "Multi-panel layout with tabs, live stats via subscriptions"
  }

  @templates Map.keys(@template_descriptions) |> Enum.sort()

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: @switches) do
      {opts, [], _} ->
        if Keyword.get(opts, :list, false) do
          print_template_list()
        else
          print_usage()
        end

      {opts, [name], _} ->
        if Keyword.get(opts, :list, false) do
          print_template_list()
        else
          opts = maybe_prompt_interactive(opts)
          template = Keyword.get(opts, :template, "counter")

          if template not in @templates do
            Mix.raise(
              "Unknown template: #{template}. Available: #{Enum.join(@templates, ", ")}"
            )
          end

          generate(name, Keyword.put(opts, :template, template))
        end

      _ ->
        print_usage()
    end
  end

  defp print_usage do
    Mix.shell().error("Usage: mix raxol.new APP_NAME [options]")
    Mix.shell().error("")
    Mix.shell().error("Options:")
    Mix.shell().error("  --module NAME      Module name (default: derived from app name)")
    Mix.shell().error("  --sup              Generate OTP application with supervision tree")
    Mix.shell().error("  --ssh              Include SSH server boilerplate")
    Mix.shell().error("  --liveview         Include Phoenix LiveView bridge")
    Mix.shell().error("  --template NAME    Starter template: #{Enum.join(@templates, ", ")}")
    Mix.shell().error("  --ci               Generate GitHub Actions CI workflow")
    Mix.shell().error("  --no-test          Skip test files")
    Mix.shell().error("  --install          Run mix deps.get + compile + test after generation")
    Mix.shell().error("  --list             Show available templates with descriptions")
    Mix.shell().error("")
    Mix.shell().error("Example: mix raxol.new my_app --sup --template todo")
  end

  defp print_template_list do
    Mix.shell().info([:bright, "Available templates:", :reset])
    Mix.shell().info("")

    for name <- @templates do
      desc = @template_descriptions[name]
      label = String.pad_trailing(name, 12)
      Mix.shell().info(["  ", :cyan, label, :reset, desc])
    end

    Mix.shell().info("")
    Mix.shell().info("Usage: mix raxol.new my_app --template NAME")
    Mix.shell().info("")

    for name <- @templates do
      print_template_preview(name)
    end
  end

  defp print_template_preview("counter") do
    Mix.shell().info([:bright, "counter", :reset, " generates:"])
    Mix.shell().info("  lib/my_app.ex      -- Counter with +/- buttons and keyboard control")
    Mix.shell().info("  test/my_app_test.exs -- Tests for increment/decrement/unknown")
    Mix.shell().info("")
  end

  defp print_template_preview("blank") do
    Mix.shell().info([:bright, "blank", :reset, " generates:"])
    Mix.shell().info("  lib/my_app.ex      -- Empty TEA app with quit handling")
    Mix.shell().info("  test/my_app_test.exs -- Tests for init and unknown messages")
    Mix.shell().info("")
  end

  defp print_template_preview("todo") do
    Mix.shell().info([:bright, "todo", :reset, " generates:"])
    Mix.shell().info("  lib/my_app.ex      -- Todo list with add/toggle/delete, input mode")
    Mix.shell().info("  test/my_app_test.exs -- Tests for CRUD operations")
    Mix.shell().info("")
  end

  defp print_template_preview("dashboard") do
    Mix.shell().info([:bright, "dashboard", :reset, " generates:"])
    Mix.shell().info("  lib/my_app.ex      -- 3-panel dashboard with live stats subscription")
    Mix.shell().info("  test/my_app_test.exs -- Tests for panel switching and tick")
    Mix.shell().info("")
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
    |> prompt_template()
    |> prompt_yes_no(:sup, "Generate OTP supervision tree?")
    |> prompt_yes_no(:ssh, "Include SSH server?")
    |> prompt_yes_no(:liveview, "Include LiveView bridge?")
    |> prompt_yes_no(:ci, "Generate GitHub Actions CI?")
  end

  defp prompt_template(opts) do
    Mix.shell().info("")
    Mix.shell().info([:bright, "Available templates:", :reset])

    for {name, i} <- Enum.with_index(@templates, 1) do
      desc = @template_descriptions[name]
      Mix.shell().info("  #{i}. #{String.pad_trailing(name, 12)} #{desc}")
    end

    answer =
      Mix.shell().prompt("Template [counter/blank/todo/dashboard] (default: counter)")
      |> String.trim()
      |> String.downcase()

    template =
      case answer do
        "" -> "counter"
        "1" -> "counter"
        "2" -> "blank"
        "3" -> "dashboard"
        "4" -> "todo"
        t when t in @templates -> t
        _ ->
          Mix.shell().info([:yellow, "Unknown template, using counter.", :reset])
          "counter"
      end

    Keyword.put(opts, :template, template)
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
  # Generation
  # ---------------------------------------------------------------------------

  defp generate(name, opts) do
    path = Path.expand(name)
    app = validate_app_name!(Path.basename(path))
    module = opts[:module] || Macro.camelize(app)
    template = Keyword.get(opts, :template, "counter")
    sup? = Keyword.get(opts, :sup, false)
    ssh? = Keyword.get(opts, :ssh, false)
    liveview? = Keyword.get(opts, :liveview, false)
    ci? = Keyword.get(opts, :ci, false)
    skip_test = Keyword.get(opts, :no_test, false)
    install? = Keyword.get(opts, :install, false)

    if File.exists?(path) do
      Mix.raise("Directory #{path} already exists")
    end

    bindings = %{
      app: app,
      module: module,
      template: template,
      sup: sup?,
      ssh: ssh?,
      liveview: liveview?,
      ci: ci?,
      version: @raxol_version
    }

    Mix.shell().info([:green, "* creating ", :reset, name])

    File.mkdir_p!(path)
    File.mkdir_p!(Path.join(path, "lib"))
    File.mkdir_p!(Path.join(path, "config"))

    unless skip_test do
      File.mkdir_p!(Path.join(path, "test"))
    end

    # Core files
    write_file(path, "mix.exs", mix_exs(bindings))
    write_file(path, "config/config.exs", config_exs(bindings))
    write_file(path, ".formatter.exs", formatter())
    write_file(path, ".gitignore", gitignore())
    write_file(path, "README.md", readme(bindings))
    write_file(path, ".mise.toml", mise_toml())

    # App modules
    if sup? do
      write_file(path, "lib/#{app}.ex", app_module_sup(bindings))
      write_file(path, "lib/#{app}/application.ex", application_module(bindings))
      write_file(path, "lib/#{app}/app.ex", tea_module(bindings))
    else
      write_file(path, "lib/#{app}.ex", tea_module_standalone(bindings))
    end

    if ssh? do
      write_file(path, "lib/#{app}/ssh.ex", ssh_module(bindings))
    end

    if liveview? do
      write_file(path, "lib/#{app}/live.ex", liveview_module(bindings))
    end

    # Tests
    unless skip_test do
      write_file(path, "test/test_helper.exs", test_helper())
      write_file(path, "test/#{app}_test.exs", app_test(bindings))
    end

    # CI
    if ci? do
      write_file(path, ".github/workflows/ci.yml", ci_workflow(bindings))
    end

    # Git init
    git_init(path)

    Mix.shell().info("")

    if install? do
      install_and_verify(path)
    end

    print_instructions(bindings, name, install?)
  end

  defp git_init(path) do
    case System.cmd("git", ["init"], cd: path, stderr_to_stdout: true) do
      {_, 0} ->
        System.cmd("git", ["add", "."], cd: path, stderr_to_stdout: true)

        System.cmd("git", ["commit", "-m", "Initial commit from mix raxol.new"],
          cd: path,
          stderr_to_stdout: true
        )

        Mix.shell().info(["  ", :green, "* initialized ", :reset, "git repo with initial commit"])

      _ ->
        Mix.shell().info(["  ", :yellow, "* skipping ", :reset, "git init (git not available)"])
    end
  end

  defp install_and_verify(path) do
    Mix.shell().info([:cyan, "Fetching dependencies...", :reset])

    case System.cmd("mix", ["deps.get"], cd: path, stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info([:green, "Dependencies installed.", :reset])
        compile_and_test(path)

      {output, _} ->
        Mix.shell().info(output)
        Mix.shell().error("Failed to install dependencies. Run `mix deps.get` manually.")
    end
  end

  defp compile_and_test(path) do
    Mix.shell().info([:cyan, "Compiling...", :reset])

    case System.cmd("mix", ["compile", "--warnings-as-errors"],
           cd: path,
           env: [{"MIX_ENV", "test"}],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info([:green, "Compilation succeeded.", :reset])
        run_tests(path)

      {output, _} ->
        Mix.shell().info(output)
        Mix.shell().error("Compilation failed.")
    end
  end

  defp run_tests(path) do
    Mix.shell().info([:cyan, "Running tests...", :reset])

    case System.cmd("mix", ["test"],
           cd: path,
           env: [{"MIX_ENV", "test"}],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        Mix.shell().info(output)
        Mix.shell().info([:green, "All tests passed.", :reset])

      {output, _} ->
        Mix.shell().info(output)
        Mix.shell().error("Some tests failed.")
    end
  end

  defp print_instructions(bindings, name, installed?) do
    %{app: app, sup: sup?, ssh: ssh?} = bindings

    Mix.shell().info([:green, :bright, "Your Raxol app is ready!", :reset])
    Mix.shell().info("")

    unless installed? do
      Mix.shell().info(["    ", :cyan, "cd #{name}", :reset])
      Mix.shell().info(["    ", :cyan, "mix deps.get", :reset])
    end

    if sup? do
      Mix.shell().info(["    ", :cyan, "mix run --no-halt", :reset])
    else
      Mix.shell().info(["    ", :cyan, "mix run lib/#{app}.ex", :reset])
    end

    Mix.shell().info("")

    case bindings.template do
      "counter" ->
        Mix.shell().info("Press '+'/'-' or click buttons. 'q' to quit.")

      "todo" ->
        Mix.shell().info("Type to add todos, Enter to confirm, 'q' to quit.")

      "dashboard" ->
        Mix.shell().info("Press Tab to cycle panels, 'q' to quit.")

      "blank" ->
        Mix.shell().info("Edit lib/#{app}.ex to build your app.")
    end

    if ssh? do
      Mix.shell().info("")
      Mix.shell().info([:yellow, "SSH server:", :reset, " mix run --no-halt"])
      Mix.shell().info(["Then connect: ", :cyan, "ssh localhost -p 2222", :reset])
    end

    Mix.shell().info("")
  end

  defp validate_app_name!(name) do
    unless name =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise(
        "App name must start with a lowercase letter and contain only " <>
          "lowercase letters, numbers, and underscores. Got: #{name}"
      )
    end

    if name in ~w(raxol elixir mix test lib config) do
      Mix.raise("App name #{name} is reserved")
    end

    name
  end

  defp write_file(path, filename, content) do
    filepath = Path.join(path, filename)
    filepath |> Path.dirname() |> File.mkdir_p!()
    File.write!(filepath, content)
    Mix.shell().info(["  ", :green, "* creating ", :reset, filename])
  end

  # ---------------------------------------------------------------------------
  # File generators
  # ---------------------------------------------------------------------------

  defp mix_exs(%{app: app, module: module, ssh: ssh?, liveview: liveview?}) do
    extra_deps =
      []
      |> maybe_add(ssh?, ~s|{:ssh_subsystem_fwup, "~> 0.6", optional: true}|)
      |> maybe_add(liveview?, ~s|{:phoenix_live_view, "~> 1.0"}|)
      |> maybe_add(liveview?, ~s|{:phoenix, "~> 1.7"}|)

    all_deps = [~s|{:raxol, "~> #{@raxol_version}"}| | extra_deps]
    deps_lines = Enum.map_join(all_deps, ",\n", &("      " <> &1))

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
    #{deps_lines}
        ]
      end
    end
    """
  end

  defp config_exs(%{app: app, ssh: ssh?, liveview: liveview?}) do
    ssh_config =
      if ssh? do
        """

        # SSH server configuration
        # config :#{app}, :ssh,
        #   port: 2222,
        #   host_keys_dir: "/tmp/#{app}_ssh_keys"
        """
      else
        ""
      end

    liveview_config =
      if liveview? do
        """

        # LiveView configuration
        # config :#{app}, :liveview,
        #   pubsub: #{Macro.camelize(app)}.PubSub
        """
      else
        ""
      end

    """
    import Config

    # Raxol application configuration
    #
    # config :#{app}, :raxol,
    #   fps: 60,                           # Target frames per second
    #   title: "#{Macro.camelize(app)}",    # Window title
    #   quit_keys: [{:ctrl, ?c}]            # Keys that quit the app

    # Accessibility options
    # config :#{app}, :accessibility,
    #   screen_reader: true,
    #   high_contrast: false,
    #   large_text: false,
    #   reduced_motion: false

    # Theme configuration
    # config :raxol, :theme, Raxol.UI.Theming.Theme.dark_theme()
    #{String.trim_trailing(ssh_config)}
    #{String.trim_trailing(liveview_config)}
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

  defp mise_toml do
    elixir_vsn = System.version()
    otp_vsn = :erlang.system_info(:otp_release) |> to_string()

    """
    [tools]
    elixir = "#{elixir_vsn}"
    erlang = "#{otp_vsn}"
    """
  end

  defp readme(%{app: app, module: module, template: template, sup: sup?}) do
    run_cmd =
      if sup? do
        "mix run --no-halt"
      else
        "mix run lib/#{app}.ex"
      end

    """
    # #{module}

    A terminal UI application built with [Raxol](https://hexdocs.pm/raxol).

    ## Getting Started

    ```bash
    mix deps.get
    #{run_cmd}
    ```

    ## About

    This app was generated with `mix raxol.new` using the `#{template}` template.
    It follows The Elm Architecture (TEA) with four callbacks:

    - `init/1` - Set up initial state
    - `update/2` - Handle messages and events
    - `view/1` - Render the UI from state
    - `subscribe/1` - Set up recurring events

    ## Learn More

    - [Raxol Documentation](https://hexdocs.pm/raxol)
    - [The Elm Architecture](https://guide.elm-lang.org/architecture/)
    """
  end

  defp ci_workflow(_bindings) do
    """
    name: CI

    on:
      push:
        branches: [main, master]
      pull_request:
        branches: [main, master]

    jobs:
      test:
        runs-on: ubuntu-latest

        steps:
          - uses: actions/checkout@v4

          - name: Set up Elixir
            uses: erlef/setup-beam@v1
            with:
              elixir-version: "1.17"
              otp-version: "27"

          - name: Restore dependencies cache
            uses: actions/cache@v4
            with:
              path: deps
              key: ${{ runner.os }}-mix-${{ hashFiles('mix.lock') }}
              restore-keys: ${{ runner.os }}-mix-

          - name: Install dependencies
            run: mix deps.get

          - name: Check formatting
            run: mix format --check-formatted

          - name: Compile with warnings as errors
            run: mix compile --warnings-as-errors

          - name: Run tests
            run: mix test
            env:
              MIX_ENV: test
    """
  end

  # ---------------------------------------------------------------------------
  # --sup modules
  # ---------------------------------------------------------------------------

  defp app_module_sup(%{module: module}) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      #{module} entrypoint. See `#{module}.Application` for the supervision tree.
      \"\"\"

      def start do
        #{module}.Application.start(:normal, [])
      end

      defdelegate version, to: Raxol
    end
    """
  end

  defp application_module(%{module: module, ssh: ssh?}) do
    children =
      if ssh? do
        """
            children = [
              {Raxol.SSH.Server, [app_module: #{module}.App, port: 2222]}
            ]
        """
      else
        """
            children = []
        """
      end

    """
    defmodule #{module}.Application do
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
    #{String.trim_trailing(children)}

        opts = [strategy: :one_for_one, name: #{module}.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    """
  end

  # ---------------------------------------------------------------------------
  # TEA app module (used as lib/app_name/app.ex with --sup, or standalone)
  # ---------------------------------------------------------------------------

  defp tea_module(%{template: template} = bindings) do
    module_name = "#{bindings.module}.App"
    do_tea_module(template, %{bindings | module: module_name})
  end

  defp tea_module_standalone(%{template: template} = bindings) do
    source = do_tea_module(template, bindings)

    source <>
      """

      {:ok, pid} = Raxol.start_link(#{bindings.module}, [])
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      end
      """
  end

  defp do_tea_module("blank", %{app: app, module: module}) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TUI application.

      Run with: mix run lib/#{app}.ex
      \"\"\"

      use Raxol.Core.Runtime.Application

      @impl true
      def init(_context) do
        %{}
      end

      @impl true
      def update(message, model) do
        case message do
          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
            {model, [command(:quit)]}

          _ ->
            {model, []}
        end
      end

      @impl true
      def view(_model) do
        column style: %{padding: 1, align_items: :center} do
          text("#{module} -- edit this view!", style: [:bold])
        end
      end

      @impl true
      def subscribe(_model), do: []
    end
    """
  end

  defp do_tea_module("counter", %{app: app, module: module}) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TUI counter application using The Elm Architecture (TEA).

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
    """
  end

  defp do_tea_module("todo", %{app: app, module: module}) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TUI todo application using The Elm Architecture (TEA).

      Run with: mix run lib/#{app}.ex
      \"\"\"

      use Raxol.Core.Runtime.Application

      defmodule Todo do
        defstruct [:id, :text, done: false]
      end

      @impl true
      def init(_context) do
        %{
          todos: [],
          input: "",
          next_id: 1,
          selected: 0,
          mode: :normal
        }
      end

      @impl true
      def update(message, model) do
        case message do
          # Input mode
          {:input_char, char} when model.mode == :input ->
            {%{model | input: model.input <> char}, []}

          :input_backspace when model.mode == :input ->
            {%{model | input: String.slice(model.input, 0..-2//1)}, []}

          :input_submit when model.mode == :input and model.input != "" ->
            todo = %Todo{id: model.next_id, text: model.input}

            {%{model |
              todos: model.todos ++ [todo],
              input: "",
              next_id: model.next_id + 1,
              mode: :normal
            }, []}

          :input_cancel ->
            {%{model | input: "", mode: :normal}, []}

          # Normal mode
          :start_input ->
            {%{model | mode: :input}, []}

          :move_up ->
            selected = max(0, model.selected - 1)
            {%{model | selected: selected}, []}

          :move_down ->
            selected = min(length(model.todos) - 1, model.selected)
            {%{model | selected: selected}, []}

          :toggle_done ->
            todos =
              model.todos
              |> Enum.with_index()
              |> Enum.map(fn {todo, i} ->
                if i == model.selected, do: %{todo | done: !todo.done}, else: todo
              end)

            {%{model | todos: todos}, []}

          :delete_todo ->
            todos = List.delete_at(model.todos, model.selected)
            selected = min(model.selected, max(0, length(todos) - 1))
            {%{model | todos: todos, selected: selected}, []}

          # Key events
          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} when model.mode == :normal ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "a"}} when model.mode == :normal ->
            update(:start_input, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "d"}} when model.mode == :normal ->
            update(:delete_todo, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: " "}} when model.mode == :normal ->
            update(:toggle_done, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :up}} when model.mode == :normal ->
            update(:move_up, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :down}} when model.mode == :normal ->
            update(:move_down, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :enter}} when model.mode == :input ->
            update(:input_submit, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :escape}} ->
            update(:input_cancel, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :backspace}} when model.mode == :input ->
            update(:input_backspace, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}} when model.mode == :input ->
            update({:input_char, ch}, model)

          _ ->
            {model, []}
        end
      end

      @impl true
      def view(model) do
        column style: %{padding: 1, gap: 1} do
          [
            text("Todo List", style: [:bold]),
            box style: %{border: :single, padding: 1, width: 40} do
              column style: %{gap: 0} do
                if model.todos == [] do
                  text("No todos yet. Press 'a' to add one.")
                else
                  Enum.with_index(model.todos)
                  |> Enum.map(fn {todo, i} ->
                    prefix = if i == model.selected, do: "> ", else: "  "
                    check = if todo.done, do: "[x] ", else: "[ ] "
                    style = if todo.done, do: [:dim], else: []
                    text(prefix <> check <> todo.text, style: style)
                  end)
                end
              end
            end,
            if model.mode == :input do
              row do
                [
                  text("New: "),
                  text(model.input <> "_", style: [:underline])
                ]
              end
            else
              text("a:add  space:toggle  d:delete  up/down:move  q:quit", style: [:dim])
            end
          ]
        end
      end

      @impl true
      def subscribe(_model), do: []
    end
    """
  end

  defp do_tea_module("dashboard", %{app: app, module: module}) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TUI dashboard application using The Elm Architecture (TEA).

      Run with: mix run lib/#{app}.ex
      \"\"\"

      use Raxol.Core.Runtime.Application

      @impl true
      def init(_context) do
        %{
          active_panel: 0,
          panels: ["System", "Logs", "Stats"],
          logs: ["App started", "Listening on port 4000", "Connected to database"],
          stats: %{
            uptime: 0,
            requests: 0,
            memory_mb: 42
          },
          tick: 0
        }
      end

      @impl true
      def update(message, model) do
        case message do
          :next_panel ->
            panel = rem(model.active_panel + 1, length(model.panels))
            {%{model | active_panel: panel}, []}

          :prev_panel ->
            panel = rem(model.active_panel - 1 + length(model.panels), length(model.panels))
            {%{model | active_panel: panel}, []}

          :tick ->
            stats = %{model.stats |
              uptime: model.stats.uptime + 1,
              requests: model.stats.requests + Enum.random(0..5)
            }

            {%{model | stats: stats, tick: model.tick + 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :tab}} ->
            update(:next_panel, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "h"}} ->
            update(:prev_panel, model)

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "l"}} ->
            update(:next_panel, model)

          _ ->
            {model, []}
        end
      end

      @impl true
      def view(model) do
        column style: %{padding: 1, gap: 1} do
          [
            row style: %{gap: 2} do
              Enum.with_index(model.panels)
              |> Enum.map(fn {name, i} ->
                style = if i == model.active_panel, do: [:bold, :underline], else: [:dim]
                text(name, style: style)
              end)
            end,
            render_panel(model),
            text("Tab/h/l:switch panels  q:quit", style: [:dim])
          ]
        end
      end

      defp render_panel(%{active_panel: 0} = model) do
        box style: %{border: :single, padding: 1, width: 50} do
          column style: %{gap: 1} do
            [
              text("System Info", style: [:bold]),
              text("Uptime: \#{model.stats.uptime}s"),
              text("Memory: \#{model.stats.memory_mb} MB"),
              text("Elixir: \#{System.version()}"),
              text("OTP: \#{:erlang.system_info(:otp_release)}")
            ]
          end
        end
      end

      defp render_panel(%{active_panel: 1} = model) do
        box style: %{border: :single, padding: 1, width: 50} do
          column style: %{gap: 0} do
            [text("Recent Logs", style: [:bold]) |
              Enum.map(model.logs, fn log -> text("  " <> log, style: [:dim]) end)]
          end
        end
      end

      defp render_panel(%{active_panel: _} = model) do
        box style: %{border: :single, padding: 1, width: 50} do
          column style: %{gap: 1} do
            [
              text("Stats", style: [:bold]),
              text("Requests: \#{model.stats.requests}"),
              row style: %{gap: 0} do
                bar = String.duplicate("#", min(model.stats.requests, 30))
                text("[" <> bar <> "]")
              end
            ]
          end
        end
      end

      @impl true
      def subscribe(_model) do
        [subscribe_interval(1000, :tick)]
      end
    end
    """
  end

  # ---------------------------------------------------------------------------
  # SSH module
  # ---------------------------------------------------------------------------

  defp ssh_module(%{module: module}) do
    app_mod = if String.ends_with?(module, ".App"), do: module, else: "#{module}.App"

    """
    defmodule #{module}.SSH do
      @moduledoc \"\"\"
      SSH server for #{module}.

      Start with:

          #{module}.SSH.start()

      Then connect:

          ssh localhost -p 2222
      \"\"\"

      def start(opts \\\\ []) do
        port = Keyword.get(opts, :port, 2222)
        Raxol.SSH.Server.serve(#{app_mod}, port: port)
      end
    end
    """
  end

  # ---------------------------------------------------------------------------
  # LiveView module
  # ---------------------------------------------------------------------------

  defp liveview_module(%{module: module}) do
    app_mod = if String.ends_with?(module, ".App"), do: module, else: "#{module}.App"

    """
    defmodule #{module}.Live do
      @moduledoc \"\"\"
      Phoenix LiveView bridge for #{module}.

      Add to your Phoenix router:

          live "/app", #{module}.Live
      \"\"\"

      use Phoenix.LiveView

      @impl true
      def mount(params, session, socket) do
        Raxol.LiveView.TEALive.mount(params, session, socket,
          app_module: #{app_mod}
        )
      end

      @impl true
      def handle_info(msg, socket) do
        Raxol.LiveView.TEALive.handle_info(msg, socket)
      end

      @impl true
      def handle_event(event, params, socket) do
        Raxol.LiveView.TEALive.handle_event(event, params, socket)
      end

      @impl true
      def render(assigns) do
        Raxol.LiveView.TEALive.render(assigns)
      end
    end
    """
  end

  # ---------------------------------------------------------------------------
  # Test files
  # ---------------------------------------------------------------------------

  defp test_helper do
    """
    ExUnit.start()
    """
  end

  defp app_test(%{module: module, template: template, sup: sup?}) do
    test_module = if sup?, do: "#{module}.App", else: module

    case template do
      "blank" ->
        """
        defmodule #{module}Test do
          use ExUnit.Case

          test "init returns initial state" do
            assert #{test_module}.init(%{}) == %{}
          end

          test "update ignores unknown messages" do
            model = %{}
            assert {%{}, []} = #{test_module}.update(:unknown, model)
          end
        end
        """

      "counter" ->
        """
        defmodule #{module}Test do
          use ExUnit.Case

          test "init returns initial state" do
            assert #{test_module}.init(%{}) == %{count: 0}
          end

          test "update handles increment" do
            model = %{count: 0}
            assert {%{count: 1}, []} = #{test_module}.update(:increment, model)
          end

          test "update handles decrement" do
            model = %{count: 5}
            assert {%{count: 4}, []} = #{test_module}.update(:decrement, model)
          end

          test "update ignores unknown messages" do
            model = %{count: 0}
            assert {%{count: 0}, []} = #{test_module}.update(:unknown, model)
          end
        end
        """

      "todo" ->
        """
        defmodule #{module}Test do
          use ExUnit.Case

          test "init returns empty todo list" do
            model = #{test_module}.init(%{})
            assert model.todos == []
            assert model.mode == :normal
          end

          test "adding a todo" do
            model = #{test_module}.init(%{})
            {model, []} = #{test_module}.update(:start_input, model)
            assert model.mode == :input
            {model, []} = #{test_module}.update({:input_char, "B"}, model)
            {model, []} = #{test_module}.update({:input_char, "u"}, model)
            {model, []} = #{test_module}.update({:input_char, "y"}, model)
            {model, []} = #{test_module}.update(:input_submit, model)
            assert length(model.todos) == 1
            assert hd(model.todos).text == "Buy"
            assert model.mode == :normal
          end

          test "toggling a todo" do
            model = %{#{test_module}.init(%{}) |
              todos: [%#{test_module}.Todo{id: 1, text: "Test", done: false}],
              selected: 0
            }
            {model, []} = #{test_module}.update(:toggle_done, model)
            assert hd(model.todos).done == true
          end

          test "deleting a todo" do
            model = %{#{test_module}.init(%{}) |
              todos: [%#{test_module}.Todo{id: 1, text: "Test"}],
              selected: 0
            }
            {model, []} = #{test_module}.update(:delete_todo, model)
            assert model.todos == []
          end
        end
        """

      "dashboard" ->
        """
        defmodule #{module}Test do
          use ExUnit.Case

          test "init returns dashboard state" do
            model = #{test_module}.init(%{})
            assert model.active_panel == 0
            assert length(model.panels) == 3
          end

          test "switching panels" do
            model = #{test_module}.init(%{})
            {model, []} = #{test_module}.update(:next_panel, model)
            assert model.active_panel == 1
            {model, []} = #{test_module}.update(:next_panel, model)
            assert model.active_panel == 2
            {model, []} = #{test_module}.update(:next_panel, model)
            assert model.active_panel == 0
          end

          test "tick updates stats" do
            model = #{test_module}.init(%{})
            {model, []} = #{test_module}.update(:tick, model)
            assert model.stats.uptime == 1
            assert model.tick == 1
          end
        end
        """
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_add(list, true, item), do: list ++ [item]
  defp maybe_add(list, false, _item), do: list
end
