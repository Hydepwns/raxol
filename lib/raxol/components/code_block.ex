defmodule Raxol.Components.CodeBlock do
  @moduledoc """
  Renders a block of code with syntax highlighting.

  Requires the `makeup_elixir` dependency (and potentially other lexers).
  Uses HTML output from Makeup.
  """
  use Raxol.Core.Runtime.Component
  import Raxol.View.Elements

  alias Makeup.Lexers

  @doc """
  Renders the code block.

  Props:
    * `content` (required): The source code string.
    * `language` (required): The language name (e.g., "elixir", "html").
    * `style`: The Makeup HTML style module (e.g., `Makeup.Styles.GithubLight`). Defaults to `:github_light` style lookup.
    * `class`: Optional CSS class for the outer `pre` tag.
  """
  def render(assigns) do
    language = assigns[:language] || "text" # Default to plain text
    code_content = assigns[:content] || "" # Default to empty string
    style_opt = assigns[:style] # User-provided style module
    custom_class = assigns[:class]

    # Combine base class with custom class
    pre_class = Enum.join(Enum.filter(["highlight", custom_class], & &1), " ")

    case {Code.ensure_loaded?(Makeup), Code.ensure_loaded?(Makeup.Lexers.ElixirLexer)} do
      {{:module, Makeup}, {:module, _lexer}} ->
        # Determine the lexer
        lexer = Makeup.Lexer.lexer_for(language)
                |> case do
                     {:ok, l} -> l
                     _ -> Lexers.PlainTextLexer # Fallback lexer
                   end

        # Determine the style
        # Allow passing a module directly or using a default
        style = cond do
           is_atom(style_opt) -> Makeup.Style.style_for(style_opt)
                                   |> case do
                                        {:ok, s} -> s
                                        _ -> Makeup.Styles.GithubLight # Default style
                                      end
           is_atom(style_opt) && Code.ensure_loaded?(style_opt) -> style_opt
           true -> Makeup.Styles.GithubLight # Default style
        end

        # Generate highlighted HTML
        # Using Makeup.highlight! which raises on error
        highlighted_html = Makeup.highlight!(code_content, lexer: lexer, style: style)

        # Render using hypothetical raw_html inside pre/code tags
        view do
          pre(class: pre_class) do
            code do
              raw_html(content: highlighted_html)
            end
          end
        end

      {{:error, _}, _} ->
        render_fallback(code_content, pre_class, "[CodeBlock Error: Makeup library not found. Please add :makeup_elixir to deps.]")
      {_, {:error, _}} ->
        # Check specifically for Elixir lexer as it's common
         render_fallback(code_content, pre_class, "[CodeBlock Error: Makeup.Lexers.ElixirLexer not found. Ensure lexers are available.]")
    end
  end

  defp render_fallback(code_content, pre_class, error_message) do
    view do
      div(style: "color: red; border: 1px solid red; padding: 5px; margin-bottom: 5px;") do
         text(content: error_message)
      end
      pre(class: pre_class) do
         code do
           text(content: code_content)
         end
      end
    end
  end

  # Again, assumes raw_html exists in Raxol
  # defp raw_html(assigns), do: # ... implementation depends on Raxol internals

end
