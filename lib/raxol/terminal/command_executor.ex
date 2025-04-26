defmodule Raxol.Terminal.CommandExecutor do
  @moduledoc """
  DEPRECATED: Handles the execution of parsed terminal commands.

  This module is being replaced by `Raxol.Terminal.Commands.Executor` and
  various submodules within `Raxol.Terminal.Commands.*`.

  Existing functions are kept temporarily for backward compatibility or as
  placeholders during refactoring, but they primarily log warnings and delegate
  to the new modules where possible.
  """
  require Logger

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Emulator
  # alias Raxol.Terminal.Commands.Executor, as: CommandImpl # Unused
  # alias Raxol.Terminal.Screen # Unused
  # alias Raxol.Terminal.ScreenBuffer # Unused
  # alias Raxol.Terminal.Cursor # Unused
  # alias Raxol.Terminal.TextAttributes # Unused
  # alias Raxol.Terminal.BufferManager # Unused
  # alias Raxol.Terminal.Config # Unused

  # Command module aliases
  # alias Raxol.Terminal.Commands.{Screen, CursorOps, Editing, Attributes, History} # All unused

  # Display a compile-time deprecation warning
  @deprecated "This module is deprecated. Use Raxol.Terminal.Commands.* modules instead."

  # --- Sequence Executors ---

  # Note: All functions receive the full Emulator.t state as the first argument

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  DEPRECATED: Use Raxol.Terminal.Commands.Executor.execute_csi_command/4 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `params_buffer` - The parameter portion of the CSI sequence
  * `intermediates_buffer` - The intermediate bytes portion of the CSI sequence
  * `final_byte` - The final byte that determines the specific command

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.execute_csi_command(emulator, params, intermediates, final_byte)

  # After
  new_emulator = Raxol.Terminal.Commands.Executor.execute_csi_command(emulator, params, intermediates, final_byte)
  ```
  """
  @spec execute_csi_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) :: Emulator.t()
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.execute_csi_command/4 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Executor.execute_csi_command/4 instead."
    )

    Raxol.Terminal.Commands.Executor.execute_csi_command(
      emulator,
      params_buffer,
      intermediates_buffer,
      final_byte
    )
  end

  @doc """
  Parses a raw parameter string buffer into a list of integers or nil values.

  DEPRECATED: Use Raxol.Terminal.Commands.Parser.parse_params/1 instead.

  ## Parameters

  * `params_string` - The raw parameter string from a CSI sequence

  ## Returns

  * A list of parsed parameters

  ## Migration Path

  ```elixir
  # Before
  params = Raxol.Terminal.CommandExecutor.parse_params(params_string)

  # After
  params = Raxol.Terminal.Commands.Parser.parse_params(params_string)
  ```
  """
  @spec parse_params(String.t()) ::
          list(integer() | nil | list(integer() | nil))
  def parse_params(params_string) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.parse_params/1 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.parse_params/1 instead."
    )

    Raxol.Terminal.Commands.Parser.parse_params(params_string)
  end

  @doc """
  Gets a parameter at a specific index from the params list.

  DEPRECATED: Use Raxol.Terminal.Commands.Parser.get_param/3 instead.

  ## Parameters

  * `params` - The list of parsed parameters
  * `index` - The index to get the parameter from
  * `default` - The default value to return if the parameter is nil or out of bounds

  ## Returns

  * The parameter value or the default value

  ## Migration Path

  ```elixir
  # Before
  value = Raxol.Terminal.CommandExecutor.get_param(params, 1, 0)

  # After
  value = Raxol.Terminal.Commands.Parser.get_param(params, 1, 0)
  ```
  """
  @spec get_param(list(integer() | nil), pos_integer(), integer()) :: integer()
  def get_param(params, index, default \\ 1) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.get_param/3 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Parser.get_param/3 instead."
    )

    Raxol.Terminal.Commands.Parser.get_param(params, index, default)
  end

  @doc """
  Handles DEC private mode setting or resetting.

  DEPRECATED: Use Raxol.Terminal.Commands.Modes.handle_dec_private_mode/3 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `params` - The parsed parameters
  * `action` - The action to perform (:set or :reset)

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.handle_dec_private_mode(emulator, params, :set)

  # After
  new_emulator = Raxol.Terminal.Commands.Modes.handle_dec_private_mode(emulator, params, :set)
  ```
  """
  @spec handle_dec_private_mode(Emulator.t(), list(integer()), :set | :reset) ::
          Emulator.t()
  def handle_dec_private_mode(emulator, params, action) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.handle_dec_private_mode/3 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Modes.handle_dec_private_mode/3 instead."
    )

    Raxol.Terminal.Commands.Modes.handle_dec_private_mode(
      emulator,
      params,
      action
    )
  end

  @doc """
  Handles ANSI mode setting or resetting.

  DEPRECATED: Use Raxol.Terminal.Commands.Modes.handle_ansi_mode/3 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `params` - The parsed parameters
  * `action` - The action to perform (:set or :reset)

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.handle_ansi_mode(emulator, params, :set)

  # After
  new_emulator = Raxol.Terminal.Commands.Modes.handle_ansi_mode(emulator, params, :set)
  ```
  """
  @spec handle_ansi_mode(Emulator.t(), list(integer()), :set | :reset) ::
          Emulator.t()
  def handle_ansi_mode(emulator, params, action) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.handle_ansi_mode/3 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Modes.handle_ansi_mode/3 instead."
    )

    Raxol.Terminal.Commands.Modes.handle_ansi_mode(emulator, params, action)
  end

  @doc """
  Clears the screen or a part of it based on the mode parameter.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `mode` - The mode parameter (0, 1, 2, or 3)

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.clear_screen(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.clear_screen(emulator, 2)
  ```
  """
  @spec clear_screen(Emulator.t(), integer()) :: Emulator.t()
  def clear_screen(emulator, mode) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.clear_screen/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead."
    )

    Raxol.Terminal.Commands.Screen.clear_screen(emulator, mode)
  end

  @doc """
  Clears a line or part of a line based on the mode parameter.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.clear_line/2 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `mode` - The mode parameter (0, 1, or 2)

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.clear_line(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.clear_line(emulator, 2)
  ```
  """
  @spec clear_line(Emulator.t(), integer()) :: Emulator.t()
  def clear_line(emulator, mode) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.clear_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.clear_line/2 instead."
    )

    Raxol.Terminal.Commands.Screen.clear_line(emulator, mode)
  end

  @doc """
  Inserts blank lines at the current cursor position.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.insert_lines/2 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to insert

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.insert_line(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.insert_lines(emulator, 2)
  ```
  """
  @spec insert_line(Emulator.t(), integer()) :: Emulator.t()
  def insert_line(emulator, count) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.insert_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.insert_lines/2 instead."
    )

    Raxol.Terminal.Commands.Screen.insert_lines(emulator, count)
  end

  @doc """
  Deletes lines at the current cursor position.

  DEPRECATED: Use Raxol.Terminal.Commands.Screen.delete_lines/2 instead.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to delete

  ## Returns

  * Updated emulator state

  ## Migration Path

  ```elixir
  # Before
  new_emulator = Raxol.Terminal.CommandExecutor.delete_line(emulator, 2)

  # After
  new_emulator = Raxol.Terminal.Commands.Screen.delete_lines(emulator, 2)
  ```
  """
  @spec delete_line(Emulator.t(), integer()) :: Emulator.t()
  def delete_line(emulator, count) do
    Logger.warning(
      "Raxol.Terminal.CommandExecutor.delete_line/2 is deprecated. " <>
        "Use Raxol.Terminal.Commands.Screen.delete_lines/2 instead."
    )

    Raxol.Terminal.Commands.Screen.delete_lines(emulator, count)
  end

  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Logger.warning(
      "Deprecated execute_osc_command called in Raxol.Terminal.CommandExecutor. " <>
        "Delegating to Raxol.Terminal.Commands.Executor.execute_osc_command/2. " <>
        "Command: #{inspect(command_string)}, Emulator: #{inspect(emulator)}"
    )

    # Parse the command string: Ps ; Pt ST
    # Ps is the command code (0, 2, 8, etc.)
    case String.split(command_string, ";", parts: 2) do
      [ps_str, pt] when ps_str != "" ->
        case Integer.parse(ps_str) do
          {ps_code, ""} ->
            # Dispatch based on the numeric code
            case ps_code do
              # Set icon name and window title
              0 ->
                Logger.info("OSC 0: Set icon/window title to: '#{pt}'")
                %{emulator | window_title: pt, icon_name: pt}

              # Set icon name
              1 ->
                Logger.info("OSC 1: Set icon name to: '#{pt}'")
                %{emulator | icon_name: pt}

              # Set window title
              2 ->
                Logger.info("OSC 2: Set window title to: '#{pt}'")
                %{emulator | window_title: pt}

              # Hyperlink: OSC 8 ; params ; uri ST
              8 ->
                case String.split(pt, ";", parts: 2) do
                  [params, uri] ->
                    Logger.info(
                      "OSC 8: Hyperlink: URI='#{uri}', Params='#{params}'"
                    )

                    # TODO: Optionally parse params (e.g., id=...)
                    %{emulator | current_hyperlink_url: uri}

                  # Handle cases with missing params: OSC 8 ; ; uri ST (common)
                  ["", uri] ->
                    Logger.info("OSC 8: Hyperlink: URI='#{uri}', Params=EMPTY")
                    %{emulator | current_hyperlink_url: uri}

                  # Handle malformed OSC 8
                  _ ->
                    Logger.warning(
                      "Malformed OSC 8 sequence: '#{command_string}'"
                    )

                    emulator
                end

              # Add other OSC commands here (e.g., colors, notifications)
              _ ->
                Logger.warning(
                  "Unhandled OSC command code: #{ps_code}, String: '#{command_string}'"
                )

                emulator
            end

          # Failed to parse Ps as integer
          _ ->
            Logger.warning(
              "Invalid OSC command code: '#{ps_str}', String: '#{command_string}'"
            )

            emulator
        end

      # Handle OSC sequences with no parameters (e.g., some color requests)
      # Or potentially malformed sequences
      _ ->
        Logger.warning(
          "Unhandled or malformed OSC sequence format: '#{command_string}'"
        )

        emulator
    end
  end

  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          String.t()
        ) :: Emulator.t()
  def execute_dcs_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte,
        payload
      ) do
    # Parse the raw param string buffer
    params = parse_params(params_buffer)
    # Use intermediates_buffer directly
    intermediates = intermediates_buffer

    Logger.warning(
      "Executing DCS: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}', Payload(len=#{String.length(payload)})"
    )

    # Dispatch based on params/intermediates/final_byte
    # Match on final_byte first
    case {final_byte, intermediates} do
      # Sixel Graphics (DECGRA) - ESC P P1 ; P2 ; P3 q <payload> ESC \
      # P1 = pixel aspect ratio (ignored), P2 = background color mode (ignored), P3 = horizontal grid size (ignored)
      {?q, _intermediates} ->
        handle_sixel_graphics(emulator, payload)

      # TODO: Add other DCS handlers (e.g., User-Defined Keys - DECDLD, Terminal Reports - DECRQSS)

      _ ->
        Logger.warning(
          "Unhandled DCS sequence: Params=#{inspect(params)}, Intermediates='#{intermediates}', Final='#{<<final_byte>>}'"
        )

        emulator
    end
  end

  # --- Command Handlers ---

  # Sixel Graphics Handler
  @spec handle_sixel_graphics(Emulator.t(), String.t()) :: Emulator.t()
  def handle_sixel_graphics(emulator, payload) do
    # TODO: Implement Sixel parsing and rendering to screen buffer.
    # This likely requires an external library (e.g., NIF bindings for libsixel) or a pure Elixir implementation.
    Logger.warning(
      "Sixel graphics received (payload length: #{String.length(payload)}), but Sixel decoding is NOT IMPLEMENTED."
    )

    # TODO: Implement Sixel parsing and rendering to screen buffer
    # Could involve calling an external library or a dedicated Elixir parser.
    # Return unchanged state for now
    emulator
  end

  # --- Helper for Erasing ---

  # Creates a list of new (empty) cells
  defp create_empty_cells(count) do
    # Create a list of `count` empty cells with default attributes
    List.duplicate(Cell.new(), count)
  end

  # Replaces a portion of a list (representing a row) with empty cells
  # Handles potential negative lengths gracefully.
  defp replace_range_with_empty(list, start_index, end_index)
       when start_index <= end_index do
    length = end_index - start_index + 1

    if length > 0 do
      empty_part = create_empty_cells(length)
      List.replace_at(list, start_index, empty_part)
    else
      # No change if length is zero or negative
      list
    end
  end

  # Start > End
  defp replace_range_with_empty(list, _start_index, _end_index), do: list

  # ED - Erase Display Handler
  @spec handle_ed(Emulator.t(), integer()) :: Emulator.t()
  def handle_ed(emulator, mode \\ 0) do
    Logger.debug("ED received - Erase Display (Mode: #{mode})")
    %{cursor: cursor} = emulator
    active_buffer = Emulator.get_active_buffer(emulator)

    # Access position directly from cursor struct instead of calling get_position
    {current_col, current_row} = cursor.position

    %{width: width, height: height, cells: cells, scrollback: scrollback} =
      active_buffer

    new_cells =
      case mode do
        # Mode 0: Erase from cursor to end of screen
        0 ->
          # Erase current line from cursor to end
          current_line = Enum.at(cells, current_row)

          erased_current_line =
            replace_range_with_empty(current_line, current_col, width - 1)

          # Erase lines below cursor
          cells_after_update =
            List.replace_at(cells, current_row, erased_current_line)

          # Replace Enum.map_indexed with Enum.with_index |> Enum.map
          cells_after_update
          |> Enum.with_index()
          |> Enum.map(fn {line, index} ->
            if index > current_row do
              create_empty_cells(width)
            else
              line
            end
          end)

        # Mode 1: Erase from beginning of screen to cursor
        1 ->
          # Erase current line from beginning to cursor (inclusive)
          current_line = Enum.at(cells, current_row)

          erased_current_line =
            replace_range_with_empty(current_line, 0, current_col)

          # Erase lines above cursor
          cells_after_update =
            List.replace_at(cells, current_row, erased_current_line)

          # Replace Enum.map_indexed with Enum.with_index |> Enum.map
          cells_after_update
          |> Enum.with_index()
          |> Enum.map(fn {line, index} ->
            if index < current_row do
              create_empty_cells(width)
            else
              line
            end
          end)

        # Mode 2: Erase entire screen
        2 ->
          List.duplicate(create_empty_cells(width), height)

        # Mode 3: Erase entire screen + scrollback (xterm)
        3 ->
          # Handled below by updating scrollback too
          List.duplicate(create_empty_cells(width), height)

        # Unknown mode - do nothing
        _ ->
          Logger.warning("Unhandled ED mode: #{mode}")
          cells
      end

    # Clear scrollback only for mode 3
    new_scrollback = if mode == 3, do: [], else: scrollback

    updated_active_buffer = %{
      active_buffer
      | cells: new_cells,
        scrollback: new_scrollback
    }

    Emulator.update_active_buffer(emulator, updated_active_buffer)
  end

  # EL - Erase in Line Handler
  @spec handle_el(Emulator.t(), integer()) :: Emulator.t()
  def handle_el(emulator, mode \\ 0) do
    Logger.debug("EL received - Erase in Line (Mode: #{mode})")
    %{cursor: cursor} = emulator
    active_buffer = Emulator.get_active_buffer(emulator)

    # Access position directly from cursor struct instead of calling get_position
    {current_col, current_row} = cursor.position
    %{width: width, cells: cells} = active_buffer

    # Ensure row index is within bounds
    if current_row >= 0 and current_row < length(cells) do
      current_line = Enum.at(cells, current_row)

      new_line =
        case mode do
          # Mode 0: Erase from cursor to end of line
          0 ->
            replace_range_with_empty(current_line, current_col, width - 1)

          # Mode 1: Erase from beginning of line to cursor (inclusive)
          1 ->
            replace_range_with_empty(current_line, 0, current_col)

          # Mode 2: Erase entire line
          2 ->
            create_empty_cells(width)

          # Unknown mode - do nothing
          _ ->
            Logger.warning("Unhandled EL mode: #{mode}")
            current_line
        end

      new_cells = List.replace_at(cells, current_row, new_line)
      updated_active_buffer = %{active_buffer | cells: new_cells}
      Emulator.update_active_buffer(emulator, updated_active_buffer)
    else
      # Cursor outside valid rows, should ideally not happen
      Logger.error(
        "EL command received with cursor row (#{current_row}) outside buffer height (#{length(cells)})"
      )

      emulator
    end
  end

  # DEC Private Mode Handlers (Not fully implemented)
  # TODO: Implement these DEC private mode handlers

  # Placeholder for DSR (Device Status Report) handling
  # Unused function
  # defp _handle_dsr(emulator, code) do
  # ... body omitted ...
  # end
end
