defmodule Mix.Tasks.Raxol.Check.Format do
  @moduledoc """
  Check code formatting for staged Elixir files.

  Only checks files that are staged for commit, making it fast and relevant.
  Supports caching for improved performance on large codebases.
  """

  use Mix.Task
  alias Raxol.PreCommit.{Cache, GitHelper}

  @shortdoc "Check code formatting"

  @impl Mix.Task
  def run(config \\ %{}) do
    verbose = Map.get(config, :verbose, false)

    use_cache =
      Map.get(config, :cache, true) and not Map.get(config, :no_cache, false)

    case GitHelper.get_staged_elixir_files() do
      {:ok, []} ->
        if verbose, do: IO.puts("  No Elixir files staged for commit")
        {:ok, "No files to check"}

      {:ok, files} ->
        if verbose, do: IO.puts("  Checking #{length(files)} staged files...")
        check_formatting_with_cache(files, config, use_cache)
    end
  end

  defp check_formatting_with_cache(files, config, true) do
    # Separate cached and uncached files
    {cached_results, files_to_check} =
      Enum.reduce(files, {[], []}, fn file, {cached, to_check} ->
        case Cache.get_cached_result(file, :format) do
          {:ok, result} ->
            {[{file, result} | cached], to_check}

          :miss ->
            {cached, [file | to_check]}
        end
      end)

    verbose = Map.get(config, :verbose, false)

    # Report cache hits
    cache_hit_count = length(cached_results)
    total_count = length(files)

    maybe_print_cache_info(cache_hit_count, total_count, verbose)

    # Check uncached files
    fresh_results = check_files_and_cache(files_to_check, config)

    # Combine results
    combine_format_results(cached_results, fresh_results, config)
  end

  defp check_formatting_with_cache(files, config, false) do
    check_formatting(files, config)
  end

  defp maybe_print_cache_info(0, _, _), do: :ok
  defp maybe_print_cache_info(_hits, _total, false), do: :ok

  defp maybe_print_cache_info(hits, total, true) do
    IO.puts("  Cache: #{hits}/#{total} files cached")
  end

  defp check_files_and_cache([], _config), do: []

  defp check_files_and_cache(files, _config) do
    # Check each file individually for better caching
    Enum.map(files, fn file ->
      result = check_single_file(file)
      # Cache the result
      Cache.save_result(file, :format, result)
      {file, result}
    end)
  end

  defp check_single_file(file) do
    case System.cmd("mix", ["format", "--check-formatted", file],
           stderr_to_stdout: true
         ) do
      {_, 0} -> %{status: :ok}
      {output, _} -> %{status: :needs_formatting, output: output}
    end
  end

  defp combine_format_results(cached_results, fresh_results, config) do
    all_results = cached_results ++ fresh_results

    unformatted =
      all_results
      |> Enum.filter(fn {_, result} -> result.status == :needs_formatting end)
      |> Enum.map(fn {file, _} -> file end)

    handle_unformatted_files(unformatted, length(all_results), config)
  end

  defp handle_unformatted_files([], count, _config) do
    {:ok, "All #{count} files properly formatted"}
  end

  defp handle_unformatted_files(unformatted, _count, config) do
    auto_fix = should_auto_fix?(config)

    case auto_fix do
      true ->
        fix_formatting(unformatted)

      false ->
        # Return structured error for better formatting
        {:error, %{files: unformatted}}
    end
  end

  defp should_auto_fix?(config) do
    case Map.get(config, :auto_fix, false) do
      true -> true
      false -> false
      list when is_list(list) -> :format in list
      _ -> false
    end
  end

  defp check_formatting(files, config) do
    args = ["format", "--check-formatted"] ++ files

    case System.cmd("mix", args, stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, "All #{length(files)} files properly formatted"}

      {output, _} ->
        unformatted = parse_unformatted_files(output)

        case should_auto_fix?(config) do
          true ->
            fix_formatting(unformatted)

          false ->
            # Return structured error for better formatting
            {:error, %{files: unformatted}}
        end
    end
  end

  defp parse_unformatted_files(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ".ex"))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp fix_formatting(files) do
    case System.cmd("mix", ["format"] ++ files) do
      {_, 0} ->
        # Add formatted files back to staging
        Enum.each(files, fn file ->
          System.cmd("git", ["add", file])
        end)

        {:ok, "Auto-formatted #{length(files)} files"}

      {error, _} ->
        {:error, "Failed to auto-format: #{error}"}
    end
  end
end
