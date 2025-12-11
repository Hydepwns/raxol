defmodule Raxol.Protocols.BufferImplementations do
  @moduledoc """
  Protocol implementations for buffer operations on existing buffer types.
  """

  alias Raxol.Terminal.Buffer

  # Implementation for ScreenBuffer
  defimpl Raxol.Protocols.BufferOperations, for: Raxol.Terminal.ScreenBuffer do
    def write(buffer, {x, y}, data, style) do
      # Delegate to existing buffer operations
      buffer
      |> Buffer.Content.write_at(x, y, data, style || %{})
    end

    def read(buffer, {x, y}, length) do
      # Read characters from the buffer
      Buffer.Queries.get_text_at(buffer, x, y, length)
    end

    def clear(buffer, :all) do
      Buffer.Eraser.clear_all(buffer)
    end

    def clear(buffer, :line) do
      {_x, y} = Buffer.Cursor.get_position(buffer)
      Buffer.Eraser.clear_line(buffer, y)
    end

    def clear(buffer, :screen) do
      Buffer.Eraser.clear_screen(buffer)
    end

    def clear(buffer, {:rect, {x1, y1}, {x2, y2}}) do
      Buffer.Eraser.clear_region(buffer, x1, y1, x2, y2)
    end

    def clear(buffer, {:lines, start_line, end_line}) do
      Enum.reduce(start_line..end_line, buffer, fn line, acc ->
        Buffer.Eraser.clear_line(acc, line)
      end)
    end

    def dimensions(buffer) do
      {Buffer.Queries.get_width(buffer), Buffer.Queries.get_height(buffer)}
    end

    def scroll(buffer, :up, lines) do
      Buffer.ScrollRegion.scroll_up(buffer, lines)
    end

    def scroll(buffer, :down, lines) do
      Buffer.ScrollRegion.scroll_down(buffer, lines)
    end
  end

  # Implementation for Renderable protocol for ScreenBuffer
  defimpl Raxol.Protocols.Renderable, for: Raxol.Terminal.ScreenBuffer do
    def render(buffer, opts) do
      width = Keyword.get(opts, :width, Buffer.Queries.get_width(buffer))
      height = Keyword.get(opts, :height, Buffer.Queries.get_height(buffer))
      colors = Keyword.get(opts, :colors, true)

      # Render the buffer content to a string
      0..(height - 1)
      |> Enum.map_join("\n", fn y ->
        0..(width - 1)
        |> Enum.map_join("", fn x ->
          cell = Buffer.Queries.get_cell(buffer, x, y)
          render_cell(cell, colors)
        end)
      end)
    end

    def render_metadata(buffer) do
      %{
        width: Buffer.Queries.get_width(buffer),
        height: Buffer.Queries.get_height(buffer),
        colors: true,
        scrollable: Buffer.Queries.has_scrollback?(buffer),
        interactive: true
      }
    end

    defp render_cell(%{char: char} = _cell, false), do: char || " "

    defp render_cell(%{char: char, style: style} = _cell, true)
         when is_map(style) do
      ansi_codes = build_ansi_codes(style)

      case ansi_codes do
        "" -> char || " "
        codes -> "#{codes}#{char || " "}\e[0m"
      end
    end

    defp render_cell(%{char: char}, true), do: char || " "

    defp build_ansi_codes(style) do
      codes = []

      codes = if style[:bold], do: ["1" | codes], else: codes
      codes = if style[:italic], do: ["3" | codes], else: codes
      codes = if style[:underline], do: ["4" | codes], else: codes

      codes =
        case style[:foreground] do
          {r, g, b} -> ["38;2;#{r};#{g};#{b}" | codes]
          nil -> codes
        end

      codes =
        case style[:background] do
          {r, g, b} -> ["48;2;#{r};#{g};#{b}" | codes]
          nil -> codes
        end

      if codes == [] do
        ""
      else
        "\e[#{Enum.join(codes, ";")}m"
      end
    end
  end

  # Implementation for Serializable protocol for ScreenBuffer
  defimpl Raxol.Protocols.Serializable, for: Raxol.Terminal.ScreenBuffer do
    def serialize(buffer, :json) do
      data = %{
        width: Buffer.Queries.get_width(buffer),
        height: Buffer.Queries.get_height(buffer),
        cursor: Buffer.Cursor.get_position(buffer),
        content: serialize_content(buffer)
      }

      case Jason.encode(data) do
        {:ok, json} -> json
        {:error, reason} -> {:error, reason}
      end
    end

    def serialize(buffer, :binary) do
      :erlang.term_to_binary(buffer)
    end

    def serialize(_buffer, format) do
      {:error, {:unsupported_format, format}}
    end

    def serializable?(_buffer, format) do
      format in [:json, :binary]
    end

    defp serialize_content(buffer) do
      width = Buffer.Queries.get_width(buffer)
      height = Buffer.Queries.get_height(buffer)

      for y <- 0..(height - 1) do
        for x <- 0..(width - 1) do
          cell = Buffer.Queries.get_cell(buffer, x, y)
          serialize_cell(cell)
        end
      end
    end

    defp serialize_cell(%{char: char, style: style}),
      do: %{char: char || " ", style: style}
  end
end
