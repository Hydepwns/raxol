defmodule Raxol.Runtime do
  @moduledoc """
  The Runtime module manages application lifecycle and event processing.
  
  This module provides the core functionality for running Raxol applications,
  handling the event loop, and managing application state. It is responsible for:
  
  - Starting and stopping applications
  - Managing the event loop
  - Handling user input
  - Coordinating rendering
  - Managing application state
  """
  
  use GenServer
  
  alias Raxol.Renderer
  alias Raxol.Event
  
  @registry Raxol.Registry
  
  # Client API
  
  @doc """
  Starts a Raxol application with the given module and options.
  
  ## Options
    * `:title` - The window title (default: "Raxol Application")
    * `:fps` - Frames per second (default: 60)
    * `:quit_keys` - List of keys that will quit the application (default: [:ctrl_c])
    * `:debug` - Enable debug mode (default: false)
  """
  def run(app_module, options \\ []) do
    app_name = get_app_name(app_module)
    
    case DynamicSupervisor.start_child(
      Raxol.DynamicSupervisor,
      {__MODULE__, {app_module, app_name, options}}
    ) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Sends a message to the running application.
  
  Returns `:ok` if the message was sent successfully,
  `{:error, :app_not_running}` if the application is not running.
  """
  def send_msg(msg, app_name \\ :default) do
    case lookup_app(app_name) do
      {:ok, pid} -> 
        GenServer.cast(pid, {:msg, msg})
        :ok
      :error -> 
        {:error, :app_not_running}
    end
  end
  
  @doc """
  Stops the running application.
  
  Returns `:ok` if the application was stopped successfully,
  `{:error, :app_not_running}` if the application is not running.
  """
  def stop(app_name \\ :default) do
    case lookup_app(app_name) do
      {:ok, pid} -> 
        GenServer.cast(pid, :stop)
        :ok
      :error -> 
        {:error, :app_not_running}
    end
  end
  
  # Server callbacks
  
  def start_link({app_module, app_name, options}) do
    GenServer.start_link(__MODULE__, {app_module, options}, name: via_tuple(app_name))
  end
  
  @impl true
  def init({app_module, options}) do
    # Extract options with defaults
    title = Keyword.get(options, :title, "Raxol Application")
    fps = Keyword.get(options, :fps, 60)
    quit_keys = Keyword.get(options, :quit_keys, [:ctrl_c])
    debug = Keyword.get(options, :debug, false)
    
    # Initialize termbox
    case :ex_termbox.start_link(
      input_mode: :esc,
      output_mode: :normal,
      window_title: title
    ) do
      {:ok, tb_pid} ->
        # Initialize the app's model
        initial_model = 
          if Code.ensure_loaded?(app_module) and function_exported?(app_module, :init, 1) do
            app_module.init(options)
          else
            %{}
          end
        
        # Setup the renderer
        case Renderer.start_link(%{fps: fps, debug: debug}) do
          {:ok, renderer_pid} ->
            # Schedule the first render
            schedule_render()
            
            state = %{
              app_module: app_module,
              model: initial_model,
              tb_pid: tb_pid,
              renderer_pid: renderer_pid,
              quit_keys: quit_keys,
              fps: fps,
              debug: debug
            }
            
            {:ok, state}
            
          {:error, reason} ->
            cleanup(%{tb_pid: tb_pid})
            {:stop, reason}
        end
        
      {:error, reason} ->
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_cast({:msg, msg}, state) do
    updated_model = update_model(state.app_module, state.model, msg)
    {:noreply, %{state | model: updated_model}}
  end
  
  @impl true
  def handle_cast(:stop, state) do
    cleanup(state)
    {:stop, :normal, state}
  end
  
  @impl true
  def handle_info(:render, state) do
    # Render the current view
    if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :render, 1) do
      view = state.app_module.render(state.model)
      Renderer.render(state.renderer_pid, view)
    end
    
    # Schedule the next render
    schedule_render()
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:ex_termbox, raw_event}, state) do
    # Convert ex_termbox event to Raxol event
    event = Event.convert(raw_event)
    
    # Process event
    case handle_event(event, state) do
      {:continue, updated_state} -> 
        {:noreply, updated_state}
        
      {:stop, updated_state} -> 
        cleanup(updated_state)
        {:stop, :normal, updated_state}
    end
  end
  
  @impl true
  def terminate(_reason, state) do
    cleanup(state)
    :ok
  end
  
  # Private functions
  
  defp get_app_name(app_module) when is_atom(app_module) do
    Module.split(app_module) |> List.last() |> String.to_atom()
  rescue
    _ -> :default
  end
  
  defp via_tuple(app_name) do
    {:via, Registry, {@registry, app_name}}
  end
  
  defp lookup_app(app_name) do
    case Registry.lookup(@registry, app_name) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end
  
  defp update_model(app_module, model, msg) do
    if Code.ensure_loaded?(app_module) and function_exported?(app_module, :update, 2) do
      app_module.update(model, msg)
    else
      model
    end
  end
  
  defp handle_event(%{type: :key} = event, state) do
    # Check for quit keys
    if is_quit_key?(event, state.quit_keys) do
      {:stop, state}
    else
      # Send the event to the application
      msg = {:event, event}
      updated_model = update_model(state.app_module, state.model, msg)
      {:continue, %{state | model: updated_model}}
    end
  end
  
  defp handle_event(%{type: :resize, width: width, height: height}, state) do
    # Update model with resize event
    msg = {:event, %{type: :resize, width: width, height: height}}
    updated_model = update_model(state.app_module, state.model, msg)
    {:continue, %{state | model: updated_model}}
  end
  
  defp handle_event(%{type: :mouse} = event, state) do
    # Send the mouse event to the application
    msg = {:event, event}
    updated_model = update_model(state.app_module, state.model, msg)
    {:continue, %{state | model: updated_model}}
  end
  
  defp handle_event(_event, state) do
    # Ignore other events
    {:continue, state}
  end
  
  defp is_quit_key?(%{type: :key, meta: meta, key: key}, quit_keys) do
    Enum.any?(quit_keys, fn
      :ctrl_c -> meta == :ctrl && key == ?c
      {:ctrl, char} -> meta == :ctrl && key == char
      :q -> meta == :none && key == ?q
      key_code when is_integer(key_code) -> meta == :none && key == key_code
      named_key when is_atom(named_key) -> meta == :none && key == named_key
      _ -> false
    end)
  end
  
  defp schedule_render do
    # Schedule next render based on FPS
    Process.send_after(self(), :render, trunc(1000 / 60))
  end
  
  defp cleanup(state) do
    if Map.has_key?(state, :renderer_pid) and Process.alive?(state.renderer_pid) do
      GenServer.stop(state.renderer_pid)
    end
    
    if Map.has_key?(state, :tb_pid) and Process.alive?(state.tb_pid) do
      :ex_termbox.stop(state.tb_pid)
    end
  end
end 