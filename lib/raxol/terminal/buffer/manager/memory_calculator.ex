defmodule Raxol.Terminal.Buffer.Manager.MemoryCalculator do
  @moduledoc """
  Handles memory calculations for buffer managers.
  Extracted from Raxol.Terminal.Buffer.Manager to improve maintainability.
  """

  @doc """
  Calculates memory usage for a buffer.
  """
  def calculate_buffer_memory(buffer) do
    case buffer do
      %Raxol.Terminal.Buffer.Manager.BufferImpl{} ->
        calculate_buffer_impl_memory(buffer)

      _ ->
        calculate_fallback_memory(buffer)
    end
  end

  defp calculate_buffer_impl_memory(buffer) do
    case buffer.cells do
      cells when is_map(cells) ->
        calculate_map_memory(cells)

      cells when is_list(cells) ->
        calculate_list_memory(cells)

      _ ->
        calculate_fallback_memory(buffer)
    end
  end

  defp calculate_map_memory(cells) do
    memory = map_size(cells) * 64

    IO.puts(
      "DEBUG: Map-based cells, size: #{map_size(cells)}, memory: #{memory}"
    )

    memory
  end

  defp calculate_list_memory(cells) do
    total_cells = Enum.reduce(cells, 0, fn row, acc -> acc + length(row) end)
    memory = total_cells * 64

    IO.puts(
      "DEBUG: List-based cells, total_cells: #{total_cells}, memory: #{memory}"
    )

    memory
  end

  defp calculate_fallback_memory(buffer) do
    memory = buffer.width * buffer.height * 8

    IO.puts(
      "DEBUG: Fallback calculation, width: #{buffer.width}, height: #{buffer.height}, memory: #{memory}"
    )

    memory
  end
end
