defmodule Raxol.Terminal.Script.UnifiedScript do
  @moduledoc """
  Unified scripting system for the Raxol terminal emulator.
  Handles script execution, management, and integration with the terminal.
  """

  use GenServer
  import Raxol.Guards
  require Logger

  # Types
  @type script_id :: String.t()
  @type script_type :: :lua | :python | :javascript | :elixir
  @type script_state :: %{
          id: script_id,
          name: String.t(),
          type: script_type,
          source: String.t(),
          config: map(),
          status: :idle | :running | :paused | :error,
          error: String.t() | nil,
          output: [String.t()],
          metadata: map()
        }

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Loads a script from a file or string source.
  """
  def load_script(source, type, opts \\ []) do
    GenServer.call(__MODULE__, {:load_script, source, type, opts})
  end

  @doc """
  Unloads a script by its ID.
  """
  def unload_script(script_id) do
    GenServer.call(__MODULE__, {:unload_script, script_id})
  end

  @doc """
  Gets the state of a script.
  """
  def get_script_state(script_id) do
    GenServer.call(__MODULE__, {:get_script_state, script_id})
  end

  @doc """
  Updates a script's configuration.
  """
  def update_script_config(script_id, config) do
    GenServer.call(__MODULE__, {:update_script_config, script_id, config})
  end

  @doc """
  Executes a script with optional arguments.
  """
  def execute_script(script_id, args \\ []) do
    GenServer.call(__MODULE__, {:execute_script, script_id, args})
  end

  @doc """
  Pauses a running script.
  """
  def pause_script(script_id) do
    GenServer.call(__MODULE__, {:pause_script, script_id})
  end

  @doc """
  Resumes a paused script.
  """
  def resume_script(script_id) do
    GenServer.call(__MODULE__, {:resume_script, script_id})
  end

  @doc """
  Stops a running script.
  """
  def stop_script(script_id) do
    GenServer.call(__MODULE__, {:stop_script, script_id})
  end

  @doc """
  Gets the output of a script.
  """
  def get_script_output(script_id) do
    GenServer.call(__MODULE__, {:get_script_output, script_id})
  end

  @doc """
  Gets all loaded scripts.
  """
  def get_scripts(opts \\ []) do
    GenServer.call(__MODULE__, {:get_scripts, opts})
  end

  @doc """
  Exports a script to a file.
  """
  def export_script(script_id, path) do
    GenServer.call(__MODULE__, {:export_script, script_id, path})
  end

  @doc """
  Imports a script from a file.
  """
  def import_script(path, opts \\ []) do
    GenServer.call(__MODULE__, {:import_script, path, opts})
  end

  # Server Callbacks
  def init(opts) do
    state = %{
      scripts: %{},
      script_paths: Keyword.get(opts, :script_paths, ["scripts"]),
      auto_load: Keyword.get(opts, :auto_load, false),
      max_scripts: Keyword.get(opts, :max_scripts, 100),
      script_timeout: Keyword.get(opts, :script_timeout, 30_000)
    }

    if state.auto_load do
      load_scripts_from_paths(state.script_paths)
    end

    {:ok, state}
  end

  def handle_call({:load_script, source, type, opts}, _from, state) do
    script_id = generate_script_id()
    script_state = load_script_state(source, type, opts)

    case validate_script(script_state) do
      :ok ->
        new_state = put_in(state.scripts[script_id], script_state)
        {:reply, {:ok, script_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unload_script, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      _script ->
        new_state = update_in(state.scripts, &Map.delete(&1, script_id))
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_script_state, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        {:reply, {:ok, script}, state}
    end
  end

  def handle_call({:update_script_config, script_id, config}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        if is_map(config) do
          config_map = config
          script_config = if is_map(script.config), do: script.config, else: %{}
          new_script = %{script | config: Map.merge(script_config, config_map)}
          new_state = put_in(state.scripts[script_id], new_script)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :invalid_script_config}, state}
        end
    end
  end

  def handle_call({:execute_script, script_id, args}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        case do_execute_script(script, args, state.script_timeout) do
          {:ok, result} ->
            new_script = %{
              script
              | status: :running,
                output: [result | script.output]
            }

            new_state = put_in(state.scripts[script_id], new_script)
            {:reply, {:ok, result}, new_state}

          {:error, reason} ->
            new_script = %{script | status: :error, error: reason}
            new_state = put_in(state.scripts[script_id], new_script)
            {:reply, {:error, reason}, new_state}
        end
    end
  end

  def handle_call({:pause_script, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        if script.status == :running do
          new_script = %{script | status: :paused}
          new_state = put_in(state.scripts[script_id], new_script)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :invalid_script_state}, state}
        end
    end
  end

  def handle_call({:resume_script, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        if script.status == :paused do
          new_script = %{script | status: :running}
          new_state = put_in(state.scripts[script_id], new_script)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :invalid_script_state}, state}
        end
    end
  end

  def handle_call({:stop_script, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        if script.status in [:running, :paused] do
          new_script = %{script | status: :idle}
          new_state = put_in(state.scripts[script_id], new_script)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :invalid_script_state}, state}
        end
    end
  end

  def handle_call({:get_script_output, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      %{output: [latest | _]} ->
        # If latest is a string and output is a single string, return it directly
        if is_binary(latest) and length([latest | []]) == 1 do
          {:reply, {:ok, latest}, state}
        else
          {:reply, {:ok, [latest | []]}, state}
        end

      %{output: []} ->
        {:reply, {:ok, ""}, state}

      _ ->
        {:reply, {:ok, ""}, state}
    end
  end

  def handle_call({:get_scripts, opts}, _from, state) do
    scripts = filter_scripts(state.scripts, opts)
    {:reply, {:ok, scripts}, state}
  end

  def handle_call({:export_script, script_id, path}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        case export_script_to_file(script, path) do
          :ok ->
            {:reply, :ok, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:import_script, path, opts}, _from, state) do
    case import_script_from_file(path, opts) do
      {:ok, script} ->
        script_id = generate_script_id()
        new_state = put_in(state.scripts[script_id], script)
        {:reply, {:ok, script_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Functions
  defp generate_script_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> binary_part(0, 8)
  end

  defp load_script_state(source, type, opts) do
    %{
      id: nil,
      name: Keyword.get(opts, :name, "Unnamed Script"),
      type: type,
      source: source,
      config: Keyword.get(opts, :config, %{}),
      status: :idle,
      error: nil,
      output: [],
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp validate_script(script) do
    case validate_script_type(script.type) do
      :ok ->
        case validate_script_source(script.source) do
          :ok ->
            validate_script_config(script.config)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_script_type(type)
       when type in [:lua, :python, :javascript, :elixir],
       do: :ok

  defp validate_script_type(_), do: {:error, :invalid_script_type}

  defp validate_script_source(source)
       when binary?(source) and byte_size(source) > 0,
       do: :ok

  defp validate_script_source(_), do: {:error, :invalid_script_source}

  defp validate_script_config(config) when map?(config), do: :ok
  defp validate_script_config(_), do: {:error, :invalid_script_config}

  defp do_execute_script(script, args, timeout) do
    try do
      case script.type do
        :elixir -> execute_elixir_script(script, args, timeout)
        :lua -> execute_lua_script(script, args, timeout)
        :python -> execute_python_script(script, args, timeout)
        :javascript -> execute_javascript_script(script, args, timeout)
      end
    rescue
      e ->
        Logger.error("Script execution failed: #{inspect(e)}")
        {:error, :execution_failed}
    end
  end

  defp execute_elixir_script(script, args, timeout) do
    # Wrap Elixir code in a module to handle def/2 properly
    module_name = "ScriptModule_#{generate_script_id()}"

    wrapped_code = """
    defmodule #{module_name} do
      #{script.source}
    end
    """

    try do
      # Compile and load the module, get the module atom from the result
      [{mod, _bin}] = Code.compile_string(wrapped_code)

      # Always call main/arity
      if function_exported?(mod, :main, length(args)) do
        result = apply(mod, :main, args)
        if is_binary(result), do: {:ok, result}, else: {:ok, inspect(result)}
      else
        {:ok, "Elixir script executed successfully"}
      end
    rescue
      e ->
        Logger.error("Script execution failed: #{inspect(e)}")
        {:error, :execution_failed}
    end
  end

  defp execute_lua_script(script, args, timeout) do
    # Execute Lua script using Port or external Lua interpreter
    case execute_external_script("lua", script.source, args, timeout) do
      {:ok, output} -> {:ok, output}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_python_script(script, args, timeout) do
    # Execute Python script using Port or external Python interpreter
    case execute_external_script("python3", script.source, args, timeout) do
      {:ok, output} -> {:ok, output}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_javascript_script(script, args, timeout) do
    # Execute JavaScript using Node.js
    case execute_external_script("node", script.source, args, timeout) do
      {:ok, output} -> {:ok, output}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_external_script(interpreter, source, args, timeout) do
    # Create temporary file for script
    temp_file =
      Path.join(
        System.tmp_dir!(),
        "raxol_script_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
      )

    try do
      # Write script to temporary file
      File.write!(temp_file, source)

      # Execute script with arguments
      cmd = [interpreter, temp_file] ++ args

      case System.cmd(interpreter, cmd,
             timeout: timeout,
             stderr_to_stdout: true
           ) do
        {output, 0} -> {:ok, String.trim(output)}
        {error_output, _exit_code} -> {:error, String.trim(error_output)}
      end
    rescue
      e -> {:error, "Failed to execute script: #{inspect(e)}"}
    after
      # Clean up temporary file
      File.rm(temp_file)
    end
  end

  defp filter_scripts(scripts, opts) do
    scripts
    |> Enum.filter(fn {_id, script} ->
      Enum.all?(opts, fn
        {:type, type} -> script.type == type
        {:status, status} -> script.status == status
        _ -> true
      end)
    end)
    |> Map.new()
  end

  defp export_script_to_file(script, path) do
    try do
      # Create directory if it doesn't exist
      File.mkdir_p!(Path.dirname(path))

      # Determine file extension based on script type
      extension = get_script_extension(script.type)

      script_path =
        if Path.extname(path) == "", do: path <> extension, else: path

      # Write script source
      File.write!(script_path, script.source)

      # Create metadata file
      metadata_path = script_path <> ".json"

      metadata = %{
        "name" => script.name,
        "type" => Atom.to_string(script.type),
        "config" => script.config,
        "metadata" => script.metadata,
        "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      File.write!(metadata_path, Jason.encode!(metadata, pretty: true))

      :ok
    rescue
      e ->
        Logger.error("Script export failed: #{inspect(e)}")
        {:error, :export_failed}
    end
  end

  defp get_script_extension(type) do
    case type do
      :elixir -> ".exs"
      :lua -> ".lua"
      :python -> ".py"
      :javascript -> ".js"
      _ -> ".txt"
    end
  end

  defp import_script_from_file(path, opts) do
    try do
      # Check if path is a directory or file
      case File.stat(path) do
        {:ok, %{type: :directory}} ->
          import_script_from_directory(path, opts)

        {:ok, %{type: :regular}} ->
          import_script_from_single_file(path, opts)

        _ ->
          {:error, :invalid_path}
      end
    rescue
      e ->
        Logger.error("Script import failed: #{inspect(e)}")
        {:error, :import_failed}
    end
  end

  defp import_script_from_directory(path, opts) do
    case File.ls(path) do
      {:ok, files} ->
        case find_script_file(files) do
          {:ok, script_file} ->
            load_script_with_metadata(path, script_file, opts)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_script_file(files) do
    script_files = Enum.filter(files, &script_file?/1)

    case script_files do
      [script_file | _] -> {:ok, script_file}
      [] -> {:error, :no_script_files}
    end
  end

  defp load_script_with_metadata(path, script_file, opts) do
    script_path = Path.join(path, script_file)
    metadata_path = Path.join(path, script_file <> ".json")

    with {:ok, source} <- File.read(script_path) do
      metadata = load_script_metadata(metadata_path)
      type = determine_script_type(metadata, script_file)
      merged_opts = merge_metadata_with_opts(metadata, opts)
      {:ok, load_script_state(source, type, merged_opts)}
    end
  end

  defp determine_script_type(metadata, script_file) do
    type = metadata["type"] || infer_script_type(script_file)
    String.to_existing_atom(type)
  end

  defp merge_metadata_with_opts(metadata, opts) do
    metadata_opts =
      [
        name: metadata["name"],
        config: metadata["config"] || %{},
        metadata: metadata["metadata"] || %{}
      ]
      |> Enum.reject(fn {_key, value} -> nil?(value) end)

    Keyword.merge(opts, metadata_opts)
  end

  defp import_script_from_single_file(path, opts) do
    case File.read(path) do
      {:ok, source} ->
        # Determine script type from file extension
        type = infer_script_type(path)
        {:ok, load_script_state(source, type, opts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp script_file?(filename) do
    String.ends_with?(filename, [".exs", ".lua", ".py", ".js", ".txt"])
  end

  defp load_script_metadata(metadata_path) do
    case File.read(metadata_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, metadata} -> metadata
          {:error, _} -> %{}
        end

      {:error, _} ->
        %{}
    end
  end

  defp infer_script_type(filename) do
    case Path.extname(filename) do
      ".exs" -> :elixir
      ".lua" -> :lua
      ".py" -> :python
      ".js" -> :javascript
      _ -> :elixir
    end
  end

  defp load_scripts_from_paths(paths) do
    Enum.each(paths, fn path ->
      case File.stat(path) do
        {:ok, %{type: :directory}} ->
          load_scripts_from_directory(path)

        {:ok, %{type: :regular}} ->
          load_script_from_single_file(path)

        _ ->
          Logger.warning("Invalid script path: #{path}")
      end
    end)
  end

  defp load_scripts_from_directory(path) do
    case File.ls(path) do
      {:ok, entries} ->
        Enum.each(entries, &process_directory_entry(path, &1))

      {:error, reason} ->
        Logger.error("Failed to list directory #{path}: #{inspect(reason)}")
    end
  end

  defp process_directory_entry(base_path, entry) do
    entry_path = Path.join(base_path, entry)

    case File.stat(entry_path) do
      {:ok, %{type: :directory}} ->
        load_scripts_from_directory(entry_path)

      {:ok, %{type: :regular}} ->
        load_script_from_single_file(entry_path)

      _ ->
        :ok
    end
  end

  defp load_script_from_single_file(path) do
    if script_file?(Path.basename(path)) do
      case import_script_from_file(path, []) do
        {:ok, script} ->
          script_id = generate_script_id()

          # Store in process dictionary for now, could be enhanced to use GenServer state
          Process.put({:loaded_script, script_id}, script)
          Logger.info("Loaded script: #{script.name} from #{path}")

        {:error, reason} ->
          Logger.error("Failed to load script from #{path}: #{inspect(reason)}")
      end
    end
  end
end
