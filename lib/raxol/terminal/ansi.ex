defmodule Raxol.Terminal.ANSI do
  @moduledoc """
  Handles ANSI escape code processing for the terminal emulator.
  Supports cursor movement, color attributes, screen manipulation, and text formatting.
  """

  alias Raxol.Style.Colors.{Color, Advanced}
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.TextFormatting
  alias Raxol.Terminal.ANSI.MouseEvents
  alias Raxol.Terminal.ANSI.WindowManipulation
  alias Raxol.Terminal.ANSI.SixelGraphics

  # Standard 16 colors
  @colors %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white,
    8 => :bright_black,
    9 => :bright_red,
    10 => :bright_green,
    11 => :bright_yellow,
    12 => :bright_blue,
    13 => :bright_magenta,
    14 => :bright_cyan,
    15 => :bright_white
  }

  # 256-color mode palette
  # 0-15: Standard colors (same as @colors)
  # 16-231: 6x6x6 RGB cube
  # 232-255: Grayscale
  @color_256_palette %{
    # RGB cube (16-231)
    16..231 => fn code ->
      code = code - 16
      r = div(code, 36) * 51
      g = rem(div(code, 6), 6) * 51
      b = rem(code, 6) * 51
      {r, g, b}
    end,
    # Grayscale (232-255)
    232..255 => fn code ->
      value = (code - 232) * 10 + 8
      {value, value, value}
    end
  }

  # Text attributes
  @attributes %{
    # Text formatting
    "0" => :reset,
    "1" => :bold,
    "2" => :faint,
    "3" => :italic,
    "4" => :underline,
    "5" => :blink,
    "6" => :rapid_blink,
    "7" => :inverse,
    "8" => :conceal,
    "9" => :strikethrough,
    
    # Proportional spacing
    "10" => :proportional_spacing_off,
    "11" => :proportional_spacing_on,
    "12" => :proportional_spacing_off,
    "13" => :proportional_spacing_on,
    "14" => :proportional_spacing_off,
    "15" => :proportional_spacing_on,
    "16" => :proportional_spacing_off,
    "17" => :proportional_spacing_on,
    "18" => :proportional_spacing_off,
    "19" => :proportional_spacing_on,
    "20" => :proportional_spacing_off,
    "21" => :proportional_spacing_on,
    "22" => :proportional_spacing_off,
    "23" => :proportional_spacing_on,
    "24" => :proportional_spacing_off,
    "25" => :proportional_spacing_on,
    "26" => :proportional_spacing_off,
    "27" => :proportional_spacing_on,
    "28" => :proportional_spacing_off,
    "29" => :proportional_spacing_on,
    "30" => :proportional_spacing_off,
    "31" => :proportional_spacing_on,
    "32" => :proportional_spacing_off,
    "33" => :proportional_spacing_on,
    "34" => :proportional_spacing_off,
    "35" => :proportional_spacing_on,
    "36" => :proportional_spacing_off,
    "37" => :proportional_spacing_on,
    "38" => :proportional_spacing_off,
    "39" => :proportional_spacing_on,
    "40" => :proportional_spacing_off,
    "41" => :proportional_spacing_on,
    "42" => :proportional_spacing_off,
    "43" => :proportional_spacing_on,
    "44" => :proportional_spacing_off,
    "45" => :proportional_spacing_on,
    "46" => :proportional_spacing_off,
    "47" => :proportional_spacing_on,
    "48" => :proportional_spacing_off,
    "49" => :proportional_spacing_on,
    "50" => :proportional_spacing_off,
    "51" => :proportional_spacing_on,
    "52" => :proportional_spacing_off,
    "53" => :proportional_spacing_on,
    "54" => :proportional_spacing_off,
    "55" => :proportional_spacing_on,
    "56" => :proportional_spacing_off,
    "57" => :proportional_spacing_on,
    "58" => :proportional_spacing_off,
    "59" => :proportional_spacing_on,
    "60" => :proportional_spacing_off,
    "61" => :proportional_spacing_on,
    "62" => :proportional_spacing_off,
    "63" => :proportional_spacing_on,
    "64" => :proportional_spacing_off,
    "65" => :proportional_spacing_on,
    "66" => :proportional_spacing_off,
    "67" => :proportional_spacing_on,
    "68" => :proportional_spacing_off,
    "69" => :proportional_spacing_on,
    "70" => :proportional_spacing_off,
    "71" => :proportional_spacing_on,
    "72" => :proportional_spacing_off,
    "73" => :proportional_spacing_on,
    "74" => :proportional_spacing_off,
    "75" => :proportional_spacing_on,
    "76" => :proportional_spacing_off,
    "77" => :proportional_spacing_on,
    "78" => :proportional_spacing_off,
    "79" => :proportional_spacing_on,
    "80" => :proportional_spacing_off,
    "81" => :proportional_spacing_on,
    "82" => :proportional_spacing_off,
    "83" => :proportional_spacing_on,
    "84" => :proportional_spacing_off,
    "85" => :proportional_spacing_on,
    "86" => :proportional_spacing_off,
    "87" => :proportional_spacing_on,
    "88" => :proportional_spacing_off,
    "89" => :proportional_spacing_on,
    "90" => :proportional_spacing_off,
    "91" => :proportional_spacing_on,
    "92" => :proportional_spacing_off,
    "93" => :proportional_spacing_on,
    "94" => :proportional_spacing_off,
    "95" => :proportional_spacing_on,
    "96" => :proportional_spacing_off,
    "97" => :proportional_spacing_on,
    "98" => :proportional_spacing_off,
    "99" => :proportional_spacing_on,
    "100" => :proportional_spacing_off,
    
    # Superscript/subscript
    "101" => :superscript,
    "102" => :subscript,
    "103" => :superscript_off,
    "104" => :subscript_off,
    
    # Font selection
    "105" => :font_1,
    "106" => :font_2,
    "107" => :font_3,
    "108" => :font_4,
    "109" => :font_5,
    "110" => :font_6,
    "111" => :font_7,
    "112" => :font_8,
    "113" => :font_9,
    "114" => :font_10,
    
    # Text alignment
    "115" => :align_left,
    "116" => :align_center,
    "117" => :align_right,
    "118" => :align_justify,
    
    # Text wrapping
    "119" => :wrap_off,
    "120" => :wrap_on,
    
    # Text direction
    "121" => :direction_ltr,
    "122" => :direction_rtl,
    
    # Text spacing
    "123" => :spacing_normal,
    "124" => :spacing_condensed,
    "125" => :spacing_expanded,
    
    # Text case
    "126" => :case_normal,
    "127" => :case_small_caps,
    "128" => :case_all_caps,
    
    # Text emphasis
    "129" => :emphasis_normal,
    "130" => :emphasis_heavy,
    "131" => :emphasis_light,
    
    # Text outline
    "132" => :outline_off,
    "133" => :outline_on,
    
    # Text shadow
    "134" => :shadow_off,
    "135" => :shadow_on,
    
    # Text rotation
    "136" => :rotation_0,
    "137" => :rotation_90,
    "138" => :rotation_180,
    "139" => :rotation_270,
    
    # Text scaling
    "140" => :scale_normal,
    "141" => :scale_condensed,
    "142" => :scale_expanded,
    
    # Text tracking
    "143" => :tracking_normal,
    "144" => :tracking_tight,
    "145" => :tracking_loose,
    
    # Text leading
    "146" => :leading_normal,
    "147" => :leading_tight,
    "148" => :leading_loose,
    
    # Text kerning
    "149" => :kerning_off,
    "150" => :kerning_on,
    
    # Text ligatures
    "151" => :ligatures_off,
    "152" => :ligatures_on,
    
    # Text baseline
    "153" => :baseline_normal,
    "154" => :baseline_superscript,
    "155" => :baseline_subscript,
    
    # Text underline style
    "156" => :underline_single,
    "157" => :underline_double,
    "158" => :underline_dotted,
    "159" => :underline_dashed,
    "160" => :underline_wavy,
    
    # Text strikethrough style
    "161" => :strikethrough_single,
    "162" => :strikethrough_double,
    "163" => :strikethrough_dotted,
    "164" => :strikethrough_dashed,
    "165" => :strikethrough_wavy,
    
    # Text overline style
    "166" => :overline_single,
    "167" => :overline_double,
    "168" => :overline_dotted,
    "169" => :overline_dashed,
    "170" => :overline_wavy,
    
    # Text blink style
    "171" => :blink_slow,
    "172" => :blink_rapid,
    "173" => :blink_off,
    
    # Text inverse style
    "174" => :inverse_on,
    "175" => :inverse_off,
    
    # Text conceal style
    "176" => :conceal_on,
    "177" => :conceal_off,
    
    # Text color
    "178" => :color_foreground,
    "179" => :color_background,
    "180" => :color_underline,
    "181" => :color_strikethrough,
    "182" => :color_overline,
    
    # Text style reset
    "183" => :style_reset,
    "184" => :style_reset_all,
    "185" => :style_reset_color,
    "186" => :style_reset_attributes,
    "187" => :style_reset_font,
    "188" => :style_reset_alignment,
    "189" => :style_reset_wrap,
    "190" => :style_reset_direction,
    "191" => :style_reset_spacing,
    "192" => :style_reset_case,
    "193" => :style_reset_emphasis,
    "194" => :style_reset_outline,
    "195" => :style_reset_shadow,
    "196" => :style_reset_rotation,
    "197" => :style_reset_scale,
    "198" => :style_reset_tracking,
    "199" => :style_reset_leading,
    "200" => :style_reset_kerning,
    "201" => :style_reset_ligatures,
    "202" => :style_reset_baseline,
    "203" => :style_reset_underline,
    "204" => :style_reset_strikethrough,
    "205" => :style_reset_overline,
    "206" => :style_reset_blink,
    "207" => :style_reset_inverse,
    "208" => :style_reset_conceal,
    "209" => :style_reset_color_foreground,
    "210" => :style_reset_color_background,
    "211" => :style_reset_color_underline,
    "212" => :style_reset_color_strikethrough,
    "213" => :style_reset_color_overline
  }

  # Character set designations
  @character_sets %{
    "B" => :us_ascii,
    "A" => :uk,
    "C" => :french,
    "D" => :german,
    "E" => :swedish,
    "F" => :italian,
    "G" => :spanish,
    "H" => :portuguese,
    "I" => :swiss,
    "J" => :japanese,
    "K" => :korean,
    "L" => :chinese,
    "M" => :russian,
    "N" => :greek,
    "O" => :turkish,
    "P" => :hebrew,
    "Q" => :arabic,
    "R" => :thai,
    "S" => :vietnamese,
    "T" => :hindi,
    "U" => :urdu,
    "V" => :persian,
    "W" => :bengali,
    "X" => :gujarati,
    "Y" => :tamil,
    "Z" => :telugu,
    "a" => :malayalam,
    "b" => :kannada,
    "c" => :oriya,
    "d" => :punjabi,
    "e" => :sanskrit,
    "f" => :burmese,
    "g" => :khmer,
    "h" => :lao,
    "i" => :mongolian,
    "j" => :tibetan,
    "k" => :sinhala,
    "l" => :nepali,
    "m" => :marathi,
    "n" => :assamese,
    "o" => :manipuri,
    "p" => :kashmiri,
    "q" => :konkani,
    "r" => :maithili,
    "s" => :santali,
    "t" => :sindhi,
    "u" => :dogri,
    "v" => :bodo,
    "w" => :sanskrit,
    "x" => :sanskrit,
    "y" => :sanskrit,
    "z" => :sanskrit
  }

  # Screen modes
  @screen_modes %{
    "?1" => :cursor_keys,
    "?2" => :ansi_vt52,
    "?3" => :columns_132,
    "?4" => :smooth_scrolling,
    "?5" => :reverse_screen,
    "?6" => :origin_mode,
    "?7" => :auto_wrap,
    "?8" => :auto_repeat,
    "?9" => :interlacing,
    "?10" => :cursor_style,
    "?12" => :start_blink,
    "?18" => :print_form_feed,
    "?19" => :set_print_extent,
    "?25" => :cursor_visible,
    "?30" => :show_scrollbar,
    "?35" => :font_shifting,
    "?38" => :enter_tek_mode,
    "?40" => :allow_80_132,
    "?41" => :more_fix,
    "?44" => :margin_bell,
    "?45" => :reverse_wrap,
    "?46" => :start_logging,
    "?47" => :alternate_screen,
    "?66" => :application_keypad,
    "?67" => :backspace_key,
    "?69" => :left_right_margin,
    "?95" => :clear_screen,
    "?1000" => :mouse_tracking,
    "?1001" => :highlight_mouse_tracking,
    "?1002" => :cell_mouse_tracking,
    "?1003" => :all_mouse_tracking,
    "?1004" => :focus_event,
    "?1005" => :utf8_mouse,
    "?1006" => :sgr_mouse,
    "?1007" => :alternate_scroll,
    "?1015" => :urxvt_mouse,
    "?1016" => :sgr_pixels_mouse,
    "?1035" => :meta_sends_escape,
    "?1036" => :meta_alt_esc,
    "?1037" => :meta_alt_shift_esc,
    "?1039" => :meta_alt_shift_esc,
    "?1040" => :meta_alt_shift_esc,
    "?1041" => :meta_alt_shift_esc,
    "?1042" => :meta_alt_shift_esc,
    "?1043" => :meta_alt_shift_esc,
    "?1044" => :meta_alt_shift_esc,
    "?1045" => :meta_alt_shift_esc,
    "?1046" => :meta_alt_shift_esc,
    "?1047" => :alternate_screen,
    "?1048" => :save_cursor,
    "?1049" => :alternate_screen_save_cursor,
    "?1050" => :termcap_terminal,
    "?1051" => :sun_function_key,
    "?1052" => :hp_function_key,
    "?1053" => :sco_function_key,
    "?1060" => :legacy_scancode,
    "?1061" => :vt220_keyboard,
    "?2004" => :bracketed_paste
  }

  @type state :: %{
    mouse_state: MouseEvents.mouse_state(),
    window_state: WindowManipulation.window_state(),
    sixel_state: SixelGraphics.sixel_state(),
    # ... existing state fields ...
  }

  @doc """
  Creates a new ANSI state with default values.
  """
  @spec new() :: state()
  def new do
    %{
      mouse_state: MouseEvents.new(),
      window_state: WindowManipulation.new(),
      sixel_state: SixelGraphics.new(),
      # ... existing state initialization ...
    }
  end

  @doc """
  Processes an ANSI sequence and returns the updated state and response.
  """
  @spec process_sequence(state(), binary()) :: {state(), binary()}
  def process_sequence(state, <<"\e[", rest::binary>>) do
    case parse_sequence(rest) do
      {:ok, operation, params} ->
        handle_operation(state, operation, params)
      :error ->
        {state, ""}
    end
  end

  @doc """
  Handles a window manipulation operation.
  """
  @spec handle_window_operation(state(), atom(), list(integer())) :: {state(), binary()}
  def handle_window_operation(state, operation, params) do
    {new_window_state, response} = WindowManipulation.handle_operation(state.window_state, operation, params)
    {%{state | window_state: new_window_state}, response}
  end

  @doc """
  Handles a Sixel graphics operation.
  """
  @spec handle_sixel_operation(state(), atom(), list(integer())) :: {state(), binary()}
  def handle_sixel_operation(state, operation, params) do
    {new_sixel_state, response} = SixelGraphics.handle_operation(state.sixel_state, operation, params)
    {%{state | sixel_state: new_sixel_state}, response}
  end

  @doc """
  Handles a mouse event operation.
  """
  @spec handle_mouse_operation(state(), atom(), list(integer())) :: {state(), binary()}
  def handle_mouse_operation(state, operation, params) do
    {new_mouse_state, response} = MouseEvents.handle_operation(state.mouse_state, operation, params)
    {%{state | mouse_state: new_mouse_state}, response}
  end

  @doc """
  Decodes an operation from its character code.
  """
  @spec decode_operation(integer()) :: atom()
  def decode_operation(?t), do: :window_manipulation
  def decode_operation(?q), do: :sixel_graphics
  def decode_operation(?M), do: :mouse_event
  # ... existing operation decodings ...

  @doc """
  Handles an operation and returns the updated state and response.
  """
  @spec handle_operation(state(), atom(), list(integer())) :: {state(), binary()}
  def handle_operation(state, :window_manipulation, params) do
    handle_window_operation(state, :window_manipulation, params)
  end

  def handle_operation(state, :sixel_graphics, params) do
    handle_sixel_operation(state, :sixel_graphics, params)
  end

  def handle_operation(state, :mouse_event, params) do
    handle_mouse_operation(state, :mouse_event, params)
  end

  # ... existing operation handlers ...

  @doc """
  Process an ANSI escape sequence and update the terminal state accordingly.
  """
  def process_escape(emulator, sequence) do
    case parse_sequence(sequence) do
      {:cursor_move, row, col} ->
        move_cursor(emulator, row, col)
      
      {:cursor_up, n} ->
        move_cursor_up(emulator, n)
      
      {:cursor_down, n} ->
        move_cursor_down(emulator, n)
      
      {:cursor_forward, n} ->
        move_cursor_forward(emulator, n)
      
      {:cursor_backward, n} ->
        move_cursor_backward(emulator, n)
      
      {:cursor_save} ->
        save_cursor_position(emulator)
      
      {:cursor_restore} ->
        restore_cursor_position(emulator)
      
      {:cursor_visible, visible} ->
        set_cursor_visibility(emulator, visible)
      
      {:foreground_true, r, g, b} ->
        set_foreground_true(emulator, r, g, b)
      
      {:background_true, r, g, b} ->
        set_background_true(emulator, r, g, b)
      
      {:foreground_256, index} ->
        set_foreground_256(emulator, index)
      
      {:background_256, index} ->
        set_background_256(emulator, index)
      
      {:foreground_basic, color} ->
        set_foreground_basic(emulator, color)
      
      {:background_basic, color} ->
        set_background_basic(emulator, color)
      
      {:text_attribute, attr} ->
        set_text_attribute(emulator, attr)
      
      {:reset_attributes} ->
        reset_attributes(emulator)
      
      {:clear_screen} ->
        clear_screen(emulator)
      
      {:clear_line} ->
        clear_line(emulator)
      
      {:insert_line, n} ->
        insert_line(emulator, n)
      
      {:delete_line, n} ->
        delete_line(emulator, n)
      
      {:set_character_set, gset, charset} ->
        set_character_set(emulator, gset, charset)
      
      {:invoke_character_set, gset} ->
        invoke_character_set(emulator, gset)
      
      {:set_screen_mode, mode} ->
        set_screen_mode(emulator, mode)
      
      {:reset_screen_mode, mode} ->
        reset_screen_mode(emulator, mode)
      
      {:device_status_query, query} ->
        device_status_query(emulator, query)
      
      {:charset_switch, set, charset} ->
        switch_charset(emulator, set, charset)
      
      {:charset_gl, set} ->
        handle_gl_charset(emulator, set)
      
      {:charset_gr, set} ->
        set_gr_charset(emulator, set)
      
      {:single_shift, set} ->
        set_single_shift(emulator, set)
      
      {:lock_shift, set} ->
        lock_shift(emulator, set)
      
      {:unlock_shift} ->
        unlock_shift(emulator)
      
      {:text_format, format} ->
        text_style = TextFormatting.apply_attribute(emulator.text_style, format)
        %{emulator | text_style: text_style}
      
      {:mouse_enable, mode} ->
        enable_mouse_tracking(emulator, mode)
      
      {:mouse_disable} ->
        disable_mouse_tracking(emulator)
      
      {:mouse_event, button, x, y} ->
        handle_mouse_event(emulator, button, x, y)
      
      _ ->
        emulator
    end
  end

  @doc """
  Generates an ANSI escape sequence for the given command and parameters.
  """
  def generate_sequence(command, params \\ []) do
    case command do
      :cursor_move ->
        [x, y] = params
        "\e[#{y};#{x}H"
      
      :cursor_up ->
        [n] = params
        "\e[#{n}A"
      
      :cursor_down ->
        [n] = params
        "\e[#{n}B"
      
      :cursor_forward ->
        [n] = params
        "\e[#{n}C"
      
      :cursor_backward ->
        [n] = params
        "\e[#{n}D"
      
      :set_foreground ->
        [color] = params
        color = Color.from_hex(color)
        adapted_color = Advanced.adapt_color_advanced(color, enhance_contrast: true)
        "\e[#{color_code(adapted_color, :foreground)}m"
      
      :set_background ->
        [color] = params
        color = Color.from_hex(color)
        adapted_color = Advanced.adapt_color_advanced(color, enhance_contrast: true)
        "\e[#{color_code(adapted_color, :background)}m"
      
      :set_foreground_256 ->
        [color] = params
        color = Color.from_hex(color)
        adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
        "\e[38;5;#{rgb_to_256color(adapted_color)}m"
      
      :set_background_256 ->
        [color] = params
        color = Color.from_hex(color)
        adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
        "\e[48;5;#{rgb_to_256color(adapted_color)}m"
      
      :set_foreground_true ->
        [color] = params
        color = Color.from_hex(color)
        adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
        "\e[38;2;#{adapted_color.r};#{adapted_color.g};#{adapted_color.b}m"
      
      :set_background_true ->
        [color] = params
        color = Color.from_hex(color)
        adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
        "\e[48;2;#{adapted_color.r};#{adapted_color.g};#{adapted_color.b}m"
      
      :set_attribute ->
        [attr] = params
        "\e[#{attribute_code(attr)}m"
      
      :reset_attribute ->
        [attr] = params
        "\e[#{reset_attribute_code(attr)}m"
      
      :clear_screen ->
        [mode] = params
        "\e[#{clear_screen_code(mode)}J"
      
      :erase_line ->
        [mode] = params
        "\e[#{erase_line_code(mode)}K"
      
      :insert_line ->
        [n] = params
        "\e[#{n}L"
      
      :delete_line ->
        [n] = params
        "\e[#{n}M"
      
      :set_scroll_region ->
        [top, bottom] = params
        "\e[#{top};#{bottom}r"
      
      :save_cursor ->
        "\e[s"
      
      :restore_cursor ->
        "\e[u"
      
      :show_cursor ->
        "\e[?25h"
      
      :hide_cursor ->
        "\e[?25l"
      
      :set_character_set ->
        [gset, charset] = params
        "\e[#{gset}#{charset}"
      
      :invoke_character_set ->
        [gset] = params
        "\e[#{gset}"
      
      :set_screen_mode ->
        [mode] = params
        "\e[?#{mode}h"
      
      :reset_screen_mode ->
        [mode] = params
        "\e[?#{mode}l"
      
      :device_status_query ->
        [query] = params
        "\e[#{query}n"
    end
  end

  # Private helper functions

  defp parse_sequence(sequence) do
    # Match standard CSI sequences
    case Regex.run(~r/\e\[([\d;]*)([A-Za-z])/, sequence) do
      [_, params, cmd] ->
        parse_csi_sequence(params, cmd)
      
      nil ->
        # Match character set sequences
        case Regex.run(~r/\e\[([0-3])([A-Za-z])/, sequence) do
          [_, gset, charset] ->
            {:set_character_set, gset, charset}
          
          nil ->
            # Match device status queries
            case Regex.run(~r/\e\[([\d;]*)\?([\d;]*)([A-Za-z])/, sequence) do
              [_, prefix, params, cmd] ->
                parse_device_query(prefix, params, cmd)
              
              nil ->
                # Match screen mode sequences
                case Regex.run(~r/\e\[\?([\d;]*)([hl])/, sequence) do
                  [_, mode, action] ->
                    if action == "h" do
                      {:set_screen_mode, mode}
                    else
                      {:reset_screen_mode, mode}
                    end
                  
                  nil ->
                    # Add mouse event parsing
                    case Regex.run(~r/\e\[<(\d+);(\d+);(\d+)M/, sequence) do
                      [_, button, x, y] ->
                        {:mouse_event, String.to_integer(button), String.to_integer(x), String.to_integer(y)}
                      
                      nil ->
                        {:unknown, sequence}
                    end
                end
            end
        end
    end
  end

  defp parse_csi_sequence(params, cmd) do
    params = String.split(params, ";") |> Enum.map(&String.to_integer/1)
    
    case {cmd, params} do
      {"H", [row, col]} -> {:cursor_move, row, col}
      {"H", [row]} -> {:cursor_move, row, 1}
      {"H", []} -> {:cursor_move, 1, 1}
      
      {"A", [n]} -> {:cursor_up, n}
      {"A", []} -> {:cursor_up, 1}
      
      {"B", [n]} -> {:cursor_down, n}
      {"B", []} -> {:cursor_down, 1}
      
      {"C", [n]} -> {:cursor_forward, n}
      {"C", []} -> {:cursor_forward, 1}
      
      {"D", [n]} -> {:cursor_backward, n}
      {"D", []} -> {:cursor_backward, 1}
      
      {"s", []} -> {:cursor_save}
      {"u", []} -> {:cursor_restore}
      
      {"h", ["25", "?"]} -> {:cursor_visible, true}
      {"l", ["25", "?"]} -> {:cursor_visible, false}
      
      {"m", params} -> parse_sgr_sequence(params)
      
      {"J", [n]} -> {:clear_screen, n}
      {"J", []} -> {:clear_screen, 0}
      
      {"K", [n]} -> {:clear_line, n}
      {"K", []} -> {:clear_line, 0}
      
      {"L", [n]} -> {:insert_line, n}
      {"L", []} -> {:insert_line, 1}
      
      {"M", [n]} -> {:delete_line, n}
      {"M", []} -> {:delete_line, 1}
      
      {"r", [top, bottom]} -> {:set_scroll_region, top, bottom}
      
      # Device status reports
      {"n", [6]} -> {:device_status, :cursor_position}
      {"n", [5]} -> {:device_status, :device_status}
      {"n", [0]} -> {:device_status, :device_ok}
      {"n", [3]} -> {:device_status, :device_malfunction}
      
      # Terminal identification
      {"c", []} -> {:device_status, :primary_attributes}
      {"c", [0]} -> {:device_status, :primary_attributes}
      {"c", [1]} -> {:device_status, :secondary_attributes}
      {"c", [2]} -> {:device_status, :tertiary_attributes}
      {"c", [3]} -> {:device_status, :fourth_attributes}
      
      # Double-width/double-height control
      {"#", [3]} -> {:text_format, :double_height_top}
      {"#", [4]} -> {:text_format, :double_height_bottom}
      {"#", [5]} -> {:text_format, :single_width}
      {"#", [6]} -> {:text_format, :double_width}
      
      _ -> {:unknown, {cmd, params}}
    end
  end

  defp parse_sgr_sequence(params) do
    case params do
      [0] -> {:reset_attributes}
      
      [38, 2, r, g, b] -> {:foreground_true, r, g, b}
      [48, 2, r, g, b] -> {:background_true, r, g, b}
      
      [38, 5, index] -> {:foreground_256, index}
      [48, 5, index] -> {:background_256, index}
      
      [n] when n >= 30 and n <= 37 -> {:foreground_basic, n - 30}
      [n] when n >= 40 and n <= 47 -> {:background_basic, n - 40}
      [n] when n >= 90 and n <= 97 -> {:foreground_basic, n - 82}
      [n] when n >= 100 and n <= 107 -> {:background_basic, n - 92}
      
      [n] when is_map_key(@attributes, n) -> {:text_attribute, @attributes[n]}
      
      _ -> {:unknown, params}
    end
  end

  defp parse_device_query(prefix, params, cmd) do
    case {prefix, params, cmd} do
      {"", "", "n"} -> {:device_status_query, "6"}
      {"", "", "c"} -> {:device_status_query, "0"}
      {"", "", "5"} -> {:device_status_query, "0"}
      _ -> {:unknown, {prefix, params, cmd}}
    end
  end

  # Character set handling
  defp set_character_set(emulator, g_set, charset) do
    case Map.get(@character_sets, charset) do
      nil ->
        emulator
      charset_symbol ->
        emulator
        |> update_in([:character_set_state, g_set], fn _ -> charset_symbol end)
        |> update_in([:character_set_state, :last_modified], fn _ -> DateTime.utc_now() end)
        |> update_in([:character_set_state, :modification_count], fn count -> count + 1 end)
    end
  end

  defp invoke_character_set(emulator, g_set) do
    charset = Map.get(emulator.character_set_state, g_set, :us_ascii)
    emulator
    |> update_in([:character_set_state, :active_set], fn _ -> g_set end)
    |> update_in([:character_set_state, :active_charset], fn _ -> charset end)
    |> update_in([:character_set_state, :last_modified], fn _ -> DateTime.utc_now() end)
    |> update_in([:character_set_state, :modification_count], fn count -> count + 1 end)
  end

  defp set_gr_charset(emulator, set) do
    charset_state = CharacterSets.set_gr(emulator.charset_state, set)
    %{emulator | charset_state: charset_state}
  end

  defp set_single_shift(emulator, set) do
    charset_state = CharacterSets.set_single_shift(emulator.charset_state, set)
    %{emulator | charset_state: charset_state}
  end

  defp lock_shift(emulator, g_set) do
    emulator
    |> update_in([:character_set_state, :locked_shift], fn _ -> g_set end)
    |> update_in([:character_set_state, :last_modified], fn _ -> DateTime.utc_now() end)
    |> update_in([:character_set_state, :modification_count], fn count -> count + 1 end)
  end

  defp unlock_shift(emulator) do
    emulator
    |> update_in([:character_set_state, :locked_shift], fn _ -> nil end)
    |> update_in([:character_set_state, :last_modified], fn _ -> DateTime.utc_now() end)
    |> update_in([:character_set_state, :modification_count], fn count -> count + 1 end)
  end

  # Screen mode handling
  defp set_screen_mode(emulator, mode) do
    case Map.get(@screen_modes, mode) do
      nil -> emulator
      mode_name -> 
        # Update the screen mode
        screen_modes = Map.put(emulator.screen_modes, mode_name, true)
        %{emulator | screen_modes: screen_modes}
    end
  end

  defp reset_screen_mode(emulator, mode) do
    case Map.get(@screen_modes, mode) do
      nil -> emulator
      mode_name -> 
        # Remove the screen mode
        screen_modes = Map.delete(emulator.screen_modes, mode_name)
        %{emulator | screen_modes: screen_modes}
    end
  end

  # Device status query handling
  defp device_status_query(emulator, query) do
    case query do
      "6" -> 
        # Report cursor position
        {row, col} = emulator.cursor
        "\e[#{row};#{col}R"
      
      "0" -> 
        # Report device attributes
        "\e[?1;2c"
      
      _ -> 
        ""
    end
  end

  # Cursor movement functions

  defp move_cursor(emulator, row, col) do
    %{emulator |
      cursor_x: max(0, min(col - 1, emulator.width - 1)),
      cursor_y: max(0, min(row - 1, emulator.height - 1))
    }
  end

  defp move_cursor_up(emulator, n) do
    %{emulator | cursor_y: max(0, emulator.cursor_y - n)}
  end

  defp move_cursor_down(emulator, n) do
    %{emulator | cursor_y: min(emulator.height - 1, emulator.cursor_y + n)}
  end

  defp move_cursor_forward(emulator, n) do
    %{emulator | cursor_x: min(emulator.width - 1, emulator.cursor_x + n)}
  end

  defp move_cursor_backward(emulator, n) do
    %{emulator | cursor_x: max(0, emulator.cursor_x - n)}
  end

  defp save_cursor_position(emulator) do
    %{emulator | cursor_saved: {emulator.cursor_x, emulator.cursor_y}}
  end

  defp restore_cursor_position(emulator) do
    case emulator.cursor_saved do
      {x, y} -> %{emulator | cursor_x: x, cursor_y: y}
      _ -> emulator
    end
  end

  defp set_cursor_visibility(emulator, visible) do
    %{emulator | cursor_visible: visible}
  end

  # Color handling functions

  defp set_foreground_true(emulator, r, g, b) do
    color = Color.from_rgb(r, g, b)
    adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
    %{emulator | attributes: %{emulator.attributes | foreground_true: {adapted_color.r, adapted_color.g, adapted_color.b}}}
  end

  defp set_background_true(emulator, r, g, b) do
    color = Color.from_rgb(r, g, b)
    adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
    %{emulator | attributes: %{emulator.attributes | background_true: {adapted_color.r, adapted_color.g, adapted_color.b}}}
  end

  defp set_foreground_256(emulator, index) do
    color = Advanced.index_to_color(index)
    _adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
    %{emulator | attributes: %{emulator.attributes | foreground_256: index}}
  end

  defp set_background_256(emulator, index) do
    color = Advanced.index_to_color(index)
    _adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
    %{emulator | attributes: %{emulator.attributes | background_256: index}}
  end

  defp set_foreground_basic(emulator, color) do
    case get_color_name(color) do
      nil -> emulator
      color_name -> 
        color_code = basic_color_code(color_name)
        "\e[#{color_code}m"
    end
  end

  defp set_background_basic(emulator, color) do
    case get_color_name(color) do
      nil -> emulator
      color_name -> 
        color_code = basic_color_code(color_name)
        "\e[#{color_code + 10}m"
    end
  end

  defp basic_color_code(color_name) do
    case color_name do
      :black -> 30
      :red -> 31
      :green -> 32
      :yellow -> 33
      :blue -> 34
      :magenta -> 35
      :cyan -> 36
      :white -> 37
      _ -> 0
    end
  end

  defp color_code(color, type) do
    case get_256_color(color) do
      nil -> nil
      {r, g, b} -> "\e[#{type};2;#{r};#{g};#{b}m"
    end
  end

  # Text attribute functions

  defp set_text_attribute(emulator, attribute) do
    case Map.get(@attributes, attribute) do
      nil ->
        emulator
      :reset ->
        %{emulator | attributes: %{}}
      :style_reset ->
        %{emulator | attributes: %{}}
      :style_reset_all ->
        %{emulator | attributes: %{}}
      :style_reset_color ->
        Map.drop(emulator.attributes, [:foreground, :background, :underline_color, :strikethrough_color, :overline_color])
      :style_reset_attributes ->
        Map.drop(emulator.attributes, [:bold, :faint, :italic, :underline, :blink, :rapid_blink, :inverse, :conceal, :strikethrough])
      :style_reset_font ->
        Map.drop(emulator.attributes, [:font])
      :style_reset_alignment ->
        Map.drop(emulator.attributes, [:alignment])
      :style_reset_wrap ->
        Map.drop(emulator.attributes, [:wrap])
      :style_reset_direction ->
        Map.drop(emulator.attributes, [:direction])
      :style_reset_spacing ->
        Map.drop(emulator.attributes, [:spacing])
      :style_reset_case ->
        Map.drop(emulator.attributes, [:case])
      :style_reset_emphasis ->
        Map.drop(emulator.attributes, [:emphasis])
      :style_reset_outline ->
        Map.drop(emulator.attributes, [:outline])
      :style_reset_shadow ->
        Map.drop(emulator.attributes, [:shadow])
      :style_reset_rotation ->
        Map.drop(emulator.attributes, [:rotation])
      :style_reset_scale ->
        Map.drop(emulator.attributes, [:scale])
      :style_reset_tracking ->
        Map.drop(emulator.attributes, [:tracking])
      :style_reset_leading ->
        Map.drop(emulator.attributes, [:leading])
      :style_reset_kerning ->
        Map.drop(emulator.attributes, [:kerning])
      :style_reset_ligatures ->
        Map.drop(emulator.attributes, [:ligatures])
      :style_reset_baseline ->
        Map.drop(emulator.attributes, [:baseline])
      :style_reset_underline ->
        Map.drop(emulator.attributes, [:underline, :underline_style])
      :style_reset_strikethrough ->
        Map.drop(emulator.attributes, [:strikethrough, :strikethrough_style])
      :style_reset_overline ->
        Map.drop(emulator.attributes, [:overline, :overline_style])
      :style_reset_blink ->
        Map.drop(emulator.attributes, [:blink, :blink_style])
      :style_reset_inverse ->
        Map.drop(emulator.attributes, [:inverse])
      :style_reset_conceal ->
        Map.drop(emulator.attributes, [:conceal])
      :style_reset_color_foreground ->
        Map.drop(emulator.attributes, [:foreground])
      :style_reset_color_background ->
        Map.drop(emulator.attributes, [:background])
      :style_reset_color_underline ->
        Map.drop(emulator.attributes, [:underline_color])
      :style_reset_color_strikethrough ->
        Map.drop(emulator.attributes, [:strikethrough_color])
      :style_reset_color_overline ->
        Map.drop(emulator.attributes, [:overline_color])
      attr ->
        Map.put(emulator.attributes, attr, true)
    end
  end

  defp reset_attributes(emulator) do
    default_attributes = %{
      bold: false,
      faint: false,
      italic: false,
      underline: false,
      blink: false,
      rapid_blink: false,
      inverse: false,
      conceal: false,
      strikethrough: false,
      proportional_spacing: nil,
      superscript: false,
      subscript: false,
      font: nil,
      alignment: nil
    }
    %{emulator | attributes: Map.merge(emulator.attributes, default_attributes)}
  end

  # Screen manipulation functions

  defp clear_screen(emulator) do
    %{emulator | buffer: []}
  end

  defp clear_line(emulator) do
    # Line clearing would be handled by the buffer management system
    emulator
  end

  defp insert_line(_emulator, _n) do
    # Implementation
  end

  defp delete_line(_emulator, _n) do
    # Implementation
  end

  # Internal function to handle GL character set changes from ANSI sequences
  defp handle_gl_charset(emulator, set) do
    charset_state = CharacterSets.set_gl(emulator.charset_state, set)
    %{emulator | charset_state: charset_state}
  end

  # Helper functions

  defp get_color_name(code) when code >= 0 and code <= 15 do
    Map.get(@colors, code)
  end

  defp get_256_color(code) when code >= 16 and code <= 231 do
    # RGB cube (16-231)
    code = code - 16
    r = div(code, 36) * 51
    g = rem(div(code, 6), 6) * 51
    b = rem(code, 6) * 51
    {r, g, b}
  end

  defp get_256_color(code) when code >= 232 and code <= 255 do
    # Grayscale (232-255)
    value = (code - 232) * 10 + 8
    {value, value, value}
  end

  defp attribute_code(attr) do
    case attr do
      :bold -> "1"
      :faint -> "2"
      :italic -> "3"
      :underline -> "4"
      :blink -> "5"
      :rapid_blink -> "6"
      :inverse -> "7"
      :conceal -> "8"
      :strikethrough -> "9"
      :fraktur -> "20"
      :double_underline -> "21"
      :normal_intensity -> "22"
      :no_italic_fraktur -> "23"
      :no_underline -> "24"
      :no_blink -> "25"
      :no_reverse -> "27"
      :reveal -> "28"
      :no_strikethrough -> "29"
      _ -> "0"
    end
  end

  defp reset_attribute_code(attr) do
    case attr do
      :bold -> "22"
      :faint -> "22"
      :italic -> "23"
      :underline -> "24"
      :blink -> "25"
      :rapid_blink -> "25"
      :inverse -> "27"
      :conceal -> "28"
      :strikethrough -> "29"
      :fraktur -> "23"
      :double_underline -> "24"
      :normal_intensity -> "22"
      :no_italic_fraktur -> "23"
      :no_underline -> "24"
      :no_blink -> "25"
      :no_reverse -> "27"
      :reveal -> "28"
      :no_strikethrough -> "29"
      _ -> "0"
    end
  end

  defp clear_screen_code(mode) do
    case mode do
      0 -> "0"  # Clear from cursor to end
      1 -> "1"  # Clear from beginning to cursor
      2 -> "2"  # Clear entire screen
      3 -> "3"  # Clear entire screen and scrollback
      _ -> "0"
    end
  end

  defp erase_line_code(mode) do
    case mode do
      0 -> "0"  # Clear from cursor to end of line
      1 -> "1"  # Clear from beginning of line to cursor
      2 -> "2"  # Clear entire line
      _ -> "0"
    end
  end

  @doc """
  Switches the specified character set to the given charset.
  """
  def switch_charset(emulator, set, charset) do
    charset_state = CharacterSets.switch_charset(emulator.charset_state, set, charset)
    %{emulator | charset_state: charset_state}
  end

  # Mouse event handling

  defp enable_mouse_tracking(emulator, mode) do
    mouse_state = MouseEvents.enable(emulator.mouse_state, mode)
    %{emulator | mouse_state: mouse_state}
  end

  defp disable_mouse_tracking(emulator) do
    mouse_state = MouseEvents.disable(emulator.mouse_state)
    %{emulator | mouse_state: mouse_state}
  end

  defp handle_mouse_event(emulator, button, x, y) do
    mouse_state = emulator.mouse_state
    |> MouseEvents.update_position({x, y})
    |> MouseEvents.update_button_state(button)
    
    # Generate the mouse event report
    report = MouseEvents.generate_report(mouse_state)
    
    # Update the emulator with the new mouse state and add the report to the output buffer
    %{emulator | 
      mouse_state: mouse_state,
      output_buffer: [report | emulator.output_buffer]
    }
  end

  # Color conversion functions

  defp rgb_to_256color(%{r: r, g: g, b: b}) do
    # Convert RGB to 256 color code
    # This is a simplified version - you may want to use a more sophisticated algorithm
    r_index = div(r, 51)
    g_index = div(g, 51)
    b_index = div(b, 51)
    16 + (36 * r_index) + (6 * g_index) + b_index
  end

end