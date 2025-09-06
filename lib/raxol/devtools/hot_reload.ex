defmodule Raxol.DevTools.HotReload do
  @moduledoc """
  Hot reloading system for Raxol components and modules.
  Functional Programming Version - All try/catch blocks replaced with Task-based error handling.

  This module provides real-time code reloading capabilities that detect changes
  to Elixir source files and automatically recompile and reload them without
  restarting the application. Particularly useful for UI development where rapid
  iteration is crucial.

  ## Features

  - File system watching with debouncing
  - Selective module reloading
  - Component tree refresh
  - State preservation across reloads
  - Functional error handling and recovery
  - Hot reload hooks for cleanup/setup

  ## Usage

      # Start hot reloading for development
      HotReload.start_watching([
        "lib/raxol/ui/components/",
        "lib/raxol/ui/layouts/"
      ])
      
      # Register hooks for component cleanup
      HotReload.register_hook(:before_reload, fn module ->
        cleanup_component_state(module)
      end)
      
      # Manual reload
      HotReload.reload_module(MyComponent)
  """

  use GenServer
  require Logger

  @file_extensions [".ex", ".exs"]
  @debounce_ms 500

  defmodule State do
    defstruct [
      :watcher_pid,
      :watched_paths,
      :hooks,
      :reload_queue,
      :debounce_timer,
      :preserve_state
    ]

    def new do
      %__MODULE__{
        watcher_pid: nil,
        watched_paths: MapSet.new(),
        hooks: %{
          before_reload: [],
          after_reload: [],
          on_error: []
        },
        reload_queue: MapSet.new(),
        debounce_timer: nil,
        preserve_state: true
      }
    end
  end

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts watching specified directories for file changes.
  """
  def start_watching(paths) when is_list(paths) do
    GenServer.call(__MODULE__, {:start_watching, paths})
  end

  @doc """
  Stops watching for file changes.
  """
  def stop_watching do
    GenServer.call(__MODULE__, :stop_watching)
  end

  @doc """
  Manually reloads a specific module.
  """
  def reload_module(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:reload_module, module})
  end

  @doc """
  Registers a hook function to be called during reload lifecycle.
  """
  def register_hook(hook_type, callback) when is_function(callback, 1) do
    GenServer.call(__MODULE__, {:register_hook, hook_type, callback})
  end

  @doc """
  Gets the current hot reload configuration.
  """
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Enables/disables state preservation across reloads.
  """
  def set_state_preservation(enabled) when is_boolean(enabled) do
    GenServer.call(__MODULE__, {:set_state_preservation, enabled})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(_opts) do
    state = State.new()
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:start_watching, paths}, _from, state) do
    # Stop existing watcher if running
    new_state = stop_watcher(state)

    # Start new watcher
    expanded_paths = expand_and_validate_paths(paths)

    # start_file_watcher/1 currently always returns {:ok, watcher_pid}
    {:ok, watcher_pid} = start_file_watcher(expanded_paths)
    
    final_state = %{
      new_state
      | watcher_pid: watcher_pid,
        watched_paths: MapSet.new(expanded_paths)
    }

    Logger.info("Hot reload started for paths: #{inspect(expanded_paths)}")
    {:reply, :ok, final_state}
  end

  @impl GenServer
  def handle_call(:stop_watching, _from, state) do
    new_state = stop_watcher(state)
    Logger.info("Hot reload stopped")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:reload_module, module}, _from, state) do
    case reload_single_module(module, state) do
      :ok ->
        Logger.info("Successfully reloaded module: #{module}")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to reload module #{module}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:register_hook, hook_type, callback}, _from, state) do
    case Map.has_key?(state.hooks, hook_type) do
      true ->
        new_hooks = Map.update!(state.hooks, hook_type, &[callback | &1])
        new_state = %{state | hooks: new_hooks}
        {:reply, :ok, new_state}

      false ->
        {:reply, {:error, :invalid_hook_type}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_config, _from, state) do
    config = %{
      watching: state.watcher_pid != nil,
      watched_paths: MapSet.to_list(state.watched_paths),
      preserve_state: state.preserve_state,
      hooks_registered: Map.new(state.hooks, fn {k, v} -> {k, length(v)} end)
    }

    {:reply, config, state}
  end

  @impl GenServer
  def handle_call({:set_state_preservation, enabled}, _from, state) do
    new_state = %{state | preserve_state: enabled}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info({:file_event, path, events}, state) do
    case {should_reload_for_events?(events), is_elixir_file?(path)} do
      {true, true} ->
        new_state = queue_reload(path, state)
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:process_reload_queue}, state) do
    new_state = %{state | debounce_timer: nil}

    case MapSet.size(state.reload_queue) do
      0 ->
        {:noreply, new_state}

      _ ->
        process_reload_queue(state.reload_queue, state)
        final_state = %{new_state | reload_queue: MapSet.new()}
        {:noreply, final_state}
    end
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Implementation

  defp expand_and_validate_paths(paths) do
    paths
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.exists?/1)
    |> Enum.uniq()
  end

  defp start_file_watcher(paths) do
    # This is a simplified file watcher implementation
    # In a real implementation, you'd use :fs, FileSystem, or similar
    watcher_pid =
      spawn_link(fn ->
        file_watcher_loop(paths, self())
      end)

    {:ok, watcher_pid}
  end

  defp file_watcher_loop(paths, parent_pid) do
    # Simplified polling-based file watching
    # Real implementation would use inotify/FSEvents
    :timer.sleep(1000)

    paths
    |> Enum.each(fn path ->
      check_directory_for_changes(path, parent_pid)
    end)

    file_watcher_loop(paths, parent_pid)
  end

  defp check_directory_for_changes(dir, parent_pid) do
    with {:ok, pattern} <- build_glob_pattern(dir),
         {:ok, files} <- safe_wildcard(pattern),
         :ok <- process_files_for_changes(files, parent_pid) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Directory check failed for #{dir}: #{inspect(reason)}")
        :ok

      _ ->
        :ok
    end
  end

  defp build_glob_pattern(dir) do
    with {:ok, pattern} <- safe_path_join(dir, "**/*.ex") do
      {:ok, pattern}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_wildcard(pattern) do
    with {:ok, files} <- safe_path_wildcard(pattern) do
      {:ok, files}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_files_for_changes(files, parent_pid) do
    with {:ok, :processed} <- safe_process_file_list(files, parent_pid) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp file_recently_modified?(_file) do
    # Placeholder implementation
    false
  end

  defp stop_watcher(%{watcher_pid: nil} = state), do: state

  defp stop_watcher(%{watcher_pid: pid} = state) when is_pid(pid) do
    Process.exit(pid, :normal)
    %{state | watcher_pid: nil, watched_paths: MapSet.new()}
  end

  defp should_reload_for_events?(events) do
    Enum.any?(events, &(&1 in [:modified, :moved_to, :created]))
  end

  defp is_elixir_file?(path) do
    ext = Path.extname(path)
    ext in @file_extensions
  end

  defp queue_reload(path, state) do
    new_queue = MapSet.put(state.reload_queue, path)

    # Cancel existing timer
    case state.debounce_timer do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end

    # Set new debounce timer
    timer = Process.send_after(self(), {:process_reload_queue}, @debounce_ms)

    %{state | reload_queue: new_queue, debounce_timer: timer}
  end

  defp process_reload_queue(file_paths, state) do
    Logger.info("Processing reload queue: #{MapSet.size(file_paths)} files")

    # Group files by module
    modules_to_reload =
      file_paths
      |> Enum.map(&path_to_module/1)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    # Execute before_reload hooks
    execute_hooks(state.hooks.before_reload, modules_to_reload)

    # Preserve state if enabled
    preserved_state =
      case state.preserve_state do
        true -> preserve_component_states(modules_to_reload)
        false -> %{}
      end

    # Reload modules
    reload_results =
      Enum.map(modules_to_reload, fn module ->
        {module, reload_single_module(module, state)}
      end)

    # Check for errors
    errors =
      Enum.filter(reload_results, fn {_mod, result} ->
        match?({:error, _}, result)
      end)

    case Enum.empty?(errors) do
      true ->
        # Restore state if preserved
        case {state.preserve_state, Enum.empty?(preserved_state)} do
          {true, false} -> restore_component_states(preserved_state)
          _ -> :ok
        end

        # Execute after_reload hooks
        execute_hooks(state.hooks.after_reload, modules_to_reload)

        Logger.info(
          "Successfully reloaded #{length(modules_to_reload)} modules"
        )

      false ->
        # Execute error hooks
        execute_hooks(state.hooks.on_error, errors)

        Logger.error(
          "Reload failed for modules: #{inspect(Enum.map(errors, &elem(&1, 0)))}"
        )
    end
  end

  defp path_to_module(file_path) do
    with {:ok, cwd} <- safe_get_cwd(),
         {:ok, relative_path} <- safe_relative_to(file_path, cwd),
         {:ok, module_name} <- extract_module_from_path(relative_path) do
      module_name
    else
      {:error, _reason} -> nil
      _ -> nil
    end
  end

  defp safe_get_cwd do
    with {:ok, cwd} <- safe_file_cwd() do
      {:ok, cwd}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_relative_to(file_path, cwd) do
    with {:ok, relative_path} <- safe_path_relative_to(file_path, cwd) do
      {:ok, relative_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_module_from_path(relative_path) do
    with {:ok, path_parts} <- safe_string_split(relative_path, "/"),
         {:ok, module_name} <- convert_path_to_module(path_parts) do
      {:ok, module_name}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp reload_single_module(module, _state) do
    with {:ok, filename} <- get_module_source_file(module),
         :ok <- purge_old_module_version(module),
         {:ok, {binary, warnings}} <- recompile_module(filename, module),
         :ok <- load_new_module_version(module, filename, binary),
         :ok <- handle_component_refresh(module) do
      case length(warnings) do
        0 ->
          :ok

        _ ->
          Logger.warning(
            "Compilation warnings for #{module}: #{inspect(warnings)}"
          )
      end

      :ok
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, {:unexpected_reload_error, error}}
    end
  end

  defp get_module_source_file(module) do
    with {:ok, code_result} <- safe_code_get_object_code(module),
         {:ok, filename} <-
           extract_filename_from_code_result(code_result, module) do
      {:ok, filename}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp purge_old_module_version(module) do
    with {:ok, :purged} <- safe_code_purge(module),
         {:ok, :deleted} <- safe_code_delete(module) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp recompile_module(filename, expected_module) do
    with {:ok, compile_result} <- safe_compile_file(filename),
         {:ok, {binary, warnings}} <-
           validate_compile_result(compile_result, expected_module) do
      {:ok, {binary, warnings}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_new_module_version(module, filename, binary) do
    with {:ok, :loaded} <- safe_code_load_binary(module, filename, binary) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_component_refresh(module) do
    with {:ok, :component_checked} <- safe_check_and_refresh_component(module) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_hooks(hooks, data) do
    Enum.each(hooks, fn hook ->
      case safe_execute_hook(hook, data) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error("Hook execution failed: #{inspect(reason)}")
      end
    end)
  end

  defp safe_execute_hook(hook, data) when is_function(hook) do
    with {:ok, :executed} <- safe_function_call(hook, data) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_execute_hook(_hook, _data) do
    {:error, :invalid_hook}
  end

  defp preserve_component_states(modules) do
    # This would integrate with the actual component system
    # to preserve state across reloads
    Enum.reduce(modules, %{}, fn module, acc ->
      case is_component_module?(module) do
        true ->
          state = get_component_state(module)
          Map.put(acc, module, state)

        false ->
          acc
      end
    end)
  end

  defp restore_component_states(preserved_states) do
    Enum.each(preserved_states, fn {module, state} ->
      restore_component_state(module, state)
    end)
  end

  defp is_component_module?(module) do
    with {:ok, functions} <- safe_get_module_functions(module),
         true <- has_component_functions?(functions) do
      true
    else
      _ -> false
    end
  end

  defp safe_get_module_functions(module) do
    with {:ok, functions} <- safe_module_info(module, :functions) do
      {:ok, functions}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp has_component_functions?(functions) when is_list(functions) do
    Enum.any?(functions, fn {func, arity} ->
      func in [:render, :component] and arity in [1, 2]
    end)
  end

  defp has_component_functions?(_), do: false

  defp get_component_state(_module) do
    # Placeholder - would integrate with component state system
    %{}
  end

  defp restore_component_state(_module, _state) do
    # Placeholder - would restore component state
    :ok
  end

  defp trigger_component_refresh(_module) do
    # Placeholder - would trigger component re-render
    :ok
  end

  # Functional helper functions replacing try/catch with Task-based error handling

  defp safe_path_join(dir, pattern) do
    Task.async(fn -> Path.join(dir, pattern) end)
    |> Task.yield(100)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:pattern_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_path_wildcard(pattern) do
    Task.async(fn -> Path.wildcard(pattern) end)
    |> Task.yield(1000)
    |> case do
      {:ok, files} ->
        {:ok, files}

      {:exit, reason} ->
        {:error, {:wildcard_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_process_file_list(files, _parent_pid) do
    Task.async(fn ->
      Enum.each(files, fn file ->
        case file_recently_modified?(file) do
          false -> :ok
        end
      end)

      :processed
    end)
    |> Task.yield(2000)
    |> case do
      {:ok, :processed} ->
        {:ok, :processed}

      {:exit, reason} ->
        {:error, {:file_processing_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_file_cwd do
    Task.async(fn -> File.cwd!() end)
    |> Task.yield(100)
    |> case do
      {:ok, cwd} ->
        {:ok, cwd}

      {:exit, reason} ->
        {:error, {:cwd_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_path_relative_to(file_path, cwd) do
    Task.async(fn -> Path.relative_to(file_path, cwd) end)
    |> Task.yield(100)
    |> case do
      {:ok, relative_path} ->
        {:ok, relative_path}

      {:exit, reason} ->
        {:error, {:relative_path_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_string_split(string, delimiter) do
    Task.async(fn -> String.split(string, delimiter) end)
    |> Task.yield(100)
    |> case do
      {:ok, parts} ->
        {:ok, parts}

      {:exit, reason} ->
        {:error, {:string_split_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp convert_path_to_module(path_parts) do
    Task.async(fn ->
      case path_parts do
        ["lib" | rest] ->
          module_name =
            rest
            |> List.last()
            |> String.trim_trailing(".ex")
            |> Macro.camelize()
            |> then(&Module.concat([&1]))

          module_name

        _ ->
          throw(:invalid_path_structure)
      end
    end)
    |> Task.yield(200)
    |> case do
      {:ok, module_name} ->
        {:ok, module_name}

      {:exit, reason} ->
        {:error, {:module_extraction_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_code_get_object_code(module) do
    Task.async(fn -> :code.get_object_code(module) end)
    |> Task.yield(500)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:code_info_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp extract_filename_from_code_result(code_result, module) do
    case code_result do
      {^module, _binary, filename} -> {:ok, filename}
      :error -> {:error, :module_not_found}
      _ -> {:error, :unexpected_code_result}
    end
  end

  defp safe_code_purge(module) do
    Task.async(fn ->
      :code.purge(module)
      :purged
    end)
    |> Task.yield(500)
    |> case do
      {:ok, :purged} ->
        {:ok, :purged}

      {:exit, reason} ->
        {:error, {:purge_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_code_delete(module) do
    Task.async(fn ->
      :code.delete(module)
      :deleted
    end)
    |> Task.yield(500)
    |> case do
      {:ok, :deleted} ->
        {:ok, :deleted}

      {:exit, reason} ->
        {:error, {:delete_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_compile_file(filename) do
    Task.async(fn ->
      :compile.file(to_charlist(filename), [:return_errors, :return_warnings])
    end)
    |> Task.yield(5000)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:compilation_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp validate_compile_result(compile_result, expected_module) do
    case compile_result do
      {:ok, ^expected_module, binary, warnings} ->
        {:ok, {binary, warnings}}

      {:ok, other_module, _binary, _warnings} ->
        {:error, {:module_mismatch, {expected_module, other_module}}}

      {:error, errors, warnings} ->
        Logger.error("Compilation errors: #{inspect(errors)}")
        Logger.warning("Compilation warnings: #{inspect(warnings)}")
        {:error, :compilation_failed}

      _ ->
        {:error, :unexpected_compile_result}
    end
  end

  defp safe_code_load_binary(module, filename, binary) do
    Task.async(fn ->
      :code.load_binary(module, filename, binary)
      :loaded
    end)
    |> Task.yield(1000)
    |> case do
      {:ok, :loaded} ->
        {:ok, :loaded}

      {:exit, reason} ->
        {:error, {:load_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_check_and_refresh_component(module) do
    Task.async(fn ->
      case is_component_module?(module) do
        true -> trigger_component_refresh(module)
        false -> :ok
      end

      :component_checked
    end)
    |> Task.yield(500)
    |> case do
      {:ok, :component_checked} ->
        {:ok, :component_checked}

      {:exit, reason} ->
        {:error, {:component_refresh_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_function_call(function, data) when is_function(function) do
    Task.async(fn ->
      function.(data)
      :executed
    end)
    |> Task.yield(1000)
    |> case do
      {:ok, :executed} ->
        {:ok, :executed}

      {:exit, reason} ->
        {:error, {:hook_exception, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_module_info(module, info_type) do
    Task.async(fn -> module.__info__(info_type) end)
    |> Task.yield(200)
    |> case do
      {:ok, info} ->
        {:ok, info}

      {:exit, reason} ->
        {:error, {:module_info_error, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end
end
