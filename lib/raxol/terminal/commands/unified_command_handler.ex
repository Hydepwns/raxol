defmodule Raxol.Terminal.Commands.UnifiedCommandHandler do
  @moduledoc """
  Unified command handler that consolidates all terminal command processing.

  This module replaces the fragmented handler pattern with a single, organized
  command processing system that handles:
  - Cursor movement and positioning commands
  - Device status and attribute commands
  - Erase operations (screen, line, character)
  - CSI (Control Sequence Introducer) commands
  - OSC (Operating System Command) sequences
  - DCS (Device Control String) commands
  - Mode setting and resetting
  - Text formatting and styling
  - Window operations
  - Buffer operations

  ## Design Principles

  1. **Unified Interface**: Single entry point for all command processing
  2. **Command Routing**: Intelligent routing based on command type and parameters
  3. **State Management**: Consistent state handling across all command types
  4. **Error Handling**: Centralized error handling with graceful fallbacks
  5. **Performance**: Optimized dispatching with minimal overhead
  6. **Extensibility**: Easy to add new command types and handlers

  ## Command Categories

  - **Cursor Commands**: CUP, CUU, CUD, CUF, CUB, HVP, etc.
  - **Erase Commands**: ED, EL, ECH, etc.
  - **Device Commands**: DA, DSR, CPR, etc.
  - **Mode Commands**: SM, RM, DECSET, DECRST, etc.
  - **Text Commands**: SGR, TBC, CTC, etc.
  - **Window Commands**: Window resize, title setting, etc.
  - **Buffer Commands**: Buffer switching, scrolling, etc.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.{OutputManager, ScreenBuffer}
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.Commands.CursorUtils
  alias Raxol.Terminal.Buffer.Eraser

  require Raxol.Core.Runtime.Log

  @type command_result :: {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  @type command_type :: :csi | :osc | :dcs | :escape | :control
  @type command_params :: %{
          type: command_type(),
          command: String.t(),
          params: list(integer()),
          intermediates: String.t(),
          private_markers: String.t()
        }

  ## Public API

  @doc """
  Processes any terminal command with unified handling.

  This is the main entry point for all command processing.
  """
  @spec handle_command(Emulator.t(), command_params()) :: command_result()
  def handle_command(emulator, %{type: type, command: command} = cmd_params) do
    Raxol.Core.Runtime.Log.debug("Processing #{type} command: #{command}")

    case route_command(type, command, cmd_params) do
      {:ok, handler_func} ->
        execute_command(emulator, handler_func, cmd_params)

      {:error, :unknown_command} ->
        Raxol.Core.Runtime.Log.warning("Unknown #{type} command: #{command}")
        # Graceful fallback
        {:ok, emulator}
    end
  end

  @doc """
  Handles CSI (Control Sequence Introducer) commands.
  """
  @spec handle_csi(Emulator.t(), String.t(), list(integer()), String.t()) ::
          command_result()
  def handle_csi(emulator, command, params \\ [], intermediates \\ "") do
    cmd_params = %{
      type: :csi,
      command: command,
      params: params,
      intermediates: intermediates,
      private_markers: ""
    }

    handle_command(emulator, cmd_params)
  end

  @doc """
  Handles OSC (Operating System Command) sequences.
  """
  @spec handle_osc(Emulator.t(), String.t(), String.t()) :: command_result()
  def handle_osc(emulator, command, data) do
    cmd_params = %{
      type: :osc,
      command: command,
      params: [data],
      intermediates: "",
      private_markers: ""
    }

    handle_command(emulator, cmd_params)
  end

  ## Command Routing

  defp route_command(:csi, command, _params) do
    case categorize_csi_command(command) do
      {:cursor, handler} -> {:ok, handler}
      {:erase, handler} -> {:ok, handler}
      {:device, handler} -> {:ok, handler}
      {:mode, handler} -> {:ok, handler}
      {:text, handler} -> {:ok, handler}
      {:scroll, handler} -> {:ok, handler}
      {:buffer, handler} -> {:ok, handler}
      {:tab, handler} -> {:ok, handler}
      :unknown -> {:error, :unknown_command}
    end
  end

  defp route_command(:osc, command, _params) do
    case command do
      "0" -> {:ok, &handle_window_title/3}
      "1" -> {:ok, &handle_window_icon/3}
      "2" -> {:ok, &handle_window_title/3}
      "4" -> {:ok, &handle_color_palette/3}
      "10" -> {:ok, &handle_foreground_color/3}
      "11" -> {:ok, &handle_background_color/3}
      _ -> {:error, :unknown_command}
    end
  end

  defp route_command(:dcs, command, _params) do
    case command do
      "q" -> {:ok, &handle_sixel/3}
      _ -> {:error, :unknown_command}
    end
  end

  defp route_command(_type, _command, _params) do
    {:error, :unknown_command}
  end

  ## CSI Command Categorization

  defp categorize_csi_command(command) do
    cond do
      command in ~w[A B C D E F G H f d] ->
        {:cursor, get_cursor_handler(command)}

      command in ~w[J K X] ->
        {:erase, get_erase_handler(command)}

      command in ~w[c n] ->
        {:device, get_device_handler(command)}

      command in ~w[h l] ->
        {:mode, get_mode_handler(command)}

      command == "m" ->
        {:text, &handle_sgr/3}

      command in ~w[S T] ->
        {:scroll, get_scroll_handler(command)}

      command in ~w[L M P @] ->
        {:buffer, get_buffer_handler(command)}

      command == "g" ->
        {:tab, &handle_tab_clear/3}

      true ->
        :unknown
    end
  end

  defp get_cursor_handler(command) do
    cursor_handlers()[command]
  end

  defp get_erase_handler(command) do
    erase_handlers()[command]
  end

  defp get_device_handler(command) do
    device_handlers()[command]
  end

  defp get_mode_handler(command) do
    mode_handlers()[command]
  end

  defp get_scroll_handler(command) do
    scroll_handlers()[command]
  end

  defp get_buffer_handler(command) do
    buffer_handlers()[command]
  end

  # Handler maps
  defp cursor_handlers do
    %{
      "A" => &handle_cursor_up/3,
      "B" => &handle_cursor_down/3,
      "C" => &handle_cursor_forward/3,
      "D" => &handle_cursor_backward/3,
      "E" => &handle_cursor_next_line/3,
      "F" => &handle_cursor_previous_line/3,
      "G" => &handle_cursor_horizontal_absolute/3,
      "H" => &handle_cursor_position/3,
      # HVP - same as CUP
      "f" => &handle_cursor_position/3,
      # VPA
      "d" => &handle_cursor_vertical_absolute/3
    }
  end

  defp erase_handlers do
    %{
      "J" => &handle_erase_display/3,
      "K" => &handle_erase_line/3,
      "X" => &handle_erase_character/3
    }
  end

  defp device_handlers do
    %{
      "c" => &handle_device_attributes/3,
      "n" => &handle_device_status_report/3
    }
  end

  defp mode_handlers do
    %{
      "h" => &handle_set_mode/3,
      "l" => &handle_reset_mode/3
    }
  end

  defp scroll_handlers do
    %{
      "S" => &handle_scroll_up/3,
      "T" => &handle_scroll_down/3
    }
  end

  defp buffer_handlers do
    %{
      "L" => &handle_insert_lines/3,
      "M" => &handle_delete_lines/3,
      "P" => &handle_delete_characters/3,
      "@" => &handle_insert_characters/3
    }
  end

  ## Command Execution

  defp execute_command(emulator, handler_func, cmd_params) do
    try do
      handler_func.(emulator, cmd_params, %{})
    rescue
      error ->
        Raxol.Core.Runtime.Log.error(
          "Command execution failed: #{inspect(error)}"
        )

        {:error, :command_execution_failed, emulator}
    catch
      :throw, reason ->
        Raxol.Core.Runtime.Log.error("Command threw: #{inspect(reason)}")
        {:error, :command_thrown, emulator}
    end
  end

  ## Cursor Movement Commands

  defp handle_cursor_up(emulator, %{params: params}, _context) do
    amount = get_param(params, 0, 1)
    move_cursor(emulator, :up, amount)
  end

  defp handle_cursor_down(emulator, %{params: params}, _context) do
    amount = get_param(params, 0, 1)
    move_cursor(emulator, :down, amount)
  end

  defp handle_cursor_forward(emulator, %{params: params}, _context) do
    amount = get_param(params, 0, 1)
    move_cursor(emulator, :right, amount)
  end

  defp handle_cursor_backward(emulator, %{params: params}, _context) do
    amount = get_param(params, 0, 1)
    move_cursor(emulator, :left, amount)
  end

  defp handle_cursor_next_line(emulator, %{params: params}, _context) do
    amount = get_param(params, 0, 1)

    with {:ok, emulator} <- move_cursor(emulator, :down, amount) do
      move_cursor_to_column(emulator, 0)
    end
  end

  defp handle_cursor_previous_line(emulator, %{params: params}, _context) do
    amount = get_param(params, 0, 1)

    with {:ok, emulator} <- move_cursor(emulator, :up, amount) do
      move_cursor_to_column(emulator, 0)
    end
  end

  defp handle_cursor_horizontal_absolute(emulator, %{params: params}, _context) do
    # Convert to 0-based
    col = get_param(params, 0, 1) - 1
    move_cursor_to_column(emulator, col)
  end

  defp handle_cursor_position(emulator, %{params: params}, _context) do
    # Convert to 0-based
    row = get_param(params, 0, 1) - 1
    # Convert to 0-based
    col = get_param(params, 1, 1) - 1
    set_cursor_position(emulator, {row, col})
  end

  defp handle_cursor_vertical_absolute(emulator, %{params: params}, _context) do
    # Convert to 0-based
    row = get_param(params, 0, 1) - 1
    {_, col} = get_cursor_position(emulator)
    set_cursor_position(emulator, {row, col})
  end

  ## Erase Commands

  defp handle_erase_display(emulator, %{params: params}, _context) do
    mode = get_param(params, 0, 0)
    perform_screen_erase(emulator, mode)
  end

  defp handle_erase_line(emulator, %{params: params}, _context) do
    mode = get_param(params, 0, 0)
    perform_line_erase(emulator, mode)
  end

  defp handle_erase_character(emulator, %{params: params}, _context) do
    count = get_param(params, 0, 1)
    perform_character_erase(emulator, count)
  end

  ## Device Commands

  defp handle_device_attributes(
         emulator,
         %{params: params, intermediates: intermediates},
         _context
       ) do
    case {params, intermediates} do
      {[], ""} ->
        # Primary DA with no params and no intermediates
        response = generate_primary_da_response()
        {:ok, OutputManager.write(emulator, response)}

      {[0], ""} ->
        # Primary DA with explicit 0 param
        response = generate_primary_da_response()
        {:ok, OutputManager.write(emulator, response)}

      {[], ">"} ->
        # Secondary DA with no params
        response = generate_secondary_da_response()
        {:ok, OutputManager.write(emulator, response)}

      {[0], ">"} ->
        # Secondary DA with explicit 0 param
        response = generate_secondary_da_response()
        {:ok, OutputManager.write(emulator, response)}

      _ ->
        # Ignore other DA requests
        {:ok, emulator}
    end
  end

  defp handle_device_status_report(emulator, %{params: params}, _context) do
    code = get_param(params, 0, 5)
    Raxol.Core.Runtime.Log.debug("DSR request: code=#{code}")

    response =
      case code do
        # Device OK
        5 -> "\e[0n"
        # Cursor Position Report
        6 -> generate_cursor_position_report(emulator)
        _ -> nil
      end

    Raxol.Core.Runtime.Log.debug("DSR response: #{inspect(response)}")

    case response do
      nil -> {:ok, emulator}
      _ -> {:ok, OutputManager.write(emulator, response)}
    end
  end

  ## Mode Commands

  defp handle_set_mode(
         emulator,
         %{params: params, private_markers: private},
         _context
       ) do
    case private do
      "?" -> handle_dec_private_mode(emulator, params, :set)
      _ -> handle_ansi_mode(emulator, params, :set)
    end
  end

  defp handle_reset_mode(
         emulator,
         %{params: params, private_markers: private},
         _context
       ) do
    case private do
      "?" -> handle_dec_private_mode(emulator, params, :reset)
      _ -> handle_ansi_mode(emulator, params, :reset)
    end
  end

  ## Text Formatting Commands

  defp handle_sgr(emulator, %{params: params}, _context) do
    apply_text_formatting(emulator, params)
  end

  ## Scrolling Commands

  defp handle_scroll_up(emulator, %{params: params}, _context) do
    lines = get_param(params, 0, 1)
    perform_scroll(emulator, :up, lines)
  end

  defp handle_scroll_down(emulator, %{params: params}, _context) do
    lines = get_param(params, 0, 1)
    perform_scroll(emulator, :down, lines)
  end

  ## OSC Commands

  defp handle_window_title(emulator, %{params: [title]}, _context) do
    # Store window title in emulator state
    updated_emulator = %{emulator | window_title: title}
    {:ok, updated_emulator}
  end

  defp handle_window_icon(emulator, %{params: [icon_name]}, _context) do
    # Store icon name in emulator state
    updated_emulator = %{emulator | icon_name: icon_name}
    {:ok, updated_emulator}
  end

  defp handle_color_palette(emulator, %{params: [color_spec]}, _context) do
    # Parse and apply color palette changes
    apply_color_palette_change(emulator, color_spec)
  end

  defp handle_foreground_color(emulator, %{params: [color_spec]}, _context) do
    apply_foreground_color(emulator, color_spec)
  end

  defp handle_background_color(emulator, %{params: [color_spec]}, _context) do
    apply_background_color(emulator, color_spec)
  end

  ## Tab Commands

  defp handle_tab_clear(emulator, %{params: params}, _context) do
    mode = get_param(params, 0, 0)
    clear_tabs(emulator, mode)
  end

  ## Buffer Operations

  defp handle_insert_lines(emulator, %{params: params}, _context) do
    count = get_param(params, 0, 1)
    perform_insert_lines(emulator, count)
  end

  defp handle_delete_lines(emulator, %{params: params}, _context) do
    count = get_param(params, 0, 1)
    perform_delete_lines(emulator, count)
  end

  defp handle_delete_characters(emulator, %{params: params}, _context) do
    count = get_param(params, 0, 1)
    perform_delete_characters(emulator, count)
  end

  defp handle_insert_characters(emulator, %{params: params}, _context) do
    count = get_param(params, 0, 1)
    perform_insert_characters(emulator, count)
  end

  ## DCS Commands

  defp handle_sixel(emulator, %{params: [sixel_data]}, _context) do
    process_sixel_graphics(emulator, sixel_data)
  end

  ## Helper Functions

  defp get_param(params, index, default) do
    case Enum.at(params, index) do
      nil -> default
      0 -> default
      value when is_integer(value) and value > 0 -> value
      _ -> default
    end
  end

  defp move_cursor(emulator, direction, amount) do
    cursor_pos = get_cursor_position(emulator)
    {row, col} = cursor_pos

    {new_row, new_col} =
      CursorUtils.calculate_new_cursor_position(
        {row, col},
        direction,
        amount,
        emulator.width,
        emulator.height
      )

    set_cursor_position(emulator, {new_row, new_col})
  end

  defp move_cursor_to_column(emulator, col) do
    {row, _} = get_cursor_position(emulator)
    clamped_col = max(0, min(col, emulator.width - 1))
    set_cursor_position(emulator, {row, clamped_col})
  end

  defp get_cursor_position(emulator) do
    extract_position_from_cursor(emulator.cursor)
  end

  defp extract_position_from_cursor(cursor) do
    case cursor do
      pid when is_pid(pid) -> get_position_from_pid(pid)
      %{position: pos} when is_tuple(pos) -> pos
      %{row: row, col: col} -> {row, col}
      _ -> {0, 0}
    end
  end

  defp get_position_from_pid(pid) do
    case CursorManager.get_position(pid) do
      {:ok, pos} when is_tuple(pos) -> pos
      pos when is_tuple(pos) -> pos
      _ -> {0, 0}
    end
  end

  defp set_cursor_position(emulator, {row, col}) do
    clamped_row = max(0, min(row, emulator.height - 1))
    clamped_col = max(0, min(col, emulator.width - 1))

    case emulator.cursor do
      pid when is_pid(pid) ->
        :ok = CursorManager.set_position(pid, {clamped_row, clamped_col})
        {:ok, emulator}

      cursor_struct ->
        updated_cursor = %{cursor_struct | position: {clamped_row, clamped_col}}
        {:ok, %{emulator | cursor: updated_cursor}}
    end
  end

  defp perform_screen_erase(emulator, mode) do
    {active_buffer, cursor_pos, default_style} = get_buffer_state(emulator)

    Raxol.Core.Runtime.Log.debug(
      "perform_screen_erase: mode=#{mode}, cursor_pos=#{inspect(cursor_pos)}"
    )

    # Ensure buffer has the correct cursor position
    active_buffer = %{active_buffer | cursor_position: cursor_pos}

    new_buffer =
      case mode do
        0 ->
          {row, col} = cursor_pos
          Eraser.clear_screen_from(active_buffer, row, col, default_style)

        1 ->
          {row, col} = cursor_pos
          Eraser.clear_screen_to(active_buffer, row, col, default_style)

        2 ->
          Eraser.clear_screen(active_buffer, default_style)

        3 ->
          Eraser.clear_scrollback(active_buffer)

        _ ->
          active_buffer
      end

    # Update the emulator with the new buffer
    updated_emulator = update_emulator_buffer(emulator, new_buffer)
    {:ok, updated_emulator}
  end

  defp perform_line_erase(emulator, mode) do
    {active_buffer, cursor_pos, default_style} = get_buffer_state(emulator)

    # Ensure buffer has the correct cursor position
    active_buffer = %{active_buffer | cursor_position: cursor_pos}

    new_buffer =
      case mode do
        0 ->
          {row, col} = cursor_pos
          Eraser.clear_line_from(active_buffer, row, col, default_style)

        1 ->
          {row, col} = cursor_pos
          Eraser.clear_line_to(active_buffer, row, col, default_style)

        2 ->
          {row, _col} = cursor_pos
          Eraser.clear_line(active_buffer, row, default_style)

        _ ->
          active_buffer
      end

    # Update the emulator with the new buffer
    updated_emulator = update_emulator_buffer(emulator, new_buffer)
    {:ok, updated_emulator}
  end

  defp perform_character_erase(emulator, count) do
    {active_buffer, cursor_pos, _default_style} = get_buffer_state(emulator)

    # Ensure buffer has the correct cursor position
    active_buffer = %{active_buffer | cursor_position: cursor_pos}

    {row, col} = cursor_pos
    new_buffer = Eraser.erase_chars(active_buffer, row, col, count)

    # Update the emulator with the new buffer
    updated_emulator = update_emulator_buffer(emulator, new_buffer)
    {:ok, updated_emulator}
  end

  defp get_buffer_state(emulator) do
    active_buffer = Emulator.get_screen_buffer(emulator)
    cursor_pos = get_cursor_position(emulator)
    default_style = TextFormatting.new()
    {active_buffer, cursor_pos, default_style}
  end

  defp update_emulator_buffer(emulator, new_buffer) do
    # Update the appropriate buffer based on which is active
    case Map.get(emulator, :active_buffer_type, :main) do
      :alternate ->
        %{emulator | alternate_screen_buffer: new_buffer}

      _ ->
        %{emulator | main_screen_buffer: new_buffer}
    end
  end

  defp generate_primary_da_response do
    # VT102 compatible terminal
    "\e[?6c"
  end

  defp generate_secondary_da_response do
    # Secondary DA response with version info (basic xterm-like response)
    "\e[>0;0;0c"
  end

  defp generate_cursor_position_report(emulator) do
    pos = get_cursor_position(emulator)

    {row, col} =
      case pos do
        {r, c} when is_integer(r) and is_integer(c) -> {r, c}
        _ -> {0, 0}
      end

    # Convert to 1-based
    "\e[#{row + 1};#{col + 1}R"
  end

  defp handle_ansi_mode(emulator, params, action) do
    # Handle standard ANSI modes
    updated_emulator =
      Enum.reduce(params, emulator, fn mode, acc ->
        apply_ansi_mode(acc, mode, action)
      end)

    {:ok, updated_emulator}
  end

  defp handle_dec_private_mode(emulator, params, action) do
    # Handle DEC private modes (prefixed with ?)
    updated_emulator =
      Enum.reduce(params, emulator, fn mode, acc ->
        apply_dec_private_mode(acc, mode, action)
      end)

    {:ok, updated_emulator}
  end

  defp apply_ansi_mode(emulator, mode, action) do
    # Apply standard ANSI mode settings
    case {mode, action} do
      {4, :set} -> %{emulator | insert_mode: true}
      {4, :reset} -> %{emulator | insert_mode: false}
      {20, :set} -> %{emulator | automatic_newline: true}
      {20, :reset} -> %{emulator | automatic_newline: false}
      _ -> emulator
    end
  end

  defp apply_dec_private_mode(emulator, mode, action) do
    # Apply DEC private mode settings
    case {mode, action} do
      {1, :set} ->
        %{emulator | cursor_keys_mode: :application}

      {1, :reset} ->
        %{emulator | cursor_keys_mode: :normal}

      {25, :set} ->
        %{emulator | cursor_visible: true}

      {25, :reset} ->
        %{emulator | cursor_visible: false}

      {47, :set} ->
        switch_to_alternate_screen(emulator)

      {47, :reset} ->
        switch_to_main_screen(emulator)

      # Mode 1049: Save cursor & switch to alternate screen buffer
      {1049, :set} ->
        emulator
        |> save_cursor_position()
        |> switch_to_alternate_screen_with_clear()

      {1049, :reset} ->
        emulator
        |> switch_to_main_screen()
        |> restore_cursor_position()

      _ ->
        emulator
    end
  end

  defp apply_text_formatting(emulator, params) do
    # Apply SGR (Select Graphic Rendition) parameters
    updated_emulator =
      Enum.reduce(params, emulator, fn param, acc ->
        apply_sgr_parameter(acc, param)
      end)

    {:ok, updated_emulator}
  end

  defp apply_sgr_parameter(emulator, param) do
    current_style = get_current_text_style(emulator)
    new_style = apply_sgr_formatting(current_style, param)
    set_current_text_style(emulator, new_style)
  end

  defp apply_sgr_formatting(style, param) do
    case categorize_sgr_parameter(param) do
      {:reset, _} -> TextFormatting.reset_attributes(style)
      {:set_attribute, attribute} -> apply_text_attribute(style, attribute)
      {:reset_attribute, attribute} -> reset_text_attribute(style, attribute)
      {:color, type, value} -> apply_color(style, type, value)
      :unknown -> style
    end
  end

  defp categorize_sgr_parameter(param) do
    sgr_mappings()[param] || categorize_sgr_range(param)
  end

  defp categorize_sgr_range(param) do
    cond do
      param >= 30 and param <= 37 -> {:color, :foreground, param - 30}
      param >= 40 and param <= 47 -> {:color, :background, param - 40}
      true -> :unknown
    end
  end

  defp sgr_mappings do
    %{
      0 => {:reset, :all},
      1 => {:set_attribute, :bold},
      2 => {:set_attribute, :faint},
      3 => {:set_attribute, :italic},
      4 => {:set_attribute, :underline},
      5 => {:set_attribute, :blink},
      7 => {:set_attribute, :reverse},
      8 => {:set_attribute, :conceal},
      9 => {:set_attribute, :strikethrough},
      22 => {:reset_attribute, :bold_faint},
      23 => {:reset_attribute, :italic},
      24 => {:reset_attribute, :underline},
      25 => {:reset_attribute, :blink},
      27 => {:reset_attribute, :reverse},
      28 => {:reset_attribute, :conceal},
      29 => {:reset_attribute, :strikethrough},
      39 => {:color, :foreground, :reset},
      49 => {:color, :background, :reset}
    }
  end

  defp apply_text_attribute(style, attribute) do
    case attribute do
      :bold -> TextFormatting.set_bold(style)
      :faint -> TextFormatting.set_faint(style)
      :italic -> TextFormatting.set_italic(style)
      :underline -> TextFormatting.set_underline(style)
      :blink -> TextFormatting.set_blink(style)
      :reverse -> TextFormatting.set_reverse(style)
      :conceal -> TextFormatting.set_conceal(style)
      :strikethrough -> TextFormatting.set_strikethrough(style)
    end
  end

  defp reset_text_attribute(style, attribute) do
    case attribute do
      :bold_faint ->
        TextFormatting.reset_bold(style) |> TextFormatting.reset_faint()

      :italic ->
        TextFormatting.reset_italic(style)

      :underline ->
        TextFormatting.reset_underline(style)

      :blink ->
        TextFormatting.reset_blink(style)

      :reverse ->
        TextFormatting.reset_reverse(style)

      :conceal ->
        TextFormatting.reset_conceal(style)

      :strikethrough ->
        TextFormatting.reset_strikethrough(style)
    end
  end

  defp apply_color(style, type, value) do
    case {type, value} do
      {:foreground, :reset} ->
        TextFormatting.reset_foreground(style)

      {:background, :reset} ->
        TextFormatting.reset_background(style)

      {:foreground, color_value} ->
        TextFormatting.set_foreground(style, color_value)

      {:background, color_value} ->
        TextFormatting.set_background(style, color_value)
    end
  end

  defp perform_scroll(emulator, direction, lines) do
    active_buffer = Emulator.get_screen_buffer(emulator)

    _new_buffer =
      case direction do
        :up -> ScreenBuffer.scroll_up(active_buffer, lines)
        :down -> ScreenBuffer.scroll_down(active_buffer, lines)
      end

    # Note: Buffer operations are performed in-place
    {:ok, emulator}
  end

  defp clear_tabs(emulator, mode) do
    case mode do
      0 -> clear_tab_at_cursor(emulator)
      3 -> clear_all_tabs(emulator)
      _ -> {:ok, emulator}
    end
  end

  # Buffer operation implementations
  defp perform_insert_lines(emulator, count) do
    active_buffer = Emulator.get_screen_buffer(emulator)
    {y, _} = get_cursor_position(emulator)

    style = get_default_style(active_buffer)

    # Check for scroll region
    case Map.get(emulator, :scroll_region) do
      {scroll_top, scroll_bottom} when y >= scroll_top and y <= scroll_bottom ->
        updated_buffer =
          insert_lines_within_scroll_region(
            active_buffer,
            y,
            count,
            style,
            scroll_top,
            scroll_bottom
          )

        # CRITICAL FIX: Actually update the emulator with new buffer
        updated_emulator = update_emulator_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      _ ->
        updated_buffer = insert_lines_normal(active_buffer, y, count, style)
        # CRITICAL FIX: Actually update the emulator with new buffer
        updated_emulator = update_emulator_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}
    end
  end

  defp perform_delete_lines(emulator, count) do
    active_buffer = Emulator.get_screen_buffer(emulator)
    {y, _} = get_cursor_position(emulator)

    style = get_default_style(active_buffer)

    # Check for scroll region
    case Map.get(emulator, :scroll_region) do
      {scroll_top, scroll_bottom} when y >= scroll_top and y <= scroll_bottom ->
        Raxol.Core.Runtime.Log.debug(
          "DL using scroll region: y=#{y}, region=#{scroll_top}..#{scroll_bottom}"
        )

        updated_buffer =
          delete_lines_within_scroll_region(
            active_buffer,
            y,
            count,
            style,
            scroll_top,
            scroll_bottom
          )

        # CRITICAL FIX: Actually update the emulator with new buffer
        updated_emulator = update_emulator_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {scroll_top, scroll_bottom} ->
        # Scroll region exists but cursor is outside it - no effect
        Raxol.Core.Runtime.Log.debug(
          "DL outside scroll region: y=#{y}, scroll_region={#{scroll_top}, #{scroll_bottom}} - no effect"
        )

        {:ok, emulator}

      nil ->
        # No scroll region - normal delete
        Raxol.Core.Runtime.Log.debug(
          "DL with no scroll region: y=#{y} - normal delete"
        )

        updated_buffer = delete_lines_normal(active_buffer, y, count, style)
        updated_emulator = update_emulator_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}
    end
  end

  defp perform_delete_characters(emulator, count) do
    active_buffer = Emulator.get_screen_buffer(emulator)
    {y, x} = get_cursor_position(emulator)

    style = get_default_style(active_buffer)
    updated_buffer = delete_characters(active_buffer, y, x, count, style)
    # CRITICAL FIX: Actually update the emulator with new buffer
    updated_emulator = update_emulator_buffer(emulator, updated_buffer)
    {:ok, updated_emulator}
  end

  defp perform_insert_characters(emulator, count) do
    active_buffer = Emulator.get_screen_buffer(emulator)
    {y, x} = get_cursor_position(emulator)

    Raxol.Core.Runtime.Log.debug(
      "perform_insert_characters: count=#{count}, pos=({#{x}, #{y}})"
    )

    Raxol.Core.Runtime.Log.debug(
      "Buffer type: #{inspect(active_buffer.__struct__)}"
    )

    Raxol.Core.Runtime.Log.debug(
      "Buffer cells nil?: #{inspect(is_nil(active_buffer.cells))}"
    )

    Raxol.Core.Runtime.Log.debug(
      "Buffer cells length: #{inspect(length(active_buffer.cells || []))}"
    )

    Raxol.Core.Runtime.Log.debug(
      "Buffer dimensions: #{active_buffer.width}x#{active_buffer.height}"
    )

    Raxol.Core.Runtime.Log.debug(
      "First cell value: #{inspect(Enum.at(active_buffer.cells, 0))}"
    )

    style = get_default_style(active_buffer)
    Raxol.Core.Runtime.Log.debug("Style: #{inspect(style)}")

    updated_buffer = insert_characters(active_buffer, y, x, count, style)

    Raxol.Core.Runtime.Log.debug(
      "Updated buffer cells nil?: #{inspect(is_nil(updated_buffer.cells))}"
    )

    if not is_nil(active_buffer.cells) and not is_nil(updated_buffer.cells) do
      line_before = Enum.at(active_buffer.cells, y)
      line_after = Enum.at(updated_buffer.cells, y)

      Raxol.Core.Runtime.Log.debug(
        "y=#{y}, line_before: #{inspect(line_before |> Enum.take(3))}"
      )

      Raxol.Core.Runtime.Log.debug(
        "y=#{y}, line_after: #{inspect(line_after |> Enum.take(3))}"
      )
    end

    # Update the emulator with the new buffer
    updated_emulator = update_emulator_buffer(emulator, updated_buffer)
    {:ok, updated_emulator}
  end

  defp get_default_style(buffer) do
    case buffer do
      %{default_style: style} when not is_nil(style) ->
        style

      _ ->
        TextFormatting.new()
    end
  end

  defp insert_lines_normal(buffer, y, count, style) do
    # Create blank lines
    blank_cell = Cell.new(" ", style)
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines = List.duplicate(blank_line, count)

    # Insert lines at position y
    {lines_before, lines_after} = Enum.split(buffer.cells, y)

    # Keep only enough lines after to maintain total buffer size
    lines_to_keep = max(0, buffer.height - y - count)
    kept_lines = Enum.take(lines_after, lines_to_keep)

    final_cells = lines_before ++ blank_lines ++ kept_lines
    %{buffer | cells: final_cells}
  end

  defp insert_lines_within_scroll_region(
         buffer,
         y,
         count,
         style,
         scroll_top,
         scroll_bottom
       ) do
    # Create blank lines using Cell.new
    blank_cell = Cell.new(" ", style)
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines_to_insert = List.duplicate(blank_line, count)

    # Split buffer into regions
    {lines_before_scroll, rest} = Enum.split(buffer.cells, scroll_top)

    {scroll_region_lines, lines_after_scroll} =
      Enum.split(rest, scroll_bottom - scroll_top + 1)

    # Split scroll region at insertion point
    insertion_point = y - scroll_top

    {scroll_before, scroll_after} =
      Enum.split(scroll_region_lines, insertion_point)

    # When inserting lines, we keep lines before insertion point,
    # add blank lines, and keep as many lines after as will fit
    # Lines that don't fit are discarded (scrolled off bottom of region)
    max_lines_in_region = scroll_bottom - scroll_top + 1
    available_space_after = max_lines_in_region - insertion_point - count

    kept_lines =
      if available_space_after > 0 do
        # Keep only lines that fit in the remaining space
        Enum.take(scroll_after, available_space_after)
      else
        # No space left, all lines after insertion are pushed out
        []
      end

    # Reconstruct scroll region
    new_scroll_region = scroll_before ++ blank_lines_to_insert ++ kept_lines

    # Pad to correct size
    padded_scroll_region =
      if length(new_scroll_region) < max_lines_in_region do
        new_scroll_region ++
          List.duplicate(
            blank_line,
            max_lines_in_region - length(new_scroll_region)
          )
      else
        Enum.take(new_scroll_region, max_lines_in_region)
      end

    # Combine all parts
    final_cells =
      lines_before_scroll ++ padded_scroll_region ++ lines_after_scroll

    %{buffer | cells: final_cells}
  end

  defp delete_lines_within_scroll_region(
         buffer,
         y,
         count,
         style,
         scroll_top,
         scroll_bottom
       ) do
    # Create blank lines for replacement
    blank_cell = Cell.new(" ", style)
    blank_line = List.duplicate(blank_cell, buffer.width)
    blank_lines_to_add = List.duplicate(blank_line, count)

    # Split buffer into regions
    {lines_before_scroll, rest} = Enum.split(buffer.cells, scroll_top)

    {scroll_region_lines, lines_after_scroll} =
      Enum.split(rest, scroll_bottom - scroll_top + 1)

    # Split scroll region at deletion point
    deletion_point = y - scroll_top

    {scroll_before, scroll_after} =
      Enum.split(scroll_region_lines, deletion_point)

    # Remove deleted lines and keep remaining lines
    remaining_lines = Enum.drop(scroll_after, count)

    # Reconstruct scroll region with blank lines at bottom
    max_lines_in_region = scroll_bottom - scroll_top + 1
    new_scroll_region = scroll_before ++ remaining_lines ++ blank_lines_to_add

    # Ensure correct size
    padded_scroll_region =
      if length(new_scroll_region) < max_lines_in_region do
        new_scroll_region ++
          List.duplicate(
            blank_line,
            max_lines_in_region - length(new_scroll_region)
          )
      else
        Enum.take(new_scroll_region, max_lines_in_region)
      end

    # Combine all parts
    final_cells =
      lines_before_scroll ++ padded_scroll_region ++ lines_after_scroll

    %{buffer | cells: final_cells}
  end

  defp delete_lines_normal(buffer, y, count, style) do
    blank_cell = Cell.new(" ", style)
    blank_line = List.duplicate(blank_cell, buffer.width)

    # Remove lines starting at y
    {lines_before, lines_after} = Enum.split(buffer.cells, y)
    remaining_lines = Enum.drop(lines_after, count)

    # Add blank lines at the end to maintain buffer size
    blank_lines_needed = min(count, buffer.height - y)
    blank_lines = List.duplicate(blank_line, blank_lines_needed)

    final_cells = lines_before ++ remaining_lines ++ blank_lines
    %{buffer | cells: final_cells}
  end

  defp delete_characters(buffer, y, x, count, style) do
    # Get the line at y
    case Enum.at(buffer.cells, y) do
      nil ->
        buffer

      line ->
        # Split line at x
        {chars_before, chars_after} = Enum.split(line, x)
        remaining_chars = Enum.drop(chars_after, count)

        # Pad with blanks
        blank_cell = Cell.new(" ", style)
        blanks_needed = count
        blank_chars = List.duplicate(blank_cell, blanks_needed)

        new_line = chars_before ++ remaining_chars ++ blank_chars
        # Ensure line doesn't exceed width
        final_line = Enum.take(new_line, buffer.width)

        # Replace line in buffer
        updated_cells = List.replace_at(buffer.cells, y, final_line)
        %{buffer | cells: updated_cells}
    end
  end

  defp insert_characters(buffer, y, x, count, style) do
    # Get the line at y
    case Enum.at(buffer.cells, y) do
      nil ->
        buffer

      line ->
        # Split line at x
        {chars_before, chars_after} = Enum.split(line, x)

        # Insert blank characters
        blank_cell = Cell.new(" ", style)
        blank_chars = List.duplicate(blank_cell, count)

        # Combine and ensure we don't exceed width
        new_line = chars_before ++ blank_chars ++ chars_after
        final_line = Enum.take(new_line, buffer.width)

        # Replace line in buffer
        updated_cells = List.replace_at(buffer.cells, y, final_line)
        %{buffer | cells: updated_cells}
    end
  end

  # Placeholder implementations for various helper functions
  defp get_current_text_style(emulator),
    do: emulator.current_style || TextFormatting.new()

  defp set_current_text_style(emulator, style),
    do: %{emulator | current_style: style}

  defp switch_to_alternate_screen(emulator) do
    # Switch to alternate screen buffer, preserving main buffer
    %{emulator | screen_mode: :alternate, active_buffer_type: :alternate}
  end

  defp switch_to_alternate_screen_with_clear(emulator) do
    # Switch to alternate screen and clear it
    emulator
    |> switch_to_alternate_screen()
    |> clear_alternate_buffer()
  end

  defp switch_to_main_screen(emulator) do
    %{emulator | screen_mode: :main, active_buffer_type: :main}
  end

  defp save_cursor_position(emulator) do
    cursor = emulator.cursor

    updated_cursor = %{
      cursor
      | saved_row: cursor.row,
        saved_col: cursor.col,
        saved_position: {cursor.row, cursor.col}
    }

    %{emulator | cursor: updated_cursor}
  end

  defp restore_cursor_position(emulator) do
    cursor = emulator.cursor

    {new_row, new_col} =
      case {cursor.saved_row, cursor.saved_col} do
        {nil, nil} -> {0, 0}
        {row, col} -> {row, col}
      end

    updated_cursor = %{
      cursor
      | row: new_row,
        col: new_col,
        position: {new_row, new_col}
    }

    %{emulator | cursor: updated_cursor}
  end

  defp clear_alternate_buffer(emulator) do
    # Clear the alternate buffer by creating a new blank one
    blank_buffer = ScreenBuffer.new(emulator.width, emulator.height)
    %{emulator | alternate_screen_buffer: blank_buffer}
  end

  defp clear_tab_at_cursor(emulator), do: {:ok, emulator}
  defp clear_all_tabs(emulator), do: {:ok, emulator}
  defp apply_color_palette_change(emulator, _color_spec), do: {:ok, emulator}
  defp apply_foreground_color(emulator, _color_spec), do: {:ok, emulator}
  defp apply_background_color(emulator, _color_spec), do: {:ok, emulator}
  defp process_sixel_graphics(emulator, _sixel_data), do: {:ok, emulator}
end
