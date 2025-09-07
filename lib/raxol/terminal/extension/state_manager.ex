defmodule Raxol.Terminal.Extension.StateManager do
  @moduledoc """
  Handles extension state management operations including loading extension states and managing configurations.
  """

  require Logger

  @manifest_file "extension.json"
  @config_file "config.exs"
  @script_file "script.ex"

  @doc """
  Loads an extension state from a file or directory.
  """
  def load_extension_state(path, type, opts) do
    # Try to load extension manifest first
    manifest = load_extension_manifest(path)

    # Load extension module if it exists
    module = load_extension_module(path, type)

    # Load configuration
    config = load_extension_config(path, Keyword.get(opts, :config, %{}))

    build_extension_state(path, type, opts, manifest, module, config)
  end

  @doc """
  Gets the state of an extension.
  """
  def get_extension_state(extension_id, state) do
    case Map.get(state.extensions, extension_id) do
      nil -> {:error, :extension_not_found}
      extension -> {:ok, extension}
    end
  end

  @doc """
  Updates an extension's configuration.
  """
  def update_extension_config(extension_id, config, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:error, :extension_not_found}

      extension ->
        case config do
          config when is_map(config) ->
            new_extension = update_in(extension.config, &Map.merge(&1, config))
            new_state = put_in(state.extensions[extension_id], new_extension)
            {:ok, new_state}

          _ ->
            {:error, :invalid_extension_config}
        end
    end
  end

  @doc """
  Filters extensions based on options.
  """
  def filter_extensions(extensions, opts) do
    extensions
    |> Enum.filter(fn {_id, extension} ->
      Enum.all?(opts, fn
        {:type, type} -> extension.type == type
        {:status, status} -> extension.status == status
        _ -> true
      end)
    end)
    |> Map.new()
  end

  # Private functions

  defp build_extension_state(path, type, opts, manifest, module, config) do
    %{
      id: nil,
      name: get_extension_name(opts, manifest),
      type: type,
      version: get_extension_version(opts, manifest),
      description: get_extension_description(opts, manifest),
      author: get_extension_author(opts, manifest),
      license: get_extension_license(opts, manifest),
      config: config,
      status: :idle,
      error: nil,
      metadata: get_extension_metadata(opts, manifest),
      dependencies: get_extension_dependencies(opts, manifest),
      hooks: get_extension_hooks(opts, manifest),
      commands: get_extension_commands(opts, manifest),
      module: module,
      path: path,
      manifest: manifest
    }
  end

  defp get_extension_name(opts, manifest),
    do: Keyword.get(opts, :name, manifest["name"] || "Unnamed Extension")

  defp get_extension_version(opts, manifest),
    do: Keyword.get(opts, :version, manifest["version"] || "1.0.1")

  defp get_extension_description(opts, manifest),
    do: Keyword.get(opts, :description, manifest["description"] || "")

  defp get_extension_author(opts, manifest),
    do: Keyword.get(opts, :author, manifest["author"] || "Unknown")

  defp get_extension_license(opts, manifest),
    do: Keyword.get(opts, :license, manifest["license"] || "MIT")

  defp get_extension_metadata(opts, manifest),
    do: Keyword.get(opts, :metadata, manifest["metadata"] || %{})

  defp get_extension_dependencies(opts, manifest),
    do: Keyword.get(opts, :dependencies, manifest["dependencies"] || [])

  defp get_extension_hooks(opts, manifest),
    do: Keyword.get(opts, :hooks, manifest["hooks"] || [])

  defp get_extension_commands(opts, manifest),
    do: Keyword.get(opts, :commands, manifest["commands"] || [])

  defp load_extension_manifest(path) do
    manifest_path = Path.join(path, @manifest_file)

    case File.read(manifest_path) do
      {:ok, content} -> parse_json_manifest(content)
      {:error, _reason} -> %{}
    end
  end

  defp parse_json_manifest(content) do
    case Jason.decode(content) do
      {:ok, manifest} -> manifest
      {:error, _reason} -> %{}
    end
  end

  defp load_extension_module(path, type) do
    case type do
      :script -> load_script_module(path)
      :plugin -> load_plugin_module(path)
      :theme -> load_theme_module(path)
      :custom -> load_custom_module(path)
      _ -> {:error, :invalid_extension_type}
    end
  end

  defp load_script_module(path) do
    script_path = Path.join(path, @script_file)
    handle_script_loading(File.exists?(script_path), script_path)
  end

  defp load_plugin_module(path) do
    # Look for plugin files in the directory
    case File.ls(path) do
      {:ok, files} -> find_and_compile_plugin(files, path)
      {:error, _reason} -> {:error, :directory_not_found}
    end
  end

  defp find_and_compile_plugin(files, path) do
    plugin_files = Enum.filter(files, &String.ends_with?(&1, ".ex"))

    case plugin_files do
      [plugin_file | _] ->
        plugin_path = Path.join(path, plugin_file)
        compile_plugin_file(plugin_path)

      [] ->
        {:error, :no_plugin_files}
    end
  end

  defp compile_plugin_file(plugin_path) do
    case Code.compile_file(plugin_path) do
      [{module, _}] -> {:ok, module}
      _ -> {:error, :compilation_failed}
    end
  end

  defp load_theme_module(path) do
    # Themes typically have a theme.ex file
    theme_path = Path.join(path, "theme.ex")
    handle_theme_loading(File.exists?(theme_path), theme_path)
  end

  defp load_custom_module(path) do
    # Custom extensions can have any structure
    # Look for main.ex or custom.ex
    custom_paths = [
      Path.join(path, "main.ex"),
      Path.join(path, "custom.ex"),
      Path.join(path, "extension.ex")
    ]

    find_custom_module(custom_paths)
  end

  defp find_custom_module(custom_paths) do
    Enum.find_value(
      custom_paths,
      {:error, :no_custom_module},
      &try_compile_custom_path/1
    )
  end

  defp try_compile_custom_path(custom_path) do
    handle_custom_compilation(File.exists?(custom_path), custom_path)
  end

  defp load_extension_config(path, default_config) do
    config_path = Path.join(path, @config_file)

    handle_config_loading(
      File.exists?(config_path),
      config_path,
      default_config
    )
  end

  defp handle_script_loading(true, script_path) do
    case Code.compile_file(script_path) do
      [{module, _}] -> {:ok, module}
      _ -> {:error, :compilation_failed}
    end
  end

  defp handle_script_loading(false, _script_path) do
    {:error, :script_not_found}
  end

  defp handle_theme_loading(true, theme_path) do
    case Code.compile_file(theme_path) do
      [{module, _}] -> {:ok, module}
      _ -> {:error, :compilation_failed}
    end
  end

  defp handle_theme_loading(false, _theme_path) do
    {:error, :theme_not_found}
  end

  defp handle_custom_compilation(true, custom_path) do
    case Code.compile_file(custom_path) do
      [{module, _}] -> {:ok, module}
      _ -> nil
    end
  end

  defp handle_custom_compilation(false, _custom_path), do: nil

  defp handle_config_loading(true, config_path, default_config) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           {config, _} = Code.eval_file(config_path)
           Map.merge(default_config, config)
         end) do
      {:ok, merged_config} -> merged_config
      {:error, _reason} -> default_config
    end
  end

  defp handle_config_loading(false, _config_path, default_config) do
    default_config
  end
end
