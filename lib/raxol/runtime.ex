defmodule Raxol.Runtime do
  @moduledoc """
  Manages the core runtime processes for a Raxol application.
  Starts and supervises the main components like EventLoop, ComponentManager, etc.
  """
  # This module acts as a GenServer, not the main Application
  use GenServer

  require Logger

  alias Raxol.Core.Runtime.ComponentManager
  # alias Raxol.Terminal.Renderer # Removed unused alias
  # alias Raxol.Event # Removed unused alias
  alias Raxol.Core.Events.Event # Keep this for the functions we *do* call
  alias ExTermbox.Bindings # Use the correct module for NIFs
  # alias Raxol.Core.Events.Manager, as: EventManager

  # Unused aliases to be removed:
  # alias Raxol.Component
  # alias Raxol.Core.Config
  # alias Raxol.Core.Events.Manager, as: EventManager
  # alias Raxol.Core.Runtime.{EventLoop, AnimationManager, LayoutEngine, RenderEngine}

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

  # Accepts options as a keyword list from the supervisor
  def start_link(opts) when is_list(opts) do
    # Extract app_module and determine app_name
    app_module = Keyword.fetch!(opts, :app_module)
    _app_name = get_app_name(app_module) # Prefixed as it's no longer used for registration

    # Pass {app_module, opts} to init/1
    GenServer.start_link(__MODULE__, {app_module, opts})
  end

  @impl true
  def init({app_module, options}) do
    # Pass the full options map from the supervisor/run call
    initial_model_from_opts = Keyword.get(options, :initial_model) # Keep for potential direct model passing
    quit_keys = Keyword.get(options, :quit_keys, [:q, :ctrl_c])
    app_name = get_app_name(app_module)

    # Start core managers
    {:ok, _comp_manager_pid} = ComponentManager.start_link()
    Raxol.Core.Events.Manager.init()

    # Start the rendering backend (Termbox)
    case Bindings.init() do
      :ok ->
        Logger.info("Termbox initialized successfully.")
        # Start polling for events from Termbox, sending them to this process (self())
        ExTermbox.Bindings.start_polling(self())
      {:error, init_reason} ->
        Logger.error("Failed to initialize Termbox: #{inspect(init_reason)}")
    end

    # Prepare initial state before calling app's init
    initial_state = %{
      app_module: app_module,
      model: initial_model_from_opts, # Use passed model if provided, otherwise app's init sets it
      options: options,
      quit_keys: quit_keys,
      shutdown_requested: false
    }

    # Initialize the application model by calling the app module's init/1
    final_state =
      if Code.ensure_loaded?(app_module) and function_exported?(app_module, :init, 1) do
        # Call app's init/1, passing the options; it should return the initial model
        initial_model = app_module.init(options)
        %{initial_state | model: initial_model}
      else
        # Fallback if init/1 is not defined (uses default from `use Raxol.App` or initial_model_from_opts)
        Logger.warning("#{inspect(app_module)} does not implement init/1. Using default model: #{inspect(initial_state.model)}")
        initial_state
      end

    # Schedule the first render
    _ = schedule_render()

    Logger.info("Raxol Runtime initialized successfully for #{app_name}.")
    {:ok, final_state}
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
    Logger.debug("Received :render message")

    # Render the application UI
    view = state.app_module.render(state.model)
    Logger.debug("App.render/1 returned: #{inspect(view)}")

    # TODO: Integrate with Renderer module
    # Potentially pass the view to the Renderer?
    # _ = Renderer.render(state.renderer_pid) # Placeholder, renderer_pid isn't in state

    # Actually draw the buffer to the screen
    :ok = ExTermbox.Bindings.present()
    Logger.debug("Called ExTermbox.Bindings.present()")

    # Schedule the next render frame
    schedule_render()

    {:noreply, state}
  end

  @impl true
  def handle_info({:event, raw_event_tuple}, state) do
    Logger.info("MATCHED handle_info({:event, tuple}): #{inspect(raw_event_tuple)}")
    # Re-enabled struct reconstruction and event processing
    try do
      {type_int, mod, key, ch, w, h, x, y} = raw_event_tuple
      event_struct = %ExTermbox.Event{
        type: case type_int do
          1 -> :key
          2 -> :resize
          3 -> :mouse
          _ -> :unknown
        end,
        mod: mod,
        key: key,
        ch: ch,
        w: w,
        h: h,
        x: x,
        y: y
      }

      # Pass the raw ExTermbox struct to handle_event
      case handle_event(event_struct, state) do
        {:continue, updated_state} ->
          {:noreply, updated_state}
        {:stop, updated_state} ->
          cleanup(updated_state)
          {:stop, :normal, updated_state}
      end
    rescue
      e ->
        Logger.error("Failed to process event tuple #{inspect(raw_event_tuple)}: #{inspect(e)}")
        {:noreply, state} # Continue running even if one event fails
    end
  end

  # Catch-all for unexpected messages (shouldn't be hit often now)
  def handle_info(message, state) do
    Logger.warning("Runtime received unexpected message: #{inspect(message)}")
    {:noreply, state}
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

  # Updated pattern match to extract key/modifiers from nested :data map
  defp is_quit_key?(%{type: :key, data: %{key: key, modifiers: modifiers}}, quit_keys) do
    Enum.any?(quit_keys, fn
      # Check for Ctrl+C
      :ctrl_c -> Enum.member?(:ctrl, modifiers) && key == ?c
      # Check for generic Ctrl + character
      {:ctrl, char} -> Enum.member?(:ctrl, modifiers) && key == char
      # Check for simple 'q' key
      :q -> modifiers == [] && key == ?q
      # Check for other simple keys (integers or atoms) without modifiers
      simple_key when is_integer(simple_key) or is_atom(simple_key) ->
         modifiers == [] && key == simple_key
      _ -> false
    end)
  end

  defp schedule_render do
    # Schedule next render based on FPS
    Process.send_after(self(), :render, trunc(1000 / 60))
  end

  defp cleanup(_state) do
    # Stop Termbox event polling and shut down Termbox unconditionally
    Logger.info("Shutting down Termbox...")
    ExTermbox.Bindings.stop_polling()
    ExTermbox.Bindings.shutdown()
    Logger.info("Termbox shut down.")

    # Perform other cleanup tasks
    :ok
  end

  # --- Restored handle_event/2 functions ---
  # Takes the raw ExTermbox.Event struct
  defp handle_event(%ExTermbox.Event{type: :key} = event, state) do
    # Check for quit keys using the updated is_quit_key? function
    # is_quit_key? expects a converted event map, so we convert here
    converted_key_event = Raxol.Core.Events.Event.convert(event)
    if is_quit_key?(converted_key_event, state.quit_keys) do
      {:stop, state}
    else
      # Send the converted event to the application
      updated_model = update_model(state.app_module, state.model, converted_key_event)
      {:continue, %{state | model: updated_model}}
    end
  end

  # Takes the raw ExTermbox.Event struct
  defp handle_event(%ExTermbox.Event{type: :resize, w: width, h: height} = _event, state) do
    # Construct the specific message for the application's update/2
    resize_msg = %{type: :resize, width: width, height: height}
    updated_model = update_model(state.app_module, state.model, resize_msg)
    {:continue, %{state | model: updated_model}}
  end

  # Takes the raw ExTermbox.Event struct
  defp handle_event(%ExTermbox.Event{type: :mouse} = event, state) do
    # Convert the raw mouse event and send it to the application
    converted_mouse_event = Raxol.Core.Events.Event.convert(event)
    updated_model = update_model(state.app_module, state.model, converted_mouse_event)
    {:continue, %{state | model: updated_model}}
  end

  defp handle_event(_event, state) do
    # Ignore other events
    {:continue, state}
  end
  # --- End of restored handle_event/2 functions ---
end
