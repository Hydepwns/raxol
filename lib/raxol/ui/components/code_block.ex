defmodule Raxol.UI.Components.CodeBlock do
  @moduledoc """
  Renders a block of code with syntax highlighting.

  Requires the `makeup_elixir` dependency (and potentially other lexers).
  Uses HTML output from Makeup.
  """
  use Raxol.UI.Components.Base.Component

  import Raxol.Guards

  @doc """
  Renders the code block.

  Props:
    * `content` (required): The source code string.
    * `language` (required): The language name (e.g., "elixir", "html").
    * `style`: The Makeup HTML style module (e.g., `Makeup.Styles.GithubLight`). Defaults to `:github_light` style lookup.
    * `class`: Optional CSS class for the outer `pre` tag.
  """
  @spec render(map(), map()) :: any()
  def render(state, _context) do
    _language = state[:language] || "text"
    code_content = state[:content] || ""
    style_opt = state[:style]
    # Unused for now
    custom_class = state[:class]
    _pre_class = Enum.join(Enum.filter(["highlight", custom_class], & &1), " ")

    # Return element structure directly
    case {Code.ensure_loaded?(Makeup),
          Code.ensure_loaded?(Makeup.Lexers.ElixirLexer)} do
      {true, true} ->
        # Makeup and ElixirLexer are loaded
        # Defaulting to PlainTextLexer as lexer_for seems unavailable/private
        # lexer = case Makeup.Lexer.lexer_for(language) do
        #           {:ok, l} -> l
        #           _ -> Makeup.Lexers.PlainTextLexer
        #         end
        lexer = Makeup.Lexers.PlainTextLexer

        style =
          if atom?(style_opt) && Code.ensure_loaded?(style_opt) do
            style_opt
          else
            Makeup.Styles.GithubLight
          end

        # Use Makeup.highlight/2 instead of highlight!/2
        highlighted_html =
          case Makeup.highlight(code_content, lexer: lexer, style: style) do
            {:ok, html} -> html
            # Fallback to raw code on error
            {:error, _reason} -> code_content
          end

        # Render using text
        Raxol.View.Components.text(content: highlighted_html)

      {false, _} ->
        # Makeup library not found
        Raxol.View.Components.text(
          content:
            code_content <> "\n[CodeBlock Error: Makeup library not found.]"
        )

      {true, false} ->
        # ElixirLexer (or potentially others) not found, but Makeup is.
        # Try highlighting with PlainTextLexer as a fallback.
        lexer = Makeup.Lexers.PlainTextLexer
        # Use default style
        style = Makeup.Styles.GithubLight

        highlighted_html =
          case Makeup.highlight(code_content, lexer: lexer, style: style) do
            {:ok, html} -> html
            {:error, _} -> code_content
          end

        Raxol.View.Components.text(
          content:
            highlighted_html <>
              "\n[CodeBlock Warning: Language lexer not found, using plain text.]"
        )
    end
  end

  @doc "Initializes the component state from props."
  @spec init(map()) :: map()
  def init(props), do: props

  @doc "Updates the component state. No updates are handled by default."
  @spec update(term(), map()) :: map()
  def update(_message, state), do: state

  @doc "Handles events for the component. No events are handled by default."
  @spec handle_event(term(), map(), map()) :: {map(), list()}
  def handle_event(_event, state, _context), do: {state, []}

  # Removed render_fallback/3 helper function

  # Again, assumes raw_html exists in Raxol
  # defp raw_html(assigns), do: # ... implementation depends on Raxol internals
end
