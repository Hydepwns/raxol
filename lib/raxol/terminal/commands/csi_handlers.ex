defmodule Raxol.Terminal.Commands.CSIHandlers do
  @moduledoc """
  Handles CSI (Control Sequence Introducer) commands.
  """

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Commands.{Cursor, Screen}
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Window.Manager, as: WindowManager
  alias Raxol.Terminal.Device.Status, as: DeviceStatus
  alias Raxol.Terminal.Charset.Manager, as: CharsetManager
  alias Raxol.Terminal.Cursor.Movement, as: CursorMovement

  # Cursor Movement Handlers
  @doc """
  CSI A: Cursor Up (CUU)
  """
  def handle_A(emulator, [n | _]) when is_integer(n), do: Cursor.move_up(emulator, n)
  def handle_A(emulator, _), do: Cursor.move_up(emulator, 1)

  @doc """
  CSI B: Cursor Down (CUD)
  """
  def handle_B(emulator, [n | _]) when is_integer(n), do: Cursor.move_down(emulator, n)
  def handle_B(emulator, _), do: Cursor.move_down(emulator, 1)

  @doc """
  CSI C: Cursor Forward (CUF)
  """
  def handle_C(emulator, [n | _]) when is_integer(n), do: Cursor.move_right(emulator, n)
  def handle_C(emulator, _), do: Cursor.move_right(emulator, 1)

  @doc """
  CSI D: Cursor Back (CUB)
  """
  def handle_D(emulator, [n | _]) when is_integer(n), do: Cursor.move_left(emulator, n)
  def handle_D(emulator, _), do: Cursor.move_left(emulator, 1)

  @doc """
  CSI E: Cursor Next Line (CNL)
  """
  def handle_E(emulator, [n | _]) when is_integer(n), do: Cursor.move_down_and_home(emulator, n)
  def handle_E(emulator, _), do: Cursor.move_down_and_home(emulator, 1)

  @doc """
  CSI F: Cursor Previous Line (CPL)
  """
  def handle_F(emulator, [n | _]) when is_integer(n), do: Cursor.move_up_and_home(emulator, n)
  def handle_F(emulator, _), do: Cursor.move_up_and_home(emulator, 1)

  @doc """
  CSI G: Cursor Horizontal Absolute (CHA)
  """
  def handle_G(emulator, [n | _]) when is_integer(n), do: Cursor.move_to_column(emulator, n)
  def handle_G(emulator, _), do: Cursor.move_to_column(emulator, 1)

  @doc """
  CSI H: Cursor Position (CUP)
  """
  def handle_H(emulator, [row, col | _]), do: Cursor.move_to(emulator, {row, col})
  def handle_H(emulator, _), do: Cursor.move_to(emulator, {1, 1})

  # Screen Manipulation Handlers
  @doc """
  CSI J: Erase in Display (ED)
  """
  def handle_J(emulator, [mode | _]), do: Screen.erase_display(emulator, mode)
  def handle_J(emulator, _), do: Screen.erase_display(emulator, 0)

  @doc """
  CSI K: Erase in Line (EL)
  """
  def handle_K(emulator, [mode | _]), do: Screen.erase_line(emulator, mode)
  def handle_K(emulator, _), do: Screen.erase_line(emulator, 0)

  @doc """
  CSI L: Insert Lines (IL)
  """
  def handle_L(emulator, [n | _]), do: Screen.insert_lines(emulator, n)
  def handle_L(emulator, _), do: Screen.insert_lines(emulator, 1)

  @doc """
  CSI M: Delete Lines (DL)
  """
  def handle_M(emulator, [n | _]), do: Screen.delete_lines(emulator, n)
  def handle_M(emulator, _), do: Screen.delete_lines(emulator, 1)

  @doc """
  CSI P: Delete Characters (DCH)
  """
  def handle_P(emulator, [n | _]), do: Screen.delete_chars(emulator, n)
  def handle_P(emulator, _), do: Screen.delete_chars(emulator, 1)

  @doc """
  CSI @: Insert Characters (ICH)
  """
  def handle_at(emulator, [n | _]), do: Screen.insert_chars(emulator, n)
  def handle_at(emulator, _), do: Screen.insert_chars(emulator, 1)

  @doc """
  CSI X: Erase Characters (ECH)
  """
  def handle_X(emulator, [n | _]), do: Screen.erase_chars(emulator, n)
  def handle_X(emulator, _), do: Screen.erase_chars(emulator, 1)

  # Device Status/Mode Handlers
  @doc """
  CSI n: Device Status Report (DSR)
  """
  def handle_n(emulator, params), do: DeviceStatus.handle_status_report(emulator, params)

  @doc """
  CSI h: Set Mode (SM)
  """
  def handle_h_or_l(emulator, params, _intermediates, ?h), do: handle_set_mode(emulator, params)
  @doc """
  CSI l: Reset Mode (RM)
  """
  def handle_h_or_l(emulator, params, _intermediates, ?l), do: handle_reset_mode(emulator, params)

  @doc """
  CSI s: Save Cursor (SCP)
  Saves the current cursor position and attributes.
  """
  def handle_s(emulator, _params) do
    # Save current cursor state
    saved_cursor = %{
      position: EmulatorStruct.get_cursor_position(emulator),
      style: emulator.cursor_style,
      attributes: emulator.style
    }

    {:ok, %{emulator | saved_cursor: saved_cursor}}
  end

  @doc """
  CSI u: Restore Cursor (RCP)
  Restores the previously saved cursor position and attributes.
  """
  def handle_u(emulator, _params) do
    case emulator.saved_cursor do
      nil ->
        # No saved cursor state, do nothing
        {:ok, emulator}

      saved ->
        # Restore cursor position and attributes
        emulator = %{emulator |
          cursor: Cursor.move_to(emulator.cursor, saved.position),
          cursor_style: saved.style,
          style: saved.attributes,
          saved_cursor: nil  # Clear saved state after restore
        }

        {:ok, emulator}
    end
  end

  @doc """
  CSI r: Set scroll region
  Sets the scroll region between top and bottom lines.
  """
  def handle_r(emulator, [top, bottom | _]) do
    # Validate scroll region
    top = max(1, min(top, emulator.height))
    bottom = max(top, min(bottom, emulator.height))

    # Set scroll region
    emulator = %{emulator | scroll_region: {top, bottom}}

    # Move cursor to home position
    emulator = Cursor.move_to(emulator, {1, 1})

    {:ok, emulator}
  end
  def handle_r(emulator, _), do: {:ok, emulator}

  @doc """
  CSI m: Select Graphic Rendition (SGR)
  Handles text styling and colors.
  """
  def handle_m(emulator, params) do
    # Default to 0 (reset) if no parameters
    params = if Enum.empty?(params), do: [0], else: params

    # Process each SGR parameter
    {new_style, _} = Enum.reduce(params, {emulator.style, []}, fn param, {style, color_params} ->
      case {param, color_params} do
        # Reset all attributes
        {0, _} -> {TextFormatting.new(), []}

        # 256-color foreground
        {38, []} -> {style, [:foreground]}
        {38, [:foreground, 5, color]} -> {TextFormatting.set_foreground_256(style, color), []}
        {38, [:foreground, 2, r, g, b]} -> {TextFormatting.set_foreground_rgb(style, {r, g, b}), []}

        # 256-color background
        {48, []} -> {style, [:background]}
        {48, [:background, 5, color]} -> {TextFormatting.set_background_256(style, color), []}
        {48, [:background, 2, r, g, b]} -> {TextFormatting.set_background_rgb(style, {r, g, b}), []}

        # Collect color parameters
        {p, [:foreground | rest]} -> {style, [:foreground, p | rest]}
        {p, [:background | rest]} -> {style, [:background, p | rest]}

        # Bold
        {1, _} -> {TextFormatting.set_bold(style, true), []}
        {22, _} -> {TextFormatting.set_bold(style, false), []}

        # Italic
        {3, _} -> {TextFormatting.set_italic(style, true), []}
        {23, _} -> {TextFormatting.set_italic(style, false), []}

        # Underline
        {4, _} -> {TextFormatting.set_underline(style, true), []}
        {24, _} -> {TextFormatting.set_underline(style, false), []}

        # Blink
        {5, _} -> {TextFormatting.set_blink(style, true), []}
        {25, _} -> {TextFormatting.set_blink(style, false), []}

        # Reverse video
        {7, _} -> {TextFormatting.set_reverse(style, true), []}
        {27, _} -> {TextFormatting.set_reverse(style, false), []}

        # Conceal
        {8, _} -> {TextFormatting.apply_attribute(style, :conceal), []}
        {28, _} -> {TextFormatting.apply_attribute(style, :reveal), []}

        # Foreground colors
        {30, _} -> {TextFormatting.set_foreground(style, :black), []}
        {31, _} -> {TextFormatting.set_foreground(style, :red), []}
        {32, _} -> {TextFormatting.set_foreground(style, :green), []}
        {33, _} -> {TextFormatting.set_foreground(style, :yellow), []}
        {34, _} -> {TextFormatting.set_foreground(style, :blue), []}
        {35, _} -> {TextFormatting.set_foreground(style, :magenta), []}
        {36, _} -> {TextFormatting.set_foreground(style, :cyan), []}
        {37, _} -> {TextFormatting.set_foreground(style, :white), []}
        {39, _} -> {TextFormatting.set_foreground(style, :default), []}

        # Background colors
        {40, _} -> {TextFormatting.set_background(style, :black), []}
        {41, _} -> {TextFormatting.set_background(style, :red), []}
        {42, _} -> {TextFormatting.set_background(style, :green), []}
        {43, _} -> {TextFormatting.set_background(style, :yellow), []}
        {44, _} -> {TextFormatting.set_background(style, :blue), []}
        {45, _} -> {TextFormatting.set_background(style, :magenta), []}
        {46, _} -> {TextFormatting.set_background(style, :cyan), []}
        {47, _} -> {TextFormatting.set_background(style, :white), []}
        {49, _} -> {TextFormatting.set_background(style, :default), []}

        # Bright foreground colors
        {90, _} -> {TextFormatting.set_foreground(style, :bright_black), []}
        {91, _} -> {TextFormatting.set_foreground(style, :bright_red), []}
        {92, _} -> {TextFormatting.set_foreground(style, :bright_green), []}
        {93, _} -> {TextFormatting.set_foreground(style, :bright_yellow), []}
        {94, _} -> {TextFormatting.set_foreground(style, :bright_blue), []}
        {95, _} -> {TextFormatting.set_foreground(style, :bright_magenta), []}
        {96, _} -> {TextFormatting.set_foreground(style, :bright_cyan), []}
        {97, _} -> {TextFormatting.set_foreground(style, :bright_white), []}

        # Bright background colors
        {100, _} -> {TextFormatting.set_background(style, :bright_black), []}
        {101, _} -> {TextFormatting.set_background(style, :bright_red), []}
        {102, _} -> {TextFormatting.set_background(style, :bright_green), []}
        {103, _} -> {TextFormatting.set_background(style, :bright_yellow), []}
        {104, _} -> {TextFormatting.set_background(style, :bright_blue), []}
        {105, _} -> {TextFormatting.set_background(style, :bright_magenta), []}
        {106, _} -> {TextFormatting.set_background(style, :bright_cyan), []}
        {107, _} -> {TextFormatting.set_background(style, :bright_white), []}

        # Unknown parameter, ignore
        {_, _} -> {style, []}
      end
    end)

    {:ok, %{emulator | style: new_style}}
  end

  @doc """
  CSI t: Window manipulation
  """
  def handle_t(emulator, params), do: WindowManager.handle_window_command(emulator, params)

  @doc """
  CSI c: Device Attributes (DA)
  """
  def handle_c(emulator, params, intermediates), do: DeviceStatus.handle_device_attributes(emulator, params, intermediates)

  @doc """
  CSI q: Set cursor style (DECSCUSR)
  Controls the appearance of the cursor.
  """
  def handle_q_deccusr(emulator, params) do
    case params do
      # Blinking block
      [0] -> {:ok, %{emulator | cursor_style: :blinking_block}}
      # Steady block
      [1] -> {:ok, %{emulator | cursor_style: :steady_block}}
      # Blinking underline
      [2] -> {:ok, %{emulator | cursor_style: :blinking_underline}}
      # Steady underline
      [3] -> {:ok, %{emulator | cursor_style: :steady_underline}}
      # Blinking bar
      [4] -> {:ok, %{emulator | cursor_style: :blinking_bar}}
      # Steady bar
      [5] -> {:ok, %{emulator | cursor_style: :steady_bar}}
      # Reset to default
      [6] -> {:ok, %{emulator | cursor_style: :blinking_block}}
      # Unknown style, ignore
      _ -> {:ok, emulator}
    end
  end

  @doc """
  CSI S: Scroll up
  """
  def handle_S(emulator, [n | _]), do: Screen.scroll_up(emulator, n)
  def handle_S(emulator, _), do: Screen.scroll_up(emulator, 1)

  @doc """
  CSI T: Scroll down
  """
  def handle_T(emulator, [n | _]), do: Screen.scroll_down(emulator, n)
  def handle_T(emulator, _), do: Screen.scroll_down(emulator, 1)

  @doc """
  CSI d: Vertical Position Absolute (VPA)
  """
  def handle_d(emulator, [row | _]), do: CursorMovement.move_to_line(emulator, row)
  def handle_d(emulator, _), do: CursorMovement.move_to_line(emulator, 1)

  @doc """
  CSI scs: Set Character Set (SCS)
  """
  def handle_scs(emulator, params_buffer, final_byte), do: CharsetManager.handle_set_charset(emulator, params_buffer, final_byte)

  @doc """
  Handle set mode command.
  Sets various terminal modes.
  """
  def handle_set_mode(emulator, params) do
    Enum.reduce(params, {:ok, emulator}, fn param, {:ok, emulator} ->
      case param do
        # Cursor Keys Mode (DECCKM)
        1 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:decckm])}}

        # ANSI/VT52 Mode (DECANM)
        2 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:ansi_mode])}}

        # Column Mode (DECCOLM)
        3 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:deccolm_132])}}

        # Scrolling Mode (DECSCLM)
        4 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:smooth_scroll])}}

        # Screen Mode (DECSCNM)
        5 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:decscnm])}}

        # Origin Mode (DECOM)
        6 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:decom])}}

        # Auto Wrap Mode (DECAWM)
        7 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:decawm])}}

        # Auto Repeat Mode (DECARM)
        8 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:decarm])}}

        # Interlace Mode (DECINLM)
        9 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, [:decinlm])}}

        # Unknown mode, ignore
        _ -> {:ok, emulator}
      end
    end)
  end

  @doc """
  Handle reset mode command.
  Resets various terminal modes.
  """
  def handle_reset_mode(emulator, params) do
    Enum.reduce(params, {:ok, emulator}, fn param, {:ok, emulator} ->
      case param do
        # Cursor Keys Mode (DECCKM)
        1 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :cursor_keys, false)}}

        # ANSI/VT52 Mode (DECANM)
        2 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :ansi_mode, false)}}

        # Column Mode (DECCOLM)
        3 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :column_mode, false)}}

        # Scrolling Mode (DECSCLM)
        4 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :smooth_scroll, false)}}

        # Screen Mode (DECSCNM)
        5 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :reverse_video, false)}}

        # Origin Mode (DECOM)
        6 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :origin_mode, false)}}

        # Auto Wrap Mode (DECAWM)
        7 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :auto_wrap, false)}}

        # Auto Repeat Mode (DECARM)
        8 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :auto_repeat, false)}}

        # Interlace Mode (DECINLM)
        9 -> {:ok, %{emulator | mode_manager: ModeManager.set_mode(emulator.mode_manager, :interlace, false)}}

        # Unknown mode, ignore
        _ -> {:ok, emulator}
      end
    end)
  end
end
