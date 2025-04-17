defmodule Raxol.RuntimeDebug do # <<< CHANGED MODULE NAME
  @moduledoc """
  DEBUG VERSION of Raxol.Runtime.
  Manages the core runtime processes for a Raxol application.
  Starts and supervises the main components like EventLoop, ComponentManager, etc.
  """
  # This module acts as a GenServer, not the main Application
  use GenServer

  require Logger

  alias Raxol.Core.Runtime.ComponentManager
  alias Raxol.Event
  alias ExTermbox.Bindings
  alias Raxol.Terminal.Registry, as: AppRegistry
  alias Raxol.Plugins.PluginManager
  alias Raxol.Plugins.ImagePlugin
  alias Raxol.Plugins.VisualizationPlugin
  alias Raxol.Terminal.ScreenBuffer

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
    Logger.debug("[RuntimeDebug.start_link] Starting runtime...") # <<< ADDED LOG + MODULE NAME
    # Extract app_module and determine app_name
    app_module = Keyword.fetch!(opts, :app_module)
    # Prefixed as it's no longer used for registration
    _app_name = get_app_name(app_module)

    # Pass {app_module, opts} to init/1
    GenServer.start_link(__MODULE__, {app_module, opts})
  end

  @impl true
  def init({app_module, opts}) do
    Logger.debug("[RuntimeDebug.init] Initializing runtime for #{inspect(app_module)}...") # <<< ADDED LOG + MODULE NAME
    # Determine app name for registration
    app_name = get_app_name(app_module)

    # Initialize ExTermbox - Important: MUST happen before most other actions
    case Bindings.init() do
      {:ok, :ok} -> Logger.debug("[RuntimeDebug.init] ExTermbox initialized successfully.") # <<< MODULE NAME
      {:error, reason} ->
        Logger.error("[RuntimeDebug.init] Failed to initialize ExTermbox: #{inspect(reason)}") # <<< MODULE NAME
        # If Termbox fails, we probably can't continue.
        exit({:shutdown, {:failed_to_init_termbox, reason}})
      other ->
        Logger.warning("[RuntimeDebug.init] Unexpected result from Bindings.init(): #{inspect(other)}") # <<< MODULE NAME
    end

    Bindings.select_output_mode(256) # Use 256 color mode

    # Initialize application state by calling the app_module's init function
    # --- SIMPLIFIED MODEL INITIALIZATION ---
    Logger.debug("[RuntimeDebug.init] Directly calling #{inspect(app_module)}.init/1...")
    # Directly call and assume success with {:ok, model_map} format
    {:ok, initial_model_data} = app_module.init(opts)
    initial_model = initial_model_data # Assign the unwrapped map
    Logger.debug("[RuntimeDebug.init] Result of direct call (initial_model): #{inspect(initial_model)}")
    # --- END SIMPLIFIED ---

    # <<< Log before register check >>>
    Logger.debug("[RuntimeDebug.init] Attempting to register app_name: #{inspect(app_name)} with pid: #{inspect(self())}")
    # Register the runtime process using the unique app_name
    AppRegistry.register(app_name, self())
    # <<< ADD LOG AFTER >>>
    Logger.debug("[RuntimeDebug.init] Successfully registered app_name: #{inspect(app_name)}")

    # Extract options or set defaults
    title = Keyword.get(opts, :title, "Raxol Application")
    fps = Keyword.get(opts, :fps, 60)
    quit_keys = Keyword.get(opts, :quit_keys, [:ctrl_c])
    _debug_mode = Keyword.get(opts, :debug, false)

    # Convert quit keys to standardized internal format
    # processed_quit_keys = Enum.map(quit_keys, &Event.parse_key_event/1) # Removed - format is already correct
    Logger.debug("[RuntimeDebug.init] Using quit_keys: #{inspect(quit_keys)}") # <<< MODULE NAME - Log raw quit_keys

    # --- Initialize Plugin System ---
    # Define default plugins and their initial states/config
    plugins = [
      {ImagePlugin, %{config: %{}, state: %{image_escape_sequence: nil}}}, # Example config/state
      {VisualizationPlugin, %{config: %{}, state: %{}}} # Example
      # Add other plugins here
    ]

    # Create a new PluginManager instance
    initial_manager = PluginManager.new()

    # Load the defined plugins into the manager
    loaded_manager_result =
      Enum.reduce(plugins, {:ok, initial_manager}, fn {module, config}, acc ->
        case acc do
          {:ok, manager} ->
            case PluginManager.load_plugin(manager, module, config) do
              # On success, load_plugin returns the updated manager struct directly
              updated_manager when is_struct(updated_manager, PluginManager) ->
                {:ok, updated_manager}
              # On failure, it returns an error tuple
              {:error, reason} ->
                Logger.error("[RuntimeDebug.init] Failed to load plugin #{inspect module}: #{inspect reason}")
                # Halt reduction on first plugin load error
                {:error, {:failed_to_load_plugin, module, reason}}
              # Handle unexpected return values
              unexpected ->
                Logger.error("[RuntimeDebug.init] Unexpected return from PluginManager.load_plugin for #{inspect module}: #{inspect unexpected}")
                {:error, {:unexpected_return_from_load_plugin, module, unexpected}}
            end
          error ->
            # Propagate previous error
            error
        end
      end)

    # Check if plugin loading succeeded
    case loaded_manager_result do
      {:ok, plugin_manager} ->
        Logger.debug("[RuntimeDebug.init] PluginManager created and plugins loaded successfully.") # <<< MODULE NAME

        # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ADD LOG HERE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        Logger.debug("[RuntimeDebug.init] Value of initial_model BEFORE building initial_state: #{inspect(initial_model)}")

        # --- Prepare initial state ---
        initial_state = %{
          title: title,
          width: 0, # Initialized later
          height: 0, # Initialized later
          app_module: app_module,
          app_name: app_name,
          fps: fps,
          quit_keys: quit_keys, # Using the raw keys now
          plugin_manager: plugin_manager,
          model: initial_model, # <<< CORRECTLY STORE THE INITIAL MODEL
          cell_buffer: ScreenBuffer.new(0, 0), # Initialized with 0,0
          mouse_enabled: false,
          termbox_initialized: true, # Set after successful Bindings.init()
          last_rendered_cells: []
        }

        # <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< LOG FINAL INITIAL STATE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        Logger.debug("[RuntimeDebug.init] Final constructed initial_state: #{inspect(initial_state)}")

        # DEFER POLLING START TO handle_continue
        # case ExTermbox.Bindings.start_polling(self()) do
        #   :ok -> Logger.debug("[RuntimeDebug.init] Termbox polling started.") # <<< MODULE NAME
        #   {:error, reason} ->
        #     Logger.error("[RuntimeDebug.init] Failed to start Termbox polling: #{inspect(reason)}") # <<< MODULE NAME
        #     exit({:shutdown, {:failed_to_start_polling, reason}})
        # end

        # Log state just before returning from init
        Logger.debug("[RuntimeDebug.init] State before returning {:ok, state, :continue}: #{inspect(initial_state)}") # <<< MODULE NAME
        {:ok, initial_state, {:continue, :after_init}} # Use handle_continue for post-init setup
      {:error, reason} ->
        Logger.error("[RuntimeDebug.init] Failed during plugin loading: #{inspect(reason)}") # <<< MODULE NAME
        exit({:shutdown, reason})
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
  def handle_cast({:set_image_sequence, sequence}, state)
      when is_binary(sequence) do
    case PluginManager.update_plugin(
           state.plugin_manager,
           "image_plugin",
           fn plugin_state ->
             %{plugin_state | image_escape_sequence: sequence}
           end
         ) do
      {:ok, updated_manager} ->
        {:noreply, %{state | plugin_manager: updated_manager}}

      {:error, reason} ->
        Logger.error(
          "[RuntimeDebug] Failed to set image sequence in ImagePlugin: #{inspect(reason)}" # <<< MODULE NAME
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:render, state) do
    # <<< ADD LOGGING AT THE VERY BEGINNING >>>
    Logger.debug("[RuntimeDebug.handle_info(:render)] START. Received state: #{inspect(state)}")

    # Check if Termbox is initialized before proceeding
    unless state.termbox_initialized do
      Logger.warning("[RuntimeDebug.handle_info(:render)] Skipping render: Termbox not initialized.") # <<< MODULE NAME
      schedule_render(state) # Reschedule for later
      {:noreply, state}
    end

    # Fetch current dimensions
    width =
      case Bindings.width() do
        {:ok, {:ok, w}} -> w
        {:ok, w} when is_integer(w) -> w
        _ -> state.width # Fallback or handle error
      end

    # --- Workaround: Hardcode dimensions due to ex_termbox issue ---
    height_val = 30
    Logger.warning("[RuntimeDebug.handle_info(:render)] Using HARDCODED dimensions: #{width}x#{height_val}") # <<< MODULE NAME
    # --- End Workaround ---\

    dims = %{x: 0, y: 0, width: width, height: height_val}

    # --- Update Model with Correct Dimensions BEFORE Rendering ---\
    # Original logic restored - Assumes state.model is populated by MyApp.init
    # Use dot notation for struct access and struct update syntax
    dashboard_model = state.model.dashboard_model
    grid_conf = dashboard_model.grid_config
    updated_grid_config = %{grid_conf | parent_bounds: dims} # Use struct update syntax

    # Re-associate the updated grid_config back into the model structure needed for rendering
    updated_dashboard_model = %{dashboard_model | grid_config: updated_grid_config}
    app_model_for_render = %{state.model | dashboard_model: updated_dashboard_model}

    # {updated_grid_config, app_model_for_render} =
    #   if state.model == %{} do
    #     Logger.debug("[RuntimeDebug DEBUG] Skipping model update and app render due to empty model.")
    #     {nil, %{}} # Provide dummy values
    #   else
    #     grid_conf = get_in(state.model, [:dashboard_model, :grid_config])
    #     updated_grid_config = put_in(grid_conf, [:parent_bounds], dims)
    #     # Re-associate the updated grid_config back into the model structure needed for rendering
    #     updated_app_model = put_in(state.model, [:dashboard_model, :grid_config], updated_grid_config)
    #     {updated_grid_config, updated_app_model}
    #   end

    Logger.debug(
      "[RuntimeDebug.handle_info(:render)] Rendering view with updated dimensions: #{inspect(dims)}"
    )

    # --- DEBUG: Check render condition ---
    app_module_loaded = Code.ensure_loaded?(state.app_module)
    render_exported = function_exported?(state.app_module, :render, 1)
    Logger.debug("[RuntimeDebug DEBUG] Checking render condition: app_module=#{inspect(state.app_module)}, loaded?=#{app_module_loaded}, exported?=#{render_exported}") # <<< MODULE NAME
    # --- END DEBUG ---\

    # Render the application view using the UPDATED application's state
    view_elements =
      # Check for render/1 again
      if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :render, 1) do
        # Call render/1 with the props map
        state.app_module.render(%{
          model: app_model_for_render,
          grid_config: updated_grid_config
        })
      else
        Logger.error("[RuntimeDebug] #{inspect state.app_module} does not export render/1. Rendering empty list.")
        []
      end

    {new_cells, _plugin_commands_render} = render_view_to_cells(view_elements, dims)

    # === Process cells through plugins ===
    Logger.debug(
      "[RuntimeDebug.handle_info(:render)] Processing #{length(new_cells)} cells through PluginManager..." # <<< MODULE NAME
    )

    Logger.debug(
      ~s|[RuntimeDebug PRE] ImagePlugin state: #{inspect(Map.get(state.plugin_manager.plugins, "image"))}| # <<< MODULE NAME - Using ~s sigil
    )

    case PluginManager.handle_cells(state.plugin_manager, new_cells, state) do
      {:ok, updated_manager, final_cells, plugin_commands} ->
        changes = ScreenBuffer.diff(state.cell_buffer, final_cells)
        Logger.debug("[RuntimeDebug.handle_info(:render)] Calculated #{length(changes)} cell changes to apply.") # <<< MODULE NAME

        # --- Create new buffer with correct dimensions BEFORE updating ---
        new_buffer = ScreenBuffer.new(width, height_val) |> ScreenBuffer.update(changes)
        # new_buffer = ScreenBuffer.update(state.cell_buffer, changes) # OLD

        Enum.each(changes, fn {x, y, cell_map} ->
          char_code = Map.get(cell_map, :char)
          style_map = Map.get(cell_map, :style, %{})
          fg = Map.get(style_map, :foreground, 7)
          bg = Map.get(style_map, :background, 0)
          if is_integer(char_code) do
            ExTermbox.Bindings.change_cell(x, y, char_code, fg, bg)
          else
            Logger.warning("[RuntimeDebug] Skipping invalid char_code in change_cell: #{inspect(char_code)} at (#{x},#{y})") # <<< MODULE NAME
          end
        end)

        ExTermbox.Bindings.present()
        send_plugin_commands(plugin_commands)

        # Store the new dimensions and buffer
        new_state = %{
          state
          | cell_buffer: new_buffer,
            last_rendered_cells: final_cells,
            plugin_manager: updated_manager,
            width: width, # <<< STORE ACTUAL WIDTH
            height: height_val # <<< STORE ACTUAL HEIGHT (workaround)
        }

        Logger.debug("[RuntimeDebug.handle_info(:render)] Finished render cycle.") # <<< MODULE NAME
        # Schedule the next render based on FPS
        schedule_render(new_state)
        {:noreply, new_state}

      {:error, reason} -> # Added error handling based on original code structure
        Logger.error(
          "[RuntimeDebug.handle_info(:render)] Error processing cells through plugins: #{inspect(reason)}" # <<< MODULE NAME
        )
        schedule_render(state) # Still schedule next render even on error
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:event, raw_event_tuple}, state) do
    if not state.termbox_initialized do
      {:noreply, state}
    else
      try do
        {type_int, mod, key, ch, w, h, x, y} = raw_event_tuple
        event_tuple = convert_raw_event(type_int, mod, key, ch, w, h, x, y)

        case event_tuple do
          {:mouse, _, _, _, _} = mouse_event -> p_handle_mouse_event(mouse_event, state)
          {:key, _, _} = key_event -> p_handle_key_event(key_event, state)
          other_event -> handle_other_event(other_event, state)
        end
      rescue
        e ->
          Logger.error(
            "[RuntimeDebug] Failed to process event tuple #{inspect(raw_event_tuple)}: #{inspect(e)}" # <<< MODULE NAME
          )
          {:noreply, state}
      end
    end
  end

  # Catch-all for unexpected messages
  @impl true
  def handle_info(message, state) do
    Logger.warning("[RuntimeDebug] Received unexpected message: #{inspect(message)}") # <<< MODULE NAME
    {:noreply, state}
  end

  # === Lifecycle Callbacks ===

  @impl true
  def handle_continue(:after_init, state) do
    Logger.debug("[RuntimeDebug.handle_continue(:after_init)] Received state: #{inspect(state)}") # <<< ADDED LOG

    # Start Termbox polling HERE
    case ExTermbox.Bindings.start_polling(self()) do
      {:ok, _ref} -> # Match {:ok, reference} on success
        Logger.debug("[RuntimeDebug.handle_continue] Termbox polling started successfully.")
        # Start the timer loop for rendering ONLY if polling started successfully
        schedule_render(state) # Schedule the first immediate render
        # Log state before returning (should be same as received state)
        Logger.debug("[RuntimeDebug.handle_continue(:after_init)] State before returning: #{inspect(state)}") # <<< ADDED LOG
        {:noreply, state}

      {:error, reason} ->
        Logger.error("[RuntimeDebug.handle_continue] Failed to start Termbox polling: #{inspect(reason)}")
        # Stop the GenServer if polling fails to start
        {:stop, {:shutdown, {:failed_to_start_polling, reason}}, state}

      # Optional: Handle unexpected return values
      other ->
        Logger.error("[RuntimeDebug.handle_continue] Unexpected return from start_polling: #{inspect(other)}")
        {:stop, {:shutdown, {:unexpected_polling_return, other}}, state}
    end
  end

  @impl true
  def terminate(reason, state) do
    # <<< ADD LOGGING AT THE VERY BEGINNING >>>
    Logger.info(
      "[RuntimeDebug.terminate] START. Reason: #{inspect(reason)}, State: #{inspect(state)}"
    )

    dashboard_model = Map.get(state.model, :dashboard_model)

    if reason == :normal and not is_nil(dashboard_model) and
         function_exported?(Raxol.Components.Dashboard.Dashboard, :save_layout, 1) do
      Logger.info("[RuntimeDebug] Saving dashboard layout...") # <<< MODULE NAME
      Raxol.Components.Dashboard.Dashboard.save_layout(dashboard_model.widgets)
    else
      if reason == :normal and dashboard_model do
        Logger.warning("[RuntimeDebug] Dashboard.save_layout/1 not found, cannot save layout.") # <<< MODULE NAME
      end
    end

    if Map.get(state, :termbox_initialized, false) do
      Logger.info("[RuntimeDebug] Shutting down Termbox during termination...") # <<< MODULE NAME
      ExTermbox.Bindings.stop_polling()
      ExTermbox.Bindings.shutdown()
      Logger.info("[RuntimeDebug] Termbox shut down during termination.") # <<< MODULE NAME
    else
      Logger.info(
        "[RuntimeDebug] Skipping Termbox cleanup during termination (not initialized)." # <<< MODULE NAME
      )
    end

    :ok
  end

  # === Core Rendering Logic ===

  def render(state) do
    Logger.debug("[RuntimeDebug.render] Rendering frame...") # <<< ADDED LOG + MODULE NAME
    # ... Placeholder logic ...
    {:noreply, state}
  end

  # Private functions (Copied and adjusted for RuntimeDebug where necessary)

  defp convert_raw_event(type_int, mod, key, ch, w, h, x, y) do
    case type_int do
      1 -> {:key, mod, if(ch > 0, do: ch, else: key)}
      2 -> {:resize, w, h}
      3 ->
        modifiers = convert_mouse_modifiers(mod)
        button = convert_mouse_button(key)
        {:mouse, button, x, y, modifiers}
      _ -> {:unknown, {type_int, mod, key, ch, w, h, x, y}}
    end
  end

  defp convert_mouse_modifiers(mod) do
     # Simplified based on common usage, adjust if more combinations needed
    cond do
      mod == 0 -> []
      mod == 1 -> [:alt]
      mod == 2 -> [:ctrl]
      mod == 3 -> [:alt, :ctrl]
      mod == 4 -> [:shift]
      # Add more combinations if necessary (e.g., 5 -> [:alt, :shift])
      true ->
        Logger.warning("[RuntimeDebug] Unknown mouse modifier integer: #{mod}") # <<< MODULE NAME
        [:unknown]
    end
  end

  defp convert_mouse_button(key) do
    case key do
      1 -> :left
      2 -> :middle
      3 -> :right
      4 -> :wheel_up
      5 -> :wheel_down
      _ -> :unknown_button
    end
  end

  defp handle_other_event(other_event, state) do
    case handle_event(other_event, state) do
      {:continue, updated_state} -> {:noreply, updated_state}
      {:stop, updated_state} ->
        cleanup(updated_state)
        {:stop, :normal, updated_state}
      other -> # Added case to handle unexpected returns from handle_event
        Logger.error("[RuntimeDebug] Unexpected return from handle_event: #{inspect other}") # <<< MODULE NAME
        {:noreply, state} # Default to continuing
    end
  end


  defp get_app_name(app_module) when is_atom(app_module) do
    Module.split(app_module) |> List.last() |> String.to_atom()
  rescue
    _ -> :default # Keep default name consistent
  end

  defp lookup_app(app_name) do
    case AppRegistry.lookup(app_name) do
      [{_registry_pid, pid}] -> {:ok, pid}
      [] -> :error
      _ -> :error
    end
  end

  defp update_model(app_module, model, msg) do
    if Code.ensure_loaded?(app_module) and function_exported?(app_module, :update, 2) do
      app_module.update(model, msg)
    else
      model # Return original model if update/2 not found
    end
  end

  defp is_quit_key?(%{type: :key, modifiers: mods, key: key}, quit_keys) do
    Logger.debug("[RuntimeDebug.is_quit_key?] ENTER. Event: #{inspect(%{type: :key, modifiers: mods, key: key})}, Quit Keys: #{inspect(quit_keys)}") # <<< ADDED LOG
    Enum.any?(quit_keys, fn quit_key ->
      Logger.debug("[RuntimeDebug.is_quit_key?] Checking event key '#{inspect(key)}' (mods: #{inspect(mods)}) against quit key '#{inspect(quit_key)}'") # <<< MODULE NAME
      match_result =
        case quit_key do
          :ctrl_c -> :ctrl in mods && key == ?c
          {:ctrl, char} -> :ctrl in mods && key == char
          {:alt, char} -> :alt in mods && key == char
          :q -> mods == [] && key == ?q
          simple_key when is_atom(simple_key) or is_integer(simple_key) -> mods == [] && key == simple_key
          _ -> false
        end
      Logger.debug("[RuntimeDebug.is_quit_key?] Match result for '#{inspect(quit_key)}': #{match_result}") # <<< MODULE NAME
      match_result
    end)
  end
  defp is_quit_key?(_event, _quit_keys), do: false

  defp cleanup(state) do
    if Map.get(state, :termbox_initialized, false) do
      ExTermbox.Bindings.shutdown()
    end
    app_name = get_app_name(state.app_module)
    AppRegistry.unregister(app_name)
    Logger.debug("[RuntimeDebug] Raxol Runtime for #{app_name} cleaned up.") # <<< MODULE NAME
  end

  defp p_handle_mouse_event({:mouse, _, _, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple) # Assuming Event.convert exists and works
    case PluginManager.handle_mouse_event(
           state.plugin_manager,
           converted_event,
           state.last_rendered_cells
         ) do
      {:ok, updated_manager, :propagate} ->
        new_state = %{state | plugin_manager: updated_manager}
        case handle_event(event_tuple, new_state) do
          {:continue, final_state} -> {:noreply, final_state}
          {:stop, _reason, final_state} -> {:stop, :normal, final_state} # Adjusted stop tuple
          other -> Logger.error("[RuntimeDebug] Unexpected return from app handle_event: #{inspect other}"); {:noreply, state} # <<< MODULE NAME
        end
      {:ok, updated_manager, :halt} ->
        {:noreply, %{state | plugin_manager: updated_manager}}
      {:error, reason} ->
        Logger.error(
          "[RuntimeDebug] Error during plugin mouse handling: #{inspect(reason)}. Propagating." # <<< MODULE NAME
        )
        case handle_event(event_tuple, state) do
          {:continue, final_state} -> {:noreply, final_state}
          {:stop, _reason, final_state} -> {:stop, :normal, final_state} # Adjusted stop tuple
          other -> Logger.error("[RuntimeDebug] Unexpected return from app handle_event: #{inspect other}"); {:noreply, state} # <<< MODULE NAME
        end
    end
  end


  defp p_handle_key_event({:key, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple)
    is_ctrl_c = converted_event == %{type: :key, modifiers: [:ctrl], key: ?c}

    # Simplified initial Ctrl+C handling check (assuming state has `initial_ctrl_c_ignored`)
    if is_ctrl_c and not Map.get(state, :initial_ctrl_c_ignored, false) do
       Logger.debug("[RuntimeDebug.p_handle_key_event] Ignoring initial Ctrl+C event.") # <<< MODULE NAME
       {:noreply, Map.put(state, :initial_ctrl_c_ignored, true)}
    else
      quit_triggered = is_quit_key?(converted_event, state.quit_keys)
      Logger.debug("[RuntimeDebug.p_handle_key_event] is_quit_key? returned: #{quit_triggered}") # <<< MODULE NAME

      case PluginManager.handle_key_event(
             state.plugin_manager,
             converted_event,
             state.last_rendered_cells
           ) do
        {:ok, updated_manager, commands, propagation_state} ->
          new_state = %{state | plugin_manager: updated_manager}
          state_after_commands = process_plugin_commands(new_state, commands)

          if propagation_state == :propagate do
            if quit_triggered do
              Logger.debug("[RuntimeDebug.p_handle_key_event] Quit key detected after plugins.") # <<< MODULE NAME
              Logger.debug("[RuntimeDebug.p_handle_key_event] TRIGGERING STOP (after plugins, propagate)") # <<< ADDED LOG
              cleanup(state_after_commands)
              {:stop, :normal, state_after_commands}
            else
              case handle_event(event_tuple, state_after_commands) do
                {:continue, final_state} -> {:noreply, final_state}
                {:stop, _reason, final_state} -> cleanup(final_state); {:stop, :normal, final_state} # Adjusted stop tuple + cleanup
                other -> Logger.error("[RuntimeDebug] Unexpected return from app handle_event: #{inspect other}"); {:noreply, state_after_commands} # <<< MODULE NAME
              end
            end
          else # :halt
            Logger.debug("[RuntimeDebug.p_handle_key_event] Plugin halted event propagation.") # <<< MODULE NAME
            {:noreply, state_after_commands}
          end
        {:error, reason} ->
           Logger.error("[RuntimeDebug] Error during plugin key event handling: #{inspect(reason)}. Propagating.") # <<< MODULE NAME
           if quit_triggered do
              Logger.debug("[RuntimeDebug.p_handle_key_event] Quit key detected after plugin error.") # <<< MODULE NAME
              Logger.debug("[RuntimeDebug.p_handle_key_event] TRIGGERING STOP (after plugin error)") # <<< ADDED LOG
              cleanup(state)
              {:stop, :normal, state}
           else
              case handle_event(event_tuple, state) do
                {:continue, final_state} -> {:noreply, final_state}
                {:stop, _reason, final_state} -> cleanup(final_state); {:stop, :normal, final_state} # Adjusted stop tuple + cleanup
                other -> Logger.error("[RuntimeDebug] Unexpected return from app handle_event: #{inspect other}"); {:noreply, state} # <<< MODULE NAME
              end
           end
      end
    end
  end

  defp handle_event(event_tuple, state) do
    app_event = Event.convert(event_tuple) # Assuming Event.convert works
    if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :update, 2) do
      case state.app_module.update(app_event, state.model) do
        new_model when is_map(new_model) -> {:continue, %{state | model: new_model}}
        # Adjusted expected stop tuples based on previous code context
        {:stop, :normal, new_model} -> {:stop, :normal, %{state | model: new_model}}
        {:stop, reason, new_model} -> {:stop, reason, %{state | model: new_model}}
        other ->
          Logger.error("[RuntimeDebug] Invalid return from #{state.app_module}.update/2: #{inspect(other)}.") # <<< MODULE NAME
          {:continue, state}
      end
    else
      Logger.warning("[RuntimeDebug] Application #{state.app_module} does not implement update/2.") # <<< MODULE NAME
      {:continue, state}
    end
  end

  defp send_plugin_commands(commands) when is_list(commands) do
    Logger.debug("[RuntimeDebug.send_plugin_commands] Sending commands: #{inspect commands}") # <<< MODULE NAME
    Enum.each(commands, fn
      {:direct_output, content} when is_binary(content) -> IO.write(content)
      other -> Logger.warning("[RuntimeDebug] Unhandled plugin command: #{inspect other}") # <<< MODULE NAME
    end)
  end

  defp process_plugin_commands(state, commands) when is_list(commands) do
    Enum.reduce(commands, state, fn command, acc_state ->
      case command do
        {:paste, content} ->
          Logger.debug("[RuntimeDebug] Processing :paste command.") # <<< MODULE NAME
          updated_model = update_model(acc_state.app_module, acc_state.model, {:paste_text, content})
          %{acc_state | model: updated_model}
        _other ->
          Logger.warning("[RuntimeDebug] Unknown plugin command: #{inspect command}") # <<< MODULE NAME
          acc_state
      end
    end)
  end

  # --- View Rendering Logic (Copied from runtime.ex) ---

  defp render_view_to_cells(view_tree_list, dims)
       when is_list(view_tree_list) do
    initial_bounds = %{x: 0, y: 0, width: dims.width, height: dims.height}
    initial_acc = %{cells: [], commands: []}

    # Iterate over the list of top-level elements from Dashboard.render/1
    final_acc =
      Enum.reduce(view_tree_list, initial_acc, fn element, accumulated_acc ->
        # Call process_view_element for the single element. It uses the passed accumulator.
        # The returned y doesn't matter much at this top level iteration.
        {_y_ignored, updated_acc} =
          process_view_element(element, initial_bounds, accumulated_acc)

        updated_acc
      end)

    # Extract cells and commands from the final accumulator map
    cells = Enum.reverse(final_acc.cells)
    # Assuming commands are already in order
    plugin_commands = final_acc.commands

    Logger.debug(
      "[RuntimeDebug.render_view_to_cells] Finished. Cells: #{length(cells)}, Commands: #{length(plugin_commands)}"
    )

    {cells, plugin_commands}
  end

  # Add fallback for non-list input just in case
  defp render_view_to_cells(single_element, dims) do
    Logger.warning(
      "[RuntimeDebug.render_view_to_cells] Called with single element, expected list. Wrapping in list."
    )

    render_view_to_cells([single_element], dims)
  end

  # Process a single view element recursively (Consolidated)
  # Takes the element, its drawing bounds %{x, y, width, height}, and accumulator map %{cells: list, commands: list}.
  # Returns {next_y_within_bounds, updated_acc_map}
  defp process_view_element(element, bounds, acc) do
    case element do
      # Handle nil child
      nil ->
        {bounds.y, acc}

      # Handle empty list child
      [] ->
        {bounds.y, acc}

      # Handle :view
      %{type: :view, children: children} when is_list(children) ->
        valid_children = Enum.reject(children, &is_nil/1)

        Enum.reduce(valid_children, {bounds.y, acc}, fn child,
                                                        {current_y,
                                                         accumulated_acc} ->
          child_bounds = %{
            bounds
            | y: current_y,
              height: max(0, bounds.height - (current_y - bounds.y))
          }

          # Reset inner acc?
          {y_after_child, child_acc} =
            process_view_element(child, child_bounds, %{
              accumulated_acc
              | cells: [],
                commands: []
            })

          # Merge results
          merged_acc = %{
            cells: accumulated_acc.cells ++ child_acc.cells,
            commands: accumulated_acc.commands ++ child_acc.commands
          }

          {y_after_child, merged_acc}
        end)

      # Handle :panel
      %{type: :panel, children: children} when is_list(children) ->
        child_bounds = %{
          x: bounds.x + 1,
          y: bounds.y + 1,
          width: max(0, bounds.width - 2),
          height: max(0, bounds.height - 2)
        }

        valid_children = Enum.reject(children, &is_nil/1)

        # Process children within panel bounds, accumulating results in panel_acc
        {_final_y, panel_acc} =
          Enum.reduce(
            valid_children,
            {child_bounds.y, %{cells: [], commands: []}},
            fn child, {current_y, accumulated_acc} ->
              current_child_bounds = %{
                child_bounds
                | y: current_y,
                  height:
                    max(0, child_bounds.height - (current_y - child_bounds.y))
              }

              {next_y_after_child, child_acc} =
                process_view_element(child, current_child_bounds, %{
                  accumulated_acc
                  | cells: [],
                    commands: []
                })

              # Merge results
              merged_acc = %{
                cells: accumulated_acc.cells ++ child_acc.cells,
                commands: accumulated_acc.commands ++ child_acc.commands
              }

              {next_y_after_child, merged_acc}
            end
          )

        # Merge panel's accumulated results with the outer accumulator
        final_acc = %{
          cells: acc.cells ++ panel_acc.cells,
          commands: acc.commands ++ panel_acc.commands
        }

        {bounds.y + bounds.height, final_acc}

      # Handle :text
      %{type: :text, text: text_content} when is_binary(text_content) ->
        {next_y, text_cells} = p_render_text_content(text_content, bounds)
        # Text doesn't generate commands directly
        {next_y, %{acc | cells: acc.cells ++ text_cells}}

      # Handle :box
      %{type: :box, opts: opts, children: children} ->
        # Check if this box represents a plugin widget placeholder
        case Keyword.get(opts, :widget_config) do
          # This box IS a plugin widget placeholder
          %{
            type: :chart,
            data: data,
            component_opts: component_opts,
            bounds: element_bounds
          } ->
            Logger.debug(
              "[RuntimeDebug.process_view_element] Matched :image widget inside :box. Incoming component_opts: #{inspect(component_opts)}"
            )
            placeholder_cell = %{
              type: :placeholder,
              value: :chart,
              data: data,
              opts: component_opts,
              bounds: element_bounds
            }
            Logger.debug(
              "[RuntimeDebug.process_view_element] Created :image placeholder cell from :box: #{inspect(placeholder_cell)}"
            )
            updated_acc = %{acc | cells: acc.cells ++ [placeholder_cell]}
            # Use the bounds from the placeholder config for the next y
            {element_bounds.y + element_bounds.height, updated_acc}

          %{
            type: :treemap,
            data: data,
            component_opts: component_opts,
            bounds: element_bounds
          } ->
            placeholder_cell = %{
              type: :placeholder,
              value: :treemap,
              data: data,
              opts: component_opts,
              bounds: element_bounds
            }
            updated_acc = %{acc | cells: acc.cells ++ [placeholder_cell]}
            {element_bounds.y, updated_acc}

          %{
            type: :image,
            component_opts: component_opts,
            bounds: element_bounds
          } ->
            Logger.debug(
              "[RuntimeDebug.process_view_element] Matched :image widget inside :box. Incoming component_opts: #{inspect(component_opts)}"
            )
            placeholder_cell = %{
              type: :placeholder,
              value: :image,
              opts: component_opts,
              bounds: element_bounds
            }
            Logger.debug(
              "[RuntimeDebug.process_view_element] Created :image placeholder cell from :box: #{inspect(placeholder_cell)}"
            )
            updated_acc = %{acc | cells: acc.cells ++ [placeholder_cell]}
            {element_bounds.y, updated_acc}

          # This box is NOT a plugin widget placeholder, process children
          nil ->
            # Extract box positioning/sizing from the :opts keyword list
            box_rel_x = Keyword.get(opts, :x, 0)
            box_rel_y = Keyword.get(opts, :y, 0)
            # Bounds passed in are the parent bounds
            box_abs_x = bounds.x + box_rel_x
            box_abs_y = bounds.y + box_rel_y

            # Calculate width/height based on opts or fill parent bounds
            box_width =
              case Keyword.get(opts, :width) do
                :fill -> bounds.width - box_rel_x
                val when is_integer(val) -> val
                _ -> bounds.width - box_rel_x # Default to fill
              end

            box_height =
              case Keyword.get(opts, :height) do
                :fill -> bounds.height - box_rel_y
                val when is_integer(val) -> val
                _ -> bounds.height - box_rel_y # Default to fill
              end

            # Clip the box to the parent bounds
            clipped_x = max(bounds.x, box_abs_x)
            clipped_y = max(bounds.y, box_abs_y)

            clipped_width =
              max(0, min(box_width, bounds.x + bounds.width - clipped_x))

            clipped_height =
              max(0, min(box_height, bounds.y + bounds.height - clipped_y))

            # Define the bounds for children within this box
            child_bounds = %{
              x: clipped_x,
              y: clipped_y,
              width: clipped_width,
              height: clipped_height
            }

            valid_children = Enum.reject(children, &is_nil/1)

            # Process children within box bounds, accumulating results in box_acc
            {_final_y_within_box, box_acc} =
              Enum.reduce(
                valid_children,
                {child_bounds.y, %{cells: [], commands: []}},
                fn child, {current_y, accumulated_acc} ->
                  if current_y < child_bounds.y + child_bounds.height do
                    current_child_bounds = %{
                      child_bounds
                      | y: current_y,
                        height:
                          max(0, child_bounds.height - (current_y - child_bounds.y))
                    }

                    # Pass inner acc
                    {y_after_child, child_acc} =
                      process_view_element(child, current_child_bounds, %{
                        accumulated_acc
                        | cells: [],
                          commands: []
                      })

                    # Merge results
                    merged_acc = %{
                      cells: accumulated_acc.cells ++ child_acc.cells,
                      commands: accumulated_acc.commands ++ child_acc.commands
                    }

                    next_y =
                      min(y_after_child, child_bounds.y + child_bounds.height)

                    {next_y, merged_acc}
                  else
                    {current_y, accumulated_acc}
                  end
                end
              )

            # Merge box's accumulated results with the outer accumulator
            final_acc = %{
              cells: acc.cells ++ box_acc.cells,
              commands: acc.commands ++ box_acc.commands
            }

            next_y_after_box =
              min(bounds.y + bounds.height, child_bounds.y + child_bounds.height)

            {next_y_after_box, final_acc}
        end # End case Map.get(opts, :widget_config)

      # Handle :placeholder (Should not be generated by view, but maybe by plugin?)
      %{type: :placeholder} = placeholder ->
        Logger.debug(
          "[RuntimeDebug.process_view_element] Passing through existing placeholder: #{inspect(placeholder)}"
        )
        updated_acc = %{acc | cells: acc.cells ++ [placeholder]}
        {bounds.y, updated_acc}

      # Catch-all for other map types (log warning)
      element when is_map(element) ->
        Logger.warning(
          "[RuntimeDebug.process_view_element] Unhandled view element type: #{inspect(element)}"
        )
        {bounds.y, acc}

      # Handle strings directly (assuming they are meant as simple text)
      element when is_binary(element) ->
        Logger.debug(
          "[RuntimeDebug.process_view_element] Handling raw string: \"#{element}\""
        )
        {next_y, text_cells} = p_render_text_content(element, bounds)
        {next_y, %{acc | cells: acc.cells ++ text_cells}}

      # Catch-all for other unexpected element types
      _other ->
        Logger.warning(
          "[RuntimeDebug.process_view_element] Encountered unexpected element type: #{inspect(element)}"
        )
        {bounds.y, acc}
    end
  end

  # --- Helper for OSC 8 Parsing (Copied from runtime.ex) ---

  @osc8_start "\\e]8;"
  @osc8_st "\\a"
  @osc8_end "\\e]8;;\\a"

  defp parse_osc8_segments(text) do
    parse_osc8_segments(text, []) |> Enum.reverse()
  end

  defp parse_osc8_segments("", acc), do: acc

  defp parse_osc8_segments(text, acc) do
    case String.split(text, @osc8_start, parts: 2) do
      # No OSC 8 start sequence found
      [^text] ->
        [{:plain, text} | acc]

      # Found OSC 8 start sequence
      [plain_before, rest_after_start] ->
        # Add the plain text before the sequence (if any)
        new_acc =
          if plain_before == "", do: acc, else: [{:plain, plain_before} | acc]

        # Delegate parsing the rest to the helper function
        p_parse_after_osc8_start(rest_after_start, new_acc)
    end
  end

  # Helper to parse the string segment after finding \\e]8;
  defp p_parse_after_osc8_start(rest_after_start, acc) do
    case String.split(rest_after_start, @osc8_st, parts: 2) do
      # Malformed: No ST (\\a) found after params/URI
      [_] ->
        [{:plain, @osc8_start <> rest_after_start} | acc]

      # Found ST (\\a), separating params/URI from link text
      [params_uri, rest_after_st] ->
        uri = String.trim(params_uri, ";")

        case String.split(rest_after_st, @osc8_end, parts: 2) do
          # Malformed: No end sequence found
          [_] ->
            [{:plain, @osc8_start <> rest_after_start} | acc]

          # Found the end sequence
          [link_text, rest_after_end] ->
            link_acc = [{:link, uri, link_text} | acc]
            parse_osc8_segments(rest_after_end, link_acc)
        end
    end
  end

  # --- Private View Rendering Helpers (Copied from runtime.ex) ---

  # Renders text content within bounds, handling OSC8 links.
  # Returns {next_y, list_of_cells}
  defp p_render_text_content(text_content, bounds) do
    if text_content == "" or bounds.width <= 0 or bounds.height <= 0 do
      {bounds.y, []}
    else
      segments = parse_osc8_segments(text_content)
      text_cells = p_render_text_segments(segments, bounds)
      next_y = min(bounds.y + 1, bounds.y + bounds.height)
      {next_y, text_cells}
    end
  end

  # Processes a list of parsed text segments into cells.
  # Returns list_of_cells
  defp p_render_text_segments(segments, bounds) do
    {text_cells_rev, _final_col} =
      Enum.reduce(segments, {[], bounds.x}, fn segment,
                                               {cells_acc, current_col} ->
        case segment do
          {:plain, plain_text} ->
            process_text_segment(
              plain_text,
              bounds,
              current_col,
              %{},
              cells_acc
            )

          {:link, url, link_text} ->
            link_style = %{hyperlink: url}

            process_text_segment(
              link_text,
              bounds,
              current_col,
              link_style,
              cells_acc
            )
        end
      end)

    Enum.reverse(text_cells_rev)
  end

  # Helper function to process a single text segment (plain or linked)
  # Returns {updated_cells_acc, next_col}
  defp process_text_segment(text, bounds, start_col, base_style, cells_acc) do
    text
    |> String.graphemes()
    |> Enum.reduce({cells_acc, start_col}, fn grapheme,
                                              {inner_cells_acc, current_col} ->
      if current_col >= bounds.x and current_col < bounds.x + bounds.width do
        if bounds.y < bounds.y + bounds.height do
          [char_code | _] = String.to_charlist(grapheme)
          cell_map = %{
            char: char_code,
            fg: 7,
            bg: 0,
            style: base_style
          }
          cell_tuple = {current_col, bounds.y, cell_map}
          {[cell_tuple | inner_cells_acc], current_col + 1}
        else
          {inner_cells_acc, current_col + 1}
        end
      else
        {inner_cells_acc, current_col + 1}
      end
    end)
  end

  # --- End Private View Rendering Helpers ---

  # --- Helper Functions ---

  # Helper to schedule the next render frame
  defp schedule_render(state) do
    Logger.debug("[RuntimeDebug.schedule_render] Scheduling :render message.") # <<< ADDED LOG
    render_interval_ms = round(1000 / state.fps)
    Process.send_after(self(), :render, render_interval_ms)
  end

end
