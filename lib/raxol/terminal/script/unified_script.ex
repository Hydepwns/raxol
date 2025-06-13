defmodule Raxol.Terminal.Script.UnifiedScript do
  @moduledoc """
  Unified scripting system for the Raxol terminal emulator.
  Handles script execution, management, and integration with the terminal.
  """

  use GenServer
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
  @impl true
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

  @impl true
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

  @impl true
  def handle_call({:unload_script, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      _script ->
        new_state = update_in(state.scripts, &Map.delete(&1, script_id))
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_script_state, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        {:reply, {:ok, script}, state}
    end
  end

  @impl true
  def handle_call({:update_script_config, script_id, config}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        new_script = update_in(script.config, &Map.merge(&1, config))
        new_state = put_in(state.scripts[script_id], new_script)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:execute_script, script_id, args}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        case execute_script(script, args, state.script_timeout) do
          {:ok, result} ->
            new_script = %{script | status: :running, output: [result | script.output]}
            new_state = put_in(state.scripts[script_id], new_script)
            {:reply, {:ok, result}, new_state}

          {:error, reason} ->
            new_script = %{script | status: :error, error: reason}
            new_state = put_in(state.scripts[script_id], new_script)
            {:reply, {:error, reason}, new_state}
        end
    end
  end

  @impl true
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

  @impl true
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

  @impl true
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

  @impl true
  def handle_call({:get_script_output, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:reply, {:error, :script_not_found}, state}

      script ->
        {:reply, {:ok, script.output}, state}
    end
  end

  @impl true
  def handle_call({:get_scripts, opts}, _from, state) do
    scripts = filter_scripts(state.scripts, opts)
    {:reply, {:ok, scripts}, state}
  end

  @impl true
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

  @impl true
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
    with :ok <- validate_script_type(script.type),
         :ok <- validate_script_source(script.source),
         :ok <- validate_script_config(script.config) do
      :ok
    end
  end

  defp validate_script_type(type) when type in [:lua, :python, :javascript, :elixir], do: :ok
  defp validate_script_type(_), do: {:error, :invalid_script_type}

  defp validate_script_source(source) when is_binary(source) and byte_size(source) > 0, do: :ok
  defp validate_script_source(_), do: {:error, :invalid_script_source}

  defp validate_script_config(config) when is_map(config), do: :ok
  defp validate_script_config(_), do: {:error, :invalid_script_config}

  defp execute_script(_script, args, _timeout) do
    # TODO: Implement actual script execution based on type
    # This is a placeholder that simulates script execution
    Process.sleep(100)
    {:ok, "Script executed with args: #{inspect(args)}"}
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
    # TODO: Implement actual script export
    # This is a placeholder that simulates script export
    {:ok, _} = File.write(path, script.source)
    :ok
  end

  defp import_script_from_file(path, opts) do
    # TODO: Implement actual script import
    # This is a placeholder that simulates script import
    case File.read(path) do
      {:ok, source} ->
        {:ok, load_script_state(source, :elixir, opts)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_scripts_from_paths(_paths) do
    # TODO: Implement actual script loading from paths
    # This is a placeholder that simulates script loading
    :ok
  end
end
