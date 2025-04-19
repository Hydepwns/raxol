defmodule Raxol.Components.Terminal.Emulator do
  @moduledoc """
  Terminal emulator module that handles core terminal functionality including:
  - Screen buffer management
  - Character cell operations
  - Terminal modes and attributes
  - ANSI escape code processing
  """

  alias Raxol.Components.Terminal.ANSI

  @type cell :: %{
          char: String.t(),
          style: map(),
          dirty: boolean()
        }

  @type screen :: %{
          cells: [[cell()]],
          cursor: {integer(), integer()},
          dimensions: {integer(), integer()},
          scroll_region: {integer(), integer()} | nil,
          mode: :normal | :insert,
          attributes: map()
        }

  @type emulator_state :: %{
          dimensions: {integer(), integer()},
          screen: screen(),
          history: [String.t()]
          # ansi_state is no longer needed here, state managed directly
        }

  @default_dimensions {80, 24}

  @doc """
  Initializes a new terminal emulator state.
  """
  def init do
    dimensions = @default_dimensions
    screen = init_screen(dimensions)

    %{
      dimensions: @default_dimensions,
      screen: screen,
      history: []
    }
  end

  @doc """
  Processes input and updates terminal state.
  """
  def process_input(input, state) do
    # Pass current screen state to ANSI processor
    {updated_cells, updated_cursor, updated_style} =
      ANSI.process(
        input,
        state.screen.cells,
        state.screen.cursor,
        Map.get(state.screen, :attributes, %{}),
        state.dimensions
      )

    # Update screen with results from ANSI processor
    updated_screen = %{
      state.screen
      | cells: updated_cells,
        cursor: updated_cursor,
        attributes: updated_style
    }

    %{state | screen: updated_screen}
  end

  @doc """
  Handles terminal resize events.
  """
  def handle_resize({width, height}, state) do
    new_screen = resize_screen(state.screen, {width, height})
    %{state | dimensions: {width, height}, screen: new_screen}
  end

  @doc """
  Returns the current visible content of the terminal.
  """
  def get_visible_content(state) do
    state.screen.cells
    |> Enum.map(fn row ->
      row
      |> Enum.map(& &1.char)
      |> Enum.join()
    end)
    |> Enum.join("\n")
  end

  # Private functions

  defp init_screen({width, height}) do
    cells =
      for _ <- 1..height do
        for _ <- 1..width do
          %{char: " ", style: %{}, dirty: false}
        end
      end

    %{
      cells: cells,
      cursor: {0, 0},
      dimensions: {width, height},
      scroll_region: nil,
      mode: :normal,
      attributes: %{}
    }
  end

  defp resize_screen(screen, {new_width, new_height}) do
    current_cells = screen.cells

    new_cells =
      for y <- 0..(new_height - 1) do
        for x <- 0..(new_width - 1) do
          case {x, y} do
            {x, y}
            when x < length(hd(current_cells)) and y < length(current_cells) ->
              Enum.at(Enum.at(current_cells, y), x)

            _ ->
              %{char: " ", style: %{}, dirty: true}
          end
        end
      end

    %{
      screen
      | cells: new_cells,
        dimensions: {new_width, new_height},
        cursor: clamp_cursor(screen.cursor, {new_width, new_height})
    }
  end

  defp clamp_cursor({x, y}, {width, height}) do
    {
      min(max(0, x), width - 1),
      min(max(0, y), height - 1)
    }
  end
end
