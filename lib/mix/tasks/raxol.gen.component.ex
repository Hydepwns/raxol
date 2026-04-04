defmodule Mix.Tasks.Raxol.Gen.Component do
  @moduledoc """
  Generates a new Raxol TEA component module and test.

  ## Usage

      mix raxol.gen.component MyComponent

  This creates:

    * `lib/<app>/components/my_component.ex` - Component module with TEA callbacks
    * `test/<app>/components/my_component_test.exs` - Tests for the component

  ## Options

    * `--no-test` - Skip generating the test file

  ## Examples

      mix raxol.gen.component Sidebar
      mix raxol.gen.component StatusBar --no-test
  """

  use Mix.Task

  @shortdoc "Generate a new Raxol TEA component"

  @switches [no_test: :boolean]

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: @switches) do
      {opts, [name], _} ->
        generate(name, opts)

      _ ->
        Mix.shell().error("Usage: mix raxol.gen.component MODULE_NAME")
        Mix.shell().error("Example: mix raxol.gen.component Sidebar")
    end
  end

  defp generate(name, opts) do
    validate_component_name!(name)

    {module, filename} = derive_module_and_filename(name)
    write_component_files(module, filename, opts)
    print_generation_summary(name, module)
  end

  defp validate_component_name!(name) do
    unless name =~ ~r/^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)*$/ do
      Mix.raise(
        "Component name must be a valid Elixir module name (e.g., Sidebar, StatusBar). Got: #{name}"
      )
    end
  end

  defp derive_module_and_filename(name) do
    app =
      Mix.Project.config()[:app] ||
        Mix.raise("Could not determine app name from mix.exs")

    app_module = app |> to_string() |> Macro.camelize()
    module = "#{app_module}.Components.#{name}"
    filename = name |> Macro.underscore() |> String.replace("/", "_")
    {module, "#{app}/#{filename}"}
  end

  defp write_component_files(module, path, opts) do
    write_file("lib/#{path}.ex", component_module(module))

    unless Keyword.get(opts, :no_test, false) do
      write_file("test/#{path}_test.exs", component_test(module))
    end
  end

  defp print_generation_summary(name, module) do
    Mix.shell().info("")
    Mix.shell().info([:green, :bright, "Component #{name} created.", :reset])
    Mix.shell().info("")
    Mix.shell().info("Use it in your view:")
    Mix.shell().info("")

    Mix.shell().info([
      "    ",
      :cyan,
      "process_component(#{module}, %{my_prop: value})",
      :reset
    ])

    Mix.shell().info("")
  end

  defp write_file(path, content) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
    Mix.shell().info(["  ", :green, "* creating ", :reset, path])
  end

  defp component_module(module) do
    """
    defmodule #{module} do
      @moduledoc \"\"\"
      A Raxol TEA component.

      ## Props

      * `:title` - Component title (default: "#{List.last(String.split(module, "."))}")

      ## Messages

      * `:reset` - Reset component state
      \"\"\"

      use Raxol.Core.Runtime.Application

      @impl true
      def init(props) do
        %{
          title: Map.get(props, :title, "#{List.last(String.split(module, "."))}"),
          value: 0
        }
      end

      @impl true
      def update(message, model) do
        case message do
          :reset ->
            {%{model | value: 0}, []}

          {:set_value, val} ->
            {%{model | value: val}, []}

          _ ->
            {model, []}
        end
      end

      @impl true
      def view(model) do
        box style: %{border: :single, padding: 1} do
          column style: %{gap: 1} do
            [
              text(model.title, style: [:bold]),
              text("Value: \#{model.value}")
            ]
          end
        end
      end

      @impl true
      def subscribe(_model), do: []
    end
    """
  end

  defp component_test(module) do
    """
    defmodule #{module}Test do
      use ExUnit.Case

      test "init with default props" do
        model = #{module}.init(%{})
        assert model.value == 0
      end

      test "init with custom props" do
        model = #{module}.init(%{title: "Custom"})
        assert model.title == "Custom"
      end

      test "update handles reset" do
        model = %{title: "Test", value: 42}
        assert {%{value: 0}, []} = #{module}.update(:reset, model)
      end

      test "update handles set_value" do
        model = %{title: "Test", value: 0}
        assert {%{value: 10}, []} = #{module}.update({:set_value, 10}, model)
      end

      test "update ignores unknown messages" do
        model = %{title: "Test", value: 5}
        assert {%{value: 5}, []} = #{module}.update(:unknown, model)
      end
    end
    """
  end
end
