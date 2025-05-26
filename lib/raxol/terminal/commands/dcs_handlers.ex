defmodule Raxol.Terminal.Commands.DCSHandlers do
  @moduledoc """
  Handles the execution logic for specific DCS commands.

  Functions are called by `Raxol.Terminal.Commands.Executor` after initial parsing.

  - Implements DCS handlers for DECRQSS (Request Status String), Sixel Graphics, and stubs DECDLD (Downloadable Character Set).
  - DECRQSS supports status queries for SGR ("m"), scroll region ("r"), cursor style (" q"), and page length ("t").
  - Sixel graphics are parsed and blitted to the screen buffer.
  - DECDLD is stubbed and logs a warning; not yet implemented.
  """

  alias Raxol.Terminal.Emulator
  # Add alias for TextFormatting
  alias Raxol.Terminal.ANSI.TextFormatting
  require Raxol.Core.Runtime.Log

  @doc "Dispatches DCS command execution based on intermediates and final byte."
  @spec handle_dcs(
          Emulator.t(),
          list(integer() | nil),
          String.t(),
          non_neg_integer(),
          String.t()
        ) :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_dcs(
        emulator,
        params,
        intermediates_buffer,
        final_byte,
        data_string
      ) do
    Raxol.Core.Runtime.Log.debug(
      "Handling DCS command: params=#{inspect(params)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}, data_len=#{byte_size(data_string)}"
    )

    # --- Dispatch based on params/intermediates/final byte ---
    case {intermediates_buffer, final_byte} do
      # DECRQSS (Request Status String): DCS ! | Pt ST
      # Using final byte | as marker
      {"!", ?|} ->
        case handle_decrqss(emulator, data_string) do
          %Emulator{} = emu -> {:ok, emu}
          {:ok, emu} -> {:ok, emu}
          {:error, reason, emu} -> {:error, reason, emu}
        end

      # Sixel Graphics: DCS <params> q <data> ST
      # The parser should ideally handle Sixel data streaming separately.
      {_intermediates, ?q} ->
        Raxol.Core.Runtime.Log.debug(
          "DCS Sixel Graphics (Params: #{inspect(params)}, Data Length: #{byte_size(data_string)}) - Processing in DCSHandlers"
        )

        # Get or initialize the current Sixel state from the emulator
        sixel_state =
          Map.get(emulator, :sixel_state) ||
            Raxol.Terminal.ANSI.SixelGraphics.new()

        {updated_sixel_state, _result} =
          Raxol.Terminal.ANSI.SixelGraphics.process_sequence(
            sixel_state,
            data_string
          )

        # --- Sixel Rendering: Blit to screen buffer ---
        buffer = Emulator.get_active_buffer(emulator)
        cursor = Raxol.Terminal.Emulator.get_cursor_position(emulator.cursor)
        new_buffer = blit_sixel_to_buffer(buffer, updated_sixel_state, cursor)
        emu = Emulator.update_active_buffer(emulator, new_buffer)
        {:ok, %{emu | sixel_state: updated_sixel_state}}

      # DECDLD (User-Defined Keys): DCS P1;P2;... | p <data> ST
      # Not yet implemented
      {"|", ?p} ->
        case handle_decdld(emulator, params, data_string) do
          %Emulator{} = emu -> {:ok, emu}
          {:ok, emu} -> {:ok, emu}
          {:error, reason, emu} -> {:error, reason, emu}
        end

      # Unhandled DCS
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled DCS command in DCSHandlers: params=#{inspect(params)}, intermediates=#{inspect(intermediates_buffer)}, final=#{final_byte}",
          %{}
        )

        {:error, :unhandled_dcs, emulator}
    end
  end

  # --- Specific DCS Handlers ---

  defp handle_decrqss(emulator, data_string) do
    response_payload =
      case data_string do
        "m" ->
          # SGR attributes: Response DCS 1 ! | Ps ... Ps m ST
          TextFormatting.format_sgr_params(emulator.text_style) <> "m"

        "r" ->
          # Scroll region: Response DCS 1 ! | Pt ; Pb r ST
          # Pt, Pb are 1-based
          {top, bottom} =
            case emulator.scroll_region do
              # Convert 0-indexed to 1-based
              {t, b} -> {t + 1, b + 1}
              # Full screen
              nil -> {1, emulator.height}
            end

          "#{top};#{bottom}r"

        # Note the leading space
        " q" ->
          # Cursor style: Response DCS 1 ! | Ps q ST
          ps =
            case emulator.cursor_style do
              # or 0
              :blinking_block -> 1
              :steady_block -> 2
              :blinking_underline -> 3
              :steady_underline -> 4
              :blinking_bar -> 5
              :steady_bar -> 6
              # Default/unknown for styles not in this list or if cursor_style is complex
              _ -> 0
            end

          # Include the space in the response payload before 'q'
          "#{ps} q"

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Unhandled DECRQSS request type: #{inspect(data_string)}",
            %{}
          )

          # No response for unhandled types
          nil
      end

    if response_payload do
      # DCS <validity> ! | <response_payload> ST
      # Validity 1 for "ok"
      # ST is ESC \
      # Note: Standard DCS is \eP, not \e[
      # Standard ST is \e\\
      full_response = "\eP1!|#{response_payload}\e\\"
      Raxol.Core.Runtime.Log.debug("DECRQSS response: #{inspect(full_response)}")

      {:ok,
       %{emulator | output_buffer: emulator.output_buffer <> full_response}}
    else
      {:error, :unhandled_decrqss, emulator}
    end
  end

  defp handle_decdld(emulator, params, data_string) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "DECDLD handler invoked with params: #{inspect(params)}, data_string: #{inspect(data_string)} (not yet implemented)",
      %{}
    )

    {:error, :decdld_not_implemented, emulator}
  end

  # --- Helper Functions (Moved from Executor) ---

  # --- Helper: Blit Sixel image to screen buffer ---
  defp blit_sixel_to_buffer(buffer, sixel_state, {cursor_x, cursor_y}) do
    alias Raxol.Terminal.Cell
    alias Raxol.Terminal.ANSI.TextFormatting
    pixel_buffer = sixel_state.pixel_buffer
    palette = sixel_state.palette

    # Determine image bounds
    max_x =
      Enum.max_by(Map.keys(pixel_buffer), &elem(&1, 0), fn -> {0, 0} end)
      |> elem(0)

    max_y =
      Enum.max_by(Map.keys(pixel_buffer), &elem(&1, 1), fn -> {0, 0} end)
      |> elem(1)

    # Map Sixel pixels to cells: 1 cell per 2x4 Sixel pixels (adjust as needed)
    cell_width = 2
    cell_height = 4
    cells_x = div(max_x + cell_width, cell_width)
    cells_y = div(max_y + cell_height, cell_height)

    changes =
      for cell_y <- 0..(cells_y - 1), cell_x <- 0..(cells_x - 1) do
        # Top-left pixel in this cell
        px0 = cell_x * cell_width
        py0 = cell_y * cell_height
        # Gather all Sixel pixels in this cell
        pixels =
          for dx <- 0..(cell_width - 1),
              dy <- 0..(cell_height - 1),
              do: Map.get(pixel_buffer, {px0 + dx, py0 + dy})

        # Most common color index (mode)
        color_index =
          pixels
          |> Enum.filter(& &1)
          |> Enum.frequencies()
          |> Enum.max_by(fn {_k, v} -> v end, fn -> {nil, 0} end)
          |> elem(0)

        rgb = case color_index do
          nil -> nil
          idx ->
            case get_palette_color(palette, idx) do
              {:ok, color} -> color
              {:error, _} ->
                Raxol.Core.Runtime.Log.warning_with_context(
                  "DCS Sixel: Color index #{inspect(idx)} not found in palette.",
                  %{}
                )
                nil
            end
        end

        style =
          if rgb do
            TextFormatting.set_background(
              TextFormatting.new(),
              {:rgb, elem(rgb, 0), elem(rgb, 1), elem(rgb, 2)}
            )
          else
            TextFormatting.new()
          end

        cell = Cell.new(" ", style)
        # Place at (cursor_x + cell_x, cursor_y + cell_y)
        {cursor_x + cell_x, cursor_y + cell_y, cell}
      end
      |> Enum.filter(fn {x, y, _cell} ->
        x < buffer.width and y < buffer.height
      end)

    Raxol.Terminal.Buffer.Operations.update(buffer, changes)
  end

  # Helper for safe palette access
  defp get_palette_color(palette, index) when is_integer(index) and index >= 0 and index <= 255 do
    case Map.get(palette, index) do
      nil -> {:error, :invalid_color_index}
      color -> {:ok, color}
    end
  end
  defp get_palette_color(_palette, _index), do: {:error, :invalid_color_index}
end
