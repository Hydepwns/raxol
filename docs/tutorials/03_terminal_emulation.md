# Terminal Emulation Mastery

---
id: terminal_emulation
title: Terminal Emulation and ANSI Sequences
difficulty: intermediate
estimated_time: 20
tags: [terminal, ansi, escape-sequences, vt100, emulation]
prerequisites: [getting_started]
---

## Master Raxol's Terminal Emulation

Raxol provides a world-class terminal emulator with comprehensive ANSI escape sequence support, VT100 compatibility, and advanced features like Sixel graphics.

### Step 1: Understanding ANSI Escape Sequences
---
step_id: ansi_basics
title: ANSI Escape Sequence Fundamentals
---

ANSI escape sequences control terminal display attributes, cursor movement, and special features.

#### Core Concepts

- **ESC[**: Control Sequence Introducer (CSI)
- **SGR**: Select Graphic Rendition (colors, styles)
- **Cursor Control**: Movement and positioning
- **Screen Control**: Clearing, scrolling

#### Example Code

```elixir
defmodule ANSIDemo do
  use Raxol.Component
  
  def render(_state, _props) do
    Raxol.UI.box do
      # Basic colors
      Raxol.UI.text("\e[31mRed text\e[0m")
      Raxol.UI.text("\e[32mGreen text\e[0m")
      Raxol.UI.text("\e[34mBlue text\e[0m")
      
      # Background colors
      Raxol.UI.text("\e[41mRed background\e[0m")
      Raxol.UI.text("\e[42mGreen background\e[0m")
      
      # Text styles
      Raxol.UI.text("\e[1mBold text\e[0m")
      Raxol.UI.text("\e[3mItalic text\e[0m")
      Raxol.UI.text("\e[4mUnderlined text\e[0m")
      
      # Combined attributes
      Raxol.UI.text("\e[1;31;44mBold red on blue\e[0m")
      
      # 256 colors
      Raxol.UI.text("\e[38;5;208mOrange (256 color)\e[0m")
      
      # True color (24-bit RGB)
      Raxol.UI.text("\e[38;2;255;105;180mHot pink (RGB)\e[0m")
    end
  end
end
```

#### Understanding the Parser

```elixir
# Raxol's high-performance parser handles:
# - CSI sequences: ESC[...
# - OSC sequences: ESC]...
# - DCS sequences: ESCP...
# - Single character escapes: ESC7, ESC8, etc.

defmodule ParserExample do
  alias Raxol.Terminal.Emulator
  
  def parse_sequence(input) do
    emulator = Emulator.new()
    
    # Parse ANSI sequence
    case Emulator.handle_input(emulator, input) do
      {:ok, updated_emulator} ->
        # Get the current screen state
        screen = Emulator.get_screen(updated_emulator)
        {:ok, screen}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def demonstrate_parser do
    sequences = [
      "\e[31m",          # Set foreground red
      "\e[1;34m",        # Bold blue
      "\e[2J",           # Clear screen
      "\e[H",            # Cursor home
      "\e[10;20H",       # Move cursor to row 10, col 20
      "\e[38;5;123m",    # 256 color
      "\e[38;2;255;0;0m" # RGB color
    ]
    
    for seq <- sequences do
      IO.puts("Parsing: #{inspect(seq)}")
      parse_sequence(seq)
    end
  end
end
```

#### Exercise

Create a function that generates a color gradient using 256-color mode.

#### Hints
- Use `\e[38;5;#{n}m` for foreground colors
- Colors 232-255 are grayscale
- Colors 16-231 form a 6x6x6 RGB cube

### Step 2: Cursor Control and Movement
---
step_id: cursor_control
title: Mastering Cursor Control
---

Learn to control cursor position, visibility, and save/restore operations.

#### Cursor Commands

- **Movement**: Up, Down, Forward, Back
- **Positioning**: Absolute and relative
- **Save/Restore**: DECSC/DECRC
- **Visibility**: Show/Hide cursor

#### Example Code

```elixir
defmodule CursorControl do
  use Raxol.Component
  
  def init(_props) do
    {:ok, %{
      cursor_x: 1,
      cursor_y: 1,
      saved_positions: [],
      cursor_visible: true
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box(height: 20, width: 60) do
      # Display cursor position
      Raxol.UI.text("Cursor: (#{state.cursor_x}, #{state.cursor_y})")
      
      # Control buttons
      Raxol.UI.grid(columns: 3) do
        Raxol.UI.button("↑", on_click: {:move_cursor, :up})
        Raxol.UI.button("Home", on_click: :cursor_home)
        Raxol.UI.button("↑", on_click: {:move_cursor, :up})
        
        Raxol.UI.button("←", on_click: {:move_cursor, :left})
        Raxol.UI.button("Center", on_click: :cursor_center)
        Raxol.UI.button("→", on_click: {:move_cursor, :right})
        
        Raxol.UI.button("↓", on_click: {:move_cursor, :down})
        Raxol.UI.button("End", on_click: :cursor_end)
        Raxol.UI.button("↓", on_click: {:move_cursor, :down})
      end
      
      # Save/Restore
      Raxol.UI.flex(direction: :horizontal) do
        Raxol.UI.button("Save Position", on_click: :save_cursor)
        Raxol.UI.button("Restore Position", on_click: :restore_cursor)
        Raxol.UI.button(
          if(state.cursor_visible, do: "Hide", else: "Show"),
          on_click: :toggle_cursor
        )
      end
      
      # Render canvas with cursor
      render_canvas(state)
    end
  end
  
  def handle_event({:move_cursor, direction}, state) do
    new_state = case direction do
      :up    -> %{state | cursor_y: max(1, state.cursor_y - 1)}
      :down  -> %{state | cursor_y: min(20, state.cursor_y + 1)}
      :left  -> %{state | cursor_x: max(1, state.cursor_x - 1)}
      :right -> %{state | cursor_x: min(60, state.cursor_x + 1)}
    end
    
    emit_cursor_sequence(new_state)
    {:ok, new_state}
  end
  
  def handle_event(:cursor_home, state) do
    emit_sequence("\e[H")
    {:ok, %{state | cursor_x: 1, cursor_y: 1}}
  end
  
  def handle_event(:cursor_center, state) do
    emit_sequence("\e[10;30H")
    {:ok, %{state | cursor_x: 30, cursor_y: 10}}
  end
  
  def handle_event(:cursor_end, state) do
    emit_sequence("\e[20;60H")
    {:ok, %{state | cursor_x: 60, cursor_y: 20}}
  end
  
  def handle_event(:save_cursor, state) do
    emit_sequence("\e7")  # DECSC
    saved = [{state.cursor_x, state.cursor_y} | state.saved_positions]
    {:ok, %{state | saved_positions: saved}}
  end
  
  def handle_event(:restore_cursor, state) do
    case state.saved_positions do
      [{x, y} | rest] ->
        emit_sequence("\e8")  # DECRC
        {:ok, %{state | cursor_x: x, cursor_y: y, saved_positions: rest}}
      [] ->
        {:ok, state}
    end
  end
  
  def handle_event(:toggle_cursor, state) do
    if state.cursor_visible do
      emit_sequence("\e[?25l")  # Hide cursor
    else
      emit_sequence("\e[?25h")  # Show cursor
    end
    {:ok, %{state | cursor_visible: !state.cursor_visible}}
  end
  
  defp emit_cursor_sequence(state) do
    emit_sequence("\e[#{state.cursor_y};#{state.cursor_x}H")
  end
  
  defp emit_sequence(seq) do
    IO.write(seq)
  end
  
  defp render_canvas(state) do
    # Visual representation of terminal with cursor
    canvas = for y <- 1..20 do
      for x <- 1..60 do
        if x == state.cursor_x && y == state.cursor_y do
          if state.cursor_visible, do: "█", else: " "
        else
          "·"
        end
      end
      |> Enum.join("")
    end
    
    Raxol.UI.pre(Enum.join(canvas, "\n"))
  end
end
```

#### Exercise

Implement a snake game using cursor control commands.

#### Hints
- Use absolute positioning for snake segments
- Save/restore cursor for UI updates
- Hide cursor during gameplay

### Step 3: Screen Manipulation
---
step_id: screen_manipulation
title: Screen and Line Control
---

Master screen clearing, scrolling, and line manipulation.

#### Screen Operations

- **Clear**: Entire screen, lines, partial clearing
- **Scroll**: Up/down scrolling, regions
- **Insert/Delete**: Lines and characters
- **Erase**: In line, in display

#### Example Code

```elixir
defmodule ScreenControl do
  use Raxol.Component
  
  def init(_props) do
    {:ok, %{
      lines: generate_lines(30),
      scroll_region: {1, 24},
      insert_mode: false
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.heading("Screen Manipulation Demo")
      
      # Control panel
      Raxol.UI.grid(columns: 4) do
        Raxol.UI.button("Clear Screen", on_click: :clear_screen)
        Raxol.UI.button("Clear Line", on_click: :clear_line)
        Raxol.UI.button("Clear to End", on_click: :clear_to_end)
        Raxol.UI.button("Clear to Start", on_click: :clear_to_start)
        
        Raxol.UI.button("Scroll Up", on_click: :scroll_up)
        Raxol.UI.button("Scroll Down", on_click: :scroll_down)
        Raxol.UI.button("Insert Line", on_click: :insert_line)
        Raxol.UI.button("Delete Line", on_click: :delete_line)
      end
      
      # Display area
      Raxol.UI.box(border: :double, height: 24) do
        render_screen(state)
      end
      
      # Scroll region control
      Raxol.UI.text("Scroll Region: #{elem(state.scroll_region, 0)}-#{elem(state.scroll_region, 1)}")
      Raxol.UI.slider(
        min: 1,
        max: 24,
        value: elem(state.scroll_region, 1),
        on_change: {:set_scroll_bottom, :value}
      )
    end
  end
  
  def handle_event(:clear_screen, state) do
    # ESC[2J - Clear entire screen
    emit_sequence("\e[2J")
    {:ok, %{state | lines: List.duplicate("", 30)}}
  end
  
  def handle_event(:clear_line, state) do
    # ESC[2K - Clear entire line
    emit_sequence("\e[2K")
    {:ok, state}
  end
  
  def handle_event(:clear_to_end, state) do
    # ESC[0J - Clear from cursor to end of screen
    emit_sequence("\e[0J")
    {:ok, state}
  end
  
  def handle_event(:clear_to_start, state) do
    # ESC[1J - Clear from cursor to beginning of screen
    emit_sequence("\e[1J")
    {:ok, state}
  end
  
  def handle_event(:scroll_up, state) do
    # ESC[S - Scroll up one line
    emit_sequence("\e[S")
    
    lines = Enum.drop(state.lines, 1) ++ ["New line at bottom"]
    {:ok, %{state | lines: lines}}
  end
  
  def handle_event(:scroll_down, state) do
    # ESC[T - Scroll down one line
    emit_sequence("\e[T")
    
    lines = ["New line at top"] ++ Enum.drop(state.lines, -1)
    {:ok, %{state | lines: lines}}
  end
  
  def handle_event(:insert_line, state) do
    # ESC[L - Insert line at cursor
    emit_sequence("\e[L")
    {:ok, state}
  end
  
  def handle_event(:delete_line, state) do
    # ESC[M - Delete line at cursor
    emit_sequence("\e[M")
    {:ok, state}
  end
  
  def handle_event({:set_scroll_bottom, value}, state) do
    # ESC[r - Set scroll region
    top = elem(state.scroll_region, 0)
    emit_sequence("\e[#{top};#{value}r")
    {:ok, %{state | scroll_region: {top, value}}}
  end
  
  defp generate_lines(count) do
    for i <- 1..count do
      "Line #{i}: #{String.duplicate("═", 40)}"
    end
  end
  
  defp render_screen(state) do
    state.lines
    |> Enum.take(24)
    |> Enum.map(&Raxol.UI.text/1)
  end
  
  defp emit_sequence(seq) do
    IO.write(seq)
  end
end
```

#### Exercise

Create a split-screen editor with independent scroll regions.

#### Hints
- Use `ESC[r` to set scroll regions
- Save/restore cursor between regions
- Handle insert/delete within regions

### Step 4: Advanced Terminal Features
---
step_id: advanced_features
title: Advanced Terminal Features
---

Explore Raxol's advanced terminal capabilities including mouse support, bracketed paste, and alternate screen.

#### Advanced Features

- **Mouse Tracking**: Click, drag, scroll events
- **Bracketed Paste**: Safe paste mode
- **Alternate Screen**: Secondary buffer
- **Window Title**: Dynamic title updates

#### Example Code

```elixir
defmodule AdvancedTerminal do
  use Raxol.Component
  
  def init(_props) do
    # Enable mouse tracking
    enable_mouse_tracking()
    
    {:ok, %{
      mouse_events: [],
      paste_buffer: "",
      using_alt_screen: false,
      window_title: "Raxol Terminal"
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.heading("Advanced Terminal Features")
      
      # Mouse tracking demo
      Raxol.UI.box(title: "Mouse Events", height: 10) do
        if Enum.empty?(state.mouse_events) do
          Raxol.UI.text("Move mouse or click to see events")
        else
          for event <- Enum.take(state.mouse_events, 5) do
            Raxol.UI.text(format_mouse_event(event))
          end
        end
      end
      
      # Bracketed paste demo
      Raxol.UI.box(title: "Bracketed Paste") do
        Raxol.UI.text("Paste content to test bracketed paste mode")
        Raxol.UI.pre(state.paste_buffer, style: [background: :dark_gray])
      end
      
      # Screen buffer control
      Raxol.UI.flex(direction: :horizontal) do
        Raxol.UI.button(
          if(state.using_alt_screen, do: "Main Screen", else: "Alt Screen"),
          on_click: :toggle_screen
        )
        
        Raxol.UI.button(
          "Set Window Title",
          on_click: :set_window_title
        )
      end
    end
  end
  
  def handle_event({:mouse, event}, state) do
    events = [event | state.mouse_events] |> Enum.take(10)
    {:ok, %{state | mouse_events: events}}
  end
  
  def handle_event({:paste, content}, state) do
    # Bracketed paste wraps content in ESC[200~ and ESC[201~
    {:ok, %{state | paste_buffer: content}}
  end
  
  def handle_event(:toggle_screen, state) do
    if state.using_alt_screen do
      # Switch to main screen
      emit_sequence("\e[?1049l")
    else
      # Switch to alternate screen
      emit_sequence("\e[?1049h")
    end
    
    {:ok, %{state | using_alt_screen: !state.using_alt_screen}}
  end
  
  def handle_event(:set_window_title, state) do
    title = "Raxol - #{DateTime.utc_now() |> DateTime.to_string()}"
    
    # OSC 0 - Set window title
    emit_sequence("\e]0;#{title}\a")
    
    {:ok, %{state | window_title: title}}
  end
  
  defp enable_mouse_tracking do
    # Enable mouse tracking modes
    sequences = [
      "\e[?1000h",  # Enable basic mouse tracking
      "\e[?1002h",  # Enable button event tracking
      "\e[?1003h",  # Enable any-motion tracking
      "\e[?1006h",  # Enable SGR extended mode
      "\e[?2004h"   # Enable bracketed paste
    ]
    
    Enum.each(sequences, &emit_sequence/1)
  end
  
  defp disable_mouse_tracking do
    sequences = [
      "\e[?1000l",
      "\e[?1002l",
      "\e[?1003l",
      "\e[?1006l",
      "\e[?2004l"
    ]
    
    Enum.each(sequences, &emit_sequence/1)
  end
  
  defp format_mouse_event(event) do
    case event do
      {:click, x, y, button} ->
        "Click: Button #{button} at (#{x}, #{y})"
        
      {:drag, x, y} ->
        "Drag to (#{x}, #{y})"
        
      {:scroll, direction, x, y} ->
        "Scroll #{direction} at (#{x}, #{y})"
        
      {:move, x, y} ->
        "Move to (#{x}, #{y})"
    end
  end
  
  def terminate(_reason, _state) do
    disable_mouse_tracking()
    :ok
  end
  
  defp emit_sequence(seq) do
    IO.write(seq)
  end
end
```

#### Exercise

Build a drawing application with mouse support.

#### Hints
- Track mouse button state
- Use motion events for drawing
- Implement color palette with clicks

### Step 5: Sixel Graphics
---
step_id: sixel_graphics
title: Sixel Graphics in Terminal
---

Learn to display images in the terminal using Sixel graphics protocol.

#### Sixel Overview

- **Protocol**: DEC Sixel graphics format
- **Support**: Modern terminals (iTerm2, Kitty, etc.)
- **Applications**: Charts, images, visualizations

#### Example Code

```elixir
defmodule SixelGraphics do
  use Raxol.Component
  alias Raxol.Terminal.Sixel
  
  def init(_props) do
    {:ok, %{
      image_path: nil,
      sixel_data: nil,
      supports_sixel: check_sixel_support()
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.heading("Sixel Graphics Demo")
      
      if state.supports_sixel do
        render_sixel_content(state)
      else
        Raxol.UI.text("Your terminal doesn't support Sixel graphics", 
                     style: [color: :yellow])
        Raxol.UI.text("Try iTerm2, Kitty, or mlterm")
      end
    end
  end
  
  defp render_sixel_content(state) do
    Raxol.UI.box do
      # File selector
      Raxol.UI.file_picker(
        accept: [".png", ".jpg", ".gif"],
        on_select: {:load_image, :path}
      )
      
      # Display controls
      Raxol.UI.grid(columns: 3) do
        Raxol.UI.button("Show Test Pattern", on_click: :show_test_pattern)
        Raxol.UI.button("Draw Chart", on_click: :draw_chart)
        Raxol.UI.button("Clear", on_click: :clear_sixel)
      end
      
      # Image display area
      if state.sixel_data do
        Raxol.UI.box(title: "Sixel Output") do
          display_sixel(state.sixel_data)
        end
      end
    end
  end
  
  def handle_event({:load_image, path}, state) do
    case load_and_convert_image(path) do
      {:ok, sixel_data} ->
        {:ok, %{state | image_path: path, sixel_data: sixel_data}}
        
      {:error, reason} ->
        Logger.error("Failed to load image: #{reason}")
        {:ok, state}
    end
  end
  
  def handle_event(:show_test_pattern, state) do
    sixel_data = generate_test_pattern()
    {:ok, %{state | sixel_data: sixel_data}}
  end
  
  def handle_event(:draw_chart, state) do
    sixel_data = generate_bar_chart([
      {"Jan", 45},
      {"Feb", 52},
      {"Mar", 48},
      {"Apr", 61},
      {"May", 58},
      {"Jun", 65}
    ])
    
    {:ok, %{state | sixel_data: sixel_data}}
  end
  
  def handle_event(:clear_sixel, state) do
    clear_sixel_display()
    {:ok, %{state | sixel_data: nil}}
  end
  
  defp check_sixel_support do
    # Query terminal for Sixel support
    # ESC[?1;1;0c - Request terminal attributes
    emit_sequence("\e[?1;1;0c")
    
    # Parse response for Sixel capability
    # In practice, would need async handling
    true  # Assume support for demo
  end
  
  defp load_and_convert_image(path) do
    # Use ImageMagick or similar to convert to Sixel
    case System.cmd("convert", [path, "sixel:-"]) do
      {sixel_data, 0} ->
        {:ok, sixel_data}
        
      {_, _} ->
        {:error, "Failed to convert image"}
    end
  end
  
  defp generate_test_pattern do
    # Simple Sixel test pattern
    # DCS P q # 0 ; 2 ; 0 q
    pattern = """
    \ePq
    #0;2;0;0;0#1;2;100;100;0#2;2;0;100;0#3;2;100;0;0
    #0!100~-
    #1!100~-
    #2!100~-
    #3!100~-
    \e\\
    """
    
    pattern
  end
  
  defp generate_bar_chart(data) do
    # Generate Sixel bar chart
    max_value = data |> Enum.map(&elem(&1, 1)) |> Enum.max()
    bar_width = 40
    bar_height = 200
    
    sixel = "\ePq"
    
    # Define colors
    sixel = sixel <> "#0;2;0;0;0"      # Black
    sixel = sixel <> "#1;2;30;70;100"  # Blue
    sixel = sixel <> "#2;2;100;30;30"  # Red
    
    # Draw bars
    for {{_label, value}, index} <- Enum.with_index(data) do
      height = round(value / max_value * bar_height)
      x = index * (bar_width + 10)
      
      # Draw bar using Sixel
      sixel <> draw_rectangle(x, bar_height - height, bar_width, height, 1)
    end
    
    sixel <> "\e\\"
  end
  
  defp draw_rectangle(x, y, width, height, color) do
    # Simplified rectangle drawing in Sixel
    "##{color}!#{width}~"
  end
  
  defp display_sixel(data) do
    emit_sequence(data)
  end
  
  defp clear_sixel_display do
    # Clear the Sixel display area
    emit_sequence("\e[2J")
  end
  
  defp emit_sequence(seq) do
    IO.write(seq)
  end
end
```

#### Exercise

Create an image gallery viewer with Sixel support.

#### Hints
- Cache converted Sixel data
- Implement thumbnail generation
- Add zoom/pan controls

### Congratulations!

You've mastered Raxol's terminal emulation features! You now understand:

- ✓ ANSI escape sequences and SGR codes
- ✓ Cursor control and positioning
- ✓ Screen manipulation and scrolling
- ✓ Advanced features (mouse, paste, alternate screen)
- ✓ Sixel graphics protocol

## Next Steps

- Build [Terminal Applications](docs/tutorials/building_apps.html)
- Explore [Performance Optimization](docs/tutorials/performance.html)
- Learn [Testing Strategies](docs/tutorials/testing.html)