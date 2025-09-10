defmodule Raxol.PreCommit.Cache do
  @moduledoc """
  Cache system for pre-commit checks to enable incremental checking.

  Caches check results based on file hashes to skip unchanged files,
  significantly improving performance for large codebases.

  ## Features

  - File hash-based caching
  - Automatic cache invalidation on file changes
  - Per-check result storage
  - Configurable cache directory
  """

  @cache_dir ".raxol_cache"
  @cache_file Path.join(@cache_dir, "check_results.json")
  @stats_file Path.join(@cache_dir, "cache_stats.json")

  @doc """
  Get cached result for a file and check combination.

  Returns {:ok, result} if cache hit and file unchanged,
  :miss otherwise.
  """
  def get_cached_result(file_path, check_name) do
    result =
      with {:ok, cache} <- load_cache(),
           {:ok, file_hash} <- hash_file(file_path),
           {:ok, cached} <- Map.fetch(cache, cache_key(file_path, check_name)),
           true <- cached.hash == file_hash do
        update_stats(:hit)
        {:ok, cached.result}
      else
        _ ->
          update_stats(:miss)
          :miss
      end

    result
  end

  @doc """
  Save a check result to the cache.
  """
  def save_result(file_path, check_name, result) do
    ensure_cache_dir()

    with {:ok, current_cache} <- load_cache_or_default(),
         {:ok, file_hash} <- hash_file(file_path) do
      updated_cache =
        Map.put(current_cache, cache_key(file_path, check_name), %{
          hash: file_hash,
          result: result,
          timestamp: DateTime.utc_now()
        })

      save_cache(updated_cache)
    end
  end

  @doc """
  Clear the entire cache.
  """
  def clear_cache do
    File.rm_rf(@cache_dir)
    :ok
  end

  @doc """
  Clear cache entries older than the specified duration.
  """
  def prune_cache(max_age_hours \\ 24) do
    cutoff = DateTime.add(DateTime.utc_now(), -max_age_hours * 3600, :second)

    with {:ok, cache} <- load_cache() do
      pruned =
        cache
        |> Enum.filter(fn {_, entry} ->
          DateTime.compare(entry.timestamp, cutoff) == :gt
        end)
        |> Map.new()

      save_cache(pruned)
    end
  end

  @doc """
  Get cache statistics.
  """
  def get_stats do
    runtime_stats = load_runtime_stats()

    cache_stats =
      case load_cache() do
        {:ok, cache} ->
          total_entries = map_size(cache)

          {files, checks} =
            cache
            |> Map.keys()
            |> Enum.reduce({MapSet.new(), MapSet.new()}, fn {file, check},
                                                            {files, checks} ->
              {MapSet.put(files, file), MapSet.put(checks, check)}
            end)

          %{
            total_entries: total_entries,
            unique_files: MapSet.size(files),
            unique_checks: MapSet.size(checks),
            cache_size_bytes: get_cache_size()
          }

        _ ->
          %{
            total_entries: 0,
            unique_files: 0,
            unique_checks: 0,
            cache_size_bytes: 0
          }
      end

    {:ok, Map.merge(runtime_stats, cache_stats)}
  end

  # Private functions

  defp cache_key(file_path, check_name) do
    {file_path, check_name}
  end

  defp ensure_cache_dir do
    File.mkdir_p!(@cache_dir)
  end

  defp load_cache do
    case File.read(@cache_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            # Convert JSON data back to our internal format
            cache =
              data
              |> Enum.map(fn {key, value} ->
                [file, check] = String.split(key, "|", parts: 2)
                {:ok, timestamp, _} = DateTime.from_iso8601(value["timestamp"])

                entry = %{
                  hash: value["hash"],
                  result: atomize_result(value["result"]),
                  timestamp: timestamp
                }

                {{file, String.to_atom(check)}, entry}
              end)
              |> Map.new()

            {:ok, cache}

          _ ->
            {:error, :invalid_cache}
        end

      {:error, :enoent} ->
        {:ok, %{}}

      error ->
        error
    end
  end

  defp load_cache_or_default do
    case load_cache() do
      {:ok, cache} -> {:ok, cache}
      _ -> {:ok, %{}}
    end
  end

  defp save_cache(cache) do
    # Convert to JSON-friendly format
    json_data =
      cache
      |> Enum.map(fn {{file, check}, entry} ->
        key = "#{file}|#{check}"

        value = %{
          "hash" => entry.hash,
          "result" => stringify_result(entry.result),
          "timestamp" => DateTime.to_iso8601(entry.timestamp)
        }

        {key, value}
      end)
      |> Map.new()

    content = Jason.encode!(json_data, pretty: true)
    File.write!(@cache_file, content)
    :ok
  end

  defp hash_file(path) do
    case File.read(path) do
      {:ok, content} ->
        hash = :crypto.hash(:sha256, content) |> Base.encode16()
        {:ok, hash}

      error ->
        error
    end
  end

  defp atomize_result(%{"status" => status} = result) do
    %{status: String.to_atom(status), details: result["details"]}
  end

  defp atomize_result(result) when is_map(result), do: result

  defp stringify_result(%{status: status} = result) do
    %{"status" => to_string(status), "details" => Map.get(result, :details)}
  end

  defp stringify_result(result), do: result

  defp update_stats(type) do
    stats = load_runtime_stats()

    updated =
      case type do
        :hit -> %{stats | hits: stats.hits + 1, total: stats.total + 1}
        :miss -> %{stats | misses: stats.misses + 1, total: stats.total + 1}
      end

    save_runtime_stats(updated)
  catch
    _ -> :ok
  end

  defp load_runtime_stats do
    case File.read(@stats_file) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, stats} -> stats
          _ -> %{hits: 0, misses: 0, total: 0}
        end

      _ ->
        %{hits: 0, misses: 0, total: 0}
    end
  end

  defp save_runtime_stats(stats) do
    ensure_cache_dir()
    File.write!(@stats_file, Jason.encode!(stats))
  end

  defp get_cache_size do
    case File.stat(@cache_file) do
      {:ok, stat} -> stat.size
      _ -> 0
    end
  end
end
