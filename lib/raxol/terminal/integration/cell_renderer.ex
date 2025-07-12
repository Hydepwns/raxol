defmodule Raxol.Terminal.Integration.CellRenderer do
  @moduledoc """
  Renders a list of cells to the terminal.
  """

  @doc """
  Renders a list of cells to the terminal.
  """
  def render(cells) do
    cells
    |> Enum.reduce_while(:ok, fn {row_of_cells, y_offset}, _acc ->
      case render_row(row_of_cells, y_offset) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp render_row(row_of_cells, y_offset) do
    row_of_cells
    |> Enum.reduce_while(:ok, fn {cell, x_offset}, _acc ->
      case render_cell(cell, x_offset, y_offset) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp render_cell(cell, x_offset, y_offset) do
    # Check if we're in test mode
    if Application.get_env(:raxol, :terminal_test_mode, false) do
      # In test mode, just return success without calling termbox2
      :ok
    else
      char_s = cell.char

      codepoint =
        if is_nil(char_s) or char_s == "",
          do: ?\s,
          else: hd(String.to_charlist(char_s))

      case :termbox2_nif.tb_set_cell(
             x_offset,
             y_offset,
             codepoint,
             cell.fg,
             cell.bg
           ) do
        0 ->
          :ok

        error_code ->
          {:error, {:set_cell_failed, {x_offset, y_offset, error_code}}}
      end
    end
  end
end
