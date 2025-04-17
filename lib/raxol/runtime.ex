defmodule Raxol.Runtime do
  @moduledoc """
  Manages the core runtime processes for a Raxol application.
  Starts and supervises the main components like EventLoop, ComponentManager, etc.
  """
  # This module acts as a GenServer, not the main Application
  use GenServer

  require Logger

  alias Raxol.Event
  alias ExTermbox.Bindings
  alias Raxol.Terminal.Registry, as: AppRegistry
  alias Raxol.Plugins.PluginManager
  alias Raxol.Plugins.ImagePlugin
  alias Raxol.Plugins.VisualizationPlugin
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.StdioInterface

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
    Logger.debug("[Runtime.start_link] Starting runtime...")
    # Extract app_module and determine app_name
    app_module = Keyword.fetch!(opts, :app_module)
    # Prefixed as it's no longer used for registration
    _app_name = get_app_name(app_module)

    # Pass {app_module, opts} to init/1
    GenServer.start_link(__MODULE__, {app_module, opts})
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
          "Failed to set image sequence in ImagePlugin: #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:stdio_message, %{type: :initialize, payload: payload}}, state) do
    Logger.info("[Runtime] Received :initialize message via stdio: #{inspect(payload)}")

    # TODO: Process initialization payload if needed (e.g., workspaceRoot, initial dimensions)
    # For now, just acknowledge and send back the 'initialized' message

    if state.stdio_interface_pid do
      StdioInterface.send_message(%{type: "initialized", payload: %{status: "Backend ready"}})
      Logger.info("[Runtime] Sent :initialized confirmation via stdio.")

      # Trigger an initial render now that the frontend is ready
      send(self(), :render)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:stdio_message, %{type: :user_input, payload: payload}}, state) do
    Logger.debug("[Runtime] Received :user_input message via stdio: #{inspect(payload)}")

    # Extract key and modifiers from the payload
    key = payload["key"]
    modifiers = payload["modifiers"] || []

    # Convert the WebView key format to the internal event format
    converted_event = %{
      type: :key,
      key: convert_webview_key(key),
      modifiers: convert_webview_modifiers(modifiers)
    }

    Logger.info("[Runtime] Converted user input: #{inspect(converted_event)}")

    # Handle the event through the existing event handling pipeline
    if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :update, 2) do
      new_model = state.app_module.update(converted_event, state.model)
      # Send render trigger to update the UI
      send(self(), :render)
      {:noreply, %{state | model: new_model}}
    else
      # Just trigger a re-render to show potential changes
      send(self(), :render)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:stdio_message, %{type: :resize_panel, payload: %{"cols" => cols, "rows" => rows}}}, state)
      when is_integer(cols) and is_integer(rows) do
    Logger.info("[Runtime] Received :resize_panel message via stdio: #{cols}x#{rows}")

    # Create a resize event to pass to the application
    resize_event = %{
      type: :resize,
      width: cols,
      height: rows
    }

    # Update model dimensions through the app's update function
    updated_model = if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :update, 2) do
      state.app_module.update(resize_event, state.model)
    else
      # If app doesn't handle resize, update width/height in model directly if they exist
      state.model
      |> Map.put(:width, cols)
      |> Map.put(:height, rows)
    end

    # Update internal width/height in state
    updated_state = %{state |
      model: updated_model,
      width: cols,
      height: rows
    }

    # Trigger a re-render with the new dimensions
    send(self(), :render)
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:stdio_message, unknown_message}, state) do
    Logger.warning("[Runtime] Received unknown message via stdio: #{inspect(unknown_message)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:render, state) do
    # Logger.debug("[Runtime.handle_info(:render)] Processing render event...")

    if state.is_vscode_extension_env do
      # VS Code extension mode - Send UI update via StdioInterface
      # Get current dimensions (use stored values since ExTermbox is not initialized)
      width = state.width
      height = state.height

      # Create bounds for rendering
      dims = %{x: 0, y: 0, width: width, height: height}

      # Update model with current dimensions before rendering
      # This follows the same pattern as the TTY mode but simplified
      dashboard_model = Map.get(state.model, :dashboard_model, nil)
      updated_model = if dashboard_model do
        grid_conf = dashboard_model.grid_config
        updated_grid_config = %{grid_conf | parent_bounds: dims}
        updated_dashboard_model = %{dashboard_model | grid_config: updated_grid_config}
        %{state.model | dashboard_model: updated_dashboard_model}
      else
        state.model
      end

      # Call the app_module's render function to get updated view
      rendered_view =
        if Code.ensure_loaded?(state.app_module) and function_exported?(state.app_module, :render, 1) do
          state.app_module.render(updated_model)
        else
          []
        end

      # Convert rendered view to cells
      cells = render_view_to_cells(rendered_view, dims)

      # Use cell_buffer to track rendering changes and avoid sending unchanged data
      cell_buffer = state.cell_buffer || ScreenBuffer.new(width, height)

      # Get changes (if cell_buffer is tracking)
      changes = ScreenBuffer.get_changes(cell_buffer, cells)

      # Prepare a simplified version of the cells for JSON transmission
      # This converts complex cell data to a more transport-friendly format
      simplified_cells = Enum.map(cells, fn %{x: x, y: y, ch: ch, fg: fg, bg: bg} ->
        # Convert ch (might be integer) to string
        char = if is_integer(ch), do: <<ch::utf8>>, else: to_string(ch)
        %{
          x: x,
          y: y,
          char: char,
          fg: fg,
          bg: bg
        }
      end)

      # Send UI update via StdioInterface
      if state.stdio_interface_pid do
        StdioInterface.send_message(%{
          type: "ui_update",
          payload: %{
            width: width,
            height: height,
            cells: simplified_cells,
            cursor: %{x: 0, y: 0} # Default cursor position
          }
        })
        Logger.debug("[Runtime.handle_info(:render)] Sent UI update via StdioInterface")
      else
        Logger.warning("[Runtime.handle_info(:render)] Cannot send UI update - StdioInterface not initialized")
      end

      # Schedule next render based on fps
      if state.fps > 0 do
        interval_ms = round(1000 / state.fps)
        Process.send_after(self(), :render, interval_ms)
      end

      # Return updated state with the new cell buffer
      {:noreply, %{state | model: updated_model, cell_buffer: cell_buffer}}
    else
      # TTY mode - ExTermbox-based rendering (existing code)
      # Check if Termbox is initialized before proceeding
      unless state.termbox_initialized do
        Logger.warning("[Runtime.handle_info(:render)] Skipping render: Termbox not initialized.")
        # Reschedule for later
        if state.fps > 0 do
          interval_ms = round(1000 / state.fps)
          Process.send_after(self(), :render, interval_ms)
        end
        {:noreply, state}
      else
        # Original ExTermbox rendering path
        # Ensure width and height are correctly fetched (handle potential {:ok, {:ok, val}})
        width =
          case Bindings.width() do
            {:ok, {:ok, w}} -> w
            {:ok, w} when is_integer(w) -> w
            _ -> state.width # Fallback or handle error
          end

        # --- Workaround: Hardcode dimensions due to ex_termbox issue ---
        height_val = 30
        Logger.warning("[Runtime.handle_info(:render)] Using HARDCODED dimensions: #{width}x#{height_val}")
        # --- End Workaround ---

        # Original dimension calculation (commented out)
        # dims_tuple =
        #   {{:ok, ExTermbox.Bindings.width()}, {:ok, ExTermbox.Bindings.height()}}
        # # Calculate cell diff and unwrap dimensions
        # {width_val, height_val} =
        #   case dims_tuple do
        #     # Handle potential double nesting from Bindings
        #     {{:ok, {:ok, w}}, {:ok, {:ok, h}}} when is_integer(w) and is_integer(h) ->
        #       Logger.debug(
        #         "[Runtime.handle_info(:render)] Correctly unwrapped double-nested dimensions: #{w}x#{h}"
        #       )
        #
        #       {w, h}
        #
        #     # Original success case: Single nesting
        #     {{:ok, w}, {:ok, h}} when is_integer(w) and is_integer(h) ->
        #       Logger.debug(
        #         "[Runtime.handle_info(:render)] Correctly unwrapped single-nested dimensions: #{w}x#{h}"
        #       )
        #
        #       {w, h}
        #
        #     # Test environment or direct integers (fallback)
        #     {w, h} when is_integer(w) and is_integer(h) ->
        #       Logger.warning(
        #         "[Runtime.handle_info(:render)] Got raw integer dimensions: #{w}x#{h}"
        #       )
        #
        #       {w, h}
        #
        #     # Error case or unexpected format: Use defaults
        #     error_or_unexpected ->
        #       Logger.error(
        #         "[Runtime.handle_info(:render)] Failed to get terminal dimensions: #{inspect(error_or_unexpected)}. Using defaults 80x24."
        #       )
        #
        #       {80, 24}
        #   end

        # Create dims map with correct values
        dims = %{x: 0, y: 0, width: width, height: height_val}

        # --- Update Model with Correct Dimensions BEFORE Rendering ---
        # This assumes the model structure is nested like state.model.dashboard_model.grid_config.parent_bounds
        # Adjust the path if necessary based on your actual MyApp.Model structure.
        # Corrected put_in syntax: access [:parent_bounds] within the grid_config map
        updated_grid_config = put_in(state.model.dashboard_model.grid_config, [:parent_bounds], dims)
        updated_dashboard_model = %{state.model.dashboard_model | grid_config: updated_grid_config}
        updated_app_model = %{state.model | dashboard_model: updated_dashboard_model}

        Logger.debug(
          "[Runtime.handle_info(:render)] Rendering view with updated dimensions: #{inspect(dims)}"
        )

        # --- DEBUG: Check render condition ---
        app_module_loaded = Code.ensure_loaded?(state.app_module)
        render_exported = function_exported?(state.app_module, :render, 1)
        Logger.debug("[Runtime DEBUG] Checking render condition: app_module=#{inspect(state.app_module)}, loaded?=#{app_module_loaded}, exported?=#{render_exported}")
        # --- END DEBUG ---

        # Render the application view using the UPDATED application's state
        view_elements =
          if app_module_loaded and render_exported do
            # Pass the current app model and grid config in a props map
            state.app_module.render(%{
              model: state.model, # Pass the App Model
              grid_config: updated_grid_config # Pass the resolved grid config
            })
          else
            Logger.error("[Runtime DEBUG] Render condition FAILED. Skipping app_module.render call.")
            [] # No render function available
          end

        {new_cells, _plugin_commands_render} = render_view_to_cells(view_elements, dims)

        # === Process cells through plugins ===
        Logger.debug(
          "[Runtime.handle_info(:render)] Processing #{length(new_cells)} cells through PluginManager..."
        )

        # Log ImagePlugin state *before* calling handle_cells
        Logger.debug(
          "[Runtime PRE] ImagePlugin state: #{inspect(Map.get(state.plugin_manager.plugins, "image"))}"
        )

        case PluginManager.handle_cells(state.plugin_manager, new_cells, state) do
          {:ok, updated_manager, final_cells, plugin_commands} ->
            # Calculate the difference based on the final processed cells
            changes = ScreenBuffer.diff(state.cell_buffer, final_cells)
            Logger.debug("[Runtime.handle_info(:render)] Calculated #{length(changes)} cell changes to apply.")

            # Apply changes to the buffer state *using the diff*
            new_buffer = ScreenBuffer.update(state.cell_buffer, changes)

            # Draw only changed cells to the terminal *using the diff*
            Enum.each(changes, fn {x, y, cell_map} ->
              # Extract char, fg, bg directly from the cell_map used in the diff
              char_code = Map.get(cell_map, :char)
              # Extract style and then fg/bg (handle potential nil style)
              style_map = Map.get(cell_map, :style, %{})
              fg = Map.get(style_map, :foreground, 7) # Default fg=7
              bg = Map.get(style_map, :background, 0) # Default bg=0
              # Ensure char_code is valid before sending
              if is_integer(char_code) do
                ExTermbox.Bindings.change_cell(x, y, char_code, fg, bg)
              else
                Logger.warning("[Runtime] Skipping invalid char_code in change_cell: #{inspect(char_code)} at (#{x},#{y})")
              end
            end)

            ExTermbox.Bindings.present()
            send_plugin_commands(plugin_commands)

            new_state = %{
              state
              | cell_buffer: new_buffer,
                last_rendered_cells: final_cells,
                plugin_manager: updated_manager
            }

            Logger.debug("[Runtime.handle_info(:render)] Finished render cycle.")
            {:noreply, new_state}
        end
      end
    end
  end

  @impl true
  def handle_info({:event, raw_event_tuple}, state) do
    # Logger.debug(
    #   "[Runtime.handle_info(:event)] Entering event processing for: #{inspect(raw_event_tuple)}"
    # )

    # Skip event processing if termbox isn't initialized
    if not state.termbox_initialized do
      # Logger.debug(
      #   "Skipping termbox event processing in non-interactive environment."
      # )

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
              {:continue, updated_state} ->
                {:noreply, updated_state}

              {:stop, updated_state} ->
                # Ensure cleanup happens on stop
                cleanup(updated_state)
                {:stop, :normal, updated_state}
            end
        end
      rescue
        e in FunctionClauseError ->
          Logger.error(
            "FunctionClauseError processing event tuple #{inspect(raw_event_tuple)}: #{inspect(e)}"
          )

          # Continue running even if one event fails
          {:noreply, state}

        e ->
          Logger.error(
            "Failed to process event tuple #{inspect(raw_event_tuple)}: #{inspect(e)}"
          )

          # Continue running even if one event fails
          {:noreply, state}
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
    Logger.info(
      "[Runtime] Terminate callback started. Reason: #{inspect(reason)}"
    )

    # Logger.debug("Raxol.Runtime terminating. Reason: #{inspect(reason)}")

    # Save dashboard layout if possible
    dashboard_model = Map.get(state.model, :dashboard_model)

    if reason == :normal and dashboard_model do
      Logger.info("Saving dashboard layout...")
      # Call a function in Dashboard to handle saving
      if function_exported?(
           Raxol.Components.Dashboard.Dashboard,
           :save_layout,
           1
         ) do
        Raxol.Components.Dashboard.Dashboard.save_layout(
          dashboard_model.widgets
        )
      else
        Logger.warning("Dashboard.save_layout/1 not found, cannot save layout.")
      end
    end

    # Ensure Termbox is shut down if it was initialized
    if Map.get(state, :termbox_initialized, false) do
      Logger.info("Shutting down Termbox during termination...")
      # Should be safe even if not polling
      ExTermbox.Bindings.stop_polling()
      ExTermbox.Bindings.shutdown()
      Logger.info("Termbox shut down during termination.")
    else
      Logger.info(
        "Skipping Termbox cleanup during termination (not initialized)."
      )
    end

    :ok
  end

  # Private functions

  defp runtime_env do
    Application.get_env(:raxol, :env, :prod)
  end

  defp get_app_name(app_module) when is_atom(app_module) do
    Module.split(app_module) |> List.last() |> String.to_atom()
  rescue
    _ -> :default
  end

  defp lookup_app(app_name) do
    # Use the GenServer API and handle its specific return value
    case AppRegistry.lookup(app_name) do
      # Value is the registered pid
      [{_registry_pid, pid}] -> {:ok, pid}
      [] -> :error
      # Handle any other unexpected return
      _ -> :error
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
    Enum.any?(quit_keys, fn quit_key ->
      # Log which quit_key from the list is being checked and the event details
      Logger.debug("[is_quit_key?] Checking event key '#{inspect(key)}' (mods: #{inspect(mods)}) against quit key '#{inspect(quit_key)}'")
      match_result = case quit_key do
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
          # Default: does not match
          false
      end
      # Log the result of this specific check
      Logger.debug("[is_quit_key?] Match result for '#{inspect(quit_key)}': #{match_result}")
      match_result # Return result for Enum.any?
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

  # === Core Rendering Logic ===

  # This is a duplicate function, so we'll comment it out and use the one defined earlier
  # defp render_view_to_cells(view_elements, dims) do
  #   Raxol.Terminal.Renderer.render_to_cells(view_elements, dims)
  # end

  # Define a render function or callback here
  # This is an example placeholder; actual implementation depends on your design
  def render(state) do
    Logger.debug("[Runtime.render] Rendering frame...")
    # 1. Get current terminal dimensions
    # 2. Call the application's `render` function
    # 3. Render the returned view elements into a cell buffer/map
    # 4. Diff against the previous buffer
    # 5. Apply changes using Termbox.change_cell
    # 6. Call Termbox.present

    # Placeholder: just return the current state
    {:noreply, state}
  end

  # Helper functions to convert WebView key format to internal format

  # Convert WebView key to internal key representation
  defp convert_webview_key(key) when is_binary(key) do
    case key do
      # Special keys mapping
      "Enter" -> :enter
      "Tab" -> :tab
      "Escape" -> :escape
      " " -> :space
      "Backspace" -> :backspace
      "Delete" -> :delete
      "up" -> :arrow_up
      "down" -> :arrow_down
      "left" -> :arrow_left
      "right" -> :arrow_right
      "Home" -> :home
      "End" -> :end
      "PageUp" -> :page_up
      "PageDown" -> :page_down
      "F1" -> :f1
      "F2" -> :f2
      "F3" -> :f3
      "F4" -> :f4
      "F5" -> :f5
      "F6" -> :f6
      "F7" -> :f7
      "F8" -> :f8
      "F9" -> :f9
      "F10" -> :f10
      "F11" -> :f11
      "F12" -> :f12
      # For single character keys (a, b, c, etc.)
      key when byte_size(key) == 1 -> String.to_charlist(key) |> hd()
      # For any other keys we don't explicitly handle
      _ -> {:unknown_key, key}
    end
  end

  # Convert WebView modifiers to internal modifier list
  defp convert_webview_modifiers(modifiers) when is_list(modifiers) do
    Enum.map(modifiers, fn mod ->
      case String.downcase(mod) do
        "ctrl" -> :ctrl
        "alt" -> :alt
        "shift" -> :shift
        "meta" -> :meta  # Command key on Mac
        _ -> :unknown
      end
    end)
  end
  defp convert_webview_modifiers(_), do: []

  # --- Private helper for app event delegation ---
  defp handle_event(event_tuple, state) do
    # Convert the raw event tuple/map to the application event format
    app_event = Event.convert(event_tuple)

    if Code.ensure_loaded?(state.app_module) and
         function_exported?(state.app_module, :update, 2) do
      # Call the application's update function
      case state.app_module.update(app_event, state.model) do
        # App returned a new model, continue
        new_model when is_map(new_model) ->
          {:continue, %{state | model: new_model}}

        # App requested to stop
        {:stop, :normal, new_model} ->
          # Handle normal termination
          Logger.info("[Runtime] Terminate callback started. Reason: :normal")
          # Trigger graceful shutdown of Termbox if needed
          if new_model.termbox_initialized, do: ExTermbox.Bindings.shutdown()
          {:stop, :normal, new_model}

        # Renamed _reason to reason as it's used
        {:stop, reason, new_model} ->
          Logger.error("[Runtime] Terminate callback started. Reason: #{inspect(reason)}")
          # Replaced undefined function call
          if new_model.termbox_initialized, do: ExTermbox.Bindings.shutdown()
          {:stop, reason, new_model}

        # Invalid return from app update
        other ->
          Logger.error(
            "Invalid return from #{state.app_module}.update/2: #{inspect(other)}. Continuing with old state."
          )

          {:continue, state}
      end
    else
      # App doesn't implement update/2
      Logger.warning(
        "Application #{state.app_module} does not implement update/2. Ignoring event: #{inspect(app_event)}"
      )

      {:continue, state}
    end
  end

  # Handles key events, including plugin interaction and quit key check
  defp p_handle_key_event({:key, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple)
    # Explicit check
    is_ctrl_c = converted_event == %{type: :key, modifiers: [:ctrl], key: ?c}

    # Ignore the very first Ctrl+C event
    if is_ctrl_c and not state.initial_ctrl_c_ignored do
      Logger.debug(
        "[Runtime.p_handle_key_event] Ignoring initial Ctrl+C event."
      )

      # Set the flag and continue without treating it as a quit key
      {:noreply, %{state | initial_ctrl_c_ignored: true}}
    else
      # Original logic (nested inside else)
      Logger.debug(
        "[Runtime.p_handle_key_event] Processing event: #{inspect(converted_event)}. Is Ctrl+C: #{is_ctrl_c}"
      )
      quit_triggered = is_quit_key?(converted_event, state.quit_keys)

      Logger.debug(
        "[Runtime.p_handle_key_event] is_quit_key? returned: #{quit_triggered}"
      )

      case PluginManager.handle_key_event(
             state.plugin_manager,
             converted_event,
             state.last_rendered_cells
           ) do
        {:ok, updated_manager, commands, propagation_state} ->
          new_state = %{state | plugin_manager: updated_manager}
          state_after_commands = process_plugin_commands(new_state, commands)
          # propagation_state == :halt
          # Plugin halted propagation
          if propagation_state == :propagate do
            # Check quit keys (using the result we calculated earlier)
            if quit_triggered do
              Logger.debug(
                "[Runtime.p_handle_key_event] Quit key detected after plugins."
              )

              cleanup(state_after_commands)
              {:stop, :normal, state_after_commands}
            else
              # Propagate to application's main handle_event
              case handle_event(event_tuple, state_after_commands) do
                {:continue, final_state} ->
                  {:noreply, final_state}

                # If app returns stop, ensure cleanup happens
                {:stop, final_state} ->
                  cleanup(final_state)
                  {:stop, :normal, final_state}
              end
            end
          else
            Logger.debug(
              "[Runtime.p_handle_key_event] Plugin halted event propagation."
            )

            {:noreply, state_after_commands}
          end

        {:error, reason} ->
          Logger.error(
            "[Runtime] Error during plugin key event handling: #{inspect(reason)}. Propagating event to app."
          )

          # If plugin fails, still check for quit key and pass to app
          if quit_triggered do
            Logger.debug(
              "[Runtime.p_handle_key_event] Quit key detected after plugin error."
            )

            cleanup(state)
            {:stop, :normal, state}
          else
            case handle_event(event_tuple, state) do
              {:continue, final_state} ->
                {:noreply, final_state}

              {:stop, final_state} ->
                cleanup(final_state)
                {:stop, :normal, final_state}
            end
          end
      end
    end
  end

  # Handles mouse events, including plugin interaction
  defp p_handle_mouse_event({:mouse, _, _, _, _} = event_tuple, state) do
    converted_event = Event.convert(event_tuple)

    case PluginManager.handle_mouse_event(
           state.plugin_manager,
           converted_event,
           state.last_rendered_cells
         ) do
      {:ok, updated_manager, :propagate} ->
        # Plugin didn't handle it, propagate to the application
        new_state = %{state | plugin_manager: updated_manager}

        case handle_event(event_tuple, new_state) do
          {:continue, final_state} -> {:noreply, final_state}
          # Propagate stop too
          {:stop, final_state} -> {:stop, :normal, final_state}
        end

      {:ok, updated_manager, :halt} ->
        # Plugin handled the event, stop propagation
        {:noreply, %{state | plugin_manager: updated_manager}}

      # Handle potential errors from plugin manager
      {:error, reason} ->
          Logger.error(
          "[Runtime] Error during plugin mouse handling: #{inspect(reason)}. Propagating event to app."
        )

        case handle_event(event_tuple, state) do
          {:continue, final_state} -> {:noreply, final_state}
          {:stop, final_state} -> {:stop, :normal, final_state}
        end
    end
  end

  # --- Helper to Process Plugin Commands ---
  defp process_plugin_commands(state, commands) when is_list(commands) do
    Enum.reduce(commands, state, fn command, acc_state ->
      case command do
        {:paste, content} ->
          Logger.debug("[Runtime] Processing :paste command from plugin.")
          # Send the paste content as a message to the application
          updated_model =
            update_model(
              acc_state.app_module,
              acc_state.model,
              {:paste_text, content}
            )

          %{acc_state | model: updated_model}

        # Handle other command types here in the future
        _other_command ->
          Logger.warning(
            "[Runtime] Received unknown plugin command: #{inspect(command)}"
          )

          # Ignore unknown commands for now
          acc_state
      end
    end)
  end

  # --- Private helper for sending plugin commands ---
  defp send_plugin_commands(commands) when is_list(commands) do
    # TODO: This IO.write might still interfere with ex_termbox. Proper solution needed.
    # Enum.each(commands, &IO.write/1) # Old version causing crash
    Logger.debug("[Runtime.send_plugin_commands] Sending commands: #{inspect commands}")

    Enum.each(commands, fn
      # Match the tuple from ImagePlugin
      {:direct_output, content} when is_binary(content) ->
        # Write the content string, not the tuple
        IO.write(content)

      # Log and ignore other command types for now
      other_command ->
        Logger.warning(
          "[Runtime.send_plugin_commands] Received unhandled command type: #{inspect(other_command)}"
        )
    end)
  end

  # --- Actual View Rendering Logic (Basic) ---
  defp render_view_to_cells(view_tree_list, dims)
       when is_list(view_tree_list) do
    # For simplicity, just create an empty result to get compilation working
    Logger.debug("[Runtime.render_view_to_cells] Called with view_tree_list and dims: #{inspect(dims)}")
    {[], []}
  end

  # Add fallback for non-list input
  defp render_view_to_cells(single_element, dims) do
    Logger.warning("[Runtime.render_view_to_cells] Called with single element, wrapping in list.")
    render_view_to_cells([single_element], dims)
  end
end
