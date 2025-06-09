defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handles the execution logic for specific CSI commands.

  This module serves as the main entry point for CSI command handling,
  delegating to specialized handler modules for different types of commands.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  alias Raxol.Terminal.Commands.{
    CursorHandlers,
    BufferHandlers,
    EraseHandlers,
    DeviceHandlers,
    ModeHandlers,
    WindowHandlers,
    ParameterValidation
  }

  alias Raxol.Terminal.ANSI.SGRHandler
  require Raxol.Core.Runtime.Log

  @doc "Handles Select Graphic Rendition (SGR - 'm')"
  @spec handle_m(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_m(emulator, params) do
    Raxol.Core.Runtime.Log.debug(
      "[SGR Handler] Input Style: #{inspect(emulator.style)}, Params: #{inspect(params)}"
    )

    new_style = SGRHandler.apply_sgr_params(params, emulator.style)

    Raxol.Core.Runtime.Log.debug(
      "[SGR Handler] Output Style: #{inspect(new_style)}"
    )

    {:ok, %{emulator | style: new_style}}
  end

  # Delegate cursor movement handlers
  @spec handle_H(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_H(emulator, params), do: CursorHandlers.handle_H(emulator, params)

  @spec handle_A(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_A(emulator, params), do: CursorHandlers.handle_A(emulator, params)

  @spec handle_B(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_B(emulator, params), do: CursorHandlers.handle_B(emulator, params)

  @spec handle_C(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_C(emulator, params), do: CursorHandlers.handle_C(emulator, params)

  @spec handle_D(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_D(emulator, params), do: CursorHandlers.handle_D(emulator, params)

  @spec handle_E(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_E(emulator, params), do: CursorHandlers.handle_E(emulator, params)

  @spec handle_F(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_F(emulator, params), do: CursorHandlers.handle_F(emulator, params)

  @spec handle_G(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_G(emulator, params) do
    # Default to 0 if no params or param is not an integer
    param =
      case params do
        [p | _] when is_integer(p) -> p
        _ -> 0
      end

    case param do
      0 ->
        # Clear horizontal tab stop at current position
        # Get current cursor column
        {current_col, _current_row} =
          Raxol.Terminal.Emulator.get_cursor_position(emulator)

        new_tab_stops = MapSet.delete(emulator.tab_stops, current_col)
        {:ok, %{emulator | tab_stops: new_tab_stops}}

      3 ->
        # Clear all horizontal tab stops
        # Reset to default tab stops based on current width
        new_tab_stops =
          Raxol.Terminal.Buffer.Manager.default_tab_stops(emulator.width)
          |> MapSet.new()

        {:ok, %{emulator | tab_stops: new_tab_stops}}

      _ ->
        # If not 0 or 3, assume it's Cursor Character Absolute (CHA)
        # and delegate to the original CursorHandlers.handle_G
        # This ensures existing CHA functionality is preserved.
        CursorHandlers.handle_G(emulator, params)
    end
  end

  @spec handle_d(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_d(emulator, params), do: CursorHandlers.handle_d(emulator, params)

  # Delegate buffer operation handlers
  @spec handle_L(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_L(emulator, params), do: BufferHandlers.handle_L(emulator, params)

  @spec handle_M(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_M(emulator, params), do: BufferHandlers.handle_M(emulator, params)

  @spec handle_P(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_P(emulator, params), do: BufferHandlers.handle_P(emulator, params)

  @spec handle_at(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_at(emulator, params),
    do: BufferHandlers.handle_at(emulator, params)

  @spec handle_X(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_X(emulator, params), do: BufferHandlers.handle_X(emulator, params)

  @spec handle_S(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_S(emulator, params), do: BufferHandlers.handle_S(emulator, params)

  @spec handle_T(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_T(emulator, params), do: BufferHandlers.handle_T(emulator, params)

  # Delegate erase handlers
  @spec handle_J(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_J(emulator, params), do: EraseHandlers.handle_J(emulator, params)

  @spec handle_K(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_K(emulator, params), do: EraseHandlers.handle_K(emulator, params)

  # Delegate device status handlers
  defdelegate handle_n(emulator, params), to: DeviceHandlers

  defdelegate handle_c(emulator, params, intermediates_buffer),
    to: DeviceHandlers

  # Delegate mode handlers
  defdelegate handle_h_or_l(emulator, params, intermediates_buffer, final_byte),
    to: ModeHandlers

  # Delegate window manipulation handlers
  defdelegate handle_t(emulator, params), to: WindowHandlers

  @doc "Handles Save Cursor (SCP - 's')"
  @spec handle_s(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_s(emulator, _params) do
    {:ok, %{emulator | saved_cursor: emulator.cursor}}
  end

  @doc "Handles Restore Cursor (RCP - 'u')"
  @spec handle_u(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_u(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "No saved cursor position to restore",
          %{}
        )

        {:error, :no_saved_cursor, emulator}

      saved_cursor ->
        {:ok, %{emulator | cursor: saved_cursor}}
    end
  end

  @doc "Handles Set Cursor Style (DECSCUSR - 'q')"
  @spec handle_q_deccusr(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_q_deccusr(emulator, params) do
    style = ParameterValidation.get_valid_non_neg_param(params, 0, 0)
    cursor_style = map_cursor_style(style, emulator.cursor.style)
    {:ok, %{emulator | cursor: %{emulator.cursor | style: cursor_style}}}
  end

  # Helper function to map cursor style code to style atom
  @spec map_cursor_style(non_neg_integer(), CursorManager.style()) ::
          CursorManager.style()
  defp map_cursor_style(style, current_style) do
    case style do
      0 ->
        :blink_block

      1 ->
        :blink_block

      2 ->
        :steady_block

      3 ->
        :blink_underline

      4 ->
        :steady_underline

      5 ->
        :blink_bar

      6 ->
        :steady_bar

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown cursor style: #{style}",
          %{}
        )

        current_style
    end
  end

  @doc "Handles Designate Character Set (SCS - via non-standard CSI sequences)"
  @spec handle_scs(Emulator.t(), String.t(), char()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_scs(emulator, charset_param_str, final_byte)
      when is_map(emulator) and is_binary(charset_param_str) and
             is_integer(final_byte) do
    if not Map.has_key?(emulator, :charset_state) do
      msg =
        "SCS: Emulator missing :charset_state key. Emulator: #{inspect(emulator)}"

      Raxol.Core.Runtime.Log.warning_with_context(msg, %{})
      {:error, :missing_charset_state, emulator}
    else
      # Parse the charset parameter string
      case parse_charset_param(charset_param_str) do
        {:ok, charset_code} ->
          # Map the final byte to the appropriate G-set
          gset = map_final_byte_to_gset(final_byte)

          if gset do
            # Map the charset code to the appropriate charset module
            charset = map_charset_code_to_module(charset_code)

            if charset do
              # Update the charset state
              new_charset_state = %{emulator.charset_state | gset => charset}
              {:ok, %{emulator | charset_state: new_charset_state}}
            else
              Raxol.Core.Runtime.Log.warning_with_context(
                "Unknown charset code: #{charset_code}",
                %{}
              )

              {:error, :unknown_charset_code, emulator}
            end
          else
            Raxol.Core.Runtime.Log.warning_with_context(
              "Invalid final byte for SCS: #{final_byte}",
              %{}
            )

            {:error, :invalid_final_byte, emulator}
          end

        :error ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Failed to parse charset parameter: #{charset_param_str}",
            %{}
          )

          {:error, :invalid_charset_param, emulator}
      end
    end
  end

  # Helper function to parse charset parameter
  @spec parse_charset_param(String.t()) :: {:ok, char()} | :error
  defp parse_charset_param("") do
    # Default to US ASCII
    {:ok, ?B}
  end

  defp parse_charset_param(<<code::utf8>>) when code >= ?A and code <= ?Z do
    {:ok, code}
  end

  defp parse_charset_param(_) do
    :error
  end

  # Helper function to map final byte to G-set
  @spec map_final_byte_to_gset(char()) :: :g0 | :g1 | :g2 | :g3 | nil
  defp map_final_byte_to_gset(final_byte) do
    case final_byte do
      ?( -> :g0
      ?) -> :g1
      ?* -> :g2
      ?+ -> :g3
      _ -> nil
    end
  end

  # Helper function to map charset code to module
  @spec map_charset_code_to_module(char()) :: module() | nil
  defp map_charset_code_to_module(code) do
    case code do
      # DEC Special Graphics
      code when code in [?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?<, ?=, ?>, ??] ->
        Raxol.Terminal.ANSI.CharacterSets.DECSpecialGraphics

      # German character set
      code
      when code in [?A..?Z, ?a..?z, ?[, ?\\, ?], ?^, ?_, ?`, ?{, ?|, ?}, ?~] ->
        Raxol.Terminal.ANSI.CharacterSets.German

      # French character set
      code when code in [?D..?E] ->
        Raxol.Terminal.ANSI.CharacterSets.French

      _ ->
        nil
    end
  end

  @doc "Handles cursor movement sequences"
  @spec handle_cursor_movement(Emulator.t(), list(char())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cursor_movement(emulator, [direction | _]) do
    case direction do
      # Cursor Up
      ?A -> handle_A(emulator, [1])
      # Cursor Down
      ?B -> handle_B(emulator, [1])
      # Cursor Forward
      ?C -> handle_C(emulator, [1])
      # Cursor Backward
      ?D -> handle_D(emulator, [1])
      _ -> {:error, :invalid_direction, emulator}
    end
  end

  @doc "Handles cursor positioning sequences"
  @spec handle_cursor_position(Emulator.t(), list(char())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_cursor_position(emulator, params) do
    case params do
      # Default to home position
      [] -> handle_H(emulator, [1, 1])
      # Convert ASCII to numbers
      [row, ?;, col] -> handle_H(emulator, [row - ?0, col - ?0])
      _ -> {:error, :invalid_params, emulator}
    end
  end

  @doc "Handles screen clearing sequences"
  @spec handle_screen_clear(Emulator.t(), list(char())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_screen_clear(emulator, params) do
    case params do
      # Clear from cursor to end of screen
      [] -> handle_J(emulator, [0])
      # Clear from cursor to beginning of screen
      [?1] -> handle_J(emulator, [1])
      # Clear entire screen
      [?2] -> handle_J(emulator, [2])
      _ -> {:error, :invalid_params, emulator}
    end
  end

  @doc "Handles line clearing sequences"
  @spec handle_line_clear(Emulator.t(), list(char())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_line_clear(emulator, params) do
    case params do
      # Clear from cursor to end of line
      [] -> handle_K(emulator, [0])
      # Clear from cursor to beginning of line
      [?1] -> handle_K(emulator, [1])
      # Clear entire line
      [?2] -> handle_K(emulator, [2])
      _ -> {:error, :invalid_params, emulator}
    end
  end

  @doc "Handles device status sequences"
  @spec handle_device_status(Emulator.t(), list(char())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_device_status(emulator, params) do
    case params do
      # Device Status Report
      [?6, ?n] -> handle_n(emulator, [6])
      # Cursor Position Report
      [?6, ?R] -> handle_n(emulator, [6])
      _ -> {:error, :invalid_params, emulator}
    end
  end

  @doc "Handles save/restore cursor sequences"
  @spec handle_save_restore_cursor(Emulator.t(), list(char())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_save_restore_cursor(emulator, [action | _]) do
    case action do
      # Save Cursor Position
      ?s -> handle_s(emulator, [])
      # Restore Cursor Position
      ?u -> handle_u(emulator, [])
      _ -> {:error, :invalid_action, emulator}
    end
  end

  @doc "Handles Set Scrolling Region (DECSTBM - 'r')"
  @spec handle_r(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_r(emulator, params) do
    case params do
      [] ->
        # Reset scroll region to full screen
        {:ok, %{emulator | scroll_region: nil}}

      [top, bottom] when is_integer(top) and is_integer(bottom) ->
        # Validate and set scroll region
        if top > 0 and bottom <= emulator.height and top < bottom do
          {:ok, %{emulator | scroll_region: {top, bottom}}}
        else
          {:error, :invalid_scroll_region, emulator}
        end

      _ ->
        {:error, :invalid_params, emulator}
    end
  end
end
