defmodule Raxol.Config.Loader do
  @moduledoc """
  Configuration loading utilities for various formats and sources.

  Handles loading configuration from files, environment variables,
  and other sources with proper error handling and validation.
  """

  require Logger
  alias Raxol.Config.Schema

  @supported_formats ~w(.toml .json .yaml .yml)

  @doc """
  Loads configuration from a file path.
  """
  def load_file(path) do
    with {:ok, content} <- read_file(path),
         {:ok, parsed} <- parse_content(content, Path.extname(path)),
         {:ok, config} <- normalize_config(parsed) do
      {:ok, config}
    else
      {:error, :enoent} ->
        {:error, {:file_not_found, path}}

      {:error, reason} ->
        {:error, {:load_failed, path, reason}}
    end
  end

  @doc """
  Loads configuration from multiple file paths, merging them.
  """
  def load_files(paths) when is_list(paths) do
    results = Enum.map(paths, &load_file/1)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    if length(failures) == length(paths) do
      {:error, {:all_files_failed, failures}}
    else
      configs = Enum.map(successes, fn {:ok, config} -> config end)
      merged = Enum.reduce(configs, %{}, &deep_merge/2)

      {:ok, merged}
    end
  end

  @doc """
  Loads configuration from environment variables with a prefix.
  """
  def load_environment(prefix \\ "RAXOL_") do
    env_vars =
      System.get_env()
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, prefix) end)
      |> Enum.map(fn {key, value} ->
        parsed_key = parse_env_key(key, prefix)
        parsed_value = parse_env_value(value)
        {parsed_key, parsed_value}
      end)

    config = build_nested_config(env_vars)
    {:ok, config}
  end

  @doc """
  Creates a configuration loader for a specific directory.
  """
  def create_directory_loader(directory) do
    fn ->
      config_files = find_config_files(directory)

      case load_files(config_files) do
        {:ok, config} ->
          Logger.info(
            "Loaded configuration from #{length(config_files)} files in #{directory}"
          )

          {:ok, config}

        {:error, reason} ->
          Logger.warning(
            "Failed to load configuration from #{directory}: #{inspect(reason)}"
          )

          {:ok, %{}}
      end
    end
  end

  @doc """
  Validates configuration against schema.
  """
  def validate_config(config, schema \\ Schema.schema()) do
    Schema.validate_config(config, schema)
  end

  @doc """
  Applies default values to configuration.
  """
  def apply_defaults(config, defaults) do
    deep_merge(defaults, config)
  end

  @doc """
  Transforms configuration using custom transformation functions.
  """
  def transform_config(config, transformers) do
    Enum.reduce(transformers, config, fn transformer, acc ->
      transformer.(acc)
    end)
  end

  @doc """
  Exports configuration to a file.
  """
  def export_config(config, path, opts \\ []) do
    format = Keyword.get(opts, :format) || detect_format(path)
    pretty = Keyword.get(opts, :pretty, true)

    with {:ok, content} <- encode_config(config, format, pretty),
         :ok <- ensure_directory(path),
         :ok <- File.write(path, content) do
      {:ok, path}
    else
      {:error, reason} ->
        {:error, {:export_failed, path, reason}}
    end
  end

  @doc """
  Creates a backup of a configuration file.
  """
  def backup_config(path) do
    if File.exists?(path) do
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      backup_path = "#{path}.backup.#{timestamp}"

      case File.copy(path, backup_path) do
        {:ok, _} ->
          Logger.info("Configuration backed up to #{backup_path}")
          {:ok, backup_path}

        {:error, reason} ->
          {:error, {:backup_failed, reason}}
      end
    else
      {:error, :file_not_found}
    end
  end

  @doc """
  Watches configuration files for changes.
  """
  def watch_files(paths, callback)
      when is_list(paths) and is_function(callback) do
    case FileSystem.start_link(dirs: Enum.map(paths, &Path.dirname/1)) do
      {:ok, watcher} ->
        FileSystem.subscribe(watcher)

        spawn_link(fn ->
          watch_loop(paths, callback, MapSet.new())
        end)

        {:ok, watcher}

      {:error, reason} ->
        {:error, {:watch_failed, reason}}
    end
  end

  # Private functions

  defp read_file(path) do
    expanded_path = Path.expand(path)
    File.read(expanded_path)
  end

  defp parse_content(content, ext) do
    case String.downcase(ext) do
      ".toml" -> parse_toml(content)
      ".json" -> parse_json(content)
      ".yaml" -> parse_yaml(content)
      ".yml" -> parse_yaml(content)
      _ -> {:error, {:unsupported_format, ext}}
    end
  end

  defp parse_toml(content) do
    case Toml.decode(content) do
      {:ok, config} -> {:ok, config}
      {:error, reason} -> {:error, {:toml_parse_error, reason}}
    end
  end

  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, config} -> {:ok, config}
      {:error, reason} -> {:error, {:json_parse_error, reason}}
    end
  end

  defp parse_yaml(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, config} -> {:ok, config}
      {:error, reason} -> {:error, {:yaml_parse_error, reason}}
    end
  end

  defp normalize_config(config) when is_map(config) do
    normalized =
      config
      |> atomize_keys()
      |> normalize_values()

    {:ok, normalized}
  end

  defp normalize_config(_), do: {:error, :invalid_config_format}

  defp atomize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_atom(key), else: key

      normalized_value =
        case value do
          v when is_map(v) -> atomize_keys(v)
          v when is_list(v) -> Enum.map(v, &atomize_keys/1)
          v -> v
        end

      Map.put(acc, atom_key, normalized_value)
    end)
  end

  defp atomize_keys(value), do: value

  defp normalize_values(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      normalized_value =
        case value do
          v when is_map(v) -> normalize_values(v)
          v when is_list(v) -> Enum.map(v, &normalize_values/1)
          v when is_binary(v) -> normalize_string_value(v)
          v -> v
        end

      Map.put(acc, key, normalized_value)
    end)
  end

  defp normalize_values(value), do: value

  defp normalize_string_value(value) do
    cond do
      # Boolean strings
      value in ~w(true false) ->
        value == "true"

      # Numeric strings
      Regex.match?(~r/^\d+$/, value) ->
        String.to_integer(value)

      Regex.match?(~r/^\d+\.\d+$/, value) ->
        String.to_float(value)

      # Environment variable references
      String.starts_with?(value, "${") and String.ends_with?(value, "}") ->
        var_name = String.slice(value, 2..-2//1)
        System.get_env(var_name, value)

      # File paths
      String.starts_with?(value, "~/") ->
        Path.expand(value)

      true ->
        value
    end
  end

  defp parse_env_key(key, prefix) do
    key
    |> String.replace_prefix(prefix, "")
    |> String.downcase()
    |> String.split("__")
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_env_value(value) do
    normalize_string_value(value)
  end

  defp build_nested_config(key_value_pairs) do
    Enum.reduce(key_value_pairs, %{}, fn {keys, value}, acc ->
      put_nested(acc, keys, value)
    end)
  end

  defp put_nested(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_nested(map, [key | rest], value) do
    sub_map = Map.get(map, key, %{})
    Map.put(map, key, put_nested(sub_map, rest, value))
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end

  defp find_config_files(directory) do
    if File.dir?(directory) do
      @supported_formats
      |> Enum.flat_map(fn ext ->
        Path.wildcard(Path.join(directory, "*#{ext}"))
      end)
      |> Enum.sort()
    else
      []
    end
  end

  defp detect_format(path) do
    case String.downcase(Path.extname(path)) do
      ".toml" -> :toml
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      _ -> :unknown
    end
  end

  defp encode_config(config, format, pretty) do
    case format do
      :json -> encode_json(config, pretty)
      :toml -> encode_toml(config)
      :yaml -> encode_yaml(config)
      _ -> {:error, {:unsupported_export_format, format}}
    end
  end

  defp encode_json(config, pretty) do
    stringified = stringify_keys(config)
    Jason.encode(stringified, pretty: pretty)
  end

  defp encode_toml(config) do
    # Would need a TOML encoder - using simplified version
    stringified = stringify_keys(config)
    {:ok, inspect(stringified)}
  end

  defp encode_yaml(config) do
    # Would need a YAML encoder
    stringified = stringify_keys(config)
    {:ok, inspect(stringified)}
  end

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      string_key = to_string(key)

      stringified_value =
        case value do
          v when is_map(v) -> stringify_keys(v)
          v when is_list(v) -> Enum.map(v, &stringify_keys/1)
          v -> v
        end

      Map.put(acc, string_key, stringified_value)
    end)
  end

  defp stringify_keys(value), do: value

  defp ensure_directory(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp watch_loop(paths, callback, processed_events) do
    receive do
      {:file_event, _watcher, {file_path, events}} ->
        # Debounce events to avoid multiple calls for the same file
        event_key = {file_path, events}

        if not MapSet.member?(processed_events, event_key) do
          if file_path in paths do
            Logger.debug("Configuration file changed: #{file_path}")

            case load_file(file_path) do
              {:ok, config} ->
                callback.({:file_changed, file_path, config})

              {:error, reason} ->
                callback.({:file_error, file_path, reason})
            end
          end

          # Reset processed events periodically
          new_processed =
            if MapSet.size(processed_events) > 100 do
              MapSet.new([event_key])
            else
              MapSet.put(processed_events, event_key)
            end

          # Remove event after delay to allow for debouncing
          Process.send_after(self(), {:remove_event, event_key}, 1000)

          watch_loop(paths, callback, new_processed)
        else
          watch_loop(paths, callback, processed_events)
        end

      {:remove_event, event_key} ->
        new_processed = MapSet.delete(processed_events, event_key)
        watch_loop(paths, callback, new_processed)

      _ ->
        watch_loop(paths, callback, processed_events)
    end
  end
end
