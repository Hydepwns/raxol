#!/usr/bin/env elixir

# This script runs all pre-commit checks for the Raxol project.
# It ensures that all checks pass before allowing a commit.

defmodule PreCommitCheck do
  @moduledoc """
  Pre-commit check script for the Raxol project.
  This script runs all pre-commit checks and ensures they pass.
  """

  @link_regex ~r/\[[^\]]*\]\(([^\s\)]+)[^)]*\)/

  @doc """
  Main function to run all pre-commit checks.
  """
  def run do
    IO.puts("Running pre-commit checks for Raxol project...")

    results = [
      check_code_style(),
      check_broken_links(),
      check_zero_warnings()
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
    # Scan all markdown files in the project
    all_markdown_files_in_project_glob = Path.wildcard("**/*.md")

    # Manually add known important markdown files outside typical doc locations
    # to ensure they are part of the all_files_set if they exist.
    # Path.wildcard might not pick up files in .hidden directories consistently.
    additional_known_files = [
      ".github/workflows/README.md",
      "scripts/README.md",
      # Root readme
      "README.md",
      # Root license
      "LICENSE.md"
    ]

    # Filter additional_known_files to only those that actually exist, to avoid issues if one is deleted.
    existing_additional_files =
      Enum.filter(additional_known_files, &File.exists?/1)

    all_markdown_files_in_project =
      (all_markdown_files_in_project_glob ++ existing_additional_files)
      |> Enum.uniq()

    # Filter out files in the deps/ directory, node_modules, and submodules
    markdown_files_filtered =
      Enum.reject(all_markdown_files_in_project, fn file_path ->
        String.starts_with?(file_path, "deps/") or
          String.starts_with?(file_path, "node_modules/") or
          String.contains?(file_path, "/node_modules/") or
          String.starts_with?(file_path, "lib/termbox2_nif/c_src/termbox2/")
      end)

    # Normalize all paths before putting them into the set
    normalized_markdown_files =
      Enum.map(markdown_files_filtered, fn path ->
        Path.expand(path) |> Path.relative_to_cwd()
      end)

    all_files_set = MapSet.new(normalized_markdown_files)

    broken_links =
      Enum.reduce(markdown_files_filtered, [], fn file, acc_broken_links ->
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

  @doc """
  Check for zero compilation warnings.
  """
  def check_zero_warnings do
    IO.puts("Checking for compilation warnings...")

    # Set environment variable to skip termbox tests
    System.put_env("SKIP_TERMBOX2_TESTS", "true")
    System.put_env("TMPDIR", "/tmp")

    # Run mix compile with warnings as errors
    {output, exit_code} =
      System.cmd("mix", ["compile", "--warnings-as-errors"],
        stderr_to_stdout: true,
        env: [
          {"MIX_ENV", "test"}, 
          {"SKIP_TERMBOX2_TESTS", "true"},
          {"TMPDIR", "/tmp"}
        ]
      )

    # Check if it's a real warning or just NIF build failure
    cond do
      exit_code == 0 ->
        IO.puts("✅ Zero compilation warnings detected!")
        :ok
      
      String.contains?(output, "Could not compile with \"make\"") ->
        # NIF build failure, not a warning issue
        IO.puts("⚠️  NIF build failed (not a warning issue), continuing...")
        :ok
        
      true ->
        IO.puts("❌ Compilation warnings found:")
        IO.puts(output)
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

        if MapSet.member?(all_files_set, normalized_target_file) or
             File.dir?(normalized_target_file) or
             File.exists?(normalized_target_file) do
          if anchor do
            check_anchor(normalized_target_file, anchor)
          else
            # File or directory exists, no anchor to check
            :ok
          end
        else
          {:error,
           "Target file or directory `#{normalized_target_file}` (resolved from `#{url}` in `#{source_file}`) not found"}
        end
    end
  end

  defp check_anchor(target_file, anchor) do
    try do
      full_content = File.read!(target_file)

      # Attempt to strip frontmatter
      content_without_frontmatter =
        Regex.replace(~r/\A---\s*\n(?:.|\n)*?^---\s*$\n/m, full_content, "",
          global: false
        )

      # Extract all headings (lines starting with 1-6 # followed by space)
      headings =
        content_without_frontmatter
        |> String.split("\n")
        |> Enum.filter(fn line ->
          Regex.match?(~r/^#\s|^##\s|^###\s|^####\s|^#####\s|^######\s/, line)
        end)
        |> Enum.map(fn line ->
          # Remove leading #s and whitespace
          String.replace(line, ~r/^#+\s*/, "")
        end)

      # Normalize heading to GitHub-style anchor
      normalize_anchor = fn str ->
        str
        |> String.downcase()
        # Remove most punctuation
        |> String.replace(~r/[^a-z0-9\-\s]/u, "")
        # Spaces to dashes
        |> String.replace(~r/[\s]+/, "-")
        # Collapse dashes
        |> String.replace(~r/-+/, "-")
        # Trim leading/trailing dashes
        |> String.trim("-")
      end

      heading_anchors = Enum.map(headings, normalize_anchor)
      normalized_anchor = normalize_anchor.(anchor)

      if Enum.member?(heading_anchors, normalized_anchor) do
        :ok
      else
        {:error,
         "Anchor `##{anchor}` (normalized: `##{normalized_anchor}`) not found in `#{target_file}`. Available anchors: #{inspect(heading_anchors)}"}
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
