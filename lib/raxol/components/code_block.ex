defmodule Raxol.Components.CodeBlock do
  @moduledoc """
  Renders a block of code with syntax highlighting.

  Requires the `makeup_elixir` dependency (and potentially other lexers).
  Uses HTML output from Makeup.
  """
  use Raxol.UI.Components.Base.Component
  # Removed import Raxol.View.Elements

  @doc """
  Renders the code block.

  Props:
    * `content` (required): The source code string.
    * `language` (required): The language name (e.g., "elixir", "html").
    * `style`: The Makeup HTML style module (e.g., `Makeup.Styles.GithubLight`). Defaults to `:github_light` style lookup.
    * `class`: Optional CSS class for the outer `pre` tag.
  """
  def render(state, _context) do
    _language = state[:language] || "text"
    code_content = state[:content] || ""
    style_opt = state[:style]
    custom_class = state[:class] # Unused for now
    _pre_class = Enum.join(Enum.filter(["highlight", custom_class], & &1), " ") # Prefixed unused variable

    # Return element structure directly
    case {Code.ensure_loaded?(Makeup), Code.ensure_loaded?(Makeup.Lexers.ElixirLexer)} do
      {true, true} ->
        # Makeup and ElixirLexer are loaded
        # Defaulting to PlainTextLexer as lexer_for seems unavailable/private
        # lexer = case Makeup.Lexer.lexer_for(language) do
        #           {:ok, l} -> l
        #           _ -> Makeup.Lexers.PlainTextLexer
        #         end
        lexer = Makeup.Lexers.PlainTextLexer

        style = cond do
            # Assuming Makeup.Style.style_for/1 doesn't exist or changed, use default
            # is_atom(style_opt) -> ...
            is_atom(style_opt) && Code.ensure_loaded?(style_opt) -> style_opt
            true -> Makeup.Styles.GithubLight # Default style
        end

        # Use Makeup.highlight/2 instead of highlight!/2
        highlighted_html = case Makeup.highlight(code_content, lexer: lexer, style: style) do
                             {:ok, html} -> html
                             {:error, _reason} -> code_content # Fallback to raw code on error
                           end

        # Render using text
        Raxol.View.Components.text(content: highlighted_html)

      {false, _} ->
        # Makeup library not found
        Raxol.View.Components.text(content: code_content <> "\n[CodeBlock Error: Makeup library not found.]")

      {true, false} ->
        # ElixirLexer (or potentially others) not found, but Makeup is.
        # Try highlighting with PlainTextLexer as a fallback.
        lexer = Makeup.Lexers.PlainTextLexer
        style = Makeup.Styles.GithubLight # Use default style
        highlighted_html = case Makeup.highlight(code_content, lexer: lexer, style: style) do
                              {:ok, html} -> html
                              {:error, _} -> code_content
                            end
        Raxol.View.Components.text(content: highlighted_html <> "\n[CodeBlock Warning: Language lexer not found, using plain text.]")
    end
  end

  # Add missing callbacks for Base.Component behaviour
  def init(props), do: props # Simple init stores props in state
  def update(_message, state), do: state # No updates handled
  def handle_event(_event, state, _context), do: {state, []} # No events handled

  # Removed render_fallback/3 helper function

  # Again, assumes raw_html exists in Raxol
  # defp raw_html(assigns), do: # ... implementation depends on Raxol internals

end
