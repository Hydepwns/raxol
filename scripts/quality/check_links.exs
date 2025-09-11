#!/usr/bin/env elixir

# This script checks for broken links in documentation.
# It ensures that all links in documentation are valid.

defmodule CheckLinks do
  @moduledoc """
  Script to check for broken links in documentation.
  This script ensures that all links in documentation are valid.
  """

  def run do
    IO.puts("Checking for broken links in documentation...")

    doc_files = find_markdown_files()
    broken_links = check_all_links(doc_files)

    if broken_links == [] do
      IO.puts("✅ All documentation links are valid!")
      System.halt(0)
    else
      IO.puts("❌ Found broken links:")

      Enum.each(broken_links, fn {file, link} ->
        IO.puts("  #{file}: #{link}")
      end)

      System.halt(1)
    end
  end

  defp find_markdown_files do
    Path.wildcard("docs/**/*.md")
  end

  defp check_all_links(files) do
    files
    |> Enum.flat_map(&extract_and_check_links/1)
    |> Enum.reject(fn {_, link} ->
      # Skip external links for now
      String.starts_with?(link, "http") or String.starts_with?(link, "//")
    end)
    |> Enum.filter(fn {file, link} -> not link_exists?(file, link) end)
  end

  defp extract_and_check_links(file) do
    case File.read(file) do
      {:ok, content} ->
        Regex.scan(~r/\[([^\]]+)\]\(([^)]+)\)/, content,
          capture: :all_but_first
        )
        |> Enum.map(fn [_text, url] -> {file, url} end)

      {:error, _} ->
        []
    end
  end

  defp link_exists?(source_file, link) do
    cond do
      # Skip anchor-only links
      String.starts_with?(link, "#") ->
        true

      String.contains?(link, "#") ->
        [file_part, _anchor] = String.split(link, "#", parts: 2)
        resolve_and_check_file(source_file, file_part)

      true ->
        resolve_and_check_file(source_file, link)
    end
  end

  defp resolve_and_check_file(source_file, relative_path) do
    source_dir = Path.dirname(source_file)
    resolved_path = Path.expand(relative_path, source_dir)
    File.exists?(resolved_path)
  end
end

# Run the broken links check
CheckLinks.run()
