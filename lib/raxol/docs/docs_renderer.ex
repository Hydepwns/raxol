defmodule Raxol.Docs.Renderer do
  @moduledoc """
  Handles rendering for documentation.

  This module provides functionality for rendering documentation content
  in various formats including Markdown, HTML, and plain text. It integrates
  with the Raxol documentation system to provide consistent rendering across
  different output formats.

  ## Features

  - Markdown to HTML conversion
  - Code syntax highlighting
  - Table of contents generation
  - Search index creation
  - Documentation metadata handling
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Renders Markdown content to HTML with syntax highlighting.
  """
  @spec render_markdown(String.t(), map()) :: String.t()
  def render_markdown(content, opts \\ %{}) do
    case Code.ensure_loaded?(Earmark) do
      true ->
        Earmark.as_html!(content,
          gfm: Map.get(opts, :gfm, true),
          breaks: Map.get(opts, :breaks, true),
          smartypants: Map.get(opts, :smartypants, true)
        )

      false ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Earmark not available, returning raw content",
          %{content_length: String.length(content)}
        )

        content
    end
  end

  @doc """
  Generates a table of contents from markdown content.
  """
  @spec generate_toc(String.t()) :: list(map())
  def generate_toc(content) do
    content
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.filter(fn {line, _} -> String.starts_with?(line, "#") end)
    |> Enum.map(fn {line, index} ->
      level = line |> String.trim_leading("#") |> String.length()
      title = line |> String.trim_leading("#") |> String.trim()
      anchor = generate_anchor(title)

      %{
        level: level,
        title: title,
        anchor: anchor,
        line_number: index + 1
      }
    end)
  end

  @doc """
  Creates a search index from documentation content.
  """
  @spec create_search_index(String.t(), map()) :: map()
  def create_search_index(content, metadata \\ %{}) do
    # Extract headings
    headings = extract_headings(content)

    # Extract code blocks
    code_blocks = extract_code_blocks(content)

    # Create searchable text (remove markdown syntax)
    search_text =
      content
      # Remove code blocks
      |> String.replace(~r/```[\s\S]*?```/, "")
      # Remove link URLs
      |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
      # Remove markdown syntax
      |> String.replace(~r/[#*_`]/, "")
      |> String.downcase()

    %{
      metadata: metadata,
      headings: headings,
      code_blocks: code_blocks,
      search_text: search_text,
      word_count: String.split(search_text) |> length()
    }
  end

  @doc """
  Renders documentation with full metadata and navigation.
  """
  @spec render_documentation(binary(), map()) :: %{
    content: binary(),
    metadata: map(),
    rendered_at: DateTime.t(),
    search_index: map(),
    table_of_contents: [map()]
  }
  def render_documentation(content, metadata \\ %{}) do
    html_content = render_markdown(content)
    toc = generate_toc(content)
    search_index = create_search_index(content, metadata)

    %{
      content: html_content,
      table_of_contents: toc,
      search_index: search_index,
      metadata: metadata,
      rendered_at: DateTime.utc_now()
    }
  end

  # Private helper functions

  defp generate_anchor(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  defp extract_headings(content) do
    content
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "#"))
    |> Enum.map(fn line ->
      level = line |> String.trim_leading("#") |> String.length()
      title = line |> String.trim_leading("#") |> String.trim()
      %{level: level, title: title}
    end)
  end

  defp extract_code_blocks(content) do
    content
    |> String.split("```")
    |> Enum.chunk_every(2)
    |> Enum.map(fn [language, code] ->
      %{
        language: String.trim(language),
        code: String.trim(code)
      }
    end)
    |> Enum.filter(fn %{code: code} -> String.length(code) > 0 end)
  end
end
