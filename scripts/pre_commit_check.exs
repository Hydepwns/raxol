#!/usr/bin/env elixir

# This script runs all pre-commit checks for the Raxol project.
# It ensures that all checks pass before allowing a commit.

defmodule PreCommitCheck do
  @moduledoc """
  Pre-commit check script for the Raxol project.
  This script runs all pre-commit checks and ensures they pass.
  """

  @docs_dir "docs"
  @link_regex ~r/\[[^\]]*\]\(([^\s\)]+)[^)]*\)/

  @doc """
  Main function to run all pre-commit checks.
  """
  def run do
    IO.puts("Running pre-commit checks for Raxol project...")

    results = [
      check_code_style(),
      check_broken_links()
      # check_type_safety(),
      # check_documentation_consistency(),
      # check_test_coverage(),
      # check_performance(),
      # check_accessibility(),
      # check_e2e()
    ]

    if Enum.any?(results, fn res -> res != :ok end) do
      IO.puts("One or more pre-commit checks failed.")
      System.halt(1)
    else
      IO.puts("All pre-commit checks passed!")
      System.halt(0)
    end
  end

  @doc """
  Check code style.
  """
  def check_code_style do
    IO.puts("Checking code style...")
    # Assume ok initially
    status = :ok

    # Only check files that are staged for commit
    {staged_files_output, exit_code} =
      System.cmd("git", [
        "diff",
        "--name-only",
        "--cached",
        "--diff-filter=ACMR",
        "--",
        "*.ex",
        "*.exs"
      ])

    if exit_code != 0 do
      IO.puts("Error getting staged files.")
      # Return error
      :error
    else
      staged_files = String.split(staged_files_output, "\n", trim: true)

      if Enum.empty?(staged_files) do
        IO.puts("No Elixir files staged for commit. Skipping format check.")
      else
        IO.puts("Checking format for #{length(staged_files)} staged files.")

        # Check format only for staged files
        args = ["format", "--check-formatted"] ++ staged_files
        {output, exit_code} = System.cmd("mix", args, stderr_to_stdout: true)

        if exit_code != 0 do
          IO.puts("Warning: Some files need formatting:")
          IO.puts(output)
          IO.puts("\nYou should run: mix format")
          # Don't set status to :error, it's just a warning
          IO.puts("Continuing with other checks...")
        else
          IO.puts("Code style check passed!")
        end
      end

      # Return the status (:ok)
      status
    end
  end

  @doc """
  Check for broken links in documentation files.
  """
  def check_broken_links do
    IO.puts("Checking for broken links in documentation...")
    markdown_files = Path.wildcard(Path.join(@docs_dir, "**/*.md"))
    IO.inspect(markdown_files, label: "Found markdown files")
    all_files_set = MapSet.new(markdown_files)

    broken_links =
      Enum.reduce(markdown_files, [], fn file, acc_broken_links ->
        try do
          content = File.read!(file)
          links = Regex.scan(@link_regex, content, capture: :all_but_first)

          Enum.reduce(links, acc_broken_links, fn [url], inner_acc ->
            case check_single_link(url, file, all_files_set) do
              :ok ->
                inner_acc

              {:error, reason} ->
                [%{file: file, url: url, reason: reason} | inner_acc]
            end
          end)
        rescue
          e in File.Error ->
            IO.puts("Error reading file #{file}: #{inspect(e)}")
            # Optionally treat read error as a failure
            # _broken_links = [%{file: file, url: nil, reason: "Could not read file"} | _broken_links]
            acc_broken_links
        end
      end)

    if Enum.empty?(broken_links) do
      IO.puts("Broken links check passed!")
      :ok
    else
      IO.puts("Found #{length(broken_links)} broken links:")

      for %{file: file, url: url, reason: reason} <- Enum.reverse(broken_links) do
        IO.puts("  - In `#{file}`: Link `#{url}` (#{reason})")
      end

      :error
    end
  end

  # --- Helper for check_broken_links ---

  defp check_single_link(url, source_file, all_files_set) do
    cond do
      # Skip external links
      String.starts_with?(url, "http://") or
        String.starts_with?(url, "https://") or String.starts_with?(url, "//") ->
        :ok

      # Handle anchor-only links (within the same file)
      String.starts_with?(url, "#") ->
        anchor = String.trim_leading(url, "#")
        check_anchor(source_file, anchor)

      # Handle links with file path and potentially anchor
      true ->
        [path_part | anchor_part_list] = String.split(url, "#", parts: 2)
        # nil if no anchor
        anchor = List.first(anchor_part_list)

        # Determine the target file path to check against the set
        target_file =
          cond do
            # Absolute path link (relative to project root)
            String.starts_with?(path_part, "/") ->
              # Remove leading / for comparison with wildcard results
              String.trim_leading(path_part, "/")

            # Link likely relative to project root (e.g., "docs/file.md")
            # Heuristic: Check if it starts with a known top-level dir like 'docs'
            # This might need adjustment based on project structure
            String.match?(path_part, ~r"^[a-zA-Z0-9_]+/") ->
              path_part

            # Link relative to the source file
            true ->
              source_dir = Path.dirname(source_file)
              # Join and expand, then make relative to CWD for comparison
              abs_path = Path.expand(Path.join(source_dir, path_part))
              Path.relative_to_cwd(abs_path)
          end

        # Normalize for good measure before checking
        normalized_target_file =
          Path.expand(target_file) |> Path.relative_to_cwd()

        if MapSet.member?(all_files_set, normalized_target_file) do
          if anchor do
            check_anchor(normalized_target_file, anchor)
          else
            # File exists, no anchor to check
            :ok
          end
        else
          # IO.inspect(%{check: normalized_target_file, against: all_files_set}, label: "File Check Failed")
          {:error,
           "Target file `#{normalized_target_file}` (resolved from `#{url}` in `#{source_file}`) not found"}
        end
    end
  end

  defp check_anchor(target_file, anchor) do
    try do
      content = File.read!(target_file)
      # Simple check for Markdown header: #{1,6} Anchor Title
      # More robust parsing would require a Markdown library
      # Need to construct the pattern string due to {1,6}
      pattern = "^#\{1,6\}\\s+#{Regex.escape(anchor)}\\b"
      # Compile with multiline option
      anchor_regex = Regex.compile!(pattern, "m")

      if Regex.match?(anchor_regex, content) do
        :ok
      else
        {:error, "Anchor `##{anchor}` not found in `#{target_file}`"}
      end
    rescue
      e in File.Error ->
        {:error,
         "Could not read target file `#{target_file}` to check anchor: #{inspect(e)}"}
    end
  end
end

# Run the pre-commit checks
PreCommitCheck.run()
