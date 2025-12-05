defmodule Raxol.Test.Fixtures.ANSISequences do
  @moduledoc """
  Comprehensive collection of ANSI escape sequences for testing.
  
  These fixtures include:
  - Real-world sequences from popular terminal applications
  - Edge cases and malformed sequences
  - Performance test sequences
  - Unicode and special character combinations
  """

  @doc """
  Basic cursor movement sequences
  """
  def cursor_movements do
    %{
      up: "\e[A",
      down: "\e[B",
      forward: "\e[C",
      backward: "\e[D",
      next_line: "\e[E",
      prev_line: "\e[F",
      column_absolute: "\e[10G",
      position: "\e[5;10H",
      position_alt: "\e[5;10f",
      save_cursor: "\e7",
      restore_cursor: "\e8",
      save_cursor_dec: "\e[s",
      restore_cursor_dec: "\e[u"
    }
  end

  @doc """
  Color and text attribute sequences
  """
  def colors_and_attributes do
    %{
      # Basic colors
      red_fg: "\e[31m",
      green_bg: "\e[42m",
      bright_blue: "\e[94m",
      
      # 256 colors
      color_256_fg: "\e[38;5;196m",
      color_256_bg: "\e[48;5;27m",
      
      # 24-bit true color
      rgb_fg: "\e[38;2;255;128;0m",
      rgb_bg: "\e[48;2;0;128;255m",
      
      # Text attributes
      bold: "\e[1m",
      italic: "\e[3m",
      underline: "\e[4m",
      blink: "\e[5m",
      reverse: "\e[7m",
      strikethrough: "\e[9m",
      
      # Combined attributes
      bold_red_underline: "\e[1;31;4m",
      
      # Reset
      reset: "\e[0m",
      reset_alt: "\e[m"
    }
  end

  @doc """
  Screen and line operations
  """
  def screen_operations do
    %{
      clear_screen: "\e[2J",
      clear_screen_above: "\e[1J",
      clear_screen_below: "\e[0J",
      clear_line: "\e[2K",
      clear_line_left: "\e[1K",
      clear_line_right: "\e[0K",
      insert_lines: "\e[3L",
      delete_lines: "\e[3M",
      scroll_up: "\e[3S",
      scroll_down: "\e[3T"
    }
  end

  @doc """
  Real vim sequences captured from actual usage
  """
  def vim_sequences do
    %{
      # Vim status line
      status_line: "\e[?25l\e[23;1H\e[K\e[24;1H\e[K\e[23;1H-- INSERT --\e[24;80H1,1           All\e[1;1H\e[?25h",
      
      # Vim syntax highlighting
      syntax_highlight: "\e[1;34mdef\e[0m \e[1;33mfunction\e[0m(\e[1;31marg\e[0m)",
      
      # Vim cursor shape changes
      insert_mode_cursor: "\e[6 q",
      normal_mode_cursor: "\e[2 q",
      
      # Vim window split
      vertical_split: "\e[1;40r\e[?25l\e[1;1H\e[K│\e[2;1H\e[K│",
      
      # Vim search highlighting
      search_highlight: "\e[43m\e[30msearch_term\e[0m"
    }
  end

  @doc """
  Git diff color sequences
  """
  def git_diff_sequences do
    %{
      file_header: "\e[1mdiff --git a/file.txt b/file.txt\e[0m",
      hunk_header: "\e[36m@@ -1,3 +1,4 @@\e[0m",
      addition: "\e[32m+added line\e[0m",
      deletion: "\e[31m-removed line\e[0m",
      context: " unchanged line",
      file_mode: "\e[1mnew file mode 100644\e[0m"
    }
  end

  @doc """
  tmux status bar and pane sequences
  """
  def tmux_sequences do
    %{
      # Status bar
      status_bar: "\e[1;1H\e[K\e[7m[0] 0:bash* \e[27m",
      
      # Pane borders (box drawing)
      vertical_border: "│",
      horizontal_border: "─",
      corner_tl: "┌",
      corner_tr: "┐",
      corner_bl: "└",
      corner_br: "┘",
      
      # Window title
      set_window_title: "\e]0;tmux\a",
      
      # Alternative screen
      enter_alt_screen: "\e[?1049h",
      exit_alt_screen: "\e[?1049l"
    }
  end

  @doc """
  OSC (Operating System Command) sequences
  """
  def osc_sequences do
    %{
      set_title: "\e]0;Terminal Title\e\\",
      set_title_alt: "\e]2;Window Title\a",
      set_icon: "\e]1;Icon Name\a",
      hyperlink: "\e]8;;https://example.com\e\\Click here\e]8;;\e\\",
      notification: "\e]9;Notification text\a",
      set_color_palette: "\e]4;1;rgb:ff/00/00\a",
      clipboard_copy: "\e]52;c;SGVsbG8gV29ybGQ=\a"
    }
  end

  @doc """
  Terminal mode changes
  """
  def mode_sequences do
    %{
      # Application keypad
      app_keypad_on: "\e[?1h",
      app_keypad_off: "\e[?1l",
      
      # Cursor visibility
      cursor_visible: "\e[?25h",
      cursor_invisible: "\e[?25l",
      
      # Mouse tracking
      mouse_tracking_on: "\e[?1000h",
      mouse_tracking_off: "\e[?1000l",
      
      # Bracketed paste
      bracketed_paste_on: "\e[?2004h",
      bracketed_paste_off: "\e[?2004l",
      
      # Line wrap
      autowrap_on: "\e[?7h",
      autowrap_off: "\e[?7l"
    }
  end

  @doc """
  Complex multi-sequence operations
  """
  def complex_sequences do
    %{
      # Save state, move, write, restore
      save_write_restore: "\e[s\e[10;20H\e[31mHello\e[0m\e[u",
      
      # Clear screen, set colors, draw box
      colored_box: "\e[2J\e[1;1H\e[34m┌──────┐\n│      │\n└──────┘\e[0m",
      
      # Progress bar animation
      progress_bar: "\e[1G[\e[32m████████          \e[0m] 40%\e[K",
      
      # Table with colors
      colored_table: "\e[1m Name    \e[0m│\e[1m Status \e[0m\n\e[32m[OK]\e[0m Test 1 │ \e[32mPASS\e[0m",
      
      # Nested attributes
      nested_attrs: "\e[1m\e[4m\e[31mBold Underline Red\e[21m Still Underline Red\e[0m"
    }
  end

  @doc """
  Edge cases and malformed sequences
  """
  def edge_cases do
    %{
      # Incomplete sequences
      incomplete_csi: "\e[",
      incomplete_osc: "\e]0;",
      no_terminator: "\e[31",
      
      # Invalid parameters
      negative_param: "\e[-1A",
      huge_param: "\e[999999B",
      non_numeric: "\e[abcH",
      
      # Empty parameters
      empty_params: "\e[;m",
      multiple_semicolons: "\e[;;1;;m",
      
      # Mixed valid/invalid
      partial_valid: "Hello\e[31mRed\e[invalid",
      
      # Extremely long sequences
      long_params: "\e[" <> Enum.join(1..100, ";") <> "m",
      
      # Null bytes
      with_null: "Hello\0World",
      
      # Control characters
      with_controls: "Text\x01\x02\x03\x1fMore"
    }
  end

  @doc """
  Unicode and special characters with ANSI
  """
  def unicode_sequences do
    %{
      # Emoji with colors
      colored_emoji: "\e[31m❤️\e[32m💚\e[34m💙\e[0m",
      
      # Combining characters
      combining_with_color: "\e[33ma\u0301\u0308\e[0m",
      
      # Right-to-left text
      rtl_with_ansi: "\e[35mمرحبا\e[0m \e[36mשלום\e[0m",
      
      # Zero-width characters
      zero_width: "Hello\u200bWorld",
      
      # Full-width characters
      fullwidth: "\e[1m全角文字\e[0m",
      
      # Box drawing with attributes
      styled_box: "\e[1;34m╔═══╗\n║   ║\n╚═══╝\e[0m"
    }
  end

  @doc """
  Performance stress test sequences
  """
  def stress_sequences do
    %{
      # Rapid color changes
      color_spam: Enum.map_join(1..1000, "", fn i -> "\e[#{rem(i, 7) + 31}m█" end),
      
      # Many cursor movements
      cursor_dance: Enum.map_join(1..100, "", fn i -> "\e[#{i};#{i}H*" end),
      
      # Nested attributes
      deep_nesting: Enum.reduce(1..20, "", fn i, acc -> 
        acc <> "\e[#{rem(i, 7) + 1}m"
      end) <> "Text" <> "\e[0m",
      
      # Clear and redraw
      flicker_test: Enum.map_join(1..50, "", fn _ -> "\e[2J\e[1;1HFlash\e[2J" end),
      
      # Large data with escapes
      large_formatted: Enum.map_join(1..10_000, "", fn i ->
        color = rem(i, 7) + 31
        "\e[#{color}m#{i}\e[0m "
      end)
    }
  end

  @doc """
  Terminal report sequences (responses from terminal)
  """
  def report_sequences do
    %{
      # Device status report
      dsr_ok: "\e[0n",
      
      # Cursor position report
      cpr: "\e[12;40R",
      
      # Terminal identification
      device_attributes: "\e[?1;2c",
      
      # Screen size
      screen_size: "\e[8;24;80t",
      
      # Color palette report
      color_report: "\e]4;1;rgb:ff/00/00\e\\"
    }
  end

  @doc """
  Get all test sequences as a flat list for comprehensive testing
  """
  def all_sequences do
    [
      cursor_movements(),
      colors_and_attributes(),
      screen_operations(),
      vim_sequences(),
      git_diff_sequences(),
      tmux_sequences(),
      osc_sequences(),
      mode_sequences(),
      complex_sequences(),
      unicode_sequences()
    ]
    |> Enum.flat_map(&Map.values/1)
  end

  @doc """
  Get all edge cases for robustness testing
  """
  def all_edge_cases do
    edge_cases() |> Map.values()
  end
end