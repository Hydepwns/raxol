defmodule Raxol.Core.Runtime.Rendering.Engine do
  @moduledoc """
  Provides the core rendering functionality for Raxol applications.

  This module is responsible for:
  * Rendering application views into screen buffers
  * Managing the rendering lifecycle
  * Coordinating with the output backends
  """

  require Logger
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
              stdio_interface_pid: nil
  end

  # --- Public API ---

  @doc "Starts the Rendering Engine process."
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(initial_state_map) when is_map(initial_state_map) do
    GenServer.start_link(__MODULE__, initial_state_map, name: __MODULE__)
  end

  # --- GenServer Callbacks ---

  # Default GenServer init implementation
  @impl true
  def init(initial_state_map) do
    Logger.info("Rendering Engine initializing...")
    state = struct!(State, initial_state_map)
    # Initialize buffer with initial dimensions
    initial_buffer = ScreenBuffer.new(state.width, state.height)
    {:ok, %{state | buffer: initial_buffer}}
  end

  @impl true
  def handle_cast(:render_frame, state) do
    # Fetch the latest model AND theme context from the Dispatcher
    case GenServer.call(state.dispatcher_pid, :get_render_context) do
      {:ok, %{model: current_model, theme_id: current_theme_id}} ->
        # Fetch the actual theme struct using the ID
        theme = Theme.get(current_theme_id) || Theme.default_theme()

        case do_render_frame(current_model, theme, state) do
          {:ok, new_state} ->
            {:noreply, new_state}

          {:error, _reason, current_state} ->
            # Logged inside do_render_frame, just keep current state
            {:noreply, current_state}
        end

      {:error, reason} ->
        Logger.error(
          "RenderingEngine failed to get render context from Dispatcher: #{inspect(reason)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:update_size, %{width: w, height: h}}, state) do
    Logger.debug("RenderingEngine received size update: #{w}x#{h}")
    new_state = %{state | width: w, height: h}
    # Optionally, resize buffer immediately or let render handle it
    # Let's resize it here
    # Create fresh buffer on resize
    resized_buffer = ScreenBuffer.new(w, h)
    {:noreply, %{new_state | buffer: resized_buffer}}
  end

  # --- Private Helpers ---

  defp do_render_frame(model, theme, state) do
    try do
      # 1. Get the view from the application
      view = state.app_module.view(model)

      # 2. Calculate layout
      dimensions = %{width: state.width, height: state.height}
      positioned_elements = LayoutEngine.apply_layout(view, dimensions)

      # 3. Render positioned elements to cells using the provided theme
      cells = UIRenderer.render_to_cells(positioned_elements, theme)

      # 4. Apply plugin transforms (if any)
      # TODO: Implement apply_plugin_transforms if needed
      # final_cells = apply_plugin_transforms(cells, state.plugin_manager)
      # Placeholder
      final_cells = cells

      # 5. Send to the appropriate output backend
      case state.environment do
        :terminal ->
          render_to_terminal(final_cells, state)

        :vscode ->
          render_to_vscode(final_cells, state)

        other ->
          Logger.error("Unknown rendering environment: #{inspect(other)}")
          {:error, :unknown_environment, state}
      end
    rescue
      error ->
        Logger.error(
          "Render error: #{inspect(error)} \n #{Exception.format_stacktrace(__STACKTRACE__)}"
        )

        {:error, {:render_error, error}, state}
    end
  end

  # --- Private Rendering Backends ---

  defp render_to_terminal(cells, state) do
    # Get current buffer or create if not exists
    screen_buffer =
      state.buffer || ScreenBuffer.new(state.width, state.height)

    # Transform cells into format {x, y, %Cell{...}}
    transformed_cells = transform_cells_for_update(cells)

    # Update the screen buffer state
    updated_buffer = ScreenBuffer.update(screen_buffer, transformed_cells)

    # Render the buffer using the Terminal Renderer
    output_string = Raxol.Terminal.Renderer.render(updated_buffer)

    # TODO: Actually send 'output' to the terminal IO
    # For now, just log it
    # Use IO.write to send the rendered output (ANSI codes) to stdout
    # This assumes the process running this code has direct access to the terminal stdout.
    # In a more complex setup, this might involve sending to a dedicated IO process.
    IO.write(output_string)

    # Return updated state with the new buffer
    {:ok, %{state | buffer: updated_buffer}}
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

    # TODO: Handle other modes if necessary

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

  defp convert_color_to_vscode(color) do
    cond do
      is_integer(color) ->
        # Handle terminal color codes
        case color do
          0 -> "black"
          1 -> "red"
          2 -> "green"
          3 -> "yellow"
          4 -> "blue"
          5 -> "magenta"
          6 -> "cyan"
          7 -> "white"
          8 -> "brightBlack"
          9 -> "brightRed"
          10 -> "brightGreen"
          11 -> "brightYellow"
          12 -> "brightBlue"
          13 -> "brightMagenta"
          14 -> "brightCyan"
          15 -> "brightWhite"
          _ -> "default"
        end

      is_tuple(color) and tuple_size(color) == 3 ->
        # Handle RGB colors
        {r, g, b} = color
        "rgb(#{r},#{g},#{b})"

      is_binary(color) ->
        # Pass through named colors or hex strings
        color

      true ->
        "default"
    end
  end

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
end
