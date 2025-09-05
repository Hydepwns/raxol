defmodule Raxol.Test.Visual.Matchers do
  @moduledoc """
  Provides pattern matching helpers for visual testing of Raxol components.

  This module includes matchers for:
  - ANSI color and style patterns
  - Terminal layout patterns
  - Border and edge patterns
  - Component structure patterns
  """

  @doc """
  Matches ANSI color codes in the output.

  ## Example

      output
      |> matches_color(:red, "Error message")
      |> matches_color(:green, "Success")
  """
  def matches_color(output, color, content) when is_binary(output) do
    color_code = ansi_color_code(color)

    pattern =
      Regex.compile!("#{color_code}#{Regex.escape(content)}#{IO.ANSI.reset()}")

    case Regex.match?(pattern, output) do
      true -> {:ok, output}
      false -> {:error, "Expected #{inspect(content)} to be in #{color}"}
    end
  end

  @doc """
  Matches ANSI style codes in the output.

  ## Example

      output
      |> matches_style(:bold, "Important")
      |> matches_style(:underline, "Link")
  """
  def matches_style(output, style, content) when is_binary(output) do
    style_code = ansi_style_code(style)

    pattern =
      Regex.compile!("#{style_code}#{Regex.escape(content)}#{IO.ANSI.reset()}")

    case Regex.match?(pattern, output) do
      true -> {:ok, output}
      false -> {:error, "Expected #{inspect(content)} to have style #{style}"}
    end
  end

  @doc """
  Matches box drawing characters in the output.

  ## Example

      output
      |> matches_box_edges()
      |> matches_box_corners()
  """
  def matches_box_edges(output) when is_binary(output) do
    horizontal = "─"
    vertical = "│"

    has_horizontal = String.contains?(output, horizontal)
    has_vertical = String.contains?(output, vertical)

    classify_box_edges(has_horizontal, has_vertical, output)
  end

  defp classify_box_edges(has_horizontal, has_vertical, output) do
    cond do
      has_horizontal and has_vertical ->
        {:ok, output}

      has_horizontal ->
        {:partial, "Missing vertical edges"}

      has_vertical ->
        {:partial, "Missing horizontal edges"}

      true ->
        {:error, "No box edges found"}
    end
  end

  @doc """
  Matches specific layout patterns in the output.

  ## Example

      output
      |> matches_layout(:centered)
      |> matches_layout(:padded, padding: 2)
  """
  def matches_layout(output, layout, opts \\ [])

  def matches_layout(output, :centered, _opts) when is_binary(output) do
    lines = String.split(output, "\n")
    max_length = Enum.map(lines, &String.length/1) |> Enum.max()

    centered? =
      Enum.all?(lines, fn line ->
        padding = div(max_length - String.length(line), 2)
        String.starts_with?(line, String.duplicate(" ", padding))
      end)

    case centered? do
      true -> {:ok, output}
      false -> {:error, "Content is not centered"}
    end
  end

  def matches_layout(output, :padded, opts) when is_binary(output) do
    padding = Keyword.get(opts, :padding, 1)
    lines = String.split(output, "\n")

    padded? =
      Enum.all?(lines, fn line ->
        String.starts_with?(line, String.duplicate(" ", padding)) and
          String.ends_with?(line, String.duplicate(" ", padding))
      end)

    case padded? do
      true -> {:ok, output}
      false -> {:error, "Content is not properly padded"}
    end
  end

  @doc """
  Matches specific component patterns in the output.

  ## Example

      output
      |> matches_component(:button, "Click me")
      |> matches_component(:input, placeholder: "Enter text")
  """
  def matches_component(output, type, opts \\ [])

  def matches_component(output, :button, label) when is_binary(output) do
    pattern = ~r/\[#{Regex.escape(label)}\]/

    case Regex.match?(pattern, output) do
      true -> {:ok, output}
      false -> {:error, "Button with label #{inspect(label)} not found"}
    end
  end

  def matches_component(output, :input, opts) when is_binary(output) do
    placeholder = Keyword.get(opts, :placeholder, "")
    pattern = ~r/\[#{Regex.escape(placeholder)}_+\]/

    case Regex.match?(pattern, output) do
      true ->
        {:ok, output}

      false ->
        {:error, "Input with placeholder #{inspect(placeholder)} not found"}
    end
  end

  @doc """
  Matches specific text alignment patterns in the output.

  ## Example

      output
      |> matches_alignment(:left)
      |> matches_alignment(:right, width: 80)
  """
  def matches_alignment(output, alignment, opts \\ []) when is_binary(output) do
    width = Keyword.get(opts, :width, 80)
    lines = String.split(output, "\n")

    aligned? =
      Enum.all?(lines, fn line ->
        case alignment do
          :left ->
            String.trim_leading(line) == line

          :right ->
            padding = width - String.length(String.trim(line))
            String.starts_with?(line, String.duplicate(" ", padding))

          :center ->
            line = String.trim(line)
            padding = div(width - String.length(line), 2)
            String.starts_with?(line, String.duplicate(" ", padding))
        end
      end)

    case aligned? do
      true -> {:ok, output}
      false -> {:error, "Content is not #{alignment}-aligned"}
    end
  end

  # Private Helpers

  defp ansi_color_code(:black), do: IO.ANSI.black()
  defp ansi_color_code(:red), do: IO.ANSI.red()
  defp ansi_color_code(:green), do: IO.ANSI.green()
  defp ansi_color_code(:yellow), do: IO.ANSI.yellow()
  defp ansi_color_code(:blue), do: IO.ANSI.blue()
  defp ansi_color_code(:magenta), do: IO.ANSI.magenta()
  defp ansi_color_code(:cyan), do: IO.ANSI.cyan()
  defp ansi_color_code(:white), do: IO.ANSI.white()
  defp ansi_color_code(_), do: ""

  defp ansi_style_code(:bold), do: IO.ANSI.bright()
  defp ansi_style_code(:dim), do: IO.ANSI.faint()
  defp ansi_style_code(:italic), do: IO.ANSI.italic()
  defp ansi_style_code(:underline), do: IO.ANSI.underline()
  defp ansi_style_code(:blink), do: IO.ANSI.blink_slow()
  defp ansi_style_code(:reverse), do: IO.ANSI.reverse()
  defp ansi_style_code(:hidden), do: IO.ANSI.conceal()
  defp ansi_style_code(:strikethrough), do: IO.ANSI.crossed_out()
  defp ansi_style_code(_), do: ""
end
