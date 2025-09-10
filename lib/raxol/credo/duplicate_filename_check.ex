defmodule Raxol.Credo.DuplicateFilenameCheck do
  @moduledoc """
  Custom Credo check to prevent duplicate filenames in the codebase.

  This check helps maintain code organization by flagging files with
  generic names that could cause navigation and maintenance issues.

  ## What it does

  This check will flag files with names that appear multiple times in the
  codebase, particularly focusing on generic names like:

  - manager.ex
  - handler.ex  
  - server.ex
  - supervisor.ex
  - renderer.ex
  - processor.ex
  - validator.ex
  - buffer.ex
  - parser.ex
  - state.ex
  - types.ex
  - config.ex

  ## Why it matters

  Having multiple files with the same name creates several problems:
  - Makes navigation difficult in IDEs
  - Causes confusion during code reviews
  - Makes search results ambiguous
  - Reduces code discoverability

  ## Examples

      # Problematic - multiple manager.ex files
      lib/raxol/terminal/buffer/manager.ex
      lib/raxol/terminal/cursor/manager.ex
      lib/raxol/core/config/manager.ex
      
      # Better - contextual naming
      lib/raxol/terminal/buffer/buffer_manager.ex
      lib/raxol/terminal/cursor/cursor_manager.ex
      lib/raxol/core/config/config_manager.ex

  ## Configuration

      {Raxol.Credo.DuplicateFilenameCheck, [
        # Files to exclude from duplicate checking
        exclude_files: ["mix.exs", "README.md"],
        
        # Maximum allowed duplicates before flagging (default: 1)
        max_duplicates: 1,
        
        # Whether to check test files (default: true)
        include_tests: true
      ]}
  """

  use Credo.Check,
    category: :design,
    base_priority: :high,
    explanations: [
      check: """
      Files should have unique names to improve code navigation and maintainability.

      Having multiple files with identical names (like `manager.ex`) makes it
      difficult to:
      - Navigate quickly in IDEs
      - Understand search results  
      - Review code changes
      - Maintain consistency

      Consider using domain-specific prefixes like `buffer_manager.ex` instead
      of generic names like `manager.ex`.
      """
    ]

  # Generic filenames that commonly cause issues
  @problematic_patterns [
    "manager.ex",
    "handler.ex",
    "server.ex",
    "supervisor.ex",
    "renderer.ex",
    "processor.ex",
    "validator.ex",
    "buffer.ex",
    "parser.ex",
    "state.ex",
    "types.ex",
    "config.ex",
    "client.ex",
    "worker.ex"
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    # This check runs at the project level, so we need to collect all files
    # We'll only run the check once for the entire project
    if should_run_project_check?(source_file, params) do
      run_project_check(params)
    else
      []
    end
  end

  # Only run the project-wide check once (on the first file alphabetically)
  defp should_run_project_check?(source_file, params) do
    all_files = get_all_source_files(params)
    first_file = Enum.min_by(all_files, & &1.filename)
    source_file.filename == first_file.filename
  end

  defp run_project_check(params) do
    all_files = get_all_source_files(params)
    exclude_files = Keyword.get(params, :exclude_files, [])
    max_duplicates = Keyword.get(params, :max_duplicates, 1)
    include_tests = Keyword.get(params, :include_tests, true)

    duplicates =
      all_files
      |> filter_files(exclude_files, include_tests)
      |> Enum.group_by(&Path.basename(&1.filename))
      |> Enum.filter(fn {_basename, files} ->
        length(files) > max_duplicates
      end)
      |> Enum.filter(fn {basename, _files} ->
        is_problematic_pattern?(basename)
      end)

    Enum.flat_map(duplicates, fn {basename, files} ->
      Enum.map(files, fn source_file ->
        issue_for(source_file, basename, length(files))
      end)
    end)
  end

  defp get_all_source_files(params) do
    # Get all source files from the execution context
    case Keyword.get(params, :__context__) do
      %{source_files: files} ->
        files

      _ ->
        # Fallback: scan the project directory
        scan_project_files()
    end
  end

  defp scan_project_files do
    ["lib", "test"]
    |> Enum.flat_map(&find_elixir_files/1)
    |> Enum.map(fn path ->
      %Credo.SourceFile{filename: path}
    end)
  end

  defp find_elixir_files(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          path = Path.join(dir, entry)

          cond do
            File.dir?(path) and not String.starts_with?(entry, ".") ->
              find_elixir_files(path)

            String.ends_with?(entry, ".ex") or String.ends_with?(entry, ".exs") ->
              [path]

            true ->
              []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp filter_files(files, exclude_files, include_tests) do
    files
    |> Enum.reject(fn file ->
      basename = Path.basename(file.filename)
      basename in exclude_files
    end)
    |> Enum.reject(fn file ->
      not include_tests and String.contains?(file.filename, "/test/")
    end)
  end

  defp is_problematic_pattern?(basename) do
    basename in @problematic_patterns
  end

  defp issue_for(source_file, basename, count) do
    format_issue(
      source_file,
      message: """
      Duplicate filename detected: '#{basename}' appears #{count} times.

      Consider using a more specific name like:
      #{suggest_rename(source_file.filename, basename)}

      This improves code navigation and maintainability.
      """,
      line_no: 1,
      severity: severity_for_count(count)
    )
  end

  defp suggest_rename(path, basename) do
    parent_dir = path |> Path.dirname() |> Path.basename()

    case basename do
      "manager.ex" -> "#{parent_dir}_manager.ex"
      "handler.ex" -> "#{parent_dir}_handler.ex"
      "server.ex" -> "#{parent_dir}_server.ex"
      "supervisor.ex" -> "#{parent_dir}_supervisor.ex"
      "renderer.ex" -> "#{parent_dir}_renderer.ex"
      "processor.ex" -> "#{parent_dir}_processor.ex"
      "validator.ex" -> "#{parent_dir}_validator.ex"
      "buffer.ex" -> "#{parent_dir}_buffer.ex"
      "parser.ex" -> "#{parent_dir}_parser.ex"
      "state.ex" -> "#{parent_dir}_state.ex"
      "types.ex" -> "#{parent_dir}_types.ex"
      "config.ex" -> "#{parent_dir}_config.ex"
      "client.ex" -> "#{parent_dir}_client.ex"
      "worker.ex" -> "#{parent_dir}_worker.ex"
      _ -> "#{parent_dir}_#{basename}"
    end
  end

  defp severity_for_count(count) when count > 5, do: :high
  defp severity_for_count(count) when count > 3, do: :normal
  defp severity_for_count(_), do: :low
end
