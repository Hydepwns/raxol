defmodule Raxol.Terminal.Config.AnimationCache do
  @moduledoc '''
  Manages caching for terminal animations using the unified caching system.
  '''

  alias Raxol.Terminal.Cache.System

  # Module attributes for preload dir
  @preload_dir "priv/animations"

  @doc '''
  Initializes the animation cache.
  '''
  def init_animation_cache do
    # The unified cache system is already initialized by the application
    :ok
  end

  @doc '''
  Gets a cached animation.

  ## Parameters
    * `animation_path` - Path to the animation file
  '''
  def get_cached_animation(animation_path) do
    case animation_path do
      nil -> nil
      path -> System.get(path, namespace: :animation)
    end
  end

  @doc '''
  Caches an animation.

  ## Parameters
    * `animation_path` - Path to the animation file
    * `animation_type` - Type of animation (:gif, :video, :shader, :particle)
  '''
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

        case System.put(animation_path, compressed_data,
               namespace: :animation,
               metadata: metadata
             ) do
          :ok ->
            if original_size > 0 do
              compression_ratio =
                round((1 - compressed_size / original_size) * 100)

              IO.puts(
                "Animation cached: #{animation_path} (#{compressed_size} bytes, #{compression_ratio}% compression)"
              )
            else
              IO.puts(
                "Animation cached: #{animation_path} (#{compressed_size} bytes, empty original file)"
              )
            end

            :ok

          error ->
            IO.puts("Failed to cache animation: #{inspect(error)}")
            error
        end

      {:error, reason} ->
        IO.puts("Failed to cache animation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc '''
  Decompresses an animation.

  ## Parameters
    * `compressed_data` - Compressed animation data
  '''
  def decompress_animation(compressed_data) do
    :zlib.uncompress(compressed_data)
  end

  @doc '''
  Gets the current cache size.
  '''
  def get_cache_size do
    case System.stats(namespace: :animation) do
      {:ok, stats} -> stats.size
      _ -> 0
    end
  end

  @doc '''
  Preloads animations from the preload directory.
  '''
  def preload_animations do
    preload_path = Path.expand(@preload_dir)

    case File.mkdir_p(preload_path) do
      :ok ->
        animation_files = find_animation_files(preload_path)

        Enum.each(animation_files, fn {path, type} ->
          # Ignore result for preload
          cache_animation(path, type)
        end)

        IO.puts("Preloaded #{length(animation_files)} animations")
        :ok

      {:error, reason} ->
        IO.warn(
          "Could not create preload directory "#{preload_path}": #{inspect(reason)}"
        )

        :ok
    end
  end

  @doc '''
  Clears the animation cache.
  '''
  def clear_animation_cache do
    System.clear(namespace: :animation)
    IO.puts("Animation cache cleared")
    :ok
  end

  @doc '''
  Gets animation cache statistics.
  '''
  def get_animation_cache_stats do
    case System.stats(namespace: :animation) do
      {:ok, stats} ->
        %{
          count: stats.size,
          total_size: stats.size,
          # We don't track original size in unified cache
          total_original_size: stats.size,
          average_size:
            if(stats.size > 0, do: div(stats.size, stats.size), else: 0),
          # We don't track compression ratio in unified cache
          compression_ratio: 0,
          max_size: stats.max_size,
          used_percent:
            if(stats.max_size > 0,
              do: round(stats.size / stats.max_size * 100),
              else: 0
            )
        }

      _ ->
        %{
          count: 0,
          total_size: 0,
          total_original_size: 0,
          average_size: 0,
          compression_ratio: 0,
          max_size: 0,
          used_percent: 0
        }
    end
  end

  @doc '''
  Preloads a single animation.

  ## Parameters
    * `animation_path` - Path to the animation file
  '''
  def preload_animation(animation_path) do
    if File.exists?(animation_path) do
      animation_type = determine_animation_type(animation_path)

      if animation_type do
        case cache_animation(animation_path, animation_type) do
          :ok -> {:ok, animation_type}
          error -> error
        end
      else
        {:error, :unsupported_animation_type}
      end
    else
      {:error, :file_not_found}
    end
  end

  # Private Functions

  defp compress_animation(animation_data, _animation_type) do
    :zlib.compress(animation_data)
  end

  defp find_animation_files(directory) do
    case File.ls(directory) do
      {:ok, files} ->
        Enum.reduce(files, [], fn file, acc ->
          path = Path.join(directory, file)

          if File.regular?(path) do
            type = determine_animation_type(path)
            if type, do: [{path, type} | acc], else: acc
          else
            acc
          end
        end)

      _ ->
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
