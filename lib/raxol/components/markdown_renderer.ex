defmodule Raxol.Components.MarkdownRenderer do
  @moduledoc """
  Renders Markdown text into Raxol elements or raw HTML.

  Requires the `earmark` dependency.
  """
  use Raxol.Core.Runtime.Component # Assuming this is the correct behaviour for a simple component
  import Raxol.View.Elements

  @doc """
  Renders the given Markdown string.
  """
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

  def render(assigns) do
    # Assuming Earmark is added as a dependency
    # Use :pure_html option to avoid potential container tags like <p> if rendering line by line.
    # However, for a block of markdown, parsing once might be better.
    case Code.ensure_loaded?(Earmark) do
      {:module, Earmark} ->
        # Let's stick to rendering raw HTML for simplicity and correctness,
        # assuming Raxol has a way to do this.
        # We'll use a hypothetical `raw_html` function/element.
        # If this doesn't exist, this component needs rethinking based on Raxol's capabilities.
        html_content = Earmark.as_html!(@markdown_text, gfm: true, breaks: true, smartypants: true)

        view do
          # Using a hypothetical `raw_html` element/function.
          # The actual implementation depends on how Raxol handles embedding HTML.
          # If raw_html isn't available, this component needs adaptation.
          # A simple div wrapper for potential styling.
           div(class: "markdown-body") do
             raw_html(content: html_content)
           end
        end

      {:error, _} ->
         view do
           div(style: "color: red; border: 1px solid red; padding: 5px;") do
             text(content: "[MarkdownRenderer Error: Earmark library not found. Please add :earmark to your deps.]")
             # Fallback to plain text rendering
             pre do
                text(content: @markdown_text)
             end
           end
         end
    end
  end

  # Hypothetical raw_html component/function - needed for the above approach
  # If Raxol doesn't have this, the render function needs to change.
  # defp raw_html(assigns), do: # ... implementation depends on Raxol internals

end
