defmodule Raxol.UI.Components.Progress.Indeterminate do
  @moduledoc """
  Indeterminate progress indicator component.

  Provides animated progress indicators for operations with unknown duration.
  """

  @doc """
  Creates an indeterminate progress indicator.
  """
  @spec indeterminate(integer(), keyword()) :: binary()
  def indeterminate(frame, opts \\ []) when is_integer(frame) do
    style = Keyword.get(opts, :style, :wave)
    width = Keyword.get(opts, :width, 20)

    case style do
      :wave -> render_wave(frame, width)
      :pulse -> render_pulse(frame, width)
      :bounce -> render_bounce(frame, width)
      :slide -> render_slide(frame, width)
      _ -> render_wave(frame, width)
    end
  end

  # Private rendering functions

  defp render_wave(frame, width) do
    position = rem(frame, width * 2)
    position = if position > width, do: width * 2 - position, else: position

    chars =
      for i <- 0..(width - 1) do
        distance = abs(i - position)

        cond do
          distance == 0 -> "="
          distance == 1 -> "-"
          distance == 2 -> "."
          true -> " "
        end
      end

    "[#{Enum.join(chars)}]"
  end

  defp render_pulse(frame, width) do
    intensity = rem(frame, 10)

    char =
      case div(intensity, 3) do
        0 -> "."
        1 -> "o"
        2 -> "O"
        _ -> "@"
      end

    filled = div(intensity * width, 10)
    empty = width - filled

    "[#{String.duplicate(char, filled)}#{String.duplicate(" ", empty)}]"
  end

  defp render_bounce(frame, width) do
    position = rem(frame, (width - 3) * 2)

    position =
      if position > width - 3, do: (width - 3) * 2 - position, else: position

    chars =
      for i <- 0..(width - 1) do
        if i >= position and i < position + 3, do: "=", else: " "
      end

    "[#{Enum.join(chars)}]"
  end

  defp render_slide(frame, width) do
    position = rem(frame, width + 5)

    chars =
      for i <- 0..(width - 1) do
        distance = position - i

        cond do
          distance < 0 or distance > 4 -> " "
          distance == 0 -> ">"
          distance == 1 -> "="
          distance == 2 -> "="
          distance == 3 -> "="
          distance == 4 -> "-"
          true -> " "
        end
      end

    "[#{Enum.join(chars)}]"
  end
end
