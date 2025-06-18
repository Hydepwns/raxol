defmodule Raxol.UI.Components.MarkdownRenderer do
  @moduledoc '''
  Renders Markdown text into Raxol elements or raw HTML.

  Requires the `earmark` dependency.
  '''
  use Raxol.UI.Components.Base.Component

  @doc '''
  Renders the given Markdown string.
  '''

  # Option 1: Render as raw HTML (Simpler, relies on browser rendering)
  # Requires Raxol to have a way to render raw HTML, e.g., a `raw_html` element
  # or specific handling in the rendering engine.
  # def render(assigns) do
  #   ~H'''
  #   <div class="markdown-content">
  #     <%= raw_html(render_markdown(@markdown_text)) %>
  #   </div>
  #   '''
  # end

  # Option 2: Basic Earmark AST to Raxol Elements (More complex, less feature complete)
  # This is a placeholder implementation and likely needs significant expansion
  # to handle various Markdown features correctly.
  # It avoids raw HTML but might not render complex Markdown accurately.

  @spec render(map(), map()) :: any()
  def render(state, _context) do
    markdown_text = state[:markdown_text] || ""

    case Code.ensure_loaded?(Earmark) do
      true ->
        html_content =
          Earmark.as_html!(markdown_text,
            gfm: true,
            breaks: true,
            smartypants: true
          )

        Raxol.View.Components.text(content: html_content)

      false ->
        Raxol.View.Components.text(
          content:
            markdown_text <>
              "\n[MarkdownRenderer Error: Earmark library not found.]"
        )
    end
  end

  @doc 'Initializes the MarkdownRenderer component state from props.'
  @spec init(map()) :: map()
  def init(props), do: props

  @doc 'Updates the MarkdownRenderer component state. No updates are handled by default.'
  @spec update(term(), map()) :: map()
  def update(_message, state), do: state

  @doc 'Handles events for the MarkdownRenderer component. No events are handled by default.'
  @spec handle_event(term(), map(), map()) :: {map(), list()}
  def handle_event(_event, state, _context), do: {state, []}

  # Hypothetical raw_html component/function - needed for the above approach
  # If Raxol doesn't have this, the render function needs to change.
  # defp raw_html(assigns), do: # ... implementation depends on Raxol internals
end
