defmodule Raxol.UI do
  @moduledoc """
  Unified UI framework adapter for Raxol.

  Provides a consistent interface across different UI paradigms:
  - React-style components
  - Svelte-style reactive components
  - Phoenix LiveView components
  - HEEx templates
  - Raw terminal buffer operations

  ## Usage

      # Choose your preferred framework
      use Raxol.UI, framework: :react
      use Raxol.UI, framework: :svelte
      use Raxol.UI, framework: :liveview
      use Raxol.UI, framework: :heex
      use Raxol.UI, framework: :raw

  ## Universal Features

  Regardless of framework choice, you get:
  - Actions system (use: directive)
  - Transitions and animations
  - Context API
  - Slot system
  - Theme support
  """

  defmacro __using__(opts) do
    framework = Keyword.get(opts, :framework, :react)

    # Evaluate framework selection at macro expansion time,
    # not runtime, to avoid importing non-existent modules
    framework_code =
      case framework do
        :react ->
          quote(do: use(Raxol.Component))

        :svelte ->
          raise "Svelte framework has been removed. Please use :react, :liveview, :heex, :universal, or :raw instead"

        :liveview ->
          quote(do: use(Raxol.LiveView))

        :heex ->
          quote(do: use(Raxol.HEEx))

        :universal ->
          quote(do: use(Raxol.HEEx))

        :raw ->
          quote do
            import Raxol.Terminal.Buffer
            import Raxol.Terminal.Commands
          end

        _ ->
          raise ArgumentError, """
          Invalid framework: #{inspect(framework)}

          Supported frameworks:
          - :react (React-style components)
          - :liveview (Phoenix LiveView style)
          - :heex (Phoenix HEEx templates)
          - :universal (Universal HEEx templates)
          - :raw (Direct terminal buffer access)
          """
      end

    quote do
      unquote(framework_code)

      # Universal features available to all frameworks
      import Raxol.UI.Universal
    end
  end

  @doc """
  Create a new UI component with the specified framework.
  """
  def create_component(module, framework, opts \\ []) do
    quote do
      defmodule unquote(module) do
        use Raxol.UI, framework: unquote(framework)
        unquote(opts[:body] || quote(do: nil))
      end
    end
  end

  @doc """
  Convert between different UI frameworks at runtime.
  """
  def convert_component(source_framework, target_framework, component_ast) do
    case {source_framework, target_framework} do
      {:react, :svelte} -> convert_react_to_svelte(component_ast)
      {:svelte, :react} -> convert_svelte_to_react(component_ast)
      {:liveview, :react} -> convert_liveview_to_react(component_ast)
      # Add more conversions as needed
      _ -> {:error, "Conversion not supported"}
    end
  end

  # Framework conversion helpers (simplified implementations)

  defp convert_react_to_svelte(ast) do
    # Convert React patterns to Svelte patterns
    # This would be much more complex in reality
    ast
  end

  defp convert_svelte_to_react(ast) do
    # Convert Svelte patterns to React patterns
    ast
  end

  defp convert_liveview_to_react(ast) do
    # Convert LiveView patterns to React patterns
    ast
  end
end
