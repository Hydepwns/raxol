defmodule Raxol.Terminal.Extension.FileOperations do
  @moduledoc """
  Handles extension file operations including importing, exporting, and loading from paths.
  """

  require Logger
  alias Raxol.Core.ErrorHandling

  @manifest_file "extension.json"

  @doc """
  Exports an extension to a file or directory.
  """
  def export_extension(extension, path) do
    case ErrorHandling.safe_call(fn ->
           # Create export directory if it doesn't exist
           export_dir = Path.dirname(path)
           File.mkdir_p!(export_dir)

           # Export manifest
           manifest_path = path

           manifest = %{
             "name" => extension.name,
             "version" => extension.version,
             "description" => extension.description,
             "author" => extension.author,
             "license" => extension.license,
             "type" => Atom.to_string(extension.type),
             "dependencies" => extension.dependencies,
             "hooks" => extension.hooks,
             "commands" => extension.commands,
             "metadata" => extension.config
           }

           File.write!(manifest_path, Jason.encode!(manifest, pretty: true))

           # Only copy source files if export path is a directory
           unless String.ends_with?(path, ".json") do
             if extension.path && File.exists?(extension.path) do
               copy_extension_files(extension.path, path)
             end
           end

           :ok
         end) do
      {:ok, result} ->
        result

      {:error, e} ->
        Logger.error("Extension export failed: #{inspect(e)}")
        {:error, :export_failed}
    end
  end

  @doc """
  Imports an extension from a file or directory.
  """
  def import_extension_from_path(path, opts) do
    case ErrorHandling.safe_call(fn ->
           # Check if path is a directory or file
           case File.stat(path) do
             {:ok, %{type: :directory}} ->
               import_extension_from_directory(path, opts)

             {:ok, %{type: :regular}} ->
               import_extension_from_file(path, opts)

             _ ->
               {:error, :invalid_path}
           end
         end) do
      {:ok, result} ->
        result

      {:error, e} ->
        Logger.error("Extension import failed: #{inspect(e)}")
        {:error, :import_failed}
    end
  end

  @doc """
  Loads extensions from paths.
  """
  def load_extensions_from_paths(paths) do
    Enum.each(paths, fn path ->
      case File.stat(path) do
        {:ok, %{type: :directory}} ->
          load_extensions_from_directory(path)

        {:ok, %{type: :regular}} ->
          load_extension_from_file(path)

        _ ->
          Logger.warning("Invalid extension path: #{path}")
      end
    end)
  end

  # Private functions

  defp copy_extension_files(source_path, dest_path) do
    case File.stat(source_path) do
      {:ok, %{type: :directory}} ->
        File.cp_r!(source_path, dest_path)

      {:ok, %{type: :regular}} ->
        File.cp!(source_path, dest_path)

      _ ->
        :ok
    end
  end

  defp import_extension_from_directory(path, opts) do
    # Look for manifest file
    manifest_path = Path.join(path, @manifest_file)

    case File.read(manifest_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, manifest} ->
            type = String.to_existing_atom(manifest["type"])

            {:ok,
             Raxol.Terminal.Extension.StateManager.load_extension_state(
               path,
               type,
               Keyword.merge(opts, manifest_to_opts(manifest))
             )}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _reason} ->
        # Try to infer type from directory structure
        inferred_type = infer_extension_type(path)

        {:ok,
         Raxol.Terminal.Extension.StateManager.load_extension_state(
           path,
           inferred_type,
           opts
         )}
    end
  end

  defp import_extension_from_file(path, opts) do
    # Single file import - try to determine type from extension
    case Path.extname(path) do
      ".ex" ->
        case Code.compile_file(path) do
          [{module, _}] ->
            inferred_type = infer_type_from_module(module)

            {:ok,
             Raxol.Terminal.Extension.StateManager.load_extension_state(
               Path.dirname(path),
               inferred_type,
               opts
             )}

          _ ->
            {:error, :compilation_failed}
        end

      ".json" ->
        case File.read(path) do
          {:ok, content} -> handle_json_import(content, path, opts)
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :unsupported_file_type}
    end
  end

  defp handle_json_import(content, path, opts) do
    case Jason.decode(content) do
      {:ok, manifest} ->
        type = String.to_existing_atom(manifest["type"])

        # For JSON imports, use the directory containing the JSON file as the base path
        # and look for the actual extension files in a subdirectory with the same name as the type
        base_path = Path.dirname(path)
        extension_path = Path.join(base_path, Atom.to_string(type))

        # If the extension directory doesn't exist, use the base path
        final_path =
          if File.exists?(extension_path),
            do: extension_path,
            else: base_path

        {:ok,
         Raxol.Terminal.Extension.StateManager.load_extension_state(
           final_path,
           type,
           Keyword.merge(opts, manifest_to_opts(manifest))
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp manifest_to_opts(manifest) do
    [
      name: manifest["name"],
      version: manifest["version"],
      description: manifest["description"],
      author: manifest["author"],
      license: manifest["license"],
      dependencies: manifest["dependencies"],
      hooks: manifest["hooks"],
      commands: manifest["commands"],
      metadata: manifest["metadata"]
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp infer_extension_type(path) do
    case File.ls(path) do
      {:ok, files} -> classify_by_files(files)
      {:error, _reason} -> :custom
    end
  end

  defp classify_by_files(files) do
    type_patterns = [
      {:theme, &String.contains?(&1, "theme")},
      {:script, &String.contains?(&1, "script")},
      {:plugin, &String.contains?(&1, "plugin")}
    ]

    Enum.find_value(type_patterns, :custom, fn {type, predicate} ->
      if Enum.any?(files, predicate), do: type
    end)
  end

  defp infer_type_from_module(module) do
    module_type_checks = [
      {:theme, :theme_info},
      {:script, :script_info},
      {:plugin, :plugin_info},
      {:plugin, :extension_info}
    ]

    Enum.find_value(module_type_checks, :custom, fn {type, function} ->
      if function_exported?(module, function, 0), do: type
    end)
  end

  defp load_extensions_from_directory(path) do
    case File.ls(path) do
      {:ok, entries} ->
        Enum.each(entries, &process_directory_entry(&1, path))

      {:error, reason} ->
        Logger.error("Failed to list directory #{path}: #{inspect(reason)}")
    end
  end

  defp process_directory_entry(entry, path) do
    entry_path = Path.join(path, entry)

    case File.stat(entry_path) do
      {:ok, %{type: :directory}} ->
        load_extension_from_directory(entry_path)

      {:ok, %{type: :regular}} ->
        load_extension_from_file(entry_path)

      _ ->
        :ok
    end
  end

  defp load_extension_from_directory(path) do
    # Check for manifest file to determine type
    manifest_path = Path.join(path, @manifest_file)

    case File.read(manifest_path) do
      {:ok, content} ->
        handle_manifest_parse(content, path)

      {:error, _reason} ->
        # Try to infer type
        inferred_type = infer_extension_type(path)

        Raxol.Terminal.Extension.UnifiedExtension.load_extension(
          path,
          inferred_type,
          []
        )
    end
  end

  defp handle_manifest_parse(content, path) do
    case Jason.decode(content) do
      {:ok, manifest} ->
        type = String.to_existing_atom(manifest["type"])

        Raxol.Terminal.Extension.UnifiedExtension.load_extension(
          path,
          type,
          manifest_to_opts(manifest)
        )

      {:error, reason} ->
        Logger.error("Failed to parse manifest in #{path}: #{inspect(reason)}")
    end
  end

  defp load_extension_from_file(path) do
    case Path.extname(path) do
      ".ex" ->
        case Code.compile_file(path) do
          [{module, _}] ->
            inferred_type = infer_type_from_module(module)

            Raxol.Terminal.Extension.UnifiedExtension.load_extension(
              Path.dirname(path),
              inferred_type,
              []
            )

          _ ->
            Logger.error("Failed to compile extension file: #{path}")
        end

      ".json" ->
        case File.read(path) do
          {:ok, content} ->
            handle_json_file_parse(content, path)

          {:error, reason} ->
            Logger.error(
              "Failed to read file: #{path}, reason: #{inspect(reason)}"
            )
        end

      _ ->
        :ok
    end
  end

  defp handle_json_file_parse(content, path) do
    case Jason.decode(content) do
      {:ok, manifest} ->
        type = String.to_existing_atom(manifest["type"])

        Raxol.Terminal.Extension.UnifiedExtension.load_extension(
          Path.dirname(path),
          type,
          manifest_to_opts(manifest)
        )

      {:error, reason} ->
        Logger.error(
          "Failed to parse JSON file: #{path}, reason: #{inspect(reason)}"
        )
    end
  end
end
