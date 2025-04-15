defmodule Raxol.Runtime do
  @moduledoc """
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

    termbox_initialized =
      if Mix.env() != :test do
        case Bindings.init() do
          :ok ->
            Logger.debug("Termbox initialized successfully.")
            # Polling will start *after* successful app init
            true # Mark termbox as initialized
          {:error, init_reason} ->
            Logger.error("Failed to initialize Termbox: #{inspect(init_reason)}")
            # If Termbox fails to init, we cannot proceed
            throw({:error, :termbox_init_failed, init_reason})
        end
      else
        Logger.info("Skipping Termbox initialization in test environment.")
        false # Mark termbox as not initialized in test
      end

    # Initialize Plugin Manager and load plugins
    plugin_manager = PluginManager.new()
    # TODO: Load plugins based on config/discovery
    # {:ok, plugin_manager} = PluginManager.load_plugin(plugin_manager, ImagePlugin, %{})
    # load_plugin returns the updated manager struct directly on success, or {:error, reason}
    # TODO: Add error handling for plugin loading
    plugin_manager = PluginManager.load_plugin(plugin_manager, ImagePlugin, %{})
    plugin_manager = PluginManager.load_plugin(plugin_manager, VisualizationPlugin, %{})
    # Add error handling for plugin loading later

    initial_state = %{
      app_module: app_module,
      model: initial_model_from_opts,
      options: options,
      quit_keys: quit_keys,
      shutdown_requested: false,
      # Mark as initialized based on the conditional check
      termbox_initialized: termbox_initialized,
      plugin_manager: plugin_manager,
      last_rendered_cells: %{} # Initialize map to store last rendered cells
    }

    # Initialize the application model
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

    # Start polling *after* successful app init and only if termbox was initialized
    if final_state.termbox_initialized do
      ExTermbox.Bindings.start_polling(self())
      Logger.debug("Termbox event polling started.")
    end

    _ = schedule_render()
    Logger.debug("Raxol Runtime initialized successfully for #{app_name}.")
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
    # Skip rendering if termbox isn't initialized (e.g., in test)
    if not state.termbox_initialized do
      _ = schedule_render() # Still schedule next tick
      {:noreply, state}
    else
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

      # Convert processed_cells list to a map for easier lookup by plugins
      # Build the map of cells for plugin lookup, preserving the full cell map
      # Note: processed_cells now contains maps, including placeholder markers.
      cells_map =
        Enum.reduce(processed_cells, %{}, fn
          # Match regular cell maps
          %{x: x, y: y} = cell_map, acc -> Map.put(acc, {x, y}, cell_map)
          # Ignore placeholders or other non-renderable markers for the map
          _, acc -> acc
        end)

      # Update manager state immediately
      state = %{state | plugin_manager: updated_manager, last_rendered_cells: cells_map}

      # 8. Update the :ex_termbox state with processed cells
      # Replace the incorrect set_buffer_cells with iteration using change_cell
      Enum.each(processed_cells, fn
        # Match regular cell maps and render them
        %{x: x, y: y, char: char, fg: fg, bg: bg} ->
          ExTermbox.Bindings.change_cell(x, y, char, fg, bg)

        # Ignore placeholders or other markers - they don't render directly
        _other_marker ->
          :ok
      end)

      # 9. Present the buffer (flush changes to the screen)
      :ok = ExTermbox.Bindings.present()

      # 9.1 Send plugin commands AFTER presenting the termbox buffer
      send_plugin_commands(plugin_commands)

      # 10. Schedule next render
      _ = schedule_render()
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:event, raw_event_tuple}, state) do
    # Skip event processing if termbox isn't initialized
    if not state.termbox_initialized do
      Logger.debug("Skipping termbox event processing in non-interactive environment.")
      {:noreply, state}
    else
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

        # Pass the standard ex_termbox tuple to appropriate handler
        case event_tuple do
          {:mouse, _, _, _, _} = mouse_event ->
            p_handle_mouse_event(mouse_event, state)

          {:key, _, _} = key_event ->
            p_handle_key_event(key_event, state)

          # Handle other event types directly (resize, unknown)
          other_event ->
            case handle_event(other_event, state) do
               {:continue, updated_state} -> {:noreply, updated_state}
               {:stop, updated_state} ->
                 cleanup(updated_state) # Ensure cleanup happens on stop
                 {:stop, :normal, updated_state}
             end
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
  end

  # Catch-all for unexpected messages (shouldn't be hit often now)
  def handle_info(message, state) do
    Logger.warning("Runtime received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.debug("Raxol.Runtime terminating. Reason: #{inspect(reason)}")

    # Save dashboard layout if possible
    dashboard_model = Map.get(state.model, :dashboard_model)
    if reason == :normal and dashboard_model do
      Logger.info("Saving dashboard layout...")
      # Call a function in Dashboard to handle saving
      if function_exported?(Raxol.Components.Dashboard.Dashboard, :save_layout, 1) do
        Raxol.Components.Dashboard.Dashboard.save_layout(dashboard_model.widgets)
      else
        Logger.warning("Dashboard.save_layout/1 not found, cannot save layout.")
      end
    end

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
    if state.termbox_initialized do
      ExTermbox.Bindings.shutdown()
    end
    # Unregister the application name from the registry
    # Ensure app_name is fetched correctly if needed, or assumed from init arg
    # For simplicity, let's assume app_module gives us the context
    app_name = get_app_name(state.app_module)
    AppRegistry.unregister(app_name)
    Logger.debug("Raxol Runtime for #{app_name} cleaned up.")
  end

  # --- Actual View Rendering Logic (Basic) ---
  defp render_view_to_cells(view, dimensions) do
    # Start rendering at top-left (0, 0) with full terminal dimensions as bounds
    initial_bounds = %{x: 0, y: 0, width: dimensions.width, height: dimensions.height}
    # process_view_element returns {next_y, cell_list}, we only want the list
    {_next_y, cells} = process_view_element(view, initial_bounds, [])
    cells
  end

  # Process a single view element recursively (Consolidated)
  # Takes the element, its drawing bounds %{x, y, width, height}, and accumulated cells.
  # Returns {next_y_within_bounds, updated_cell_list}
  defp process_view_element(element, bounds, acc_cells) do
    case element do
      # Handle nil child
      nil ->
        {bounds.y, acc_cells}

      # Handle empty list child
      [] ->
        {bounds.y, acc_cells}

      # Handle :view
      %{type: :view, children: children} when is_list(children) ->
        valid_children = Enum.reject(children, &is_nil/1)
        Enum.reduce(valid_children, {bounds.y, acc_cells}, fn child, {current_y, accumulated_cells} ->
          child_bounds = %{bounds | y: current_y, height: max(0, bounds.height - (current_y - bounds.y))}
          {y_after_child, cells_for_this_child} = process_view_element(child, child_bounds, [])
          {y_after_child, accumulated_cells ++ cells_for_this_child}
        end)

      # Handle :panel
      %{type: :panel, children: children} when is_list(children) ->
        child_bounds = %{x: bounds.x + 1, y: bounds.y + 1, width: max(0, bounds.width - 2), height: max(0, bounds.height - 2)}
        valid_children = Enum.reject(children, &is_nil/1)
        {_final_y, panel_child_cells} =
          Enum.reduce(valid_children, {child_bounds.y, []}, fn child, {current_y, accumulated_cells} ->
            current_child_bounds = %{child_bounds | y: current_y, height: max(0, child_bounds.height - (current_y - child_bounds.y))}
            {next_y_after_child, child_cells} = process_view_element(child, current_child_bounds, [])
            {next_y_after_child, accumulated_cells ++ child_cells}
          end)
        {bounds.y + bounds.height, acc_cells ++ panel_child_cells}

      # Handle :text
      %{type: :text, text: text_content} when is_binary(text_content) ->
        {next_y, text_cells} = p_render_text_content(text_content, bounds)
        {next_y, acc_cells ++ text_cells}

      # Handle :box
      %{type: :box, opts: opts, children: children} when is_list(children) ->
        box_rel_x = Keyword.get(opts, :x, 0)
        box_rel_y = Keyword.get(opts, :y, 0)
        box_abs_x = bounds.x + box_rel_x
        box_abs_y = bounds.y + box_rel_y
        box_width = Keyword.get(opts, :width, bounds.width - box_rel_x)
        box_height = Keyword.get(opts, :height, bounds.height - box_rel_y)
        clipped_x = max(bounds.x, box_abs_x)
        clipped_y = max(bounds.y, box_abs_y)
        clipped_width = max(0, min(box_width, bounds.x + bounds.width - clipped_x))
        clipped_height = max(0, min(box_height, bounds.y + bounds.height - clipped_y))
        child_bounds = %{x: clipped_x, y: clipped_y, width: clipped_width, height: clipped_height}
        valid_children = Enum.reject(children, &is_nil/1)
        {_final_y_within_box, box_child_cells} =
          Enum.reduce(valid_children, {child_bounds.y, []}, fn child, {current_y, accumulated_cells} ->
            if current_y < child_bounds.y + child_bounds.height do
              current_child_bounds = %{child_bounds | y: current_y, height: max(0, child_bounds.height - (current_y - child_bounds.y))}
              {y_after_child, cells_for_this_child} = process_view_element(child, current_child_bounds, [])
              next_y = min(y_after_child, child_bounds.y + child_bounds.height)
              {next_y, accumulated_cells ++ cells_for_this_child}
            else
              {current_y, accumulated_cells}
            end
          end)
        next_y_after_box = min(bounds.y + bounds.height, child_bounds.y + child_bounds.height)
        {next_y_after_box, acc_cells ++ box_child_cells}

      # Handle :placeholder - NOW calls plugin rendering functions
      %{type: :placeholder, placeholder_type: :render_chart, data: data, opts: opts} ->
        # Get cells from VisualizationPlugin, using the calculated bounds
        chart_cells = VisualizationPlugin.render_chart_to_cells(data, opts, bounds)
        {bounds.y, acc_cells ++ chart_cells}

      %{type: :placeholder, placeholder_type: :render_treemap, data: data, opts: opts} ->
        # Get cells from VisualizationPlugin, using the calculated bounds
        treemap_cells = VisualizationPlugin.render_treemap_to_cells(data, opts, bounds)
        {bounds.y, acc_cells ++ treemap_cells}

      # Handle other placeholder types (e.g., from ImagePlugin)
      %{type: :placeholder, placeholder_type: ptype} ->
        # Keep the placeholder marker itself for the PluginManager
        new_acc_cells = acc_cells ++ [%{type: :placeholder, value: ptype}]
        {bounds.y, new_acc_cells}

      # --- Handle Custom Widget Data Structures ---
      # Handle :chart data structure by calling VisualizationPlugin
      %{type: :chart, opts: opts, data: data} ->
        # Call plugin to render into cells using the calculated bounds
        chart_cells = VisualizationPlugin.render_chart_to_cells(data, opts, bounds)
        # Use bounds.y as the starting y position for the next element
        {bounds.y, acc_cells ++ chart_cells}

      # Handle :treemap data structure by calling VisualizationPlugin
      %{type: :treemap, opts: opts, data: data} ->
        # Call plugin to render into cells using the calculated bounds
        treemap_cells = VisualizationPlugin.render_treemap_to_cells(data, opts, bounds)
        # Use bounds.y as the starting y position for the next element
        {bounds.y, acc_cells ++ treemap_cells}
      # --- End Custom Widget Handling ---

      # Fallback for unknown/unhandled element types
      other_element when is_map(other_element) ->
        Logger.warning("[Runtime] Unhandled view element type: #{inspect(other_element)}")
        {bounds.y, acc_cells}

      # Handle non-map elements gracefully (e.g., strings accidentally passed)
      _ ->
        Logger.warning("[Runtime] Unhandled non-map view element: #{inspect(element)}")
        {bounds.y, acc_cells}
    end
  end

  # --- Helper for OSC 8 Parsing ---

  @osc8_start "\\e]8;"
  @osc8_st "\\a" # BEL character (ASCII 7) acts as ST (String Terminator)
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
        new_acc = if plain_before == "", do: acc, else: [{:plain, plain_before} | acc]
        # Delegate parsing the rest to the helper function
        p_parse_after_osc8_start(rest_after_start, new_acc)
    end
  end

  # Helper to parse the string segment after finding \\e]8;
  defp p_parse_after_osc8_start(rest_after_start, acc) do
    case String.split(rest_after_start, @osc8_st, parts: 2) do
      # Malformed: No ST (\\a) found after params/URI
      [_] ->
        # Treat the rest as plain text, including the incomplete start sequence
        [{:plain, @osc8_start <> rest_after_start} | acc]

      # Found ST (\\a), separating params/URI from link text
      [params_uri, rest_after_st] ->
        # For now, we ignore params (like id=) and assume the whole part is the URI
        # A more robust parser would handle `id=foo;bar:baz;` before the URI.
        uri = params_uri # Simplification: Assuming only URI is present
        uri = String.trim(uri, ";") # Handle potential trailing ;

        # Now find the end sequence \\e]8;;\\a in the rest
        case String.split(rest_after_st, @osc8_end, parts: 2) do
          # Malformed: No end sequence found
          [_] ->
            # Treat the rest as plain text (including URI and link text part)
            [{:plain, @osc8_start <> rest_after_start} | acc] # Backtrack slightly

          # Found the end sequence
          [link_text, rest_after_end] ->
            # Successfully parsed a link!
            link_acc = [{:link, uri, link_text} | acc]
            # Continue parsing the rest of the string from the top level
            parse_osc8_segments(rest_after_end, link_acc)
        end
    end
  end

  # --- Private View Rendering Helpers ---

  # Renders text content within bounds, handling OSC8 links.
  # Returns {next_y, list_of_cells}
  defp p_render_text_content(text_content, bounds) do
    if text_content == "" or bounds.width <= 0 or bounds.height <= 0 do
      {bounds.y, []} # Return empty cells list and current y
    else
      segments = parse_osc8_segments(text_content) # Commented out OSC8 parsing
      # Treat all text as plain for now
      # segments = [{:plain, text_content}]
      text_cells = p_render_text_segments(segments, bounds)
      # Assuming text rendering always takes one line for now (simplified)
      next_y = min(bounds.y + 1, bounds.y + bounds.height)
      {next_y, text_cells}
    end
  end

  # Processes a list of parsed text segments into cells.
  # Returns list_of_cells
  defp p_render_text_segments(segments, bounds) do
    {text_cells_rev, _final_col} =
      Enum.reduce(segments, {[], bounds.x}, fn segment, {cells_acc, current_col} ->
        case segment do
          {:plain, plain_text} ->
            process_text_segment(plain_text, bounds, current_col, %{}, cells_acc)
          {:link, url, link_text} ->
            link_style = %{hyperlink: url}
            process_text_segment(link_text, bounds, current_col, link_style, cells_acc)
        end
      end)
    Enum.reverse(text_cells_rev)
  end

  # Helper function to process a single text segment (plain or linked)
  # Returns {updated_cells_acc, next_col}
  defp process_text_segment(text, bounds, start_col, base_style, cells_acc) do
    text
    |> String.graphemes()
    |> Enum.reduce({cells_acc, start_col}, fn grapheme, {inner_cells_acc, current_col} ->
      # Check horizontal bounds
      if current_col >= bounds.x and current_col < (bounds.x + bounds.width) do
        # Check vertical bounds (only need to check current line `bounds.y`)
        if bounds.y < (bounds.y + bounds.height) do
          # Assume first char of grapheme is the one to render for simplicity
          [char_code | _] = String.to_charlist(grapheme)
          # TODO: Merge with existing style attributes from parent/view element if any
          cell = %{x: current_col, y: bounds.y, char: char_code, fg: 7, bg: 0, style: base_style}
          {[cell | inner_cells_acc], current_col + 1}
        else
          # Outside vertical bounds (should not happen with current logic, but good to have)
          {inner_cells_acc, current_col + 1}
        end
      else
        # Outside horizontal bounds
        {inner_cells_acc, current_col + 1}
      end
    end)
  end

  # --- End Private View Rendering Helpers ---

  # --- Helper to get terminal dimensions ---
  defp get_terminal_dimensions do
    if Mix.env() == :test do
      # Return fixed dimensions for tests if termbox isn't active
      {80, 24}
    else
      width = ExTermbox.Bindings.width()
      height = ExTermbox.Bindings.height()
      {width, height}
    end
  end

  # --- Private Event Handling Helpers ---

  # Handles mouse events, including plugin interaction
  defp p_handle_mouse_event({:mouse, _, _, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple)
    case PluginManager.handle_mouse_event(state.plugin_manager, converted_event, state.last_rendered_cells) do
      {:ok, updated_manager, :propagate} ->
        # Plugin didn't handle it, propagate to the application
        new_state = %{state | plugin_manager: updated_manager}
        case handle_event(event_tuple, new_state) do
          {:continue, final_state} -> {:noreply, final_state}
          {:stop, final_state} -> {:stop, :normal, final_state} # Propagate stop too
        end
      {:ok, updated_manager, :halt} ->
        # Plugin handled the event, stop propagation
        {:noreply, %{state | plugin_manager: updated_manager}}
      {:error, reason} -> # Handle potential errors from plugin manager
        Logger.error("[Runtime] Error during plugin mouse handling: #{inspect(reason)}. Propagating event to app.")
        case handle_event(event_tuple, state) do
          {:continue, final_state} -> {:noreply, final_state}
          {:stop, final_state} -> {:stop, :normal, final_state}
        end
    end
  end

  # Handles key events, including plugin interaction and quit key check
  defp p_handle_key_event({:key, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple)
    case PluginManager.handle_key_event(state.plugin_manager, converted_event, state.last_rendered_cells) do
      {:ok, updated_manager, commands, propagation_state} ->
        new_state = %{state | plugin_manager: updated_manager}
        state_after_commands = process_plugin_commands(new_state, commands)
        if propagation_state == :propagate do
          # Check quit keys *before* passing to app's handle_event
          if is_quit_key?(converted_event, state_after_commands.quit_keys) do
            cleanup(state_after_commands)
            {:stop, :normal, state_after_commands}
          else
            # Propagate to application's main handle_event
            case handle_event(event_tuple, state_after_commands) do
              {:continue, final_state} -> {:noreply, final_state}
              # If app returns stop, ensure cleanup happens
              {:stop, final_state} ->
                cleanup(final_state)
                {:stop, :normal, final_state}
            end
          end
        else # propagation_state == :halt
          {:noreply, state_after_commands}
        end
      {:error, reason} ->
        Logger.error("[Runtime] Error during plugin key event handling: #{inspect(reason)}. Propagating event to app.")
        # If plugin fails, still check for quit key and pass to app
        if is_quit_key?(converted_event, state.quit_keys) do
          cleanup(state)
          {:stop, :normal, state}
        else
          case handle_event(event_tuple, state) do
            {:continue, final_state} -> {:noreply, final_state}
            {:stop, final_state} ->
              cleanup(final_state)
              {:stop, :normal, final_state}
          end
        end
    end
  end

  # --- End Private Event Handling Helpers ---

  # --- Private helper for app event delegation ---
  defp handle_event(event_tuple, state) do
    # Convert the raw event tuple/map to the application event format
    app_event = Event.convert(event_tuple)

    if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :update, 2) do
      # Call the application's update function
      case state.app_module.update(app_event, state.model) do
        # App returned a new model, continue
        new_model when is_map(new_model) ->
          {:continue, %{state | model: new_model}}

        # App requested to stop
        {:stop, reason, new_model} ->
          Logger.debug("Application requested stop. Reason: #{inspect(reason)}")
          {:stop, %{state | model: new_model}}

        # Invalid return from app update
        other ->
          Logger.error("Invalid return from #{state.app_module}.update/2: #{inspect(other)}. Continuing with old state.")
          {:continue, state}
      end
    else
      # App doesn't implement update/2
      Logger.warning("Application #{state.app_module} does not implement update/2. Ignoring event: #{inspect(app_event)}")
      {:continue, state}
    end
  end

  # --- Private helper for sending plugin commands ---
  defp send_plugin_commands(commands) when is_list(commands) do
    # TODO: This IO.write might still interfere with ex_termbox. Proper solution needed.
    Enum.each(commands, &IO.write/1)
  end

  # --- Helper to Process Plugin Commands ---
  defp process_plugin_commands(state, commands) when is_list(commands) do
    Enum.reduce(commands, state, fn command, acc_state ->
      case command do
        {:paste, content} ->
          Logger.debug("[Runtime] Processing :paste command from plugin.")
          # Send the paste content as a message to the application
          updated_model = update_model(acc_state.app_module, acc_state.model, {:paste_text, content})
          %{acc_state | model: updated_model}

        # Handle other command types here in the future
        _other_command ->
          Logger.warning("[Runtime] Received unknown plugin command: #{inspect(command)}")
          acc_state # Ignore unknown commands for now
      end
    end)
  end
end
