if Code.ensure_loaded?(Credo.Check) do
  defmodule Raxol.Credo.DuplicateFilenameCheck do
    @moduledoc """
    Credo check for detecting duplicate filenames in the codebase.
    """

    @dialyzer [:no_undefined_callbacks, :no_missing_calls, :no_unknown]

    use Credo.Check,
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Files with duplicate names can cause navigation issues in IDEs and editors.

        Consider renaming files to include their context:
        - `manager.ex` -> `buffer_manager.ex`
        - `handler.ex` -> `event_handler.ex`
        """
      ]

    @default_excludes ["mix.exs", "README.md", ".gitignore", ".formatter.exs"]

    @impl Credo.Check
    def run(%Credo.SourceFile{} = source_file, params) do
      if Keyword.get(params, :__run_on_all__, false) do
        run_on_all(source_file, params)
      else
        []
      end
    end

    def run_on_all(%Credo.SourceFile{filename: filename}, params) do
      exclude_files = Keyword.get(params, :exclude_files, @default_excludes)
      max_duplicates = Keyword.get(params, :max_duplicates, 1)
      include_tests = Keyword.get(params, :include_tests, true)

      dirs = if include_tests, do: ["lib", "test"], else: ["lib"]

      duplicates =
        dirs
        |> Enum.flat_map(&find_files/1)
        |> Enum.reject(fn path -> Path.basename(path) in exclude_files end)
        |> group_by_filename()
        |> Enum.filter(fn {_name, paths} -> length(paths) > max_duplicates end)

      create_issues(duplicates, filename)
    end

    defp find_files(dir) do
      case File.ls(dir) do
        {:ok, entries} ->
          Enum.flat_map(entries, fn entry ->
            path = Path.join(dir, entry)

            cond do
              File.dir?(path) ->
                find_files(path)

              String.ends_with?(entry, ".ex") or
                  String.ends_with?(entry, ".exs") ->
                [path]

              true ->
                []
            end
          end)

        {:error, _} ->
          []
      end
    end

    defp group_by_filename(paths), do: Enum.group_by(paths, &Path.basename/1)

    defp create_issues(duplicates, trigger_file) do
      Enum.flat_map(duplicates, fn {filename, paths} ->
        severity = categorize_severity(filename)

        [
          %Credo.Issue{
            check: __MODULE__,
            category: :warning,
            filename: trigger_file,
            message:
              "Duplicate filename '#{filename}' found in #{length(paths)} locations: #{Enum.join(paths, ", ")}",
            trigger: filename,
            priority: severity_to_priority(severity)
          }
        ]
      end)
    end

    defp categorize_severity(filename) do
      critical = ~w(manager.ex handler.ex server.ex worker.ex client.ex)
      warning = ~w(utils.ex helpers.ex types.ex)

      cond do
        filename in critical -> :critical
        filename in warning -> :warning
        true -> :info
      end
    end

    defp severity_to_priority(:critical), do: :high
    defp severity_to_priority(:warning), do: :normal
    defp severity_to_priority(:info), do: :low
  end
end
