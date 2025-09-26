defmodule Raxol.Benchmark.ScenarioGenerator do
  @moduledoc """
  Generates realistic test scenarios and data for benchmarking.
  Includes real-world terminal sequences, user interactions, edge cases,
  and visualization data for comprehensive benchmark testing.
  """

  @doc """
  Generate a comprehensive set of test scenarios.
  """
  def generate_all_scenarios do
    %{
      basic: generate_basic_scenarios(),
      ansi: generate_ansi_scenarios(),
      terminal: generate_terminal_scenarios(),
      real_world: generate_real_world_scenarios(),
      edge_cases: generate_edge_cases(),
      stress_test: generate_stress_test_scenarios()
    }
  end

  @doc """
  Generate basic text scenarios.
  """
  def generate_basic_scenarios do
    %{
      empty: "",
      single_char: "a",
      short_text: "Hello, World!",
      line_of_text: "The quick brown fox jumps over the lazy dog.",
      multiline: "Line 1\nLine 2\nLine 3",
      with_tabs: "Column1\tColumn2\tColumn3",
      with_carriage_return: "Progress: 50%\rProgress: 100%",
      unicode: "Hello 世界 [WORLD]",
      special_chars: "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    }
  end

  @doc """
  Generate ANSI escape sequence scenarios.
  """
  def generate_ansi_scenarios do
    %{
      # Basic colors
      simple_color: "\e[31mRed Text\e[0m",
      multiple_colors: "\e[31mRed \e[32mGreen \e[34mBlue\e[0m",

      # Text attributes
      bold: "\e[1mBold Text\e[0m",
      underline: "\e[4mUnderlined\e[0m",
      combined_attrs: "\e[1;4;31mBold Red Underlined\e[0m",

      # 256 colors
      color_256: "\e[38;5;196mBright Red\e[0m",
      bg_256: "\e[48;5;21mBlue Background\e[0m",

      # RGB colors
      rgb_fg: "\e[38;2;255;128;0mOrange RGB\e[0m",
      rgb_bg: "\e[48;2;0;255;0mGreen RGB Background\e[0m",

      # Cursor movement
      cursor_up: "\e[5A",
      cursor_down: "\e[3B",
      cursor_forward: "\e[10C",
      cursor_back: "\e[2D",
      cursor_position: "\e[10;20H",
      cursor_save_restore: "\e[s\e[10;10H\e[u",

      # Screen operations
      clear_screen: "\e[2J",
      clear_line: "\e[K",
      clear_to_end: "\e[J",
      scroll_region: "\e[5;20r",

      # Complex sequences
      progress_bar: generate_progress_bar(),
      color_gradient: generate_color_gradient(),
      box_drawing: generate_box_drawing()
    }
  end

  @doc """
  Generate terminal emulator specific scenarios.
  """
  def generate_terminal_scenarios do
    %{
      # VT100 sequences
      vt100_init: "\e[?1h\e[?3l\e[?4l\e[?5l\e[?6l\e[?7h",

      # xterm sequences
      xterm_title: "\e]0;Terminal Title\a",
      xterm_colors: "\e]10;#ffffff\a\e]11;#000000\a",

      # Screen modes
      alternate_buffer: "\e[?1049h",
      normal_buffer: "\e[?1049l",

      # Mouse tracking
      mouse_enable: "\e[?1000h",
      mouse_disable: "\e[?1000l",

      # Character sets
      charset_g0: "\e(B",
      charset_g1: "\e)0",
      charset_switch: "\x0e\x0f",

      # Terminal queries
      device_status: "\e[6n",
      device_attrs: "\e[c",

      # Window operations
      resize_window: "\e[8;24;80t",
      move_window: "\e[3;100;100t"
    }
  end

  @doc """
  Generate real-world application scenarios.
  """
  def generate_real_world_scenarios do
    %{
      vim_session: generate_vim_session(),
      git_diff: generate_git_diff(),
      htop_output: generate_htop_output(),
      log_viewer: generate_log_viewer(),
      npm_install: generate_npm_install(),
      docker_output: generate_docker_output(),
      tmux_panes: generate_tmux_panes(),
      interactive_menu: generate_interactive_menu(),
      repl_session: generate_repl_session(),
      file_browser: generate_file_browser()
    }
  end

  @doc """
  Generate edge cases and stress tests.
  """
  def generate_edge_cases do
    %{
      # Malformed sequences
      incomplete_csi: "\e[",
      invalid_params: "\e[999999999m",
      negative_params: "\e[-5;-10H",

      # Boundary conditions
      max_params: "\e[" <> Enum.join(1..32, ";") <> "m",
      zero_params: "\e[0;0;0;0m",

      # Rapid changes
      rapid_colors: generate_rapid_color_changes(),
      rapid_cursor: generate_rapid_cursor_movement(),

      # Unicode edge cases
      # e with multiple accents
      combining_chars: "e\u0301\u0300\u0302",
      # Zero-width space
      zero_width: "Hello\u200bWorld",
      # Mixed LTR/RTL
      rtl_text: "Hello עברית مرحبا",
      emojis: "[FAST][CODE][STYLE][HOT][POWER][COLOR]",

      # Control characters
      all_controls: Enum.map_join(0..31, fn i -> <<i>> end),

      # Very long lines
      long_line: String.duplicate("x", 10_000),
      long_escape: "\e[" <> String.duplicate("1;", 1000) <> "m"
    }
  end

  @doc """
  Generate stress test scenarios.
  """
  def generate_stress_test_scenarios do
    %{
      large_text: generate_large_text(100_000),
      many_escapes: generate_many_escapes(10_000),
      deep_nesting: generate_deep_nesting(100),
      concurrent_updates: generate_concurrent_updates(1000),
      memory_stress: generate_memory_stress(),
      performance_stress: generate_performance_stress()
    }
  end

  @doc """
  Generate visualization data (treemap) with varying depth based on size.
  Consolidated from DataGenerator module.
  """
  def generate_treemap_data(size) when size <= 10 do
    # Small dataset - flat structure
    %{
      name: "Root",
      value: size * 10,
      children:
        for i <- 1..size do
          %{
            name: "Item #{i}",
            value: :rand.uniform(100)
          }
        end
    }
  end

  def generate_treemap_data(size) when size <= 100 do
    # Medium dataset - two levels
    num_groups = min(10, div(size, 5))
    items_per_group = div(size, num_groups)

    %{
      name: "Root",
      value: size * 10,
      children:
        for g <- 1..num_groups do
          %{
            name: "Group #{g}",
            value: items_per_group * 10,
            children:
              for i <- 1..items_per_group do
                %{
                  name: "Item #{g}.#{i}",
                  value: :rand.uniform(100)
                }
              end
          }
        end
    }
  end

  def generate_treemap_data(size) do
    # Large dataset - three levels
    num_sections = min(10, div(size, 50))
    num_groups_per_section = min(10, div(size, 10))
    items_per_group = max(1, div(size, num_sections * num_groups_per_section))

    %{
      name: "Root",
      value: size * 10,
      children:
        for s <- 1..num_sections do
          %{
            name: "Section #{s}",
            value: div(size, num_sections) * 10,
            children:
              for g <- 1..num_groups_per_section do
                %{
                  name: "Group #{s}.#{g}",
                  value: items_per_group * 10,
                  children:
                    for i <- 1..items_per_group do
                      %{
                        name: "Item #{s}.#{g}.#{i}",
                        value: :rand.uniform(100)
                      }
                    end
                }
              end
          }
        end
    }
  end

  @doc """
  Count nodes in a treemap structure.
  """
  def count_nodes(nil), do: 0
  def count_nodes(%{children: nil}), do: 1
  def count_nodes(%{children: []}), do: 1

  def count_nodes(%{children: children}) when is_list(children) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end

  def count_nodes(_), do: 1

  @doc """
  Generate chart data for visualization benchmarks.
  """
  def generate_chart_data(size) do
    for i <- 1..size do
      {"Item #{i}", :rand.uniform(100)}
    end
  end

  # Private helper functions

  defp generate_progress_bar do
    bars =
      for i <- 0..100, rem(i, 10) == 0 do
        filled = div(i, 10)
        empty = 10 - filled

        "\r[\e[32m#{String.duplicate("█", filled)}\e[0m#{String.duplicate(" ", empty)}] #{i}%"
      end

    Enum.join(bars, "")
  end

  defp generate_color_gradient do
    for i <- 0..255 do
      "\e[48;5;#{i}m "
    end
    |> Enum.join()
    |> Kernel.<>("\e[0m")
  end

  defp generate_box_drawing do
    """
    \e[0m┌────────────────────┐
    │ Box Drawing Test   │
    ├────────────────────┤
    │ • Item 1           │
    │ • Item 2           │
    │ • Item 3           │
    └────────────────────┘
    """
  end

  defp generate_vim_session do
    """
    \e[?1049h\e[?1h\e[?2004h\e[?1004h
    \e[1;1H\e[K  1 " Vim session simulation
    \e[2;1H\e[K  2
    \e[3;1H\e[K  3 func main() {
    \e[4;1H\e[K  4     \e[33mprintf\e[0m(\e[32m"Hello, World!\\n"\e[0m);
    \e[5;1H\e[K  5     \e[34mreturn\e[0m 0;
    \e[6;1H\e[K  6 }
    \e[7;1H\e[K  7
    \e[24;1H\e[K\e[1m-- INSERT --\e[0m
    """
  end

  defp generate_git_diff do
    """
    \e[1mdiff --git a/file.txt b/file.txt\e[0m
    \e[1mindex abc123..def456 100644\e[0m
    \e[1m--- a/file.txt\e[0m
    \e[1m+++ b/file.txt\e[0m
    \e[36m@@ -1,5 +1,5 @@\e[0m
     Line 1
    \e[31m-Old line 2\e[0m
    \e[32m+New line 2\e[0m
     Line 3
     Line 4
     Line 5
    """
  end

  defp generate_htop_output do
    """
    \e[?1049h\e[1;1H\e[30;47m  CPU[\e[32m|||||||||\e[30m                  34.2%]   Mem[\e[33m||||||||||||||||\e[30m     2.43G/8.00G]\e[0m
    \e[2;1H\e[30;47m  Tasks: 127, 234 thr; 2 running            Load average: 1.42 1.38 1.41\e[0m
    \e[3;1H\e[30;47m  Uptime: 12:34:56\e[0m

    \e[5;1H\e[30;47m    PID USER      PRI  NI  VIRT   RES   SHR S CPU% MEM%   TIME+  Command\e[0m
    \e[6;1H  12345 user       20   0  123M  45.6M 12.3M R 45.2  1.2  1:23.45 \e[32mnode\e[0m app.js
    \e[7;1H  23456 user       20   0  234M  67.8M 23.4M S 12.3  2.3  0:45.67 \e[32mpython\e[0m script.py
    """
  end

  defp generate_log_viewer do
    """
    \e[90m2024-01-15 10:30:45.123\e[0m [\e[32mINFO\e[0m] Application started successfully
    \e[90m2024-01-15 10:30:45.456\e[0m [\e[34mDEBUG\e[0m] Connecting to database...
    \e[90m2024-01-15 10:30:45.789\e[0m [\e[33mWARN\e[0m] Deprecated API usage detected
    \e[90m2024-01-15 10:30:46.012\e[0m [\e[31mERROR\e[0m] Failed to connect: Connection refused
    \e[90m2024-01-15 10:30:46.345\e[0m [\e[32mINFO\e[0m] Retrying connection...
    """
  end

  defp generate_npm_install do
    """
    \e[?25lnpm install

    \e[90m⠋\e[0m Installing dependencies...
    \e[1A\e[K\e[90m⠙\e[0m Installing dependencies...
    \e[1A\e[K\e[90m⠹\e[0m Installing dependencies...
    \e[1A\e[K\e[32m[OK]\e[0m Dependencies installed

    added 234 packages, and audited 567 packages in 12s

    \e[32m123\e[0m packages are looking for funding
      run `npm fund` for details

    found \e[33m3 moderate\e[0m severity vulnerabilities
      run `npm audit fix` to fix them
    \e[?25h
    """
  end

  defp generate_docker_output do
    """
    \e[1mSending build context to Docker daemon  2.048kB\e[0m
    Step 1/5 : FROM node:14-alpine
    \e[32m --->\e[0m abc123def456
    Step 2/5 : WORKDIR /app
    \e[32m --->\e[0m Using cache
    \e[32m --->\e[0m 123abc456def
    Step 3/5 : COPY package*.json ./
    \e[32m --->\e[0m 456def789ghi
    Step 4/5 : RUN npm install
    \e[32m --->\e[0m Running in container789
    \e[32m --->\e[0m 789ghi012jkl
    Step 5/5 : COPY . .
    \e[32m --->\e[0m 012jkl345mno
    \e[32mSuccessfully built 012jkl345mno\e[0m
    \e[32mSuccessfully tagged myapp:latest\e[0m
    """
  end

  defp generate_tmux_panes do
    """
    \e[1;1H\e[32m┌─ pane 1 ────────────────┐\e[0m\e[1;40H\e[34m┌─ pane 2 ────────────────┐\e[0m
    \e[2;1H\e[32m│\e[0m Terminal 1             \e[32m│\e[0m\e[2;40H\e[34m│\e[0m Terminal 2             \e[34m│\e[0m
    \e[12;1H\e[32m└─────────────────────────┘\e[0m\e[12;40H\e[34m└─────────────────────────┘\e[0m
    \e[13;1H\e[33m┌─ pane 3 ─────────────────────────────────────────────────────────┐\e[0m
    \e[14;1H\e[33m│\e[0m Terminal 3                                                       \e[33m│\e[0m
    \e[24;1H\e[33m└──────────────────────────────────────────────────────────────────┘\e[0m
    """
  end

  defp generate_interactive_menu do
    """
    \e[2J\e[H\e[1;36m╔══════════════════════════════╗\e[0m
    \e[2;1H\e[1;36m║\e[0m     \e[1mMain Menu\e[0m              \e[1;36m║\e[0m
    \e[3;1H\e[1;36m╠══════════════════════════════╣\e[0m
    \e[4;1H\e[1;36m║\e[0m \e[7m 1. Option One             \e[0m \e[1;36m║\e[0m
    \e[5;1H\e[1;36m║\e[0m   2. Option Two              \e[1;36m║\e[0m
    \e[6;1H\e[1;36m║\e[0m   3. Option Three            \e[1;36m║\e[0m
    \e[7;1H\e[1;36m║\e[0m   4. Settings                \e[1;36m║\e[0m
    \e[8;1H\e[1;36m║\e[0m   5. Exit                    \e[1;36m║\e[0m
    \e[9;1H\e[1;36m╚══════════════════════════════╝\e[0m
    \e[11;1HUse arrow keys to navigate, Enter to select
    """
  end

  defp generate_repl_session do
    """
    \e[1;32miex(1)>\e[0m 1 + 1
    \e[33m2\e[0m
    \e[1;32miex(2)>\e[0m Enum.map([1, 2, 3], &(&1 * 2))
    \e[33m[2, 4, 6]\e[0m
    \e[1;32miex(3)>\e[0m IO.puts("\e[31mHello\e[0m \e[32mWorld\e[0m")
    \e[31mHello\e[0m \e[32mWorld\e[0m
    \e[33m:ok\e[0m
    \e[1;32miex(4)>\e[0m _
    """
  end

  defp generate_file_browser do
    """
    \e[1;34m.\e[0m
    ├── \e[1;34mapp\e[0m
    │   ├── \e[32mcontrollers\e[0m
    │   │   └── application_controller.rb
    │   ├── \e[32mmodels\e[0m
    │   │   └── user.rb
    │   └── \e[32mviews\e[0m
    │       └── \e[33mlayouts\e[0m
    │           └── application.html.erb
    ├── \e[1;34mconfig\e[0m
    │   └── routes.rb
    └── \e[36mREADME.md\e[0m
    """
  end

  defp generate_rapid_color_changes do
    Enum.map_join(1..100, "", fn i -> "\e[#{30 + rem(i, 8)}m█" end)
    |> Kernel.<>("\e[0m")
  end

  defp generate_rapid_cursor_movement do
    Enum.map_join(1..50, "", fn i -> "\e[#{i};#{i}H*" end)
  end

  defp generate_large_text(size) do
    # Generate realistic text content
    words = [
      "the",
      "quick",
      "brown",
      "fox",
      "jumps",
      "over",
      "lazy",
      "dog",
      "lorem",
      "ipsum",
      "dolor",
      "sit",
      "amet",
      "consectetur",
      "adipiscing"
    ]

    1..size
    |> Enum.map_join("\n", fn _ -> Enum.random(words) end)
    |> Enum.chunk_every(10)
    |> Enum.map_join("\n", &Enum.join(&1, " "))
  end

  defp generate_many_escapes(count) do
    sequences = ["\e[31m", "\e[0m", "\e[1m", "\e[K", "\e[2J", "\e[H"]

    Enum.map_join(1..count, "", fn _ -> Enum.random(sequences) end)
  end

  defp generate_deep_nesting(depth) do
    1..depth
    |> Enum.reduce("text", fn i, acc ->
      "\e[#{rem(i, 8) + 30}m#{acc}\e[0m"
    end)
  end

  defp generate_concurrent_updates(count) do
    1..count
    |> Enum.map(fn i ->
      row = rem(i, 24) + 1
      col = rem(i * 7, 80) + 1
      "\e[#{row};#{col}H#{i}"
    end)
  end

  defp generate_memory_stress do
    # Generate scenarios that stress memory allocation
    %{
      many_small_allocs: List.duplicate("x", 100_000),
      large_single_alloc: String.duplicate("x", 1_000_000),
      fragmented: Enum.map_join(1..10_000, fn i -> String.duplicate("x", i) end)
    }
  end

  defp generate_performance_stress do
    # Generate scenarios that stress performance
    %{
      complex_parsing: generate_complex_parsing_scenario(),
      heavy_rendering: generate_heavy_rendering_scenario(),
      state_thrashing: generate_state_thrashing_scenario()
    }
  end

  defp generate_complex_parsing_scenario do
    # Mix of all escape sequence types
    sequences = [
      "\e[31;1;4m",
      "\e[0m",
      "\e[2J",
      "\e[10;20H",
      "\e[K",
      "\e[?25h",
      "\e[?25l",
      "\e[38;5;196m",
      "\e[48;2;255;0;0m",
      "\e]0;Title\a",
      "\e[?1049h",
      "\e[?1049l"
    ]

    1..1000
    |> Enum.map(fn _ ->
      Enum.random(sequences) <> Enum.random(["text", "data", "test"])
    end)
  end

  defp generate_heavy_rendering_scenario do
    # Scenario that requires many screen updates
    frames =
      for frame <- 1..60 do
        "\e[2J\e[H" <>
          Enum.map_join(1..24, fn row ->
            Enum.map(1..80, fn col ->
              color = rem(frame + row + col, 8) + 30
              "\e[#{color}m█"
            end)
          end)
      end

    Enum.join(frames, "")
  end

  defp generate_state_thrashing_scenario do
    # Rapid state changes
    1..100
    |> Enum.map(fn i ->
      [
        # Enable mode
        "\e[?#{1000 + rem(i, 50)}h",
        # Disable mode
        "\e[?#{1000 + rem(i, 50)}l",
        # Charset switches
        "\e(B",
        "\e)0",
        # Save/restore cursor
        "\e[s",
        "\e[u"
      ]
    end)
    |> List.flatten()
    |> Enum.join("")
  end
end
