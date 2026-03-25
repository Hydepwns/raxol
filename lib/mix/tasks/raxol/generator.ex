defmodule Mix.Raxol.Generator do
  @moduledoc """
  File creation orchestration for `mix raxol.new`.

  Handles directory scaffolding, file writing, git init,
  optional dependency installation, and post-generation output.
  """

  alias Mix.Raxol.Content

  @compile {:no_warn_undefined, Mix.Raxol.Content}

  @doc "Generates the full project structure at `path` with the given opts."
  def generate(name, opts, raxol_version) do
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
      version: raxol_version
    }

    Mix.shell().info([:green, "* creating ", :reset, name])

    File.mkdir_p!(path)
    File.mkdir_p!(Path.join(path, "lib"))
    File.mkdir_p!(Path.join(path, "config"))
    unless skip_test, do: File.mkdir_p!(Path.join(path, "test"))

    # Core files
    write_file(path, "mix.exs", Content.mix_exs(bindings))
    write_file(path, "config/config.exs", Content.config_exs(bindings))
    write_file(path, ".formatter.exs", Content.formatter())
    write_file(path, ".gitignore", Content.gitignore())
    write_file(path, "README.md", Content.readme(bindings))
    write_file(path, ".mise.toml", Content.mise_toml())

    # App modules
    if sup? do
      write_file(path, "lib/#{app}.ex", Content.app_module_sup(bindings))

      write_file(
        path,
        "lib/#{app}/application.ex",
        Content.application_module(bindings)
      )

      write_file(path, "lib/#{app}/app.ex", Content.tea_module(bindings))
    else
      write_file(path, "lib/#{app}.ex", Content.tea_module_standalone(bindings))
    end

    if ssh?,
      do: write_file(path, "lib/#{app}/ssh.ex", Content.ssh_module(bindings))

    if liveview?,
      do:
        write_file(
          path,
          "lib/#{app}/live.ex",
          Content.liveview_module(bindings)
        )

    unless skip_test do
      write_file(path, "test/test_helper.exs", Content.test_helper())
      write_file(path, "test/#{app}_test.exs", Content.app_test(bindings))
    end

    if ci?,
      do:
        write_file(
          path,
          ".github/workflows/ci.yml",
          Content.ci_workflow(bindings)
        )

    git_init(path)

    Mix.shell().info("")

    if install?, do: install_and_verify(path)

    print_instructions(bindings, name, install?)
  end

  # --- Private ---

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

  defp git_init(path) do
    case System.cmd("git", ["init"], cd: path, stderr_to_stdout: true) do
      {_, 0} ->
        System.cmd("git", ["add", "."], cd: path, stderr_to_stdout: true)

        System.cmd(
          "git",
          ["commit", "-m", "Initial commit from mix raxol.new"],
          cd: path,
          stderr_to_stdout: true
        )

        Mix.shell().info([
          "  ",
          :green,
          "* initialized ",
          :reset,
          "git repo with initial commit"
        ])

      _ ->
        Mix.shell().info([
          "  ",
          :yellow,
          "* skipping ",
          :reset,
          "git init (git not available)"
        ])
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

        Mix.shell().error(
          "Failed to install dependencies. Run `mix deps.get` manually."
        )
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

      Mix.shell().info([
        "Then connect: ",
        :cyan,
        "ssh localhost -p 2222",
        :reset
      ])
    end

    Mix.shell().info("")
  end
end
