defmodule Raxol.Core.Runtime.Rendering.Backends do
  @moduledoc """
  Rendering backend implementations for different output targets.

  Handles converting cells to output for terminal, VSCode, LiveView, and SSH backends.
  Extracted from `Raxol.Core.Runtime.Rendering.Engine` to keep rendering dispatch
  separate from the GenServer lifecycle.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ScreenBuffer

  # --- Backend Dispatch ---

  @doc """
  Renders cells to the terminal backend with ANSI output.
  """
  def render_to_terminal(cells, state) do
    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Executing render_to_terminal"
    )

    updated_buffer = apply_cells_to_buffer(cells, state)

    renderer = Raxol.Terminal.Renderer.new(updated_buffer)
    output_string = Raxol.Terminal.Renderer.render(renderer)

    Raxol.Core.Runtime.Log.debug(
      "Rendering Engine: Terminal output generated (length: #{String.length(output_string)})"
    )

    # Move cursor to top-left and clear screen before each frame
    frame = "\e[H\e[2J" <> output_string

    if state.sync_output do
      IO.write("\e[?2026h")
      IO.write(frame)
      IO.write("\e[?2026l")
    else
      IO.write(frame)
    end

    # Send frame to recorder if active
    if pid = Process.whereis(Raxol.Recording.Recorder) do
      Raxol.Recording.Recorder.record_output(pid, frame)
    end

    {:ok, %{state | buffer: updated_buffer}}
  end

  @doc """
  Renders cells to the VSCode backend via stdio interface.
  """
  def render_to_vscode(_cells, state) do
    case state.stdio_interface_pid do
      nil -> {:error, :stdio_not_available}
      _ -> {:ok, :rendered}
    end
  end

  @doc """
  Renders cells to the LiveView backend via PubSub broadcast.
  """
  def render_to_liveview(cells, state) do
    updated_buffer = apply_cells_to_buffer(cells, state)

    html =
      Raxol.LiveView.TerminalBridge.buffer_to_html(updated_buffer,
        use_inline_styles: true
      )

    _ =
      if state.liveview_topic && Code.ensure_loaded?(Phoenix.PubSub) do
        Phoenix.PubSub.broadcast(
          Raxol.PubSub,
          state.liveview_topic,
          {:render_update, html}
        )
      end

    {:ok, %{state | buffer: updated_buffer}}
  end

  @doc """
  Renders cells to an SSH channel via an io_writer function.
  """
  def render_to_ssh(cells, state) do
    updated_buffer = apply_cells_to_buffer(cells, state)

    renderer = Raxol.Terminal.Renderer.new(updated_buffer)
    output_string = Raxol.Terminal.Renderer.render(renderer)

    write_output(state.io_writer, output_string, state.sync_output)

    {:ok, %{state | buffer: updated_buffer}}
  end

  # --- Output Helpers ---

  @doc false
  def write_output(writer, output, true) when is_function(writer, 1) do
    writer.("\e[?2026h")
    writer.(output)
    writer.("\e[?2026l")
  end

  def write_output(writer, output, _sync) when is_function(writer, 1) do
    writer.(output)
  end

  def write_output(_, _, _) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "SSH render: no io_writer configured",
      %{}
    )
  end

  # --- Cell Processing ---

  @doc """
  Transforms raw cells and writes them into a fresh ScreenBuffer.

  A new buffer is created each frame so stale cells from previous views don't persist.
  """
  def apply_cells_to_buffer(cells, state) do
    screen_buffer = ScreenBuffer.new(state.width, state.height)
    transformed_cells = transform_cells_for_update(cells)

    Enum.reduce(transformed_cells, screen_buffer, fn {x, y, cell}, buffer ->
      style = extract_cell_style(cell)
      ScreenBuffer.write_char(buffer, x, y, cell.char || " ", style)
    end)
  end

  @doc false
  def extract_cell_style(cell) do
    case Map.get(cell, :style) do
      nil ->
        %{
          foreground: Map.get(cell, :foreground),
          background: Map.get(cell, :background)
        }

      cell_style when is_map(cell_style) ->
        cell_style

      _ ->
        nil
    end
  end

  # --- Color Conversion ---

  # Terminal color code mapping
  @terminal_color_map %{
    0 => "black",
    1 => "red",
    2 => "green",
    3 => "yellow",
    4 => "blue",
    5 => "magenta",
    6 => "cyan",
    7 => "white",
    8 => "brightBlack",
    9 => "brightRed",
    10 => "brightGreen",
    11 => "brightYellow",
    12 => "brightBlue",
    13 => "brightMagenta",
    14 => "brightCyan",
    15 => "brightWhite"
  }

  @doc false
  def convert_color_to_vscode(color) when is_integer(color) do
    @terminal_color_map[color] || "default"
  end

  def convert_color_to_vscode({r, g, b})
      when is_integer(r) and is_integer(g) and is_integer(b) do
    "rgb(#{r},#{g},#{b})"
  end

  def convert_color_to_vscode(color) when is_binary(color), do: color
  def convert_color_to_vscode(_), do: "default"

  # --- Private Helpers ---

  defp transform_cells_for_update(cells) when is_list(cells) do
    Enum.map(cells, fn {x, y, char, fg, bg, attrs_list} ->
      attrs_map = Enum.into(attrs_list || [], %{}, fn atom -> {atom, true} end)

      cell_attrs =
        %{
          foreground: fg,
          background: bg
        }
        |> Map.merge(Map.take(attrs_map, [:bold, :underline, :italic]))

      cell = %Raxol.Terminal.Cell{char: char, style: cell_attrs}
      {x, y, cell}
    end)
  end
end
