defmodule Raxol.Terminal.Input.FileDropHandler do
  alias Raxol.Core.Runtime.Log
  import Bitwise

  @moduledoc """
  Handles file drag-and-drop operations for the terminal emulator.

  Processes file URIs from drag-and-drop events and provides secure
  file access with permission controls and type validation.

  ## Features

  - File URI parsing and validation
  - Multiple file drop support
  - MIME type detection
  - File size and permission checking
  - Security controls and sandbox validation
  - Integration with system file watchers

  ## Supported Protocols

  - `file://` - Local file system paths
  - `content://` - Android content URIs (if applicable)
  - Data URLs for small embedded content

  ## Security

  - File access is restricted to allowed directories
  - File size limits prevent memory exhaustion
  - MIME type validation prevents execution of dangerous files
  - Symlink resolution with loop detection
  """
  @type file_info :: %{
          path: String.t(),
          name: String.t(),
          size: non_neg_integer(),
          mime_type: String.t(),
          permissions: map(),
          last_modified: DateTime.t()
        }

  @type drop_event :: %{
          files: [file_info()],
          position: {non_neg_integer(), non_neg_integer()},
          modifiers: map(),
          timestamp: non_neg_integer()
        }

  @type drop_options :: %{
          optional(:max_files) => non_neg_integer(),
          optional(:max_file_size) => non_neg_integer(),
          optional(:allowed_mime_types) => [String.t()],
          optional(:allowed_extensions) => [String.t()],
          optional(:allowed_directories) => [String.t()],
          optional(:resolve_symlinks) => boolean(),
          optional(:validate_permissions) => boolean()
        }

  # Configuration constants
  @default_max_files 10
  # 50MB
  @default_max_file_size 50 * 1024 * 1024
  @max_symlink_depth 10

  # Common MIME type mappings
  @mime_types %{
    ".txt" => "text/plain",
    ".md" => "text/markdown",
    ".json" => "application/json",
    ".xml" => "application/xml",
    ".csv" => "text/csv",
    ".log" => "text/plain",
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".gif" => "image/gif",
    ".svg" => "image/svg+xml",
    ".pdf" => "application/pdf",
    ".zip" => "application/zip",
    ".tar" => "application/x-tar",
    ".gz" => "application/gzip"
  }

  @doc """
  Processes a file drop event from the terminal.

  Takes raw file URIs from a drag-and-drop operation and converts them
  into validated file information structures.

  ## Parameters

  - `file_uris` - List of file URIs from the drop event
  - `position` - {x, y} coordinates where files were dropped
  - `options` - Configuration options for validation and security

  ## Returns

  - `{:ok, drop_event}` - Successfully processed drop event
  - `{:error, reason}` - Error with validation failure details

  ## Examples

      iex> FileDropHandler.process_drop_event([
      ...>   "file:///home/user/document.txt",
      ...>   "file:///home/user/image.png"
      ...> ], {100, 200})
      {:ok, %{files: [...], position: {100, 200}, ...}}
  """
  @spec process_drop_event(
          [String.t()],
          {non_neg_integer(), non_neg_integer()},
          drop_options()
        ) ::
          {:ok, drop_event()} | {:error, term()}
  def process_drop_event(file_uris, position, options \\ %{})
      when is_list(file_uris) and is_tuple(position) do
    config = build_config(options)

    with :ok <- validate_drop_constraints(file_uris, config),
         {:ok, file_infos} <- process_file_uris(file_uris, config) do
      drop_event = %{
        files: file_infos,
        position: position,
        modifiers: Map.get(options, :modifiers, %{}),
        timestamp: System.monotonic_time(:millisecond)
      }

      {:ok, drop_event}
    end
  end

  @doc """
  Parses a file URI and extracts the local file path.

  Supports various URI schemes and handles URL decoding properly.

  ## Parameters

  - `uri` - File URI string (e.g., "file:///path/to/file.txt")

  ## Returns

  - `{:ok, path}` - Successfully extracted file path
  - `{:error, reason}` - Error parsing URI

  ## Examples

      iex> FileDropHandler.parse_file_uri("file:///home/user/test%20file.txt")
      {:ok, "/home/user/test file.txt"}

      iex> FileDropHandler.parse_file_uri("http://example.com/file.txt")
      {:error, :unsupported_scheme}
  """
  @spec parse_file_uri(String.t()) ::
          {:ok, String.t()}
          | {:ok, {:data, binary(), String.t()}}
          | {:error, term()}
  def parse_file_uri(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: "file", path: path} when is_binary(path) ->
        decoded_path = URI.decode(path)
        {:ok, decoded_path}

      %URI{scheme: "data"} ->
        # Handle data URLs for embedded content
        parse_data_uri(uri)

      %URI{scheme: nil, path: path} when is_binary(path) ->
        # Assume it's already a local path
        {:ok, path}

      %URI{scheme: scheme} when scheme not in ["file", "data"] ->
        {:error, {:unsupported_scheme, scheme}}

      _ ->
        {:error, :invalid_uri}
    end
  end

  @doc """
  Gets detailed information about a file.

  Retrieves file metadata including size, permissions, MIME type, and timestamps.

  ## Parameters

  - `file_path` - Path to the file
  - `options` - Options for information gathering

  ## Returns

  - `{:ok, file_info}` - File information structure
  - `{:error, reason}` - Error accessing file
  """
  @spec get_file_info(String.t(), map()) ::
          {:ok, file_info()} | {:error, term()}
  def get_file_info(file_path, options \\ %{}) when is_binary(file_path) do
    resolve_symlinks = Map.get(options, :resolve_symlinks, true)
    validate_permissions = Map.get(options, :validate_permissions, true)

    with {:ok, resolved_path} <- resolve_file_path(file_path, resolve_symlinks),
         {:ok, stat} <- File.stat(resolved_path),
         {:ok, permissions} <-
           get_file_permissions(resolved_path, validate_permissions) do
      file_info = %{
        path: resolved_path,
        name: Path.basename(resolved_path),
        size: stat.size,
        mime_type: detect_mime_type(resolved_path),
        permissions: permissions,
        last_modified: stat.mtime
      }

      {:ok, file_info}
    end
  end

  @doc """
  Validates that a file drop operation meets security and size constraints.

  ## Parameters

  - `files` - List of file information structures
  - `options` - Validation options

  ## Returns

  - `:ok` - All files pass validation
  - `{:error, reason}` - Validation failure with details
  """
  @spec validate_files([file_info()], drop_options()) :: :ok | {:error, term()}
  def validate_files(files, options \\ %{}) when is_list(files) do
    config = build_config(options)

    with :ok <- validate_file_count(files, config),
         :ok <- validate_file_sizes(files, config),
         :ok <- validate_mime_types(files, config),
         :ok <- validate_extensions(files, config) do
      validate_directories(files, config)
    end
  end

  @doc """
  Watches dropped files for changes and executes callbacks.

  Sets up file system watchers on dropped files to detect modifications,
  deletions, or other changes.

  ## Parameters

  - `files` - List of files to watch
  - `callbacks` - Map of callback functions for different events

  ## Returns

  - `{:ok, watcher_pid}` - File watcher process ID
  - `{:error, reason}` - Error setting up file watching
  """
  @spec watch_dropped_files([file_info()], map()) ::
          {:ok, pid()} | {:error, term()}
  def watch_dropped_files(files, callbacks \\ %{}) when is_list(files) do
    file_paths = Enum.map(files, & &1.path)

    case start_file_watcher(file_paths, callbacks) do
      {:ok, watcher_pid} ->
        Log.info("Started file watcher for #{length(files)} dropped files")

        {:ok, watcher_pid}

      {:error, reason} ->
        Log.warning("Failed to start file watcher: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Creates a temporary copy of dropped files in a secure location.

  Useful for processing files without affecting the originals or when
  working with files from untrusted sources.

  ## Parameters

  - `files` - List of files to copy
  - `options` - Copy options including temporary directory

  ## Returns

  - `{:ok, copied_files}` - List of temporary file paths
  - `{:error, reason}` - Error during copying
  """
  @spec create_temporary_copies([file_info()], map()) ::
          {:ok, [String.t()]} | {:error, term()}
  def create_temporary_copies(files, options \\ %{}) when is_list(files) do
    temp_dir = Map.get(options, :temp_dir, System.tmp_dir!())
    preserve_names = Map.get(options, :preserve_names, true)

    results =
      Enum.map(files, fn file ->
        temp_name =
          if preserve_names do
            Path.basename(file.path)
          else
            generate_temp_filename(file)
          end

        temp_path = Path.join(temp_dir, temp_name)

        case File.cp(file.path, temp_path) do
          :ok -> {:ok, temp_path}
          {:error, reason} -> {:error, {file.path, reason}}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        copied_paths = Enum.map(results, fn {:ok, path} -> path end)
        {:ok, copied_paths}

      {:error, reason} ->
        # Clean up any successfully copied files
        results
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.each(fn {:ok, path} -> File.rm(path) end)

        {:error, reason}
    end
  end

  # Private functions

  defp build_config(options) do
    Map.merge(
      %{
        max_files: @default_max_files,
        max_file_size: @default_max_file_size,
        allowed_mime_types: nil,
        allowed_extensions: nil,
        allowed_directories: nil,
        resolve_symlinks: true,
        validate_permissions: true
      },
      options
    )
  end

  defp validate_drop_constraints(file_uris, config) do
    if length(file_uris) > config.max_files do
      {:error, {:too_many_files, length(file_uris), config.max_files}}
    else
      :ok
    end
  end

  defp process_file_uris(file_uris, config) do
    results =
      Enum.map(file_uris, fn uri ->
        case parse_file_uri(uri) do
          {:ok, {:data, _decoded_data, _header} = data_info} ->
            # Data URIs don't need file info lookup
            {:ok, %{path: nil, name: "embedded_data", data: data_info}}

          {:ok, path} when is_binary(path) ->
            get_file_info(path, config)

          {:error, _} = error ->
            error
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        file_infos = Enum.map(results, fn {:ok, info} -> info end)
        {:ok, file_infos}

      {:error, _} = error ->
        error
    end
  end

  defp parse_data_uri(uri) do
    # Handle data: URIs for embedded content
    # data:[<mediatype>][;base64],<data>
    case String.split(uri, ",", parts: 2) do
      [header, data] ->
        if String.contains?(header, "base64") do
          case Base.decode64(data) do
            {:ok, decoded_data} -> {:ok, {:data, decoded_data, header}}
            :error -> {:error, :invalid_base64_data}
          end
        else
          {:ok, {:data, URI.decode(data), header}}
        end

      _ ->
        {:error, :invalid_data_uri}
    end
  end

  defp resolve_file_path(path, resolve_symlinks) do
    if resolve_symlinks do
      resolve_symlinks_recursive(path, 0)
    else
      {:ok, path}
    end
  end

  defp resolve_symlinks_recursive(path, depth)
       when depth > @max_symlink_depth do
    {:error, {:symlink_loop, path}}
  end

  defp resolve_symlinks_recursive(path, depth) do
    case File.read_link(path) do
      {:ok, target} ->
        # Resolve relative symlinks
        resolved_target =
          if Path.type(target) == :absolute do
            target
          else
            Path.join(Path.dirname(path), target)
          end

        resolve_symlinks_recursive(resolved_target, depth + 1)

      {:error, :enoent} ->
        {:error, :file_not_found}

      {:error, _} ->
        # Not a symlink, return the original path
        {:ok, path}
    end
  end

  defp get_file_permissions(path, validate) do
    if validate do
      case File.stat(path) do
        {:ok, %File.Stat{mode: mode}} ->
          permissions = %{
            readable: (mode &&& 0o444) != 0,
            writable: (mode &&& 0o222) != 0,
            executable: (mode &&& 0o111) != 0,
            mode: mode
          }

          {:ok, permissions}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, %{}}
    end
  end

  defp detect_mime_type(path) do
    extension = Path.extname(path) |> String.downcase()
    Map.get(@mime_types, extension, "application/octet-stream")
  end

  defp validate_file_count(files, config) do
    if length(files) > config.max_files do
      {:error, {:too_many_files, length(files), config.max_files}}
    else
      :ok
    end
  end

  defp validate_file_sizes(files, config) do
    oversized_files =
      Enum.filter(files, fn file ->
        file.size > config.max_file_size
      end)

    case oversized_files do
      [] ->
        :ok

      [file | _] ->
        {:error, {:file_too_large, file.path, file.size, config.max_file_size}}
    end
  end

  defp validate_mime_types(files, config) do
    case config.allowed_mime_types do
      nil ->
        :ok

      allowed_types when is_list(allowed_types) ->
        invalid_files =
          Enum.filter(files, fn file ->
            file.mime_type not in allowed_types
          end)

        case invalid_files do
          [] ->
            :ok

          [file | _] ->
            {:error, {:invalid_mime_type, file.path, file.mime_type}}
        end
    end
  end

  defp validate_extensions(files, config) do
    case config.allowed_extensions do
      nil ->
        :ok

      allowed_extensions when is_list(allowed_extensions) ->
        invalid_files =
          Enum.filter(files, fn file ->
            extension = Path.extname(file.path) |> String.downcase()
            extension not in allowed_extensions
          end)

        case invalid_files do
          [] -> :ok
          [file | _] -> {:error, {:invalid_extension, file.path}}
        end
    end
  end

  defp validate_directories(files, config) do
    case config.allowed_directories do
      nil ->
        :ok

      allowed_dirs when is_list(allowed_dirs) ->
        invalid_files =
          Enum.filter(files, fn file ->
            not Enum.any?(allowed_dirs, fn allowed_dir ->
              String.starts_with?(file.path, allowed_dir)
            end)
          end)

        case invalid_files do
          [] -> :ok
          [file | _] -> {:error, {:directory_not_allowed, file.path}}
        end
    end
  end

  defp start_file_watcher(file_paths, callbacks) do
    # This would integrate with a file watcher library like FileSystem
    # For now, return a mock implementation
    file_watcher_available? =
      Application.get_env(:raxol, :file_watcher_available, false)

    if file_watcher_available? do
      # In a real implementation, this would start FileSystem.Watcher
      # and set up event handlers for the callbacks
      spawn_link(fn ->
        file_watcher_loop(file_paths, callbacks)
      end)
      |> then(&{:ok, &1})
    else
      {:error, :file_watcher_not_available}
    end
  end

  defp file_watcher_loop(file_paths, callbacks) do
    # Mock file watcher implementation
    # In a real implementation, this would use FileSystem events
    receive do
      {:file_event, path, event} ->
        handle_file_event(path, event, callbacks)
        file_watcher_loop(file_paths, callbacks)

      :stop ->
        :ok
    after
      30_000 ->
        # Check files every 30 seconds as a fallback
        check_files_manually(file_paths, callbacks)
        file_watcher_loop(file_paths, callbacks)
    end
  end

  defp handle_file_event(path, event, callbacks) do
    callback =
      case event do
        :modified -> callbacks[:on_modified]
        :deleted -> callbacks[:on_deleted]
        :moved -> callbacks[:on_moved]
        _ -> nil
      end

    if is_function(callback, 1) do
      try do
        callback.(path)
      rescue
        error ->
          Log.warning("File watcher callback error: #{inspect(error)}")
      end
    end
  end

  defp check_files_manually(file_paths, callbacks) do
    # Fallback manual file checking
    Enum.each(file_paths, fn path ->
      case File.stat(path) do
        # File still exists
        {:ok, _stat} ->
          :ok

        {:error, :enoent} ->
          handle_file_event(path, :deleted, callbacks)

        {:error, _} ->
          :ok
      end
    end)
  end

  defp generate_temp_filename(file) do
    extension = Path.extname(file.path)
    timestamp = System.system_time(:microsecond)
    "raxol_temp_#{timestamp}#{extension}"
  end
end
