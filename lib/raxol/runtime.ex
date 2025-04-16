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
  def handle_info(:render, state) do
    Logger.debug("[Runtime.handle_info(:render)] Starting render cycle...")
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

  # --- Actual View Rendering Logic (Basic) ---
  defp render_view_to_cells(view_tree_list, dims)
       when is_list(view_tree_list) do
    initial_bounds = %{x: 0, y: 0, width: dims.width, height: dims.height}
    initial_acc = %{cells: [], commands: []}

    # Iterate over the list of top-level elements from Dashboard.render/1
    final_acc =
      Enum.reduce(view_tree_list, initial_acc, fn element, accumulated_acc ->
        # Process each element. Note: y position tracking might need refinement
        # if elements are expected to stack vertically at the top level.
        # For now, assume elements are positioned absolutely via bounds or don't stack.
        # Pass inner acc?
        {_y_after_element, _element_acc} =
          process_view_element(element, initial_bounds, %{
            accumulated_acc
            | cells: [],
              commands: []
          })

        # No, pass the outer accumulator to merge results
        # process_view_element needs the parent accumulator to add its cells/commands to.
        # {y_after_element, element_acc} = process_view_element(element, initial_bounds, accumulated_acc)
        # Let's rethink this. Each top-level element should render independently into the buffer
        # based on its bounds. The accumulator should just collect all cells/commands.

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
      "[Runtime.render_view_to_cells] Finished. Cells: #{length(cells)}, Commands: #{length(plugin_commands)}"
    )

    {cells, plugin_commands}
  end

  # Add fallback for non-list input just in case
  defp render_view_to_cells(single_element, dims) do
    Logger.warning(
      "[Runtime.render_view_to_cells] Called with single element, expected list. Wrapping in list."
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

          # Recursive call expects acc map, returns {y_after_child, child_acc_map}
          # Reset inner acc?
          {y_after_child, child_acc} =
            process_view_element(child, child_bounds, %{
              accumulated_acc
              | cells: [],
                commands: []
            })

          # No, pass the accumulated map directly
          # {y_after_child, child_acc} =
          #  process_view_element(child, child_bounds, accumulated_acc)

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

              # Reset inner?
              {next_y_after_child, child_acc} =
                process_view_element(child, current_child_bounds, %{
                  accumulated_acc
                  | cells: [],
                    commands: []
                })

              # No, pass accumulated
              # {next_y_after_child, child_acc} =
              #  process_view_element(child, current_child_bounds, accumulated_acc)

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
      %{type: :box, opts: opts, children: children} when is_list(children) ->
        # ... (bounds calculation same as before) ...
        box_rel_x = Keyword.get(opts, :x, 0)
        box_rel_y = Keyword.get(opts, :y, 0)
        box_abs_x = bounds.x + box_rel_x
        box_abs_y = bounds.y + box_rel_y
        box_width = Keyword.get(opts, :width, bounds.width - box_rel_x)
        box_height = Keyword.get(opts, :height, bounds.height - box_rel_y)
        clipped_x = max(bounds.x, box_abs_x)
        clipped_y = max(bounds.y, box_abs_y)

        clipped_width =
          max(0, min(box_width, bounds.x + bounds.width - clipped_x))

        clipped_height =
          max(0, min(box_height, bounds.y + bounds.height - clipped_y))

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

      # Handle :chart data map by creating a placeholder cell
      # Match the structure coming from Dashboard: %{type: :chart, data: ..., component_opts: ..., bounds: ...}
      # Make the match more explicit, including keys passed from Dashboard
      %{
        type: :chart,
        # Match but ignore
        id: _id,
        # Match but ignore
        title: _title,
        # Match but ignore
        grid_spec: _grid_spec,
        data: data,
        component_opts: component_opts,
        bounds: element_bounds
      } = _widget_config ->
        # Create placeholder cell with data, component_opts (as opts), using bounds from element
        placeholder_cell = %{
          type: :placeholder,
          value: :chart,
          data: data,
          # Pass component_opts as opts
          opts: component_opts,
          # Use bounds from the element map
          bounds: element_bounds
        }

        updated_acc = %{acc | cells: acc.cells ++ [placeholder_cell]}
        # Assume placeholder occupies no vertical space itself
        {element_bounds.y, updated_acc}

      # Handle :treemap data map by creating a placeholder cell
      # Match the structure coming from Dashboard: %{type: :treemap, data: ..., component_opts: ..., bounds: ...}
      # Make the match more explicit, including keys passed from Dashboard
      %{
        type: :treemap,
        # Match but ignore
        id: _id,
        # Match but ignore
        title: _title,
        # Match but ignore
        grid_spec: _grid_spec,
        data: data,
        component_opts: component_opts,
        bounds: element_bounds
      } = _widget_config ->
        # Create placeholder cell with data, component_opts (as opts), using bounds from element
        placeholder_cell = %{
          type: :placeholder,
          value: :treemap,
          data: data,
          # Pass component_opts as opts
          opts: component_opts,
          # Use bounds from the element map
          bounds: element_bounds
        }

        updated_acc = %{acc | cells: acc.cells ++ [placeholder_cell]}
        # Assume placeholder occupies no vertical space itself
        {element_bounds.y, updated_acc}

      # Handle :image data map by creating a placeholder cell
      # Match the structure coming from Dashboard
      # Capture the whole map for logging
      %{
        type: :image,
        # Match but ignore
        id: _id,
        # Match but ignore
        title: _title,
        # Match but ignore
        grid_spec: _grid_spec,
        # data: data, # Data is optional/not present in MyApp.init
        component_opts: component_opts,
        bounds: element_bounds
      } = _widget_config ->
        # Log the incoming opts
        Logger.debug(
          "[Runtime.process_view_element] Matched :image widget. Incoming component_opts: #{inspect(component_opts)}"
        )

        # Create placeholder cell
        placeholder_cell = %{
          type: :placeholder,
          value: :image,
          # data: data, # Omit data key for now
          # Pass component_opts as opts
          opts: component_opts,
          # Use bounds from the element map
          bounds: element_bounds
        }

        # Log the created placeholder
        Logger.debug(
          "[Runtime.process_view_element] Created :image placeholder cell: #{inspect(placeholder_cell)}"
        )

        updated_acc = %{acc | cells: acc.cells ++ [placeholder_cell]}
        # Assume placeholder occupies no vertical space itself
        {element_bounds.y, updated_acc}

      # Handle :placeholder (Should not be generated by view, but maybe by plugin?)
      %{type: :placeholder} = placeholder ->
        # Placeholders should be handled by PluginManager, not rendered directly.
        # Treat it as taking up no space and pass it through.
        Logger.debug(
          "[Runtime.process_view_element] Passing through existing placeholder: #{inspect(placeholder)}"
        )

        updated_acc = %{acc | cells: acc.cells ++ [placeholder]}
        {bounds.y, updated_acc}

      # Catch-all for other map types (log warning)
      element when is_map(element) ->
        Logger.warning(
          "[Runtime.process_view_element] Unhandled view element type: #{inspect(element)}"
        )

        # Return original accumulator, skip element
        {bounds.y, acc}

      # Handle strings directly (assuming they are meant as simple text)
      element when is_binary(element) ->
        Logger.debug(
          "[Runtime.process_view_element] Handling raw string: \\\"#{element}\\\""
        )

        {next_y, text_cells} = p_render_text_content(element, bounds)
        {next_y, %{acc | cells: acc.cells ++ text_cells}}

      # Catch-all for other unexpected element types
      _other ->
        Logger.warning(
          "[Runtime.process_view_element] Encountered unexpected element type: #{inspect(element)}"
        )

        {bounds.y, acc}
    end
  end

  # --- Helper for OSC 8 Parsing ---

  @osc8_start "\\e]8;"
  # BEL character (ASCII 7) acts as ST (String Terminator)
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
        # Treat the rest as plain text, including the incomplete start sequence
        [{:plain, @osc8_start <> rest_after_start} | acc]

      # Found ST (\\a), separating params/URI from link text
      [params_uri, rest_after_st] ->
        # For now, we ignore params (like id=) and assume the whole part is the URI
        # A more robust parser would handle `id=foo;bar:baz;` before the URI.
        # Simplification: Assuming only URI is present
        uri = params_uri
        # Handle potential trailing ;
        uri = String.trim(uri, ";")

        # Now find the end sequence \\e]8;;\\a in the rest
        case String.split(rest_after_st, @osc8_end, parts: 2) do
          # Malformed: No end sequence found
          [_] ->
            # Treat the rest as plain text (including URI and link text part)
            # Backtrack slightly
            [{:plain, @osc8_start <> rest_after_start} | acc]

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
      # Return empty cells list and current y
      {bounds.y, []}
    else
      # Commented out OSC8 parsing
      segments = parse_osc8_segments(text_content)
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
      # Check horizontal bounds
      if current_col >= bounds.x and current_col < bounds.x + bounds.width do
        # Check vertical bounds (only need to check current line `bounds.y`)
        if bounds.y < bounds.y + bounds.height do
          # Assume first char of grapheme is the one to render for simplicity
          [char_code | _] = String.to_charlist(grapheme)

          # TODO: Merge with existing style attributes from parent/view element if any
          cell_map = %{
            # Remove x, y from map as they are now in the tuple
            # x: current_col,
            # y: bounds.y,
            char: char_code,
            fg: 7,
            bg: 0,
            style: base_style
          }

          # Create the {x, y, cell_map} tuple
          cell_tuple = {current_col, bounds.y, cell_map}

          {[cell_tuple | inner_cells_acc], current_col + 1}
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

  # --- Private Event Handling Helpers ---

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

    # End of added else block
  end

  # --- End Private Event Handling Helpers ---

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

  @impl true
  def init({app_module, opts}) do
    Logger.debug("[Runtime.init] Initializing runtime for #{inspect(app_module)}...")
    # Determine app name for registration
    app_name = get_app_name(app_module)

    # Initialize ExTermbox - Important: MUST happen before most other actions
    case Bindings.init() do
      {:ok, :ok} -> Logger.debug("[Runtime.init] ExTermbox initialized successfully.")
      {:error, reason} ->
        Logger.error("[Runtime.init] Failed to initialize ExTermbox: #{inspect(reason)}")
        # If Termbox fails, we probably can't continue.
        exit({:shutdown, {:failed_to_init_termbox, reason}})
      other ->
        Logger.warning("[Runtime.init] Unexpected result from Bindings.init(): #{inspect(other)}")
    end

    Bindings.select_output_mode(256) # Use 256 color mode

    # Initialize application state by calling the app_module's init function
    initial_model =
      if function_exported?(app_module, :init, 1) do
        # Pass runtime options to the app's init function
        app_module.init(opts)
      else
        %{} # Default empty model if init/1 is not defined
      end

    # Register the runtime process using the unique app_name
    AppRegistry.register_app(self(), app_name)

    # Extract options or set defaults
    title = Keyword.get(opts, :title, "Raxol Application")
    fps = Keyword.get(opts, :fps, 60)
    quit_keys = Keyword.get(opts, :quit_keys, [:ctrl_c])
    _debug_mode = Keyword.get(opts, :debug, false)

    # Convert quit keys to standardized internal format
    processed_quit_keys = Enum.map(quit_keys, &Event.parse_key_event/1)
    Logger.debug("[Runtime.init] Using quit_keys: #{inspect(processed_quit_keys)}")

    # --- Initialize Plugin System ---
    # Define default plugins and their initial states/config
    plugins = [
      {ImagePlugin, %{config: %{}, state: %{image_escape_sequence: nil}}}, # Example config/state
      {VisualizationPlugin, %{config: %{}, state: %{}}} # Example
      # Add other plugins here
    ]

    # Start the PluginManager with the defined plugins
    case PluginManager.start(plugins) do
      {:ok, plugin_manager} ->
        Logger.debug("[Runtime.init] PluginManager started successfully.")

        # --- Prepare initial state ---
        initial_state = %{
          app_module: app_module,
          app_name: app_name,
          model: initial_model,
          title: title,
          fps: fps,
          width: 0, # Initialize width
          height: 0, # Initialize height
          quit_keys: processed_quit_keys,
          cell_buffer: ScreenBuffer.new(),
          plugin_manager: plugin_manager, # Store the initialized PluginManager
          mouse_enabled: false # Start with mouse events disabled
          # Add other initial state fields here if needed
        }

        # Trigger the Termbox event loop (blocks within Termbox.run/1)
        Logger.debug("[Runtime.init] Calling Termbox.run(self())...")
        Termbox.run(self())
        Logger.debug("[Runtime.init] Termbox.run(self()) returned.") # This might not be reached if Termbox blocks indefinitely

        # This message is sent after Termbox initialization to kick off the first render cycle.
        # We use handle_continue for this initialization pattern.
        {:ok, initial_state, {:continue, :after_init}}

      {:error, reason} ->
        Logger.error("[Runtime.init] Failed to start PluginManager: #{inspect(reason)}")
        exit({:shutdown, {:failed_to_start_plugin_manager, reason}})
    end
  end

  # === Lifecycle Callbacks ===

  @impl true
  def handle_continue(:after_init, state) do
    Logger.debug("[Runtime.handle_continue(:after_init)] Post-initialization setup...")
    # Setup render timer
    if state.fps > 0 do
      interval_ms = round(1000 / state.fps)
      :timer.send_interval(interval_ms, self(), :render)
      Logger.debug("[Runtime.handle_continue(:after_init)] Render timer started with interval #{interval_ms}ms.")
    else
      # Optionally trigger a single initial render if fps is 0
      send(self(), :render)
      Logger.debug("[Runtime.handle_continue(:after_init)] FPS is 0, triggering single initial render.")
    end

    # Enable mouse events if needed (example)
    # if Keyword.get(state.opts, :mouse, false) do
    #   Bindings.select_input_mode([:esc, :mouse])
    #   Logger.debug("Mouse input mode enabled.")
    #   {:noreply, %{state | mouse_enabled: true}}
    # else
    #   Bindings.select_input_mode([:esc]) # Default: Escape sequences only
    #   Logger.debug("Default input mode (ESC) enabled.")
    #   {:noreply, state}
    # end
    # Defaulting to just ESC for now
    Bindings.select_input_mode([:esc])
    Logger.debug("[Runtime.handle_continue(:after_init)] Default input mode (ESC) enabled.")

    {:noreply, state}
  end

  # === Core Rendering Logic ===

  defp render_view_to_cells(view_elements, dims) do
    Raxol.Terminal.Renderer.render_to_cells(view_elements, dims)
  end

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
end
