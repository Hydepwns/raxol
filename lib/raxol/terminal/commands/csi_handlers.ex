defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handlers for CSI (Control Sequence Introducer) commands.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.CSIHandlers.{Basic, Cursor, Screen, Device}
  alias Raxol.Terminal.Commands.WindowHandlers
  require Raxol.Core.Runtime.Log
  require Logger

  @private_modes %{
    1 => :decckm,
    2 => :ansi,
    3 => :deccolm_132,
    4 => :smooth_scroll,
    5 => :decscnm,
    6 => :decom,
    7 => :decawm,
    8 => :decarm,
    9 => :decinlm,
    12 => :att_blink,
    25 => :dectcem,
    47 => :dec_alt_screen,
    1047 => :dec_alt_screen_save,
    1048 => :decsc_deccara,
    1049 => :alt_screen_buffer
  }

  @charsets %{
    ?0 => :us_ascii,
    ?1 => :dec_special,
    ?2 => :dec_supplementary,
    ?3 => :dec_technical,
    ?4 => :dec_supplementary_graphics,
    ?5 => :dec_supplementary_ipa,
    ?6 => :dec_supplementary_arabic,
    ?7 => :dec_supplementary_hebrew,
    ?8 => :dec_supplementary_latin1,
    ?9 => :dec_supplementary_latin2
  }

  @public_modes %{
    2 => :keyboard_action,
    4 => :irm,
    12 => :send_receive,
    20 => :lnm,
    34 => :cursor_style,
    36 => :keyboard_type,
    40 => :allow_80_to_132,
    42 => :more_fix,
    44 => :turn_off_margin_bell,
    66 => :application_keypad
  }

  @sequence_handlers %{
    [?A] => {:cursor_up, 1},
    [?B] => {:cursor_down, 1},
    [?C] => {:cursor_forward, 1},
    [?D] => {:cursor_backward, 1},
    [?H] => {:cursor_position, []},
    [?G] => {:cursor_column, 1},
    [?J] => {:screen_clear, []},
    [?K] => {:line_clear, 0},
    [?m] => {:text_attributes, []},
    [?S] => {:scroll_up, 1},
    [?T] => {:scroll_down, 1},
    [?n] => {:device_status, []},
    [?s] => {:save_restore_cursor, []},
    [?u] => {:save_restore_cursor, []},
    [?6, ?n] => {:device_status_report, []},
    [?6, ?R] => {:cursor_position_report, []},
    [?N] => {:locking_shift_g0, []},
    [?O] => {:locking_shift_g1, []},
    [?R] => {:single_shift_g2, []}
  }

  # Cursor movement functions (defined before the map that references them)
  def handle_cursor_up(emulator, amount) do
    case Raxol.Terminal.Commands.CSIHandlers.Cursor.handle_command(
           emulator,
           [amount],
           ?A
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  def handle_cursor_down(emulator, amount) do
    case Raxol.Terminal.Commands.CSIHandlers.Cursor.handle_command(
           emulator,
           [amount],
           ?B
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  def handle_cursor_forward(emulator, amount) do
    case Raxol.Terminal.Commands.CSIHandlers.Cursor.handle_command(
           emulator,
           [amount],
           ?C
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  def handle_cursor_backward(emulator, amount) do
    case Raxol.Terminal.Commands.CSIHandlers.Cursor.handle_command(
           emulator,
           [amount],
           ?D
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  def handle_cursor_position(emulator, row, col) do
    # Handle direct coordinate setting with proper clamping
    # The test passes 1-indexed coordinates that should be converted to 0-indexed
    active_buffer = Raxol.Terminal.BufferManager.get_active_buffer(emulator)
    width = Raxol.Terminal.ScreenBuffer.get_width(active_buffer)
    height = Raxol.Terminal.ScreenBuffer.get_height(active_buffer)

    # Convert from 1-indexed to 0-indexed coordinates, handling negative values
    row_0_indexed = if row <= 0, do: 0, else: row - 1
    col_0_indexed = if col <= 0, do: 0, else: col - 1

    # Clamp coordinates to screen bounds
    row_clamped = max(0, min(row_0_indexed, height - 1))
    col_clamped = max(0, min(col_0_indexed, width - 1))

    # Update cursor position - cursor stores {col, row} format
    # For test cursors that are structs, update directly
    updated_cursor =
      case emulator.cursor do
        %{row: _, col: _} = cursor ->
          %{
            cursor
            | row: row_clamped,
              col: col_clamped,
              position: {col_clamped, row_clamped}
          }

        _ ->
          # For PID cursors, use the manager
          Raxol.Terminal.Cursor.Manager.set_position(
            emulator.cursor,
            {col_clamped, row_clamped}
          )

          emulator.cursor
      end

    {:ok, %{emulator | cursor: updated_cursor}}
  end

  def handle_cursor_position(emulator, params) do
    {row, col} = parse_cursor_position_params(params)

    result =
      Raxol.Terminal.Commands.CSIHandlers.Cursor.handle_command(
        emulator,
        [row, col],
        ?H
      )

    case result do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  defp parse_cursor_position_params(params) do
    case params do
      [] ->
        {1, 1}

      [row] ->
        {row, 1}

      [row, col] ->
        {row, col}

      [row, ?;, col] ->
        row_int = if is_integer(row), do: row, else: row - ?0
        col_int = if is_integer(col), do: col, else: col - ?0
        {row_int, col_int}

      _ ->
        {1, 1}
    end
  end

  def handle_cursor_column(emulator, column) do
    case Raxol.Terminal.Commands.CSIHandlers.Cursor.handle_command(
           emulator,
           [column],
           ?G
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator -> updated_emulator
    end
  end

  # Screen operations (defined before the map that references them)
  def handle_erase_display(emulator, mode) do
    Raxol.Terminal.Commands.CSIHandlers.Screen.handle_command(
      emulator,
      [mode],
      ?J
    )
  end

  def handle_erase_line(emulator, mode) do
    Raxol.Terminal.Commands.CSIHandlers.Screen.handle_command(
      emulator,
      [mode],
      ?K
    )
  end

  def handle_screen_clear(emulator, params) do
    case params do
      [] -> handle_erase_display(emulator, 0)
      [0] -> handle_erase_display(emulator, 0)
      [1] -> handle_erase_display(emulator, 1)
      [2] -> handle_erase_display(emulator, 2)
      _ -> {:ok, emulator}
    end
  end

  def handle_line_clear(emulator, params) do
    case params do
      [] -> handle_erase_line(emulator, 0)
      [0] -> handle_erase_line(emulator, 0)
      [1] -> handle_erase_line(emulator, 1)
      [2] -> handle_erase_line(emulator, 2)
      _ -> {:ok, emulator}
    end
  end

  # Scrolling operations (defined before the map that references them)
  def handle_scroll_up(emulator, lines) do
    Raxol.Terminal.Commands.CSIHandlers.Screen.handle_command(
      emulator,
      [lines],
      ?S
    )
  end

  def handle_scroll_down(emulator, lines) do
    Raxol.Terminal.Commands.CSIHandlers.Screen.handle_command(
      emulator,
      [lines],
      ?T
    )
  end

  # Device operations (defined before the map that references them)
  def handle_device_status(emulator, param) when is_integer(param) do
    case param do
      5 -> handle_device_status_report(emulator, 5)
      6 -> handle_device_status_report(emulator, 6)
      _ -> emulator
    end
  end

  def handle_device_status(emulator, params) when is_list(params) do
    case params do
      [?6, ?n] -> handle_device_status_report(emulator, 6)
      [?6, ?R] -> handle_cursor_position_report(emulator)
      [param] when is_integer(param) -> handle_device_status(emulator, param)
      _ -> emulator
    end
  end

  defp handle_device_status_report(emulator, status_code) do
    case Raxol.Terminal.Commands.CSIHandlers.Device.handle_command(
           emulator,
           [status_code],
           "",
           ?n
         ) do
      {:ok, updated_emulator} -> updated_emulator
      result -> result
    end
  end

  defp handle_device_status_report(emulator) do
    # Default to status code 6 (cursor position report)
    handle_device_status_report(emulator, 6)
  end

  def handle_cursor_position_report(emulator) do
    # Handle cursor position report sequence [?6, ?R]
    case Raxol.Terminal.Commands.CSIHandlers.Device.handle_command(
           emulator,
           [6],
           "",
           ?n
         ) do
      {:ok, updated_emulator} ->
        %{updated_emulator | cursor_position_reported: true}

      result ->
        %{result | cursor_position_reported: true}
    end
  end

  def handle_locking_shift_g0(emulator) do
    # Locking Shift G0 - set GL to G0
    updated_charset_state = %{emulator.charset_state | gl: :g0}
    %{emulator | charset_state: updated_charset_state}
  end

  def handle_locking_shift_g1(emulator) do
    # Locking Shift G1 - set GL to G1
    updated_charset_state = %{emulator.charset_state | gl: :g1}
    %{emulator | charset_state: updated_charset_state}
  end

  def handle_single_shift_g2(emulator) do
    # Single Shift G2 - set single_shift to G2
    updated_charset_state = %{
      emulator.charset_state
      | single_shift: emulator.charset_state.g2
    }

    %{emulator | charset_state: updated_charset_state}
  end

  def handle_single_shift_g3(emulator) do
    # Single Shift G3 - set single_shift to G3
    updated_charset_state = %{
      emulator.charset_state
      | single_shift: emulator.charset_state.g3
    }

    %{emulator | charset_state: updated_charset_state}
  end

  # Text attributes (defined before the map that references them)
  def handle_text_attributes(emulator, params) do
    case Raxol.Terminal.Commands.CSIHandlers.Basic.handle_command(
           emulator,
           params,
           ?m
         ) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, _} -> emulator
      updated_emulator when is_map(updated_emulator) -> updated_emulator
      _ -> emulator
    end
  end

  # Save/Restore cursor (defined before the map that references them)
  def handle_save_restore_cursor(emulator, params) do
    Raxol.Terminal.Commands.CSIHandlers.Basic.handle_command(
      emulator,
      params,
      ?s
    )
  end

  def csi_command_handlers do
    [
      {:cursor_up, &handle_cursor_up/2},
      {:cursor_down, &handle_cursor_down/2},
      {:cursor_forward, &handle_cursor_forward/2},
      {:cursor_backward, &handle_cursor_backward/2},
      {:cursor_position, &handle_cursor_position/2, :with_params},
      {:cursor_column, &handle_cursor_column/2},
      {:screen_clear, &handle_screen_clear/2, :with_params},
      {:line_clear, &handle_erase_line/2, 0},
      {:text_attributes, &handle_text_attributes/2, :with_params},
      {:scroll_up, &handle_scroll_up/2},
      {:scroll_down, &handle_scroll_down/2},
      {:device_status, &handle_device_status/2, :with_params},
      {:save_restore_cursor, &handle_save_restore_cursor/2, :with_params}
    ]
    |> Enum.map(fn
      {key, fun} -> {key, create_handler(fun)}
      {key, fun, :with_params} -> {key, create_handler_with_params(fun)}
      {key, fun, default} -> {key, create_handler(fun, default)}
    end)
    |> Map.new()
  end

  # Helper functions for creating handlers
  defp create_handler(fun) do
    fn emulator, params ->
      fun.(emulator, params)
    end
  end

  defp create_handler(fun, default) do
    fn emulator, params ->
      case params do
        [] -> fun.(emulator, default)
        [param] -> fun.(emulator, param)
        _ -> fun.(emulator, params)
      end
    end
  end

  defp create_handler_with_params(fun) do
    fn emulator, params ->
      fun.(emulator, params)
    end
  end

  def handle_basic_command(emulator, params, byte) do
    Basic.handle_command(emulator, params, byte)
  end

  def handle_cursor_command(emulator, params, byte) do
    Cursor.handle_command(emulator, params, byte)
  end

  def handle_screen_command(emulator, params, byte) do
    Screen.handle_command(emulator, params, byte)
  end

  def handle_device_command(emulator, params, intermediates_buffer, byte) do
    Device.handle_command(emulator, params, intermediates_buffer, byte)
  end

  def handle_h_or_l(emulator, params, intermediates_buffer, final_byte) do
    require Logger

    Logger.debug(
      "CSIHandlers.handle_h_or_l called with params=#{inspect(params)}, intermediates_buffer=#{inspect(intermediates_buffer)}, final_byte=#{inspect(final_byte)}"
    )

    case intermediates_buffer do
      "?" -> handle_private_mode(emulator, params, final_byte)
      _ -> handle_public_mode(emulator, params, final_byte)
    end
  end

  def handle_deccusr(emulator, params) do
    Basic.handle_decscusr(emulator, params)
  end

  @doc """
  Handles DECCUSR (DEC Cursor Style Report) command.
  This is an alias for handle_deccusr/2 for backward compatibility.
  """
  def handle_q_deccusr(emulator, params) do
    handle_deccusr(emulator, params)
  end

  @charset_mapping %{
    ?0 => :dec_special_graphics,
    ?1 => :uk,
    ?2 => :us_ascii,
    ?3 => :dec_technical,
    ?4 => :dec_special_graphics,
    ?5 => :dec_special_graphics,
    ?6 => :portuguese,
    ?7 => :dec_special_graphics,
    ?8 => :dec_special_graphics,
    ?9 => :dec_special_graphics,
    ?A => :uk,
    ?B => :us_ascii,
    ?F => :german,
    ?D => :french,
    ?R => :dec_technical,
    ?' => :portuguese,
    ?> => Raxol.Terminal.ANSI.CharacterSets.DEC
  }

  defp parse_charset_code(params) do
    case params do
      "" -> ?B
      # Special case: "16" maps to DEC Special Graphics (same as "0")
      "16" -> ?0
      <<code>> when code in ?0..?9 or code in ?A..?Z or code in ?a..?z -> code
      _ -> ?B
    end
  end

  defp get_charset(charset_code) do
    Map.get(@charset_mapping, charset_code, :us_ascii)
  end

  def handle_scs(emulator, params_buffer, final_byte) do
    charset_code = parse_charset_code(params_buffer)
    charset = get_charset(charset_code)

    field =
      case final_byte do
        ?( -> :g0
        ?) -> :g1
        ?* -> :g2
        ?+ -> :g3
        _ -> :g0
      end

    updated_charset_state = Map.put(emulator.charset_state, field, charset)
    %{emulator | charset_state: updated_charset_state}
  end

  # Private mode handlers
  defp handle_private_mode(emulator, [mode], final_byte) do
    require Logger

    Logger.debug(
      "handle_private_mode: mode=#{inspect(mode)}, final_byte=#{inspect(final_byte)}"
    )

    case Map.get(@private_modes, mode) do
      nil ->
        Logger.debug(
          "handle_private_mode: mode #{inspect(mode)} not found in @private_modes"
        )

        emulator

      mode_name ->
        Logger.debug(
          "handle_private_mode: found mode_name=#{inspect(mode_name)}"
        )

        case final_byte do
          ?h ->
            Logger.debug(
              "handle_private_mode: calling Emulator.set_mode(emulator, #{inspect(mode_name)})"
            )

            result = Emulator.set_mode(emulator, mode_name)

            Logger.debug(
              "handle_private_mode: Emulator.set_mode returned #{inspect(result)}"
            )

            result

          ?l ->
            Logger.debug(
              "handle_private_mode: calling Emulator.reset_mode(emulator, #{inspect(mode_name)})"
            )

            result = Emulator.reset_mode(emulator, mode_name)

            Logger.debug(
              "handle_private_mode: Emulator.reset_mode returned #{inspect(result)}"
            )

            result
        end
    end
  end

  defp handle_public_mode(emulator, [mode], final_byte) do
    require Logger
    mode_name = Map.get(@public_modes, mode)

    Logger.debug(
      "handle_public_mode: mode=#{inspect(mode)}, mode_name=#{inspect(mode_name)}, final_byte=#{inspect(final_byte)}, type=#{inspect(is_integer(final_byte))}"
    )

    case mode_name do
      nil ->
        emulator

      _ ->
        case final_byte do
          ?h ->
            Raxol.Terminal.Emulator.set_mode(emulator, mode_name)

          ?l ->
            Raxol.Terminal.Emulator.reset_mode(emulator, mode_name)

          _ ->
            Logger.debug(
              "handle_public_mode: Unhandled final_byte #{inspect(final_byte)}"
            )

            emulator
        end
    end
  end

  def handle_cursor_movement(emulator, sequence) do
    case sequence do
      [?A] -> handle_cursor_up(emulator, 1)
      [?B] -> handle_cursor_down(emulator, 1)
      [?C] -> handle_cursor_forward(emulator, 1)
      [?D] -> handle_cursor_backward(emulator, 1)
      _ -> emulator
    end
  end

  # Mode changes
  def handle_mode_change(emulator, mode, enabled) do
    case get_mode_name(mode) do
      nil -> emulator
      mode_name -> set_or_reset_mode(emulator, mode_name, enabled)
    end
  end

  defp get_mode_name(mode) do
    Map.get(@public_modes, mode) || Map.get(@private_modes, mode)
  end

  defp set_or_reset_mode(emulator, mode_name, enabled) do
    if enabled do
      Emulator.set_mode(emulator, mode_name)
    else
      Emulator.reset_mode(emulator, mode_name)
    end
  end

  # Scrolling region
  def handle_r(emulator, params) do
    case params do
      [] -> Screen.handle_command(emulator, [], ?r)
      [top] -> Screen.handle_command(emulator, [top], ?r)
      [top, bottom] -> Screen.handle_command(emulator, [top, bottom], ?r)
      _ -> emulator
    end
  end

  # Save/Restore cursor (alias)
  def handle_s(emulator, params) do
    Basic.handle_command(emulator, params, ?s)
  end

  def handle_u(emulator, params) do
    Basic.handle_command(emulator, params, ?u)
  end

  # Sequence handler
  def handle_sequence(emulator, sequence) do
    case Map.get(@sequence_handlers, sequence) do
      {handler, args} ->
        result = apply_handler(emulator, handler, args)

        case result do
          {:ok, emu} -> emu
          {:error, _, emu} -> emu
          emu -> emu
        end

      nil ->
        # Handle parameterized sequences
        case parse_parameterized_sequence(sequence) do
          {:ok, handler, params} ->
            result = apply_handler(emulator, handler, params)

            case result do
              {:ok, emu} -> emu
              {:error, _, emu} -> emu
              emu -> emu
            end

          :error ->
            emulator
        end
    end
  end

  defp parse_parameterized_sequence(sequence) do
    case sequence do
      [row, ?;, col, ?H] ->
        row_int = if is_integer(row), do: row, else: row - ?0
        col_int = if is_integer(col), do: col, else: col - ?0
        {:ok, :cursor_position, [row_int, col_int]}

      [row, ?H] ->
        row_int = if is_integer(row), do: row, else: row - ?0
        {:ok, :cursor_position, [row_int]}

      [?H] ->
        {:ok, :cursor_position, []}

      [col, ?G] ->
        col_int = if is_integer(col), do: col, else: col - ?0
        {:ok, :cursor_column, [col_int]}

      [?G] ->
        {:ok, :cursor_column, [1]}

      [mode, ?J] ->
        mode_int = if is_integer(mode), do: mode, else: mode - ?0
        {:ok, :screen_clear, [mode_int]}

      [?J] ->
        {:ok, :screen_clear, []}

      [mode, ?K] ->
        mode_int = if is_integer(mode), do: mode, else: mode - ?0
        {:ok, :line_clear, [mode_int]}

      [?K] ->
        {:ok, :line_clear, []}

      [lines, ?S] ->
        lines_int = if is_integer(lines), do: lines, else: lines - ?0
        {:ok, :scroll_up, [lines_int]}

      [?S] ->
        {:ok, :scroll_up, [1]}

      [lines, ?T] ->
        lines_int = if is_integer(lines), do: lines, else: lines - ?0
        {:ok, :scroll_down, [lines_int]}

      [?T] ->
        {:ok, :scroll_down, [1]}

      [amount, ?A] ->
        amount_int = if is_integer(amount), do: amount, else: amount - ?0
        {:ok, :cursor_up, [amount_int]}

      [?A] ->
        {:ok, :cursor_up, [1]}

      [amount, ?B] ->
        amount_int = if is_integer(amount), do: amount, else: amount - ?0
        {:ok, :cursor_down, [amount_int]}

      [?B] ->
        {:ok, :cursor_down, [1]}

      [amount, ?C] ->
        amount_int = if is_integer(amount), do: amount, else: amount - ?0
        {:ok, :cursor_forward, [amount_int]}

      [?C] ->
        {:ok, :cursor_forward, [1]}

      [amount, ?D] ->
        amount_int = if is_integer(amount), do: amount, else: amount - ?0
        {:ok, :cursor_backward, [amount_int]}

      [?D] ->
        {:ok, :cursor_backward, [1]}

      _ ->
        :error
    end
  end

  defp apply_handler(emulator, :cursor_up, amount),
    do: handle_cursor_up(emulator, amount)

  defp apply_handler(emulator, :cursor_down, amount),
    do: handle_cursor_down(emulator, amount)

  defp apply_handler(emulator, :cursor_forward, amount),
    do: handle_cursor_forward(emulator, amount)

  defp apply_handler(emulator, :cursor_backward, amount),
    do: handle_cursor_backward(emulator, amount)

  defp apply_handler(emulator, :cursor_position, params),
    do: handle_cursor_position(emulator, params)

  defp apply_handler(emulator, :cursor_column, column),
    do: handle_cursor_column(emulator, column)

  defp apply_handler(emulator, :screen_clear, params),
    do: handle_screen_clear(emulator, params)

  defp apply_handler(emulator, :line_clear, params),
    do: handle_line_clear(emulator, params)

  defp apply_handler(emulator, :text_attributes, params),
    do: handle_text_attributes(emulator, params)

  defp apply_handler(emulator, :save_restore_cursor, params),
    do: handle_save_restore_cursor(emulator, params)

  defp apply_handler(emulator, :r, params), do: handle_r(emulator, params)

  defp apply_handler(emulator, :scroll_up, lines),
    do: handle_scroll_up(emulator, lines)

  defp apply_handler(emulator, :scroll_down, lines),
    do: handle_scroll_down(emulator, lines)

  defp apply_handler(emulator, :device_status, params),
    do: handle_device_status(emulator, params)

  defp apply_handler(emulator, :device_status_report, _params),
    do: handle_device_status_report(emulator)

  defp apply_handler(emulator, :cursor_position_report, _params),
    do: handle_cursor_position_report(emulator)

  defp apply_handler(emulator, :locking_shift_g0, _params),
    do: handle_locking_shift_g0(emulator)

  defp apply_handler(emulator, :locking_shift_g1, _params),
    do: handle_locking_shift_g1(emulator)

  defp apply_handler(emulator, :single_shift_g2, _params),
    do: handle_single_shift_g2(emulator)

  defp apply_handler(emulator, :single_shift_g3, _params),
    do: handle_single_shift_g3(emulator)

  # Window handler implementations
  def handle_window_maximize(emulator) do
    case WindowHandlers.handle_t(emulator, [9]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_unmaximize(emulator) do
    case WindowHandlers.handle_t(emulator, [10]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_minimize(emulator) do
    case WindowHandlers.handle_t(emulator, [2]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_unminimize(emulator) do
    case WindowHandlers.handle_t(emulator, [1]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_iconify(emulator) do
    case WindowHandlers.handle_t(emulator, [2]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_deiconify(emulator) do
    case WindowHandlers.handle_t(emulator, [1]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_raise(emulator) do
    case WindowHandlers.handle_t(emulator, [5]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_lower(emulator) do
    case WindowHandlers.handle_t(emulator, [6]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_fullscreen(emulator) do
    # Set stacking order to fullscreen
    updated_window_state = %{
      emulator.window_state
      | stacking_order: :fullscreen
    }

    %{emulator | window_state: updated_window_state}
  end

  def handle_window_unfullscreen(emulator) do
    # Set stacking order to normal
    updated_window_state = %{emulator.window_state | stacking_order: :normal}
    %{emulator | window_state: updated_window_state}
  end

  def handle_window_title(emulator) do
    # Get title from emulator.window_title or use empty string
    title = emulator.window_title || ""

    case WindowHandlers.handle_t(emulator, [0, title]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_icon_name(emulator) do
    # Get icon name from window_state if available
    icon_name = Map.get(emulator.window_state, :icon_name, "")

    case WindowHandlers.handle_t(emulator, [8, icon_name]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_icon_title(emulator) do
    # Icon title should be the same as window title
    title = emulator.window_title || ""
    output = "\x1b]2;#{title}\x07"
    %{emulator | output_buffer: output}
  end

  def handle_window_icon_title_name(emulator) do
    # Icon title and name should be window title and icon name
    title = emulator.window_title || ""
    icon_name = Map.get(emulator.window_state, :icon_name, "")
    output = "\x1b]3;#{title};#{icon_name}\x07"
    %{emulator | output_buffer: output}
  end

  def handle_window_save_title(emulator) do
    # Save current size
    current_size = emulator.window_state.size
    updated_window_state = %{emulator.window_state | saved_size: current_size}
    %{emulator | window_state: updated_window_state}
  end

  def handle_window_restore_title(emulator) do
    # Restore saved size or use default
    saved_size = Map.get(emulator.window_state, :saved_size, {80, 24})
    updated_window_state = %{emulator.window_state | size: saved_size}
    %{emulator | window_state: updated_window_state}
  end

  def handle_window_size_report(emulator) do
    case WindowHandlers.handle_t(emulator, [18]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  def handle_window_size_pixels(emulator) do
    {w, h} = emulator.window_state.size

    width_px =
      w * Raxol.Terminal.Commands.WindowHandlers.default_char_width_px()

    height_px =
      h * Raxol.Terminal.Commands.WindowHandlers.default_char_height_px()

    output = "\x1b[4;#{height_px};#{width_px}t"
    %{emulator | output_buffer: output}
  end

  @doc """
  Handles a CSI sequence with command and parameters.
  """
  @spec handle_csi_sequence(Emulator.t(), atom(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_csi_sequence(emulator, command, params) do
    handlers = csi_command_handlers()

    case Map.get(handlers, command) do
      nil -> emulator
      handler -> handler.(emulator, params)
    end
  end
end
