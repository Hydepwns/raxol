defmodule Raxol.Core.Runtime.Rendering.Engine do
  @moduledoc """
  Provides the core rendering functionality for Raxol applications with functional error handling.

  This module is responsible for:
  * Rendering application views into screen buffers
  * Managing the rendering lifecycle
  * Coordinating with the output backends

  REFACTORED: All try/catch blocks replaced with functional error handling patterns.
  """

  require Raxol.Core.Runtime.Log
  use GenServer

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.Renderer, as: UIRenderer
  alias Raxol.UI.Theming.Theme

  defmodule State do
    @moduledoc false
    defstruct app_module: nil,
              dispatcher_pid: nil,
              width: 80,
              height: 24,
              # Screen buffer
              buffer: nil,
              # Default rendering target
              environment: :terminal,
              # For VSCode, etc.
              stdio_interface_pid: nil,
              # PubSub topic for LiveView rendering
              liveview_topic: nil,
              # Writer function for SSH rendering
              io_writer: nil,
              # Registry of running process components {id => pid}
              process_components: %{},
              # Whether terminal supports Mode 2026 synchronized output
              sync_output: false
  end

  # --- Public API ---

  @doc "Starts the Rendering Engine process."
  # Support both map and list initialization
  def start_link(opts \\ [])

  def start_link(initial_state_map) when is_map(initial_state_map) do
    # Convert map to keyword list and add name option
    opts = [{:name, __MODULE__} | Map.to_list(initial_state_map)]
    start_link(opts)
  end

  def start_link(opts) when is_list(opts) do
    {server_opts, manager_opts} = normalize_and_split_opts(opts)
    GenServer.start_link(__MODULE__, manager_opts, server_opts)
  end

  defp normalize_and_split_opts(opts) when is_list(opts) do
    {Keyword.take(opts, [:name, :timeout, :debug, :spawn_opt]),
     Keyword.drop(opts, [:name, :timeout, :debug, :spawn_opt])}
  end

  defp normalize_and_split_opts(_), do: {[], []}

  # --- BaseManager Callbacks ---

  # Default BaseManager init implementation
  @impl true
  def init(initial_state_map) do
    Raxol.Core.Runtime.Log.info("Rendering Engine initializing...")

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine init state map: #{inspect(initial_state_map)}"
    )

    state = struct!(State, initial_state_map)
    # Initialize buffer with initial dimensions
    initial_buffer = ScreenBuffer.new(state.width, state.height)

    sync_supported =
      state.environment == :terminal and
        Raxol.Terminal.AdvancedFeatures.supports_synchronized_output?()

    new_state = %{state | buffer: initial_buffer, sync_output: sync_supported}

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine init completed. State: #{inspect(new_state)}"
    )

    {:ok, new_state}
  end

  @impl true
  def handle_cast(:render_frame, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine received :render_frame cast. State: #{inspect(state)}"
    )

    # Fetch the latest model AND theme context from the Dispatcher
    case GenServer.call(state.dispatcher_pid, :get_render_context) do
      {:ok, %{model: current_model, theme_id: current_theme_id}} ->
        Raxol.Core.Runtime.Log.debug(
          "Rendering Engine got render context: Model=#{inspect(current_model)}, Theme=#{inspect(current_theme_id)}"
        )

        # Fetch the actual theme struct using the ID
        theme =
          Theme.get(current_theme_id) || Theme.get(Theme.default_theme_id())

        case do_render_frame(current_model, theme, state) do
          {:ok, new_state} ->
            {:noreply, new_state}

          {:error, _reason, current_state} ->
            # Logged inside do_render_frame, just keep current state
            {:noreply, current_state}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "RenderingEngine failed to get render context from Dispatcher: #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_size, %{width: w, height: h}}, state) do
    Raxol.Core.Runtime.Log.debug(
      "RenderingEngine received size update: #{w}x#{h}"
    )

    new_state = %{state | width: w, height: h}

    resized_buffer = ScreenBuffer.new(w, h)
    {:noreply, %{new_state | buffer: resized_buffer}}
  end

  @impl true
  def handle_call({:update_props, _new_props}, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  # --- Private Helpers ---

  # Functional rendering pipeline replacing try/catch
  defp do_render_frame(model, theme, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine executing do_render_frame. Model=#{inspect(model)}, Theme=#{inspect(theme)}, State=#{inspect(state)}"
    )

    with {:ok, view} <- safe_get_view(state.app_module, model),
         false <- is_nil(view),
         {:ok, positioned_elements} <- safe_apply_layout(view, state),
         :ok <- update_dispatcher_view_tree(state.dispatcher_pid, view),
         {:ok, cells} <- safe_render_to_cells(positioned_elements, theme),
         {:ok, final_cells} <- safe_apply_plugin_transforms(cells, state),
         {:ok, new_state} <- safe_render_to_backend(final_cells, state) do
      {:ok, new_state}
    else
      true ->
        # Headless agent -- no view/1, skip rendering
        {:ok, state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Render error",
          reason,
          nil,
          %{module: __MODULE__, state: state}
        )

        {:error, {:render_error, reason}, state}
    end
  end

  # Safe view retrieval using functional error handling
  defp safe_get_view(app_module, model) do
    if not function_exported?(app_module, :view, 1) do
      {:ok, nil}
    else
      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Calling app_module.view(model)"
      )

      Raxol.Core.ErrorHandling.safe_call(fn ->
        case apply(app_module, :view, [model]) do
          nil ->
            {:ok, nil}

          view ->
            resolved = resolve_process_components(view)

            Raxol.Core.Runtime.Log.debug(
              "Rendering Engine: Got view: #{inspect(resolved)}"
            )

            {:ok, resolved}
        end
      end)
      |> case do
        {:ok, result} -> result
        {:error, reason} -> {:error, {:view_error, reason}}
      end
    end
  end

  # Safe layout application using functional error handling
  defp safe_apply_layout(view, state) do
    dimensions = %{width: state.width, height: state.height}

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Calculating layout with dimensions: #{inspect(dimensions)}"
    )

    Raxol.Core.ErrorHandling.safe_call(fn ->
      positioned_elements = LayoutEngine.apply_layout(view, dimensions)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got positioned elements: #{inspect(positioned_elements)}"
      )

      {:ok, positioned_elements}
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:layout_error, reason}}
    end
  end

  # Safe cell rendering using functional error handling
  defp safe_render_to_cells(positioned_elements, theme) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Rendering to cells with theme: #{inspect(theme)}"
    )

    Raxol.Core.ErrorHandling.safe_call(fn ->
      cells = UIRenderer.render_to_cells(positioned_elements, theme)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got cells: #{inspect(cells)}"
      )

      {:ok, cells}
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:cell_rendering_error, reason}}
    end
  end

  # Safe plugin transforms using functional error handling
  defp safe_apply_plugin_transforms(cells, state) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      processed_cells = apply_plugin_transforms(cells, state)
      {:ok, processed_cells}
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, {:plugin_transform_error, reason}}
    end
  end

  # Safe backend rendering
  defp safe_render_to_backend(final_cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Sending final cells to backend: #{state.environment}"
    )

    case state.environment do
      :terminal ->
        render_to_terminal(final_cells, state)

      :vscode ->
        render_to_vscode(final_cells, state)

      :liveview ->
        render_to_liveview(final_cells, state)

      :ssh ->
        render_to_ssh(final_cells, state)

      :agent ->
        # Agent environment: buffer maintained for inspection, no output written
        updated_buffer = apply_cells_to_buffer(final_cells, state)
        {:ok, %{state | buffer: updated_buffer}}

      other ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Unknown rendering environment",
          other,
          nil,
          %{module: __MODULE__, state: state}
        )

        {:error, :unknown_environment}
    end
  end

  # --- Private Rendering Backends ---

  defp render_to_terminal(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing render_to_terminal"
    )

    updated_buffer = apply_cells_to_buffer(cells, state)

    renderer = Raxol.Terminal.Renderer.new(updated_buffer)
    output_string = Raxol.Terminal.Renderer.render(renderer)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Terminal output generated (length: #{String.length(output_string)})"
    )

    if state.sync_output do
      IO.write("\e[?2026h")
      IO.write(output_string)
      IO.write("\e[?2026l")
    else
      IO.write(output_string)
    end

    {:ok, %{state | buffer: updated_buffer}}
  end

  defp render_to_vscode(cells, state) do
    case state.stdio_interface_pid do
      nil -> {:error, :stdio_not_available}
      _ -> send_buffer_to_vscode(cells, state)
    end
  end

  defp send_buffer_to_vscode(cells, _state) do
    # Convert cells to VS Code format
    _vscode_cells =
      Enum.map(cells, fn {x, y, char, fg, bg, _attrs} ->
        %{
          x: x,
          y: y,
          char: char,
          fg: convert_color_to_vscode(fg),
          bg: convert_color_to_vscode(bg),
          bold: false,
          underline: false,
          italic: false
        }
      end)

    # Note: Additional rendering modes can be added here as needed

    # Commented out as StdioInterface is likely obsolete
    # Raxol.StdioInterface.send_message(%{
    #   type: "render",
    #   payload: %{
    #     buffer: buffer,
    #     dimensions: dimensions
    #   }
    # })
    {:ok, :rendered}
  end

  # Terminal color code mapping
  @terminal_color_map %{
    0 => "black",
    1 => "red",
    2 => "green",
    3 => "yellow",
    4 => "blue",
    5 => "magenta",
    6 => "cyan",
    7 => "white",
    8 => "brightBlack",
    9 => "brightRed",
    10 => "brightGreen",
    11 => "brightYellow",
    12 => "brightBlue",
    13 => "brightMagenta",
    14 => "brightCyan",
    15 => "brightWhite"
  }

  defp convert_color_to_vscode(color) when is_integer(color) do
    @terminal_color_map[color] || "default"
  end

  defp convert_color_to_vscode({r, g, b})
       when is_integer(r) and is_integer(g) and is_integer(b) do
    "rgb(#{r},#{g},#{b})"
  end

  defp convert_color_to_vscode(color) when is_binary(color), do: color
  defp convert_color_to_vscode(_), do: "default"

  # Helper to transform cell format
  defp transform_cells_for_update(cells) when is_list(cells) do
    Enum.map(cells, fn {x, y, char, fg, bg, attrs_list} ->
      # Simpler version: Assume format is correct, remove case
      attrs_map = Enum.into(attrs_list || [], %{}, fn atom -> {atom, true} end)

      cell_attrs =
        %{
          foreground: fg,
          background: bg
        }
        |> Map.merge(Map.take(attrs_map, [:bold, :underline, :italic]))

      # Directly create cell using full name and correct key :style
      cell = %Raxol.Terminal.Cell{char: char, style: cell_attrs}
      {x, y, cell}
    end)
  end

  # --- LiveView Backend ---

  defp render_to_liveview(cells, state) do
    updated_buffer = apply_cells_to_buffer(cells, state)
    html = Raxol.LiveView.TerminalBridge.buffer_to_html(updated_buffer)

    if state.liveview_topic && Code.ensure_loaded?(Phoenix.PubSub) do
      Phoenix.PubSub.broadcast(
        Raxol.PubSub,
        state.liveview_topic,
        {:render_update, html}
      )
    end

    {:ok, %{state | buffer: updated_buffer}}
  end

  # --- SSH Backend ---

  defp render_to_ssh(cells, state) do
    updated_buffer = apply_cells_to_buffer(cells, state)

    renderer = Raxol.Terminal.Renderer.new(updated_buffer)
    output_string = Raxol.Terminal.Renderer.render(renderer)

    write_output(state.io_writer, output_string, state.sync_output)

    {:ok, %{state | buffer: updated_buffer}}
  end

  defp write_output(writer, output, true) when is_function(writer, 1) do
    writer.("\e[?2026h")
    writer.(output)
    writer.("\e[?2026l")
  end

  defp write_output(writer, output, _sync) when is_function(writer, 1) do
    writer.(output)
  end

  defp write_output(_, _, _) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "SSH render: no io_writer configured",
      %{}
    )
  end

  # Shared helper: transforms raw cells and writes them into a ScreenBuffer.
  defp apply_cells_to_buffer(cells, state) do
    screen_buffer = state.buffer || ScreenBuffer.new(state.width, state.height)
    transformed_cells = transform_cells_for_update(cells)

    Enum.reduce(transformed_cells, screen_buffer, fn {x, y, cell}, buffer ->
      style = extract_cell_style(cell)
      ScreenBuffer.write_char(buffer, x, y, cell.char || " ", style)
    end)
  end

  defp extract_cell_style(cell) do
    case Map.get(cell, :style) do
      nil ->
        %{
          foreground: Map.get(cell, :foreground),
          background: Map.get(cell, :background)
        }

      cell_style when is_map(cell_style) ->
        cell_style

      _ ->
        nil
    end
  end

  # --- Process Component Resolution ---

  defp resolve_process_components(
         %{type: :process_component, module: mod, props: props} = node
       ) do
    id = Map.get(node, :id, "pc-#{inspect(mod)}")

    pid =
      case DynamicSupervisor.start_child(
             Raxol.DynamicSupervisor,
             {Raxol.Core.Runtime.ProcessComponent,
              [module: mod, props: props, id: id]}
           ) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
        _ -> nil
      end

    if pid do
      Raxol.Core.Runtime.ProcessComponent.get_render_tree(pid, %{})
    else
      %{type: :text, content: "[#{id}: failed to start]", style: %{}}
    end
  end

  defp resolve_process_components(%{children: children} = node)
       when is_list(children) do
    %{node | children: Enum.map(children, &resolve_process_components/1)}
  end

  defp resolve_process_components(node), do: node

  defp apply_plugin_transforms(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Applying plugin transforms to #{length(cells)} cells"
    )

    # Get the plugin manager from the dispatcher
    case get_plugin_manager_from_dispatcher(state.dispatcher_pid) do
      {:ok, %Raxol.Plugins.Manager{} = plugin_manager} ->
        # Create emulator state context for plugins
        emulator_state = %{
          width: state.width,
          height: state.height,
          environment: state.environment,
          buffer: state.buffer
        }

        # Process cells through plugins using CellProcessor
        {:ok, updated_manager, processed_cells, collected_commands} =
          Raxol.Plugins.CellProcessor.process(
            plugin_manager,
            cells,
            emulator_state
          )

        # Execute any collected commands (like escape sequences)
        execute_plugin_commands(collected_commands)

        # Update plugin manager state in dispatcher if needed
        _ =
          update_plugin_manager_in_dispatcher(
            state.dispatcher_pid,
            updated_manager
          )

        Raxol.Core.Runtime.Log.debug(
          "Rendering Engine: Plugin transforms applied. Processed cells: #{length(processed_cells)}, Commands: #{length(collected_commands)}"
        )

        processed_cells

      {:ok, _non_struct_manager} ->
        # Plugin manager is a PID or other non-struct value; skip cell processing
        Raxol.Core.Runtime.Log.debug(
          "Rendering Engine: Plugin manager is not a Manager struct, skipping cell processing"
        )

        cells

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Rendering Engine: Could not get plugin manager for transforms",
          %{reason: reason, module: __MODULE__}
        )

        # Return original cells if plugin manager unavailable
        cells
    end
  end

  # Functional wrapper for dispatcher plugin manager retrieval
  defp get_plugin_manager_from_dispatcher(dispatcher_pid)
       when is_pid(dispatcher_pid) do
    with {:ok, response} <-
           safe_genserver_call(dispatcher_pid, :get_plugin_manager, 5000),
         {:ok, plugin_manager} <- validate_plugin_manager_response(response) do
      {:ok, plugin_manager}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_plugin_manager_from_dispatcher(_), do: {:error, :invalid_dispatcher}

  # Safe GenServer call wrapper using functional error handling
  defp safe_genserver_call(pid, message, timeout) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      GenServer.call(pid, message, timeout)
    end)
    |> case do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Rendering Engine: Error getting plugin manager from dispatcher",
          reason,
          nil,
          %{dispatcher_pid: pid}
        )

        {:error, :dispatcher_error}
    end
  end

  # Validate plugin manager response
  defp validate_plugin_manager_response({:ok, plugin_manager}) do
    {:ok, plugin_manager}
  end

  defp validate_plugin_manager_response({:error, reason}) do
    {:error, reason}
  end

  defp validate_plugin_manager_response(_) do
    {:error, :unexpected_response}
  end

  # Helper function to execute plugin commands (like escape sequences)
  defp execute_plugin_commands(commands)
       when is_list(commands) and length(commands) > 0 do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing #{length(commands)} plugin commands"
    )

    Enum.each(commands, fn command ->
      case is_binary(command) do
        true ->
          # Write escape sequences or other commands directly to output
          IO.write(command)

        false ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Rendering Engine: Unknown plugin command format",
            %{command: command}
          )
      end
    end)
  end

  defp execute_plugin_commands(_), do: :ok

  # Send the view tree to Dispatcher for event bubbling
  defp update_dispatcher_view_tree(dispatcher_pid, view)
       when is_pid(dispatcher_pid) do
    GenServer.cast(dispatcher_pid, {:update_view_tree, view})
    :ok
  end

  defp update_dispatcher_view_tree(_, _), do: :ok

  # Functional wrapper for dispatcher plugin manager updates
  defp update_plugin_manager_in_dispatcher(dispatcher_pid, updated_manager)
       when is_pid(dispatcher_pid) do
    case safe_genserver_cast(
           dispatcher_pid,
           {:update_plugin_manager, updated_manager}
         ) do
      {:ok, :ok} ->
        :ok

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Rendering Engine: Error updating plugin manager in dispatcher",
          reason,
          nil,
          %{dispatcher_pid: dispatcher_pid}
        )

        {:error, reason}
    end
  end

  defp update_plugin_manager_in_dispatcher(_, _),
    do: {:error, :invalid_dispatcher}

  # Safe GenServer cast wrapper using functional error handling
  defp safe_genserver_cast(pid, message) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      GenServer.cast(pid, message)
      :ok
    end)
  end
end
