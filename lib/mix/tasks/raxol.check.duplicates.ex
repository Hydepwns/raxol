defmodule Mix.Tasks.Raxol.Check.Duplicates do
  @moduledoc """
  Check for duplicate filenames in the Raxol codebase.

  This task helps maintain code organization by identifying files with
  identical names that could cause navigation issues.

  ## Usage

      mix raxol.check.duplicates
      mix raxol.check.duplicates --suggest-fixes
      mix raxol.check.duplicates --strict

  ## Options

    * `--suggest-fixes` - Show suggested renames for problematic files
    * `--strict` - Exit with error code if any duplicates are found
    * `--exclude` - Comma-separated list of files to exclude from checking

  ## Examples

      # Basic check
      mix raxol.check.duplicates
      
      # With suggestions
      mix raxol.check.duplicates --suggest-fixes
      
      # Strict mode (fails build on duplicates)
      mix raxol.check.duplicates --strict
      
      # Exclude specific files
      mix raxol.check.duplicates --exclude "mix.exs,README.md"
  """

  use Mix.Task

  @shortdoc "Check for duplicate filenames"

  # Problematic filename patterns
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

  @scan_dirs ["lib", "test"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          suggest_fixes: :boolean,
          strict: :boolean,
          exclude: :string
        ],
        aliases: [
          s: :suggest_fixes,
          e: :exclude
        ]
      )

    exclude_files = parse_exclude_list(opts[:exclude])
    show_suggestions = opts[:suggest_fixes] || false
    strict_mode = opts[:strict] || false

    Mix.shell().info("🔍 Checking for duplicate filenames...")
    Mix.shell().info("Scanning directories: #{Enum.join(@scan_dirs, ", ")}")
    Mix.shell().info("")

    duplicates = find_duplicates(exclude_files)

    case {Enum.empty?(duplicates), strict_mode} do
      {true, _} ->
        Mix.shell().info("✅ No duplicate filenames found!")

      {false, true} ->
        display_duplicates(duplicates, show_suggestions)

        Mix.shell().error(
          "\n❌ Found #{length(duplicates)} sets of duplicate filenames in strict mode"
        )

        System.halt(1)

      {false, false} ->
        display_duplicates(duplicates, show_suggestions)

        if has_problematic_duplicates?(duplicates) do
          Mix.shell().error(
            "\n⚠️  Consider running with --suggest-fixes to see rename suggestions"
          )
        end
    end
  end

  defp parse_exclude_list(nil), do: ["mix.exs", "README.md", ".gitignore"]

  defp parse_exclude_list(exclude_str) do
    exclude_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp find_duplicates(exclude_files) do
    @scan_dirs
    |> Enum.flat_map(&find_elixir_files/1)
    |> Enum.reject(&(Path.basename(&1) in exclude_files))
    |> Enum.group_by(&Path.basename/1)
    |> Enum.filter(fn {_basename, paths} -> length(paths) > 1 end)
    |> Enum.sort_by(fn {basename, paths} -> {-length(paths), basename} end)
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

  defp display_duplicates(duplicates, show_suggestions) do
    Enum.each(duplicates, fn {basename, paths} ->
      problem_level =
        cond do
          basename in @problematic_patterns -> "🔴 CRITICAL"
          length(paths) > 3 -> "🟡 WARNING"
          true -> "🔵 INFO"
        end

      Mix.shell().info(
        "#{problem_level} - '#{basename}' (#{length(paths)} files):"
      )

      Enum.each(paths, fn path ->
        Mix.shell().info("  • #{path}")
      end)

      if show_suggestions and basename in @problematic_patterns do
        show_naming_suggestions(basename, paths)
      end

      Mix.shell().info("")
    end)
  end

  defp show_naming_suggestions(basename, paths) do
    Mix.shell().info("  📝 Suggested renames:")

    Enum.each(paths, fn path ->
      suggestion = generate_rename_suggestion(path, basename)
      Mix.shell().info("    #{path} → #{suggestion}")
    end)
  end

  defp generate_rename_suggestion(path, basename) do
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

  defp has_problematic_duplicates?(duplicates) do
    Enum.any?(duplicates, fn {basename, _paths} ->
      basename in @problematic_patterns
    end)
  end
end
