defmodule Raxol.Core.Renderer do
  @moduledoc """
  Pure functional renderer for Raxol buffers.

  This module provides efficient rendering and diffing capabilities
  without requiring GenServers or stateful components.

  ## Performance Targets

  - `render_to_string/1` completes in < 1ms for 80x24 buffer
  - `render_diff/2` completes in < 2ms for 80x24 buffer
  - Memory efficient (minimal allocations)

  ## Examples

      # Render buffer to ASCII string
      buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
      output = Raxol.Core.Renderer.render_to_string(buffer)

      # Calculate diff between two buffers
      old_buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
      new_buffer = Raxol.Core.Buffer.write_at(old_buffer, 0, 0, "Changed")
      diff = Raxol.Core.Renderer.render_diff(old_buffer, new_buffer)

  """

  alias Raxol.Core.Buffer

  @doc """
  Renders a buffer to an ASCII string representation.

  Primarily used for testing and debugging. For production rendering,
  use more efficient methods.

  ## Parameters

    - `buffer` - The buffer to render

  ## Returns

  A string representation of the buffer suitable for terminal display.

  """
  @spec render_to_string(Buffer.t()) :: String.t()
  def render_to_string(buffer) do
    Buffer.to_string(buffer)
  end

  @doc """
  Calculates the minimal diff between two buffers.

  This is useful for efficient terminal updates where only changed
  cells need to be redrawn.

  ## Parameters

    - `old_buffer` - The previous buffer state
    - `new_buffer` - The new buffer state

  ## Returns

  A list of changes representing the minimal set of updates needed
  to transform old_buffer into new_buffer.

  Each change is a map with:
  - `:x` - Column coordinate
  - `:y` - Row coordinate
  - `:char` - New character
  - `:style` - New style

  """
  @spec render_diff(Buffer.t(), Buffer.t()) :: list(map())
  def render_diff(
        %{lines: old_lines, width: old_width, height: old_height},
        %{lines: new_lines, width: new_width, height: new_height}
      ) do
    # If dimensions differ, treat as complete change
    cond do
      old_width != new_width or old_height != new_height ->
        collect_all_cells(new_lines, new_width, new_height)

      true ->
        collect_changed_cells(old_lines, new_lines, new_width, new_height)
    end
  end

  # Private helpers

  @spec collect_all_cells(list(map()), non_neg_integer(), non_neg_integer()) ::
          list(map())
  defp collect_all_cells(lines, width, height) do
    for y <- 0..(height - 1),
        x <- 0..(width - 1) do
      cell =
        lines
        |> Enum.at(y)
        |> Map.get(:cells)
        |> Enum.at(x)

      %{
        x: x,
        y: y,
        char: cell.char,
        style: cell.style
      }
    end
  end

  @spec collect_changed_cells(
          list(map()),
          list(map()),
          non_neg_integer(),
          non_neg_integer()
        ) :: list(map())
  defp collect_changed_cells(old_lines, new_lines, _width, _height) do
    old_lines
    |> Enum.zip(new_lines)
    |> Enum.with_index()
    |> Enum.flat_map(fn {{old_line, new_line}, y} ->
      old_line.cells
      |> Enum.zip(new_line.cells)
      |> Enum.with_index()
      |> Enum.filter(fn {{old_cell, new_cell}, _x} ->
        old_cell.char != new_cell.char or old_cell.style != new_cell.style
      end)
      |> Enum.map(fn {{_old_cell, new_cell}, x} ->
        %{
          x: x,
          y: y,
          char: new_cell.char,
          style: new_cell.style
        }
      end)
    end)
  end
end
