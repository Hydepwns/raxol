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
  alias Raxol.Terminal.Renderer

  # Default GenServer init implementation
  @impl true
  def init(init_arg) do
    Logger.info("Rendering Engine initializing...")
    {:ok, init_arg}
  end

  @doc """
  Renders a complete frame for the application.

  This function:
  1. Processes the view tree into a collection of cells
  2. Applies plugins transforms to the cells
  3. Writes the cells to the screen buffer
  4. Sends the buffer to the appropriate output backend

  ## Parameters
  - `state`: The current application state

  ## Returns
  `{:ok, updated_state}` if rendering succeeded,
  `{:error, reason, state}` otherwise.
  """
  def render_frame(state) do
    try do
      # Get the view from the application
      _view = state.app_module.view(state.model)

      # Process the view into cells
      cells = []
      component_state = state.components

      # Apply plugin cell transforms if any
      # cells = # Commented out as cells is temp empty
      #   if state.plugin_manager do
      #     apply_plugin_transforms(cells, state.plugin_manager)
      #   else
      #     cells
      #   end

      # Update component state
      updated_state = %{state | components: component_state}

      # Send to the appropriate output backend
      case state.environment do
        :terminal ->
          render_to_terminal(updated_state)

        :vscode ->
          render_to_vscode(cells, updated_state)

        other ->
          Logger.error("Unknown rendering environment: #{inspect(other)}")
          {:error, :unknown_environment, updated_state}
      end
    rescue
      error ->
        Logger.error("Render error: #{inspect(error)}")
        {:error, {:render_error, error}, state}
    end
  end

  @doc """
  Processes a view tree into a collection of renderable cells.

  This takes the element tree from the application's view function
  and converts it into a flat list of cells that can be rendered
  to the screen buffer.

  ## Parameters
  - `view`: The element tree from the application's view function
  - `component_state`: The current component state

  ## Returns
  A tuple of `{cells, updated_component_state}`.
  """
  # def process_view(view, component_state) do
  #   # Process the view tree to create cells
  #   {cells, updated_component_state} =
  #     Element.to_cells(view, %{
  #       width: 0,
  #       height: 0,
  #       x: 0,
  #       y: 0,
  #       components: component_state,
  #       theme: Theme.current()
  #     })
  #
  #   # Return cells and the updated component state
  #   {cells, updated_component_state}
  # end

  # Private functions

  defp render_to_terminal(state) do
    # Get current buffer or create if not exists
    screen_buffer =
      state.buffer || ScreenBuffer.new(state.width, state.height)

    # Transform cells into format {x, y, %Cell{...}}
    # Ensure cells is a list before transforming
    # Note: 'buffer' here was likely intended to be 'cells' from a previous stage
    # Using state.buffer temporarily, needs review if cells are passed differently.
    transformed_cells = if is_list(state.buffer), do: transform_cells_for_update(state.buffer), else: []

    # Update the screen buffer state
    updated_buffer = ScreenBuffer.update(screen_buffer, transformed_cells)

    # Render the buffer using the Terminal Renderer
    renderer = Raxol.Terminal.Renderer.new(updated_buffer)
    output = Raxol.Terminal.Renderer.render(renderer)

    # TODO: Actually send 'output' to the terminal IO
    # For now, just log it
    Logger.debug("Terminal Output (HTML?):\n#{output}")

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

  defp send_buffer_to_vscode(cells, state) do
    # Convert cells to VS Code format
    vscode_cells =
      Enum.map(cells, fn {x, y, ch, fg, bg, attrs} ->
        %{
          x: x,
          y: y,
          char: ch,
          fg: convert_color_to_vscode(fg),
          bg: convert_color_to_vscode(bg),
          bold: Enum.member?(attrs || [], :bold),
          underline: Enum.member?(attrs || [], :underline),
          italic: Enum.member?(attrs || [], :italic)
        }
      end)

    # Send to VS Code
    Raxol.StdioInterface.send_message(%{
      type: "render",
      payload: %{
        cells: vscode_cells,
        width: state.width,
        height: state.height
      }
    })

    {:ok, state}
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
      cell_attrs = %{
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
