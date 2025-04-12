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
  # Use correct alias for Event.convert/1
  alias Raxol.Event
  # Use the correct module for NIFs
  alias ExTermbox.Bindings
  # alias Raxol.Core.Events.Manager, as: EventManager

  # Unused aliases to be removed:
  # alias Raxol.Component
  # alias Raxol.Core.Config
  # alias Raxol.Core.Events.Manager, as: EventManager
  # alias Raxol.Core.Runtime.{EventLoop, AnimationManager, LayoutEngine, RenderEngine}

  alias Raxol.Terminal.Registry, as: AppRegistry

  alias Raxol.Plugins.PluginManager
  alias Raxol.Plugins.ImagePlugin

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
    # Prefixed as it's no longer used for registration
    _app_name = get_app_name(app_module)

    # Pass {app_module, opts} to init/1
    GenServer.start_link(__MODULE__, {app_module, opts})
  end

  @impl true
  def init({app_module, options}) do
    initial_model_from_opts = Keyword.get(options, :initial_model)
    quit_keys = Keyword.get(options, :quit_keys, [:q, :ctrl_c])
    app_name = get_app_name(app_module)

    # Register this Runtime process using the GenServer API
    :ok = AppRegistry.register(app_name, self())
    Logger.debug("Raxol Runtime registered as '#{app_name}' in registry AppRegistry.")

    {:ok, _comp_manager_pid} = ComponentManager.start_link()
    Raxol.Core.Events.Manager.init()

    case Bindings.init() do
      :ok ->
        Logger.debug("Termbox initialized successfully.")
        # Polling will start *after* successful app init
      {:error, init_reason} ->
        Logger.error("Failed to initialize Termbox: #{inspect(init_reason)}")
        # If Termbox fails to init, we cannot proceed
        throw({:error, :termbox_init_failed, init_reason})
    end

    # Initialize Plugin Manager and load plugins
    plugin_manager = PluginManager.new()
    # TODO: Load plugins based on config/discovery
    # {:ok, plugin_manager} = PluginManager.load_plugin(plugin_manager, ImagePlugin, %{})
    # load_plugin returns the updated manager struct directly on success, or {:error, reason}
    # TODO: Add error handling for plugin loading
    plugin_manager = PluginManager.load_plugin(plugin_manager, ImagePlugin, %{})
    # Add error handling for plugin loading later

    initial_state = %{
      app_module: app_module,
      model: initial_model_from_opts,
      options: options,
      quit_keys: quit_keys,
      shutdown_requested: false,
      # Mark as initialized
      termbox_initialized: true,
      plugin_manager: plugin_manager
    }

    # Initialize the application model
    # --- Temporarily Commented Out Try/Catch for Debugging ---
    # try do
    final_state =
      if Code.ensure_loaded?(app_module) and
           function_exported?(app_module, :init, 1) do
        Logger.debug("Calling #{inspect(app_module)}.init(options)...")
        initial_model = app_module.init(options)
        Logger.debug("#{inspect(app_module)}.init(options) successful.")
        %{initial_state | model: initial_model}
      else
        Logger.warning(
          "#{inspect(app_module)} does not implement init/1. Using default model: #{inspect(initial_state.model)}"
        )

        initial_state
      end

    # Start polling *after* successful app init
    ExTermbox.Bindings.start_polling(self())
    Logger.debug("Termbox event polling started.")

    _ = schedule_render()
    Logger.debug("Raxol Runtime initialized successfully for #{app_name}.")
    {:ok, final_state}
    # catch
    #   kind, reason ->
    #     stacktrace = __STACKTRACE__
    #     Logger.error("Error during app initialization for #{app_name}: #{kind} - #{inspect(reason)}\nStacktrace: #{inspect(stacktrace)}")
    #     # Ensure Termbox is shut down if init fails after it was initialized
    #     # Re-bind initial_state locally in catch scope (should be unnecessary but trying for compiler)
    #     bound_initial_state = initial_state
    #     if bound_initial_state.termbox_initialized do
    #       Logger.info("Shutting down Termbox due to init failure...")
    #       ExTermbox.Bindings.stop_polling() # Attempt to stop polling
    #       ExTermbox.Bindings.shutdown()
    #       Logger.info("Termbox shut down.")
    #     end
    #     {:stop, {:app_init_failed, {kind, reason, stacktrace}}}
    # end
    # --- End of Temporarily Commented Out Try/Catch ---
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
  def handle_cast({:set_image_sequence, sequence}, state) when is_binary(sequence) do
    case PluginManager.update_plugin(state.plugin_manager, "image_plugin", fn plugin_state ->
           %{plugin_state | image_escape_sequence: sequence}
         end) do
      {:ok, updated_manager} ->
        {:noreply, %{state | plugin_manager: updated_manager}}

      {:error, reason} ->
        Logger.error("Failed to set image sequence in ImagePlugin: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:render, state) do
    # 1. Render the application UI into a View structure
    view = state.app_module.render(state.model)
    # Log the raw view structure received
    Logger.debug("[Runtime.render] View structure received from app: #{inspect(view)}")

    # 2. Get terminal dimensions (needed for rendering/layout)
    dimensions = get_terminal_dimensions()

    # 3. Process the View structure into a list of cells {x, y, char, fg, bg} or placeholders
    cells_from_view = render_view_to_cells(view, dimensions)
    # Re-add logging immediately before passing cells to the manager
    Logger.debug("[Runtime.render] Cells GENERATED before plugin processing: #{inspect(cells_from_view)}")

    # 4. Pass cells through PluginManager for processing
    # 7. Process Cells through Plugins
    # This allows plugins like ImagePlugin to modify cells or inject commands
    # based on the rendered view.
    {:ok, updated_manager, processed_cells, plugin_commands, _plugin_messages} =
      Raxol.Plugins.PluginManager.process_cells(state.plugin_manager, cells_from_view)

    # Update manager state immediately
    state = %{state | plugin_manager: updated_manager}

    # 7.1. Send any direct output commands from plugins (e.g., escape sequences)
    # TODO: This IO.write might still interfere with ex_termbox. Proper solution needed.
    send_plugin_commands(plugin_commands)

    # 8. Update the :ex_termbox state with processed cells
    # This effectively transfers the processed view state to the low-level buffer.
    :ok = ExTermbox.Bindings.set_buffer_cells(processed_cells)

    # 9. Present the buffer (flush changes to the screen)
    :ok = ExTermbox.Bindings.present()

    # 9. Schedule next render
    _ = schedule_render()
    {:noreply, state}
  end

  @impl true
  def handle_info({:event, raw_event_tuple}, state) do
    try do
      # Decode the raw tuple from the NIF poller
      {type_int, mod, key, ch, w, h, x, y} = raw_event_tuple

      # Convert raw data to the standard ex_termbox event tuple format
      event_tuple =
        case type_int do
          # Key event
          1 ->
            # Pass the original modifier integer `mod` directly.
            # The atom conversion (:alt/:none) was incorrect here.
            # Event.convert/1 expects the integer.
            actual_key = if ch > 0, do: ch, else: key
            {:key, mod, actual_key}

          # Resize event
          2 ->
            {:resize, w, h}

          # Mouse event
          3 ->
            # Convert modifier integer to a *list* of modifier atoms
            modifiers =
              case mod do
                0 ->
                  []

                1 ->
                  [:alt]

                2 ->
                  [:ctrl]

                3 ->
                  [:alt, :ctrl]

                4 ->
                  [:shift]

                5 ->
                  [:alt, :shift]

                6 ->
                  [:ctrl, :shift]

                7 ->
                  [:alt, :ctrl, :shift]

                _ ->
                  Logger.warning(
                    "Unknown mouse modifier integer: #{mod} for button: #{key} at (#{x}, #{y})"
                  )

                  [:unknown]
              end

            button =
              case key do
                1 -> :left
                2 -> :middle
                3 -> :right
                4 -> :wheel_up
                5 -> :wheel_down
                _ -> :unknown_button
              end

            # Pass the modifiers list instead of the old meta atom
            {:mouse, button, x, y, modifiers}

          # Unknown event type
          _ ->
            {:unknown, raw_event_tuple}
        end

      # Pass the standard ex_termbox tuple to handle_event
      case handle_event(event_tuple, state) do
        {:continue, updated_state} ->
          {:noreply, updated_state}

        {:stop, updated_state} ->
          cleanup(updated_state)
          {:stop, :normal, updated_state}
      end
    rescue
      e in FunctionClauseError ->
        Logger.error("FunctionClauseError processing event tuple #{inspect(raw_event_tuple)}: #{inspect(e)}")
        {:noreply, state} # Continue running even if one event fails

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
  def terminate(reason, state) do
    Logger.debug("Raxol.Runtime terminating. Reason: #{inspect(reason)}")
    # Ensure Termbox is shut down if it was initialized
    if Map.get(state, :termbox_initialized, false) do
      Logger.info("Shutting down Termbox during termination...")
      ExTermbox.Bindings.stop_polling() # Should be safe even if not polling
      ExTermbox.Bindings.shutdown()
      Logger.info("Termbox shut down during termination.")
    else
      Logger.info("Skipping Termbox cleanup during termination (not initialized).")
    end
    :ok
  end

  # Private functions

  defp get_app_name(app_module) when is_atom(app_module) do
    Module.split(app_module) |> List.last() |> String.to_atom()
  rescue
    _ -> :default
  end

  defp lookup_app(app_name) do
    # Use the GenServer API and handle its specific return value
    case AppRegistry.lookup(app_name) do
      [{_registry_pid, pid}] -> {:ok, pid} # Value is the registered pid
      [] -> :error
      _ -> :error # Handle any other unexpected return
    end
  end

  defp update_model(app_module, model, msg) do
    if Code.ensure_loaded?(app_module) and
         function_exported?(app_module, :update, 2) do
      app_module.update(model, msg)
    else
      model
    end
  end

  # Updated to expect flat map: %{type: :key, modifiers: list(), key: key_atom_or_char}
  defp is_quit_key?(%{type: :key, modifiers: mods, key: key}, quit_keys) do
    Enum.any?(quit_keys, fn
      # Check for Ctrl+C
      :ctrl_c ->
        :ctrl in mods && key == ?c

      # Check for generic Ctrl + character
      {:ctrl, char} ->
        :ctrl in mods && key == char

      # Check for generic Alt + character
      {:alt, char} ->
        :alt in mods && key == char

      # Check for simple 'q' key (no modifiers)
      :q ->
        mods == [] && key == ?q

      # Check for other simple keys (atoms like :escape, or chars) without modifiers
      simple_key when is_atom(simple_key) or is_integer(simple_key) ->
        mods == [] && key == simple_key

      _ ->
        false
    end)
  end

  # Catch clause for non-key events or mismatched maps
  defp is_quit_key?(_event, _quit_keys), do: false

  defp schedule_render do
    # Schedule next render based on FPS
    Process.send_after(self(), :render, trunc(1000 / 60))
  end

  defp cleanup(state) do
    # Check if termbox was initialized before trying to shut down
    # Note: This check is now mainly handled in terminate/2, but kept here for safety
    if state.termbox_initialized do
      Logger.debug("Shutting down Termbox...")
      ExTermbox.Bindings.stop_polling()
      ExTermbox.Bindings.shutdown()
      Logger.debug("Termbox shut down.")
    end

    # Perform other cleanup tasks
    :ok
  end

  # --- Placeholder for view rendering ---
  # TODO: Implement actual view processing logic based on Raxol.View structure
  # This will likely involve recursive processing of view elements (panels, text, etc.)
  # and potentially layout calculations.
  # defp render_view_to_cells(_view, dimensions) do
  #   # Temporary placeholder: Draw "TODO" at top-left
  #   [
  #     {0, 0, ?T, 7, 0},
  #     {1, 0, ?O, 7, 0},
  #     {2, 0, ?D, 7, 0},
  #     {3, 0, ?O, 7, 0},
  #     {5, 0, ?(, 7, 0},
  #     {6, 0, dimensions.width |> Integer.to_string() |> List.first(), 7, 0}, # Width
  #     {7, 0, ?x, 7, 0},
  #     {8, 0, dimensions.height |> Integer.to_string() |> List.first(), 7, 0}, # Height
  #     {9, 0, ?), 7, 0}
  #   ]
  # end
  # --- End Placeholder ---

  # --- Actual View Rendering Logic (Basic) ---
  defp render_view_to_cells(view, _dimensions) do
    # Start rendering at top-left (0, 0)
    # process_view_element returns {next_y, cell_list}, we only want the list
    {_next_y, cells} = process_view_element(view, 0, 0, [])
    cells
  end

  # Process a single view element recursively
  # Returns {next_y, updated_cell_list}

  # Handle nil child
  defp process_view_element(nil, _x, y, acc_cells), do: {y, acc_cells}
  # Handle empty list child
  defp process_view_element([], _x, y, acc_cells), do: {y, acc_cells}

  defp process_view_element(%{type: :view, children: children}, x, y, acc_cells) when is_list(children) do
    # Filter out nil children before reducing
    valid_children = Enum.reject(children, &is_nil/1)
    # Accumulator is {current_y, accumulated_cells}
    Enum.reduce(valid_children, {y, acc_cells}, fn child, {current_y, accumulated_cells} ->
      # Process child independently, starting from current_y and an empty list for its own cells
      {y_after_child, cells_for_this_child} = process_view_element(child, x, current_y, [])
      # Combine the previously accumulated cells with the new child's cells
      # The next iteration starts at y_after_child
      {y_after_child, accumulated_cells ++ cells_for_this_child}
    end)
  end

  defp process_view_element(%{type: :panel, children: children}, x, y, acc_cells) when is_list(children) do
    # Filter out nil children before reducing
    valid_children = Enum.reject(children, &is_nil/1)
    Enum.reduce(valid_children, {y + 1, acc_cells}, fn child, {current_y, current_cells} ->
      {next_y_after_child, child_cells} = process_view_element(child, x + 1, current_y, [])
      {next_y_after_child, current_cells ++ child_cells}
    end)
  end

  defp process_view_element(%{type: :text, text: text_content}, x, y, acc_cells) when is_binary(text_content) do
    # Convert text content to cells
    text_cells =
      text_content
      |> String.to_charlist()
      |> Enum.with_index()
      |> Enum.map(fn {char_code, index} ->
        {x + index, y, char_code, 7, 0} # Default white on black
      end)

    # Return the next available Y position and the accumulated cells
    {y + 1, acc_cells ++ text_cells}
  end

  # Handle the new placeholder type
  defp process_view_element(%{type: :placeholder, placeholder_type: ptype}, _x, y, acc_cells) do
    # Placeholders don't occupy visual space in the initial render,
    # they just add a marker to the cell list for plugins.
    # Do not advance y; let plugins handle positioning via commands if needed.
    new_acc_cells = acc_cells ++ [{:placeholder, ptype}]
    {y, new_acc_cells}
  end

  # Fallback for unknown/unhandled element types (ignore them)
  defp process_view_element(element, _x, y, acc_cells) do
    Logger.warning("[Runtime] Unhandled view element type: #{inspect(element)}")
    {y, acc_cells}
  end
  # --- End Actual View Rendering Logic ---

  # --- Helper to get terminal dimensions ---
  defp get_terminal_dimensions() do
    width = ExTermbox.Bindings.width()
    height = ExTermbox.Bindings.height()
    %{width: width, height: height}
  end

  # --- Restored handle_event/2 functions ---
  # Takes the standard ex_termbox event *tuple*
  defp handle_event({:key, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple)
    # Check for quit keys using the *converted* event map
    if is_quit_key?(converted_event, state.quit_keys) do
      {:stop, state}
    else
      # Send the *converted* event map to the application
      updated_model =
        update_model(state.app_module, state.model, converted_event)

      {:continue, %{state | model: updated_model}}
    end
  end

  # Takes the standard ex_termbox event *tuple*
  # Prefix unused vars
  defp handle_event({:resize, _width, _height} = event_tuple, state) do
    # Convert the resize tuple to the expected map format for the app
    # Use convert for consistency
    converted_event = Event.convert(event_tuple)
    updated_model = update_model(state.app_module, state.model, converted_event)
    {:continue, %{state | model: updated_model}}
  end

  # Takes the standard ex_termbox event *tuple*
  defp handle_event({:mouse, _, _, _, _mods_list} = event_tuple, state) do
    # Convert the mouse tuple and send the map to the application
    converted_event = Event.convert(event_tuple)
    updated_model = update_model(state.app_module, state.model, converted_event)
    {:continue, %{state | model: updated_model}}
  end

  # Handle unknown or other event tuples (convert if possible)
  defp handle_event(event_tuple, state) do
    converted_event = Event.convert(event_tuple)
    # Pass converted (or {:unknown, raw}) event to the app
    updated_model = update_model(state.app_module, state.model, converted_event)
    {:continue, %{state | model: updated_model}}
  end

  # --- End of modified handle_event/2 functions ---

  # --- Private helper for sending plugin commands ---
  defp send_plugin_commands(commands) when is_list(commands) do
    # TODO: This IO.write might still interfere with ex_termbox. Proper solution needed.
    Enum.each(commands, &IO.write/1)
  end
end
