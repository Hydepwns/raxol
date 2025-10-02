defmodule Raxol.Terminal.Config.AnimationCache do
  @moduledoc """
  Manages caching for terminal animations using the unified caching system.
  """

  alias Raxol.Core.Runtime.Log
  # Module attributes for preload dir
  @preload_dir "priv/animations"

  @doc """
  Initializes the animation cache.
  """
  def init_animation_cache do
    # The unified cache system is already initialized by the application
    :ok
  end

  @doc """
  Gets a cached animation.

  ## Parameters
    * `animation_path` - Path to the animation file
  """
  def get_cached_animation(animation_path) do
    case animation_path do
      nil -> {:error, :invalid_path}
      path -> Raxol.Terminal.Cache.System.get(path, namespace: :animation)
    end
  end

  @doc """
  Caches animation data directly (for testing and in-memory usage).

  ## Parameters
    * `animation_key` - Key to store the animation under
    * `animation_data` - Animation data to cache
  """
  def cache_animation_data(animation_key, animation_data) do
    case Raxol.Terminal.Cache.System.put(animation_key, animation_data,
           namespace: :animation,
           metadata: %{
             type: :data,
             size: byte_size(:erlang.term_to_binary(animation_data)),
             original_size: byte_size(:erlang.term_to_binary(animation_data)),
             compressed: false
           }
         ) do
      :ok ->
        Log.info("Animation data cached: #{animation_key}")
        :ok

      error ->
        Log.info("Failed to cache animation data: #{inspect(error)}")
        error
    end
  end

  @doc """
  Caches an animation from a file.

  ## Parameters
    * `animation_path` - Path to the animation file
    * `animation_type` - Type of animation (:gif, :video, :shader, :particle)
  """
  def cache_animation(animation_path, animation_type) do
    case File.read(animation_path) do
      {:ok, animation_data} ->
        compressed_data = compress_animation(animation_data, animation_type)
        compressed_size = byte_size(compressed_data)
        original_size = byte_size(animation_data)

        metadata = %{
          type: animation_type,
          size: compressed_size,
          original_size: original_size,
          compressed: true
        }

        case Raxol.Terminal.Cache.System.put(animation_path, compressed_data,
               namespace: :animation,
               metadata: metadata
             ) do
          :ok ->
            handle_cache_success(animation_path, compressed_size, original_size)

          error ->
            handle_cache_error(error)
        end

      {:error, reason} ->
        handle_file_error(reason)
    end
  end

  @doc """
  Decompresses an animation.

  ## Parameters
    * `compressed_data` - Compressed animation data
  """
  def decompress_animation(compressed_data) do
    :zlib.uncompress(compressed_data)
  end

  @doc """
  Gets the current cache size.
  """
  def get_cache_size do
    case Raxol.Terminal.Cache.System.stats(namespace: :animation) do
      {:ok, stats} -> stats.size
      _ -> 0
    end
  end

  @doc """
  Preloads animations from the preload directory.
  """
  def preload_animations do
    preload_path = Path.expand(@preload_dir)

    case File.mkdir_p(preload_path) do
      :ok ->
        animation_files = find_animation_files(preload_path)

        Enum.each(animation_files, fn {path, type} ->
          # Ignore result for preload
          cache_animation(path, type)
        end)

        Log.info("Preloaded #{length(animation_files)} animations")
        :ok

      {:error, reason} ->
        IO.warn(
          "Could not create preload directory #{preload_path}: #{inspect(reason)}"
        )

        :ok
    end
  end

  @doc """
  Clears the animation cache.
  """
  def clear_animation_cache do
    Raxol.Terminal.Cache.System.clear(namespace: :animation)
    Log.info("Animation cache cleared")
    :ok
  end

  @doc """
  Gets animation cache statistics.
  """
  def get_animation_cache_stats do
    case Raxol.Terminal.Cache.System.stats(namespace: :animation) do
      {:ok, stats} ->
        {:ok,
         %{
           count: stats.size,
           total_size: stats.size,
           # We don't track original size in unified cache
           total_original_size: stats.size,
           average_size:
             case stats.size > 0 do
               true -> div(stats.size, stats.size)
               false -> 0
             end,
           # We don't track compression ratio in unified cache
           compression_ratio: 0,
           max_size: stats.max_size,
           used_percent:
             case stats.max_size > 0 do
               true -> round(stats.size / stats.max_size * 100)
               false -> 0
             end,
           hit_count: Map.get(stats, :hit_count, 0),
           miss_count: Map.get(stats, :miss_count, 0),
           hit_ratio: Map.get(stats, :hit_ratio, 0.0)
         }}

      _ ->
        {:ok,
         %{
           count: 0,
           total_size: 0,
           total_original_size: 0,
           average_size: 0,
           compression_ratio: 0,
           max_size: 0,
           used_percent: 0,
           hit_count: 0,
           miss_count: 0,
           hit_ratio: 0.0
         }}
    end
  end

  @doc """
  Preloads a single animation.

  ## Parameters
    * `animation_path` - Path to the animation file
  """
  def preload_animation(animation_path) do
    preload_animation_with_validation(
      animation_path,
      File.exists?(animation_path)
    )
  end

  defp preload_animation_with_validation(_animation_path, false) do
    {:error, :file_not_found}
  end

  defp preload_animation_with_validation(animation_path, true) do
    case determine_animation_type(animation_path) do
      nil ->
        {:error, :unsupported_animation_type}

      animation_type ->
        case cache_animation(animation_path, animation_type) do
          :ok -> {:ok, animation_type}
          error -> error
        end
    end
  end

  # Private Functions

  defp handle_cache_success(animation_path, compressed_size, original_size) do
    case original_size > 0 do
      true ->
        compression_ratio = round((1 - compressed_size / original_size) * 100)

        Log.info(
          "Animation cached: #{animation_path} (#{compressed_size} bytes, #{compression_ratio}% compression)"
        )

      false ->
        Log.info(
          "Animation cached: #{animation_path} (#{compressed_size} bytes, empty original file)"
        )
    end

    :ok
  end

  defp handle_cache_error(error) do
    Log.info("Failed to cache animation: #{inspect(error)}")
    error
  end

  defp handle_file_error(reason) do
    Log.info("Failed to cache animation: #{inspect(reason)}")
    {:error, reason}
  end

  defp compress_animation(animation_data, _animation_type) do
    :zlib.compress(animation_data)
  end

  defp find_animation_files(directory) do
    case File.ls(directory) do
      {:ok, files} ->
        Enum.flat_map(files, &process_animation_file(&1, directory))

      _ ->
        []
    end
  end

  defp process_animation_file(file, directory) do
    path = Path.join(directory, file)

    case File.regular?(path) do
      true ->
        case determine_animation_type(path) do
          nil -> []
          type -> [{path, type}]
        end

      false ->
        []
    end
  end

  defp determine_animation_type(path) do
    ext = Path.extname(path) |> String.downcase()

    case ext do
      ".gif" -> :gif
      ".mp4" -> :video
      ".webm" -> :video
      ".glsl" -> :shader
      ".frag" -> :shader
      ".vert" -> :shader
      ".particle" -> :particle
      _ -> nil
    end
  end
end
