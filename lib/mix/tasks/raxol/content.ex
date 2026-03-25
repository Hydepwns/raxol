defmodule Mix.Raxol.Content do
  @moduledoc """
  Boilerplate content generators for `mix raxol.new`.

  All functions return strings of generated file content.
  """

  @doc "Generates mix.exs content."
  def mix_exs(%{
        app: app,
        module: module,
        ssh: ssh?,
        liveview: liveview?,
        version: version
      }) do
    extra_deps =
      []
      |> maybe_add(ssh?, ~s|{:ssh_subsystem_fwup, "~> 0.6", optional: true}|)
      |> maybe_add(liveview?, ~s|{:phoenix_live_view, "~> 1.0"}|)
      |> maybe_add(liveview?, ~s|{:phoenix, "~> 1.7"}|)

    all_deps = [~s|{:raxol, "~> #{version}"}| | extra_deps]
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

  @doc "Generates config/config.exs content."
  def config_exs(%{app: app, ssh: ssh?, liveview: liveview?}) do
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

  @doc "Generates .formatter.exs content."
  def formatter do
    """
    [
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
    ]
    """
  end

  @doc "Generates .gitignore content."
  def gitignore do
    """
    /_build/
    /deps/
    /doc/
    *.beam
    .fetch
    erl_crash.dump
    """
  end

  @doc "Generates .mise.toml content."
  def mise_toml do
    elixir_vsn = System.version()
    otp_vsn = :erlang.system_info(:otp_release) |> to_string()

    """
    [tools]
    elixir = "#{elixir_vsn}"
    erlang = "#{otp_vsn}"
    """
  end

  @doc "Generates README.md content."
  def readme(%{app: app, module: module, template: template, sup: sup?}) do
    run_cmd = if sup?, do: "mix run --no-halt", else: "mix run lib/#{app}.ex"

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

  @doc "Generates GitHub Actions CI workflow YAML."
  def ci_workflow(_bindings) do
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

  @doc "Generates the main module when --sup is used."
  def app_module_sup(%{module: module}) do
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

  @doc "Generates Application module for --sup."
  def application_module(%{module: module, ssh: ssh?}) do
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

  @doc "Generates TEA app module (lib/app/app.ex with --sup)."
  def tea_module(%{template: template} = bindings) do
    module_name = "#{bindings.module}.App"
    do_tea_module(template, %{bindings | module: module_name})
  end

  @doc "Generates standalone TEA app module (lib/app.ex without --sup)."
  def tea_module_standalone(%{template: template} = bindings) do
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

  @doc "Generates SSH server module."
  def ssh_module(%{module: module}) do
    app_mod =
      if String.ends_with?(module, ".App"), do: module, else: "#{module}.App"

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

  @doc "Generates Phoenix LiveView bridge module."
  def liveview_module(%{module: module}) do
    app_mod =
      if String.ends_with?(module, ".App"), do: module, else: "#{module}.App"

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

  @doc "Generates test/test_helper.exs content."
  def test_helper do
    """
    ExUnit.start()
    """
  end

  @doc "Generates the app test file content based on template."
  def app_test(%{module: module, template: template, sup: sup?}) do
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

  # --- Private ---

  defp do_tea_module("blank", %{app: app, module: module}) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TUI application.

      Run with: mix run lib/#{app}.ex
      \"\"\"

      use Raxol.Core.Runtime.Application

      @impl true
      def init(_context), do: %{}

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
      def init(_context), do: %{count: 0}

      @impl true
      def update(message, model) do
        case message do
          :increment -> {%{model | count: model.count + 1}, []}
          :decrement -> {%{model | count: model.count - 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "+"}} ->
            {%{model | count: model.count + 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "-"}} ->
            {%{model | count: model.count - 1}, []}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
            {model, [command(:quit)]}

          %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
            {model, [command(:quit)]}

          _ -> {model, []}
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
        %{todos: [], input: "", next_id: 1, selected: 0, mode: :normal}
      end

      @impl true
      def update(message, model) do
        case message do
          {:input_char, char} when model.mode == :input ->
            {%{model | input: model.input <> char}, []}

          :input_backspace when model.mode == :input ->
            {%{model | input: String.slice(model.input, 0..-2//1)}, []}

          :input_submit when model.mode == :input and model.input != "" ->
            todo = %Todo{id: model.next_id, text: model.input}
            {%{model | todos: model.todos ++ [todo], input: "", next_id: model.next_id + 1, mode: :normal}, []}

          :input_cancel -> {%{model | input: "", mode: :normal}, []}
          :start_input -> {%{model | mode: :input}, []}
          :move_up -> {%{model | selected: max(0, model.selected - 1)}, []}
          :move_down -> {%{model | selected: min(length(model.todos) - 1, model.selected)}, []}

          :toggle_done ->
            todos = model.todos |> Enum.with_index() |> Enum.map(fn {t, i} ->
              if i == model.selected, do: %{t | done: !t.done}, else: t
            end)
            {%{model | todos: todos}, []}

          :delete_todo ->
            todos = List.delete_at(model.todos, model.selected)
            {%{model | todos: todos, selected: min(model.selected, max(0, length(todos) - 1))}, []}

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

          _ -> {model, []}
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
                [text("New: "), text(model.input <> "_", style: [:underline])]
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
          stats: %{uptime: 0, requests: 0, memory_mb: 42},
          tick: 0
        }
      end

      @impl true
      def update(message, model) do
        case message do
          :next_panel ->
            {%{model | active_panel: rem(model.active_panel + 1, length(model.panels))}, []}

          :prev_panel ->
            {%{model | active_panel: rem(model.active_panel - 1 + length(model.panels), length(model.panels))}, []}

          :tick ->
            stats = %{model.stats | uptime: model.stats.uptime + 1, requests: model.stats.requests + Enum.random(0..5)}
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

          _ -> {model, []}
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

  defp maybe_add(list, true, item), do: list ++ [item]
  defp maybe_add(list, false, _item), do: list
end
