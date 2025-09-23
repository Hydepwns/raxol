defmodule Raxol.PreCommit.GitHelper do
  @moduledoc """
  Optimized Git operations for pre-commit checks.

  Provides cached and batched Git operations to improve performance.
  """

  # Cache git status for 5 seconds to avoid repeated calls
  @cache_ttl 5_000

  # Use Agent to store cached results
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc """
  Get all staged files, with caching and filtering.

  Options:
    - extensions: List of file extensions to filter (e.g., [".ex", ".exs"])
    - exclude_paths: List of path patterns to exclude
  """
  def get_staged_files(opts \\ []) do
    cache_key = {:staged_files, opts}

    case get_cached(cache_key) do
      {:ok, files} ->
        {:ok, files}

      :miss ->
        files = fetch_staged_files(opts)
        cache_result(cache_key, files)
        {:ok, files}
    end
  end

  @doc """
  Get staged files of specific types efficiently.
  """
  def get_staged_elixir_files do
    get_staged_files(extensions: [".ex", ".exs"])
  end

  @doc """
  Clear the git cache.
  """
  def clear_cache do
    _ = ensure_started()
    Agent.update(__MODULE__, fn _ -> %{} end)
  end

  # Private functions

  defp fetch_staged_files(opts) do
    extensions = Keyword.get(opts, :extensions, [])
    exclude_paths = Keyword.get(opts, :exclude_paths, ["deps/", "_build/"])

    case System.cmd(
           "git",
           ["diff", "--name-only", "--cached", "--diff-filter=ACMR"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> filter_by_extensions(extensions)
        |> filter_excluded_paths(exclude_paths)
        |> Enum.filter(&File.exists?/1)

      _ ->
        []
    end
  end

  defp filter_by_extensions(files, []), do: files

  defp filter_by_extensions(files, extensions) do
    Enum.filter(files, fn file ->
      Enum.any?(extensions, &String.ends_with?(file, &1))
    end)
  end

  defp filter_excluded_paths(files, []), do: files

  defp filter_excluded_paths(files, exclude_paths) do
    Enum.reject(files, fn file ->
      Enum.any?(exclude_paths, &String.starts_with?(file, &1))
    end)
  end

  defp get_cached(key) do
    _ = ensure_started()

    case Agent.get(__MODULE__, &Map.get(&1, key)) do
      nil ->
        :miss

      {value, timestamp} ->
        age = System.monotonic_time(:millisecond) - timestamp

        case age < @cache_ttl do
          true -> {:ok, value}
          false -> :miss
        end
    end
  end

  defp cache_result(key, value) do
    _ = ensure_started()

    Agent.update(__MODULE__, fn cache ->
      Map.put(cache, key, {value, System.monotonic_time(:millisecond)})
    end)
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_link()
      _pid -> :ok
    end
  end
end
