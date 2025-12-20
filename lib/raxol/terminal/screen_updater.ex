defmodule Raxol.Terminal.ScreenUpdater do
  @moduledoc """
  Handles screen update operations for the terminal.

  This module manages updating the terminal screen content,
  including batched updates and differential rendering.
  """

  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Updates the screen with new buffer content.
  """
  @spec update_screen(ScreenBuffer.t(), map()) :: :ok | {:error, term()}
  def update_screen(buffer, options \\ %{}) do
    # Prepare the update
    updates = prepare_updates(buffer, options)

    # Apply updates to the screen
    apply_updates(updates, options)

    :ok
  rescue
    error -> {:error, error}
  end

  @doc """
  Performs a batched screen update for efficiency.
  """
  @spec batch_update_screen(list(ScreenBuffer.t()), map()) ::
          :ok | {:error, term()}
  def batch_update_screen(buffers, options \\ %{}) when is_list(buffers) do
    # Collect all updates
    all_updates =
      buffers
      |> Enum.map(&prepare_updates(&1, options))
      |> merge_updates()

    # Apply all updates at once
    apply_updates(all_updates, options)

    :ok
  rescue
    error -> {:error, error}
  end

  @doc """
  Clears the screen.
  """
  @spec clear_screen() :: :ok
  def clear_screen do
    IO.write("\e[2J\e[H")
    :ok
  end

  @doc """
  Refreshes the entire screen.
  """
  @spec refresh_screen(ScreenBuffer.t()) :: :ok | {:error, term()}
  def refresh_screen(buffer) do
    clear_screen()
    update_screen(buffer, %{force: true})
  end

  @doc """
  Updates a specific region of the screen.
  """
  @spec update_region(
          ScreenBuffer.t(),
          integer(),
          integer(),
          integer(),
          integer()
        ) ::
          :ok | {:error, term()}
  def update_region(buffer, x, y, width, height) do
    options = %{
      region: %{
        x: x,
        y: y,
        width: width,
        height: height
      }
    }

    update_screen(buffer, options)
  end

  @doc """
  Scrolls the screen content.
  """
  @spec scroll_screen(integer()) :: :ok
  def scroll_screen(lines) when is_integer(lines) do
    cond do
      lines > 0 ->
        # Scroll up
        IO.write("\e[#{lines}S")

      lines < 0 ->
        # Scroll down
        IO.write("\e[#{-lines}T")

      true ->
        :ok
    end
  end

  # Private helper functions

  defp prepare_updates(buffer, options) do
    %{
      buffer: buffer,
      changes: detect_changes(buffer, options),
      options: options
    }
  end

  defp detect_changes(buffer, %{force: true}) do
    # Force full update
    %{
      type: :full,
      cells: buffer.cells
    }
  end

  defp detect_changes(buffer, %{region: region}) do
    # Update only specific region
    %{
      type: :region,
      region: region,
      cells: extract_region_cells(buffer, region)
    }
  end

  defp detect_changes(buffer, _options) do
    # Differential update based on damage regions
    %{
      type: :differential,
      damage_regions: Map.get(buffer, :damage_regions, [])
    }
  end

  defp extract_region_cells(buffer, %{x: x, y: y, width: w, height: h}) do
    buffer.cells
    |> Enum.slice(y, h)
    |> Enum.map(fn row ->
      Enum.slice(row, x, w)
    end)
  end

  defp merge_updates(updates) do
    # Merge multiple updates into one
    Enum.reduce(updates, %{changes: []}, fn update, acc ->
      %{acc | changes: acc.changes ++ [update.changes]}
    end)
  end

  defp apply_updates(%{changes: changes}, options) when is_list(changes) do
    Enum.each(changes, &render_change(&1, options))
  end

  defp apply_updates(%{changes: change}, options) do
    render_change(change, options)
  end

  defp apply_updates(_, _), do: :ok

  defp render_change(%{type: :full, cells: cells}, _options) do
    # Render full screen
    # Always use fallback since render_cells doesn't exist
    render_cells_directly(cells)
  end

  defp render_change(%{type: :region, region: region, cells: cells}, _options) do
    # Render specific region
    render_region_cells(region, cells)
  end

  defp render_change(%{type: :differential, damage_regions: regions}, _options) do
    # Render only damaged regions
    Enum.each(regions, &render_damage_region/1)
  end

  defp render_change(_, _), do: :ok

  defp render_cells_directly(cells) do
    cells
    |> Enum.with_index()
    |> Enum.each(fn {row, y} ->
      IO.write("\e[#{y + 1};1H")

      row
      |> Enum.map_join("", fn cell -> Map.get(cell, :char, " ") end)
      |> IO.write()
    end)
  end

  defp render_region_cells(%{x: x, y: y} = _region, cells) do
    cells
    |> Enum.with_index()
    |> Enum.each(fn {row, row_idx} ->
      IO.write("\e[#{y + row_idx + 1};#{x + 1}H")

      row
      |> Enum.map_join("", fn cell -> Map.get(cell, :char, " ") end)
      |> IO.write()
    end)
  end

  defp render_damage_region({x, y, width, height}) do
    # Simple damage region rendering
    for dy <- 0..(height - 1) do
      IO.write("\e[#{y + dy + 1};#{x + 1}H")
      IO.write(String.duplicate(" ", width))
    end
  end
end
