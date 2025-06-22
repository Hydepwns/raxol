defmodule Raxol.Core.Runtime.Rendering.Engine do
  @moduledoc """
  Provides the core rendering functionality for Raxol applications.

  This module is responsible for:
  * Rendering application views into screen buffers
  * Managing the rendering lifecycle
  * Coordinating with the output backends
  """

  require Raxol.Core.Runtime.Log
  use GenServer
  import Raxol.Guards
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
              stdio_interface_pid: nil
  end

  # --- Public API ---

  @doc "Starts the Rendering Engine process."
  @impl true
  def start_link(initial_state_map) when map?(initial_state_map) do
    GenServer.start_link(__MODULE__, initial_state_map, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  # Default GenServer init implementation
  @impl GenServer
  def init(initial_state_map) do
    Raxol.Core.Runtime.Log.info("Rendering Engine initializing...")

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine init state map: #{inspect(initial_state_map)}"
    )

    state = struct!(State, initial_state_map)
    # Initialize buffer with initial dimensions
    initial_buffer = ScreenBuffer.new(state.width, state.height)
    new_state = %{state | buffer: initial_buffer}

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

  @impl GenServer
  def handle_cast({:update_size, %{width: w, height: h}}, state) do
    Raxol.Core.Runtime.Log.debug(
      "RenderingEngine received size update: #{w}x#{h}"
    )

    new_state = %{state | width: w, height: h}

    resized_buffer = ScreenBuffer.new(w, h)
    {:noreply, %{new_state | buffer: resized_buffer}}
  end

  @impl GenServer
  def handle_call({:update_props, _new_props}, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  # --- Private Helpers ---

  defp do_render_frame(model, theme, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine executing do_render_frame. Model=#{inspect(model)}, Theme=#{inspect(theme)}, State=#{inspect(state)}"
    )

    try do
      # 1. Get the view from the application
      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Calling app_module.view(model)"
      )

      view = state.app_module.view(model)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got view: #{inspect(view)}"
      )

      # 2. Calculate layout
      dimensions = %{width: state.width, height: state.height}

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Calculating layout with dimensions: #{inspect(dimensions)}"
      )

      positioned_elements = LayoutEngine.apply_layout(view, dimensions)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got positioned elements: #{inspect(positioned_elements)}"
      )

      # 3. Render positioned elements to cells using the provided theme
      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Rendering to cells with theme: #{inspect(theme)}"
      )

      cells = UIRenderer.render_to_cells(positioned_elements, theme)

      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Got cells: #{inspect(cells)}"
      )

      # 4. Apply plugin transforms (if any)
      final_cells = apply_plugin_transforms(cells, state)

      # 5. Send to the appropriate output backend
      Raxol.Core.Runtime.Log.debug(
        "Rendering Engine: Sending final cells to backend: #{state.environment}"
      )

      case state.environment do
        :terminal ->
          render_to_terminal(final_cells, state)

        :vscode ->
          render_to_vscode(final_cells, state)

        other ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "Unknown rendering environment",
            other,
            nil,
            %{module: __MODULE__, state: state}
          )

          {:error, :unknown_environment, state}
      end
    rescue
      error ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Render error",
          error,
          __STACKTRACE__,
          %{module: __MODULE__, state: state}
        )

        {:error, {:render_error, error}, state}
    end
  end

  # --- Private Rendering Backends ---

  defp render_to_terminal(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing render_to_terminal. State: #{inspect(state)}"
    )

    # Get current buffer or create if not exists
    screen_buffer =
      state.buffer || ScreenBuffer.new(state.width, state.height)

    # Transform cells into format {x, y, %Cell{...}}
    transformed_cells = transform_cells_for_update(cells)

    # Update the screen buffer state
    updated_buffer = ScreenBuffer.update(screen_buffer, transformed_cells)

    # Render the buffer using the Terminal Renderer
    output_string = Raxol.Terminal.Renderer.render(updated_buffer)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Terminal output generated (length: #{String.length(output_string)})"
    )

    # Send rendered output (ANSI codes) to stdout
    # This assumes the process running this code has direct access to the terminal stdout.
    # In a more complex setup, this might involve sending to a dedicated IO process.
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Writing output string to IO"
    )

    IO.write(output_string)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Finished writing output string to IO"
    )

    # Return updated state with the new buffer
    updated_state_with_buffer = %{state | buffer: updated_buffer}

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: render_to_terminal complete. New state: #{inspect(updated_state_with_buffer)}"
    )

    {:ok, updated_state_with_buffer}
  end

  defp render_to_vscode(cells, state) do
    if state.stdio_interface_pid do
      send_buffer_to_vscode(cells, state)
    else
      {:error, :stdio_not_available, state}
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
    :ok
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

  defp convert_color_to_vscode(color) when integer?(color) do
    @terminal_color_map[color] || "default"
  end

  defp convert_color_to_vscode({r, g, b}) when integer?(r) and integer?(g) and integer?(b) do
    "rgb(#{r},#{g},#{b})"
  end

  defp convert_color_to_vscode(color) when binary?(color), do: color
  defp convert_color_to_vscode(_), do: "default"

  # Helper to transform cell format
  defp transform_cells_for_update(cells) when list?(cells) do
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

  defp apply_plugin_transforms(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Applying plugin transforms to #{length(cells)} cells"
    )

    # Get the plugin manager from the dispatcher
    case get_plugin_manager_from_dispatcher(state.dispatcher_pid) do
      {:ok, plugin_manager} ->
        # Create emulator state context for plugins
        emulator_state = %{
          width: state.width,
          height: state.height,
          environment: state.environment,
          buffer: state.buffer
        }

        # Process cells through plugins using CellProcessor
        case Raxol.Plugins.CellProcessor.process(plugin_manager, cells, emulator_state) do
          {:ok, updated_manager, processed_cells, collected_commands} ->
            # Execute any collected commands (like escape sequences)
            execute_plugin_commands(collected_commands)

            # Update plugin manager state in dispatcher if needed
            update_plugin_manager_in_dispatcher(state.dispatcher_pid, updated_manager)

            Raxol.Core.Runtime.Log.debug(
              "Rendering Engine: Plugin transforms applied. Processed cells: #{length(processed_cells)}, Commands: #{length(collected_commands)}"
            )

            processed_cells

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "Rendering Engine: Plugin transform error",
              reason,
              nil,
              %{module: __MODULE__, cells_count: length(cells)}
            )

            # Return original cells on error
            cells
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Rendering Engine: Could not get plugin manager for transforms",
          %{reason: reason, module: __MODULE__}
        )

        # Return original cells if plugin manager unavailable
        cells
    end
  end

  # Helper function to get plugin manager from dispatcher
  defp get_plugin_manager_from_dispatcher(dispatcher_pid) when pid?(dispatcher_pid) do
    try do
      case GenServer.call(dispatcher_pid, :get_plugin_manager, 5000) do
        {:ok, plugin_manager} -> {:ok, plugin_manager}
        {:error, reason} -> {:error, reason}
        _ -> {:error, :unexpected_response}
      end
    rescue
      e ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Rendering Engine: Error getting plugin manager from dispatcher",
          e,
          nil,
          %{dispatcher_pid: dispatcher_pid}
        )
        {:error, :dispatcher_error}
    end
  end

  defp get_plugin_manager_from_dispatcher(_), do: {:error, :invalid_dispatcher}

  # Helper function to execute plugin commands (like escape sequences)
  defp execute_plugin_commands(commands) when list?(commands) and length(commands) > 0 do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing #{length(commands)} plugin commands"
    )

    Enum.each(commands, fn command ->
      if binary?(command) do
        # Write escape sequences or other commands directly to output
        IO.write(command)
      else
        Raxol.Core.Runtime.Log.warning_with_context(
          "Rendering Engine: Unknown plugin command format",
          %{command: command}
        )
      end
    end)
  end

  # Helper function to update plugin manager state in dispatcher
  defp update_plugin_manager_in_dispatcher(dispatcher_pid, updated_manager)
       when pid?(dispatcher_pid) do
    try do
      GenServer.cast(dispatcher_pid, {:update_plugin_manager, updated_manager})
    rescue
      e ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Rendering Engine: Error updating plugin manager in dispatcher",
          e,
          nil,
          %{dispatcher_pid: dispatcher_pid}
        )
    end
  end
end
