defmodule Raxol.Core.Runtime.Rendering.Engine do
  @moduledoc """
  Provides the core rendering functionality for Raxol applications.

  This module is responsible for:
  * Rendering application views into screen buffers
  * Managing the rendering lifecycle
  * Coordinating with the output backends
  """

  require Logger

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Core.Renderer.Element

  @doc """
  Renders a complete frame for the application.

  This function:
  1. Processes the view tree into a collection of cells
  2. Applies plugins transforms to the cells
  3. Writes the cells to the screen buffer
  4. Sends the buffer to the appropriate output backend

  ## Parameters
  - `state`: The current application state
  - `force`: Force a full render even if nothing changed

  ## Returns
  `{:ok, updated_state}` if rendering succeeded,
  `{:error, reason, state}` otherwise.
  """
  def render_frame(state, force \\ false) do
    try do
      # Get the view from the application
      view = state.app_module.view(state.model)

      # Process the view into cells
      {cells, component_state} = process_view(view, state.components)

      # Apply plugin cell transforms if any
      cells =
        if state.plugin_manager do
          apply_plugin_transforms(cells, state.plugin_manager)
        else
          cells
        end

      # Update component state
      updated_state = %{state | components: component_state}

      # Send to the appropriate output backend
      case state.environment do
        :terminal ->
          render_to_terminal(cells, updated_state, force)

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
  def process_view(view, component_state) do
    # Process the view tree to create cells
    {cells, updated_component_state} =
      Element.to_cells(view, %{
        width: 0,
        height: 0,
        x: 0,
        y: 0,
        components: component_state
      })

    # Return cells and the updated component state
    {cells, updated_component_state}
  end

  @doc """
  Applies changes to the output based on the environment.

  ## Parameters
  - `cells`: The cells to render
  - `state`: The current application state

  ## Returns
  `{:ok, updated_state}` if the changes were applied,
  `{:error, reason, state}` otherwise.
  """
  def apply_changes(cells, state) do
    case state.environment do
      :terminal ->
        # For terminal, we diff against the previous buffer
        screen_buffer = state.screen_buffer || ScreenBuffer.new(state.width, state.height)

        # Create a new buffer from the cells
        new_buffer = ScreenBuffer.from_cells(cells, state.width, state.height)

        # Diff the buffers to get changes
        diff = ScreenBuffer.diff(screen_buffer, new_buffer)

        # Apply the changes to the terminal
        ScreenBuffer.apply_diff(diff)

        # Store the new buffer state
        {:ok, %{state | screen_buffer: new_buffer}}

      :vscode ->
        # For VS Code, we just send the full buffer each time
        if state.stdio_interface_pid do
          send_buffer_to_vscode(cells, state)
        else
          {:error, :stdio_not_available, state}
        end

      _ ->
        {:error, :unknown_environment, state}
    end
  end

  # Private functions

  defp render_to_terminal(cells, state, force) do
    if force do
      # Force a full redraw of the screen
      screen_buffer = ScreenBuffer.from_cells(cells, state.width, state.height)
      ScreenBuffer.render(screen_buffer)
      {:ok, %{state | screen_buffer: screen_buffer}}
    else
      # Use diffing for efficient updates
      apply_changes(cells, state)
    end
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

  defp apply_plugin_transforms(cells, plugin_manager) do
    # Let plugins transform the cells before rendering
    Raxol.Plugins.PluginManager.process_cells(plugin_manager, cells) || cells
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
end
