defmodule Raxol.Terminal.Config.AnimationCache do
  @moduledoc """
  Manages caching for terminal animations.
  """

  # Module attributes for cache table name, ttl, max size, preload dir
  @animation_cache_table :raxol_animation_cache
  @animation_cache_ttl 3600 # 1 hour
  @max_cache_size 100 * 1024 * 1024 # 100MB
  @preload_dir "priv/animations"

  # --- Functions Moved from Raxol.Terminal.Configuration ---

  @spec init_animation_cache() :: :ok
  def init_animation_cache do # Make public
    table_name = @animation_cache_table
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [:named_table, :public, :set])
    end
    :ok
  end

  @spec get_cached_animation(String.t() | nil) :: map() | nil
  def get_cached_animation(animation_path) do # Make public
    table_name = @animation_cache_table
    cache_ttl = @animation_cache_ttl

    case animation_path do
      nil ->
        nil
      path ->
        case :ets.lookup(table_name, path) do
          [{^path, animation_data, timestamp}] ->
            if :os.system_time(:second) - timestamp < cache_ttl do
              animation_data
            else
              :ets.delete(table_name, path)
              nil
            end
          [] ->
            nil
        end
    end
  end

  @spec cache_animation(String.t(), atom()) :: :ok | {:error, atom()}
  def cache_animation(animation_path, animation_type) do # Make public
    table_name = @animation_cache_table

    case File.read(animation_path) do
      {:ok, animation_data} ->
        compressed_data = compress_animation(animation_data, animation_type)
        compressed_size = byte_size(compressed_data)
        original_size = byte_size(animation_data)

        if would_exceed_cache_limit(compressed_size) do
          make_space_for_animation(compressed_size)
        end

        :ets.insert(table_name, {
          animation_path,
          %{
            type: animation_type,
            data: compressed_data,
            size: compressed_size,
            original_size: original_size,
            compressed: true
          },
          :os.system_time(:second)
        })

        if original_size > 0 do
          compression_ratio = round((1 - compressed_size / original_size) * 100)
          IO.puts(
            "Animation cached: #{animation_path} (#{compressed_size} bytes, #{compression_ratio}% compression)"
          )
        else
          IO.puts(
            "Animation cached: #{animation_path} (#{compressed_size} bytes, empty original file)"
          )
        end
        :ok

      {:error, reason} ->
        IO.puts("Failed to cache animation: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec compress_animation(binary(), atom()) :: binary()
  defp compress_animation(animation_data, _animation_type) do
    :zlib.compress(animation_data)
  end

  @spec decompress_animation(binary()) :: binary()
  def decompress_animation(compressed_data) do # Make public
    :zlib.uncompress(compressed_data)
  end

  @spec would_exceed_cache_limit(non_neg_integer()) :: boolean()
  defp would_exceed_cache_limit(new_size) do
    max_cache_size = @max_cache_size
    current_size = get_cache_size()
    current_size + new_size > max_cache_size
  end

  @spec get_cache_size() :: non_neg_integer()
  def get_cache_size do # Make public
    table_name = @animation_cache_table
    if :ets.whereis(table_name) != :undefined do
      entries = :ets.tab2list(table_name)
      Enum.reduce(entries, 0, fn {_path, %{size: size}, _timestamp}, acc ->
        acc + size
      end)
    else
      0
    end
  end

  @spec make_space_for_animation(non_neg_integer()) :: :ok
  defp make_space_for_animation(required_size) do
    table_name = @animation_cache_table
    max_cache_size = @max_cache_size

    if :ets.whereis(table_name) != :undefined do
      entries = :ets.tab2list(table_name)
      sorted_entries = Enum.sort_by(entries, fn {_path, _data, timestamp} -> timestamp end)
      current_size = get_cache_size()
      space_to_free = current_size + required_size - max_cache_size
      freed_bytes_ref = make_ref() # Use make_ref/Process.put for state in reduce
      Process.put(freed_bytes_ref, 0)

      Enum.reduce_while(sorted_entries, 0, fn {path, data, _timestamp}, freed_acc ->
        entry_size = Map.get(data, :size, 0)
        new_freed = freed_acc + entry_size

        if new_freed >= space_to_free do
           :ets.delete(table_name, path) # Delete the current one too
           Process.put(freed_bytes_ref, new_freed) # Store final freed amount
          {:halt, new_freed}
        else
          :ets.delete(table_name, path)
          {:cont, new_freed}
        end
      end)

      final_freed = Process.get(freed_bytes_ref, 0)
      Process.delete(freed_bytes_ref)
      IO.puts("Cache cleaned: freed #{final_freed} bytes")
    end
    :ok
  end

  @spec preload_animations() :: :ok
  def preload_animations do # Make public
    preload_dir = @preload_dir
    preload_path = Path.expand(preload_dir)

    case File.mkdir_p(preload_path) do
      :ok ->
        animation_files = find_animation_files(preload_path)
        Enum.each(animation_files, fn {path, type} ->
          cache_animation(path, type) # Ignore result for preload
        end)
        IO.puts("Preloaded #{length(animation_files)} animations")
        :ok

      {:error, reason} ->
        IO.warn("Could not create preload directory '#{preload_path}': #{inspect(reason)}")
        :ok
    end
  end

  @spec find_animation_files(String.t()) :: [{String.t(), atom()}]
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

  @spec determine_animation_type(String.t()) :: :gif | :video | :shader | :particle | nil
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

  @spec clear_animation_cache() :: :ok
  def clear_animation_cache do # Make public
    table_name = @animation_cache_table
    if :ets.whereis(table_name) != :undefined do
      :ets.delete_all_objects(table_name)
      IO.puts("Animation cache cleared")
    end
    :ok
  end

  @spec get_animation_cache_stats() :: map()
  def get_animation_cache_stats do # Make public
    table_name = @animation_cache_table
    max_cache_size = @max_cache_size

    if :ets.whereis(table_name) != :undefined do
      entries = :ets.tab2list(table_name)
      count = length(entries)
      total_size = Enum.reduce(entries, 0, fn {_path, %{size: size}, _ts}, acc -> acc + size end)
      total_original_size = Enum.reduce(entries, 0, fn {_path, %{original_size: size}, _ts}, acc -> acc + size end)

      %{
        count: count,
        total_size: total_size,
        total_original_size: total_original_size,
        average_size: if(count > 0, do: div(total_size, count), else: 0),
        compression_ratio: if(total_original_size > 0, do: round((1 - total_size / total_original_size) * 100), else: 0),
        max_size: max_cache_size,
        used_percent: if(max_cache_size > 0, do: round(total_size / max_cache_size * 100), else: 0)
      }
    else
      %{
        count: 0, total_size: 0, total_original_size: 0, average_size: 0,
        compression_ratio: 0, max_size: max_cache_size, used_percent: 0
      }
    end
  end

  @spec preload_animation(String.t()) :: {:ok, atom()} | {:error, atom()}
  def preload_animation(animation_path) do # Make public
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

  # Functions to set module attributes are commented out as it's not standard practice.
  # These should be managed via Application config or a state process.

end
