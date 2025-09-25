defmodule Raxol.UI.Components.Progress.Circular do
  @moduledoc """
  Circular progress indicator component.

  Provides circular/radial progress indicators for terminal UIs.
  """

  @doc """
  Creates a circular progress indicator.
  """
  @spec circular(number(), keyword()) :: binary()
  def circular(value, opts \\ []) when is_number(value) do
    max = Keyword.get(opts, :max, 100)
    size = Keyword.get(opts, :size, :medium)
    style = Keyword.get(opts, :style, :blocks)

    percentage = min(100, value / max * 100)

    case size do
      :small -> render_small(percentage, style)
      :medium -> render_medium(percentage, style)
      :large -> render_large(percentage, style)
      _ -> render_medium(percentage, style)
    end
  end

  # Private rendering functions

  defp render_small(percentage, style) do
    filled = round(percentage / 25)
    char = get_char(filled, style)
    "#{char} #{round(percentage)}%"
  end

  defp render_medium(percentage, :blocks) do
    segments = 8
    filled = round(segments * percentage / 100)

    chars =
      for i <- 1..segments do
        if i <= filled, do: "█", else: "░"
      end

    top = Enum.slice(chars, 0..2) |> Enum.join()
    middle_left = Enum.at(chars, 7)
    middle_right = Enum.at(chars, 3)
    bottom = Enum.slice(chars, 4..6) |> Enum.reverse() |> Enum.join()

    """
     #{top}
    #{middle_left}   #{middle_right}
     #{bottom}  #{round(percentage)}%
    """
    |> String.trim()
  end

  defp render_medium(percentage, :ascii) do
    segments = 8
    filled = round(segments * percentage / 100)

    chars =
      for i <- 1..segments do
        if i <= filled, do: "#", else: "-"
      end

    "(#{Enum.join(chars)}) #{round(percentage)}%"
  end

  defp render_medium(percentage, _) do
    render_medium(percentage, :ascii)
  end

  defp render_large(percentage, style) do
    # For large size, create a more detailed circular representation
    radius = 3
    grid = create_circle_grid(radius, percentage, style)

    lines = Enum.map(grid, &Enum.join(&1))
    center_line = div(length(lines), 2)

    lines
    |> List.update_at(center_line, fn line ->
      "#{line}  #{round(percentage)}%"
    end)
    |> Enum.join("\n")
  end

  defp create_circle_grid(radius, percentage, style) do
    size = radius * 2 + 1
    center = radius

    for y <- 0..(size - 1) do
      for x <- 0..(size - 1) do
        dx = x - center
        dy = y - center
        distance = :math.sqrt(dx * dx + dy * dy)

        cond do
          distance > radius + 0.5 ->
            " "

          distance < radius - 0.5 ->
            angle = :math.atan2(dy, dx)
            normalized_angle = (angle + :math.pi()) / (2 * :math.pi())

            if normalized_angle * 100 <= percentage do
              get_filled_char(style)
            else
              get_empty_char(style)
            end

          true ->
            get_border_char(style)
        end
      end
    end
  end

  defp get_char(level, :blocks) do
    case level do
      0 -> " "
      1 -> "░"
      2 -> "▒"
      3 -> "▓"
      _ -> "█"
    end
  end

  defp get_char(level, :ascii) do
    case level do
      0 -> " "
      1 -> "."
      2 -> "o"
      3 -> "O"
      _ -> "@"
    end
  end

  defp get_char(level, _), do: get_char(level, :ascii)

  defp get_filled_char(:blocks), do: "█"
  defp get_filled_char(:ascii), do: "#"
  defp get_filled_char(_), do: "#"

  defp get_empty_char(:blocks), do: "░"
  defp get_empty_char(:ascii), do: "."
  defp get_empty_char(_), do: "."

  defp get_border_char(:blocks), do: "▒"
  defp get_border_char(:ascii), do: "o"
  defp get_border_char(_), do: "o"
end
