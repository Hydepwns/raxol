defmodule Raxol.Demo.GameOfLife do
  @moduledoc """
  Conway's Game of Life implementation for the demo showcase.
  Features age-based coloring where newer cells are brighter.
  """

  @live_chars ["█", "▓", "▒", "░"]
  @dead_char " "

  @type grid :: %{{integer(), integer()} => integer()}

  @doc """
  Creates a new grid with random initial state.
  """
  @spec create_grid(integer(), integer(), float()) :: grid()
  def create_grid(width, height, density \\ 0.3) do
    for y <- 0..(height - 1), x <- 0..(width - 1), into: %{} do
      alive = :rand.uniform() < density
      {{x, y}, if(alive, do: 1, else: 0)}
    end
  end

  @doc """
  Creates an R-pentomino pattern (small but produces interesting evolution).
  """
  @spec create_r_pentomino(integer(), integer()) :: grid()
  def create_r_pentomino(width, height) do
    cx = div(width, 2)
    cy = div(height, 2)

    base =
      for y <- 0..(height - 1), x <- 0..(width - 1), into: %{}, do: {{x, y}, 0}

    pattern = [{0, -1}, {1, -1}, {-1, 0}, {0, 0}, {0, 1}]

    Enum.reduce(pattern, base, fn {dx, dy}, grid ->
      Map.put(grid, {cx + dx, cy + dy}, 1)
    end)
  end

  @doc """
  Advances the grid by one generation.
  """
  @spec step(grid(), integer(), integer()) :: grid()
  def step(grid, width, height) do
    for y <- 0..(height - 1), x <- 0..(width - 1), into: %{} do
      neighbors = count_neighbors(grid, x, y, width, height)
      current = Map.get(grid, {x, y}, 0)
      alive = current > 0

      new_state =
        cond do
          alive and neighbors in [2, 3] -> current + 1
          not alive and neighbors == 3 -> 1
          true -> 0
        end

      {{x, y}, new_state}
    end
  end

  @doc """
  Renders the grid to ANSI escape sequences.
  """
  @spec render(grid(), integer(), integer()) :: String.t()
  def render(grid, width, height) do
    lines =
      for y <- 0..(height - 1) do
        line =
          for x <- 0..(width - 1) do
            age = Map.get(grid, {x, y}, 0)

            if age > 0 do
              char = Enum.at(@live_chars, min(age - 1, 3))
              color = age_to_color(age)
              "\e[#{color}m#{char}\e[0m"
            else
              @dead_char
            end
          end

        Enum.join(line)
      end

    Enum.join(lines, "\r\n")
  end

  @doc """
  Returns positions of all live cells (for particle explosion).
  """
  @spec live_cells(grid()) :: list({integer(), integer()})
  def live_cells(grid) do
    grid
    |> Enum.filter(fn {_pos, age} -> age > 0 end)
    |> Enum.map(fn {{x, y}, _age} -> {x, y} end)
  end

  @doc """
  Counts the number of live cells.
  """
  @spec population(grid()) :: integer()
  def population(grid) do
    Enum.count(grid, fn {_pos, age} -> age > 0 end)
  end

  defp count_neighbors(grid, x, y, width, height) do
    for dx <- -1..1, dy <- -1..1, {dx, dy} != {0, 0}, reduce: 0 do
      acc ->
        nx = rem(x + dx + width, width)
        ny = rem(y + dy + height, height)

        if Map.get(grid, {nx, ny}, 0) > 0 do
          acc + 1
        else
          acc
        end
    end
  end

  defp age_to_color(age) do
    cond do
      age <= 2 -> "38;5;51"
      age <= 5 -> "38;5;45"
      age <= 10 -> "38;5;39"
      age <= 20 -> "38;5;99"
      true -> "38;5;60"
    end
  end
end
