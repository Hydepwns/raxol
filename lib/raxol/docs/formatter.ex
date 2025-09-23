defmodule Raxol.Docs.Formatter do
  @moduledoc """
  Documentation formatter for command palette and interactive docs.

  Handles formatting of function docs, examples, and API references
  for both terminal and web display.
  """

  @doc """
  Format function documentation for display.
  """
  def format_function_docs(module, function, arity, doc_content) do
    case doc_content do
      %{"en" => doc_text} when is_binary(doc_text) ->
        format_function_doc_text(module, function, arity, doc_text)

      _ ->
        format_basic_function_info(module, function, arity)
    end
  end

  @doc """
  Format API reference documentation.
  """
  def format_api_reference(module_or_topic) do
    case module_or_topic do
      module when is_atom(module) ->
        format_module_reference(module)

      topic when is_binary(topic) ->
        format_topic_reference(topic)
    end
  end

  @doc """
  Format example documentation.
  """
  def format_example(example_id, content) do
    """
    #{header("Example: #{example_id}")}

    #{content}

    #{section_divider()}
    """
  end

  @doc """
  Format guide documentation.
  """
  def format_guide(guide_id, content) do
    """
    #{header("Guide: #{String.replace(guide_id, "_", " ") |> String.capitalize()}")}

    #{content}

    #{section_divider()}
    """
  end

  @doc """
  Format search results for terminal display.
  """
  def format_search_results(results, query) do
    header_text = "Search Results for \"#{query}\""

    formatted_results =
      results
      |> Enum.with_index(1)
      |> Enum.map_join("\n\n", &format_search_result/1)

    """
    #{header(header_text)}

    #{formatted_results}

    #{section_divider()}
    """
  end

  @doc """
  Format component preview for display.
  """
  def format_component_preview(component, props \\ %{}) do
    """
    #{header("Component: #{component.name}")}

    #{component.description}

    #{format_component_properties(component, props)}

    #{format_component_example(component, props)}

    #{section_divider()}
    """
  end

  # Private Functions

  defp format_function_doc_text(module, function, arity, doc_text) do
    signature = "#{inspect(module)}.#{function}/#{arity}"

    # Extract first paragraph as summary
    {summary, rest} = extract_summary(doc_text)

    # Parse examples from doc text
    examples = extract_examples(doc_text)

    formatted_examples =
      if examples != [] do
        "\n#{subheader("Examples:")}\n" <>
          Enum.map_join(examples, "\n\n", &format_code_example/1)
      else
        ""
      end

    """
    #{header(signature)}

    #{format_doc_text(summary)}

    #{if rest != "", do: format_doc_text(rest), else: ""}
    #{formatted_examples}

    #{section_divider()}
    """
  end

  defp format_basic_function_info(module, function, arity) do
    signature = "#{inspect(module)}.#{function}/#{arity}"

    try do
      # Get function spec if available - using safe approach
      specs = fetch_specs_safe(module)

      spec_info =
        case specs do
          {:ok, type_specs} ->
            case Enum.find(type_specs, fn {{name, ar}, _} ->
                   name == function and ar == arity
                 end) do
              {_, spec} -> format_typespec(spec)
              _ -> ""
            end

          _ ->
            ""
        end

      """
      #{header(signature)}

      #{if spec_info != "", do: "#{bold("Spec:")} #{spec_info}\n", else: ""}

      No documentation available. Use h(#{inspect(module)}.#{function}) in IEx for more info.

      #{section_divider()}
      """
    rescue
      _ ->
        """
        #{header(signature)}

        Function information not available.

        #{section_divider()}
        """
    end
  end

  defp format_module_reference(module) do
    try do
      case Code.fetch_docs(module) do
        {:docs_v1, _, _, _, moduledoc, _, function_docs} ->
          module_doc =
            case moduledoc do
              %{"en" => doc} -> format_doc_text(doc)
              _ -> "No module documentation available."
            end

          functions =
            function_docs
            |> Enum.filter(fn {{type, _, _}, _, _, _, _} ->
              type == :function
            end)
            |> Enum.map_join("\n", fn {{_, name, arity}, _, _, doc, _} ->
              doc_summary =
                case doc do
                  %{"en" => text} -> extract_summary(text) |> elem(0)
                  _ -> ""
                end

              "  • #{bold("#{name}/#{arity}")} - #{doc_summary}"
            end)

          """
          #{header("Module: #{inspect(module)}")}

          #{module_doc}

          #{if functions != "", do: "#{subheader("Functions:")}\n#{functions}", else: ""}

          #{section_divider()}
          """

        _ ->
          """
          #{header("Module: #{inspect(module)}")}

          Module documentation not available.

          #{section_divider()}
          """
      end
    rescue
      _ ->
        """
        #{header("Module: #{inspect(module)}")}

        Unable to load module documentation.

        #{section_divider()}
        """
    end
  end

  defp format_topic_reference(topic) do
    content =
      case topic do
        "ui" -> format_ui_reference()
        "terminal" -> format_terminal_reference()
        "components" -> format_components_reference()
        _ -> "Reference documentation for #{topic} not available."
      end

    """
    #{header("#{String.capitalize(topic)} API Reference")}

    #{content}

    #{section_divider()}
    """
  end

  defp format_ui_reference do
    """
    The Raxol.UI module provides the core framework for building terminal UIs.

    #{bold("Key Concepts:")}
    • Multi-framework support (React, Svelte, LiveView, HEEx)
    • Universal components that work across frameworks
    • Event handling and state management
    • Theme and styling system

    #{bold("Basic Usage:")}
    ```elixir
    use Raxol.UI, framework: :react

    def render(assigns) do
      ~H\"\"\"
      <div class="container">
        <h1>Hello Raxol!</h1>
      </div>
      \"\"\"
    end
    ```
    """
  end

  defp format_terminal_reference do
    """
    Terminal emulation and control APIs for ANSI/VT100 compatible terminals.

    #{bold("Core Modules:")}
    • Raxol.Terminal.Emulator - Main terminal emulator
    • Raxol.Terminal.Buffer - Screen buffer management
    • Raxol.Terminal.ANSI.Parser - ANSI sequence parsing
    • Raxol.Terminal.Cursor - Cursor positioning and control

    #{bold("Common Operations:")}
    ```elixir
    # Clear screen
    Raxol.Terminal.clear_screen()

    # Move cursor
    Raxol.Terminal.move_cursor(row, col)

    # Set colors
    Raxol.Terminal.set_color(:red, :black)
    ```
    """
  end

  defp format_components_reference do
    """
    Built-in component library for common UI patterns.

    #{bold("Available Components:")}
    • Button - Interactive buttons with various styles
    • TextInput - Single and multi-line text input
    • Table - Data tables with sorting and filtering
    • Modal - Overlay dialogs and popups
    • Progress - Progress bars and indicators
    • Menu - Dropdown and context menus

    #{bold("Example Usage:")}
    ```elixir
    use Raxol.UI.Components

    def render(assigns) do
      ~H\"\"\"
      <Button onclick={@handle_click}>
        Click me!
      </Button>
      \"\"\"
    end
    ```
    """
  end

  defp format_search_result({result, index}) do
    score_indicator =
      case result.score do
        s when s > 0.8 -> "🎯"
        s when s > 0.6 -> "✅"
        s when s > 0.4 -> "⚡"
        _ -> "💡"
      end

    category_tag = "[#{String.upcase(to_string(result.category))}]"

    """
    #{score_indicator} #{bold("#{index}.")} #{result.title} #{dim(category_tag)}
       #{result.description}
    """
  end

  defp format_component_properties(component, current_props) do
    case Map.get(component, :properties) do
      nil ->
        ""

      properties ->
        prop_list =
          properties
          |> Enum.map_join(
            "\n",
            fn {prop_name, prop_config} ->
              current_value =
                Map.get(current_props, prop_name, prop_config[:default])

              "  • #{bold(to_string(prop_name))} (#{prop_config[:type]}) = #{inspect(current_value)}"
            end
          )

        "#{subheader("Properties:")}\n#{prop_list}\n"
    end
  end

  defp format_component_example(component, props) do
    case Map.get(component, :example_code) do
      nil ->
        ""

      code ->
        rendered_code = String.replace(code, "%PROPS%", inspect(props))

        """
        #{subheader("Example:")}
        #{format_code_block(rendered_code, "elixir")}
        """
    end
  end

  defp extract_summary(text) do
    lines = String.split(text, "\n")

    # Find first paragraph (until empty line)
    {summary_lines, rest_lines} = Enum.split_while(lines, &(&1 != ""))

    summary = Enum.join(summary_lines, "\n")
    rest = rest_lines |> Enum.drop(1) |> Enum.join("\n")

    {summary, rest}
  end

  defp extract_examples(doc_text) do
    # Extract code blocks that look like examples
    ~r/```(?:elixir)?\n(.*?)\n```/s
    |> Regex.scan(doc_text, capture: :all_but_first)
    |> Enum.map(&List.first/1)
    |> Enum.filter(&String.contains?(&1, ["iex>", "=>", "#"]))
  end

  defp format_code_example(code) do
    format_code_block(code, "elixir")
  end

  defp format_code_block(code, language) do
    """
    ```#{language}
    #{String.trim(code)}
    ```
    """
  end

  defp format_doc_text(text) do
    text
    |> String.replace(~r/`([^`]+)`/, "#{IO.ANSI.yellow()}\\1#{IO.ANSI.reset()}")
    |> String.replace(
      ~r/\*\*([^*]+)\*\*/,
      "#{IO.ANSI.bright()}\\1#{IO.ANSI.reset()}"
    )
    |> String.replace(
      ~r/\*([^*]+)\*/,
      "#{IO.ANSI.italic()}\\1#{IO.ANSI.reset()}"
    )
  end

  defp format_typespec(spec) do
    # Simplified typespec formatting
    inspect(spec)
  end

  # Terminal formatting helpers

  defp header(text) do
    width = String.length(text) + 4
    border = String.duplicate("═", width)

    """
    #{IO.ANSI.cyan()}╔#{border}╗
    ║  #{text}  ║
    ╚#{border}╝#{IO.ANSI.reset()}
    """
  end

  defp subheader(text) do
    "#{IO.ANSI.bright()}#{text}#{IO.ANSI.reset()}"
  end

  defp section_divider do
    "#{IO.ANSI.light_black()}#{String.duplicate("─", 60)}#{IO.ANSI.reset()}"
  end

  defp bold(text) do
    "#{IO.ANSI.bright()}#{text}#{IO.ANSI.reset()}"
  end

  defp dim(text) do
    "#{IO.ANSI.light_black()}#{text}#{IO.ANSI.reset()}"
  end

  # Safe wrapper for fetching type specs
  defp fetch_specs_safe(module) do
    try do
      # Use Code.Typespec instead of Kernel.Typespec
      case Code.Typespec.fetch_specs(module) do
        {:ok, specs} -> {:ok, specs}
        :error -> {:error, :no_specs}
      end
    rescue
      _ -> {:error, :fetch_failed}
    end
  end
end
