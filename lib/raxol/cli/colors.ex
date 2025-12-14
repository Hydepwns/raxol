defmodule Raxol.CLI.Colors do
  @moduledoc """
  Centralized color palette for consistent CLI styling.

  This module provides a unified color scheme for all terminal output,
  ensuring visual consistency across mix tasks, the playground, and error messages.

  ## Design Principles

  - **Semantic colors**: Use purpose-based names (`:success`, `:error`) not raw colors
  - **Composable**: Functions return ANSI strings that can be concatenated
  - **Accessible**: Reasonable contrast for most terminals
  - **Consistent**: Same meaning everywhere in the CLI

  ## Usage

      import Raxol.CLI.Colors

      # Inline styling
      IO.puts(success("[OK]") <> " Task completed")
      IO.puts(error("[FAIL]") <> " Something went wrong")

      # With reset
      IO.puts(info("Processing...") <> reset())

      # Status indicators
      IO.puts(status_indicator(:ok) <> " All checks passed")

      # Formatted messages
      IO.puts(format_success("Build complete"))
      IO.puts(format_error("Compilation failed", "missing module Foo"))
  """

  # ============================================================================
  # Core ANSI Codes
  # ============================================================================

  @doc "Reset all formatting"
  def reset, do: IO.ANSI.reset()

  @doc "Bold text"
  def bold, do: IO.ANSI.bright()

  @doc "Dim/faint text"
  def dim, do: IO.ANSI.faint()

  # ============================================================================
  # Semantic Colors
  # ============================================================================

  @doc "Success color (green) - for positive outcomes"
  def success, do: IO.ANSI.green()

  @doc "Error color (red) - for failures and problems"
  def error, do: IO.ANSI.red()

  @doc "Warning color (yellow) - for non-fatal issues"
  def warning, do: IO.ANSI.yellow()

  @doc "Info color (cyan) - for informational messages"
  def info, do: IO.ANSI.cyan()

  @doc "Muted color (light black/gray) - for secondary information"
  def muted, do: IO.ANSI.light_black()

  @doc "Accent color (magenta) - for highlighting important items"
  def accent, do: IO.ANSI.magenta()

  @doc "Primary color (blue) - for primary actions and headers"
  def primary, do: IO.ANSI.blue()

  # ============================================================================
  # Text Styling Functions
  # ============================================================================

  @doc "Apply success styling to text"
  def success(text), do: "#{success()}#{text}#{reset()}"

  @doc "Apply error styling to text"
  def error(text), do: "#{error()}#{text}#{reset()}"

  @doc "Apply warning styling to text"
  def warning(text), do: "#{warning()}#{text}#{reset()}"

  @doc "Apply info styling to text"
  def info(text), do: "#{info()}#{text}#{reset()}"

  @doc "Apply muted styling to text"
  def muted(text), do: "#{muted()}#{text}#{reset()}"

  @doc "Apply accent styling to text"
  def accent(text), do: "#{accent()}#{text}#{reset()}"

  @doc "Apply primary styling to text"
  def primary(text), do: "#{primary()}#{text}#{reset()}"

  @doc "Apply bold styling to text"
  def bold(text), do: "#{bold()}#{text}#{reset()}"

  # ============================================================================
  # Status Indicators
  # ============================================================================

  @doc """
  Returns a formatted status indicator.

  ## Examples

      status_indicator(:ok)      # => "[OK]" in green
      status_indicator(:error)   # => "[FAIL]" in red
      status_indicator(:warning) # => "[WARN]" in yellow
      status_indicator(:skip)    # => "[SKIP]" in muted
      status_indicator(:info)    # => "[INFO]" in cyan
  """
  def status_indicator(:ok), do: success("[OK]")
  def status_indicator(:pass), do: success("[PASS]")
  def status_indicator(:success), do: success("[OK]")
  def status_indicator(:error), do: error("[FAIL]")
  def status_indicator(:fail), do: error("[FAIL]")
  def status_indicator(:warning), do: warning("[WARN]")
  def status_indicator(:warn), do: warning("[WARN]")
  def status_indicator(:skip), do: muted("[SKIP]")
  def status_indicator(:skipped), do: muted("[SKIP]")
  def status_indicator(:info), do: info("[INFO]")
  def status_indicator(:pending), do: muted("[....]")
  def status_indicator(:running), do: info("[....]")

  # ============================================================================
  # Formatted Messages
  # ============================================================================

  @doc """
  Format a success message with indicator.

  ## Examples

      format_success("Build complete")
      # => "[OK] Build complete" with green indicator
  """
  def format_success(message) do
    "#{status_indicator(:ok)} #{message}"
  end

  @doc """
  Format an error message with indicator and optional details.

  ## Examples

      format_error("Compilation failed")
      format_error("Compilation failed", "undefined function foo/1")
  """
  def format_error(message) do
    "#{status_indicator(:error)} #{message}"
  end

  def format_error(message, details) do
    """
    #{status_indicator(:error)} #{message}
        #{muted(details)}
    """
    |> String.trim_trailing()
  end

  @doc """
  Format a warning message with indicator.
  """
  def format_warning(message) do
    "#{status_indicator(:warning)} #{message}"
  end

  @doc """
  Format an info message with indicator.
  """
  def format_info(message) do
    "#{status_indicator(:info)} #{message}"
  end

  @doc """
  Format a skip message with indicator.
  """
  def format_skip(message) do
    "#{status_indicator(:skip)} #{message}"
  end

  # ============================================================================
  # Headers and Sections
  # ============================================================================

  @doc """
  Format a section header.

  ## Examples

      section_header("Running Tests")
      # => "==> Running Tests" in cyan
  """
  def section_header(title) do
    "#{info("==>")} #{bold(title)}"
  end

  @doc """
  Format a subsection header.
  """
  def subsection_header(title) do
    "#{muted("-->")} #{title}"
  end

  @doc """
  Format a divider line.
  """
  def divider(char \\ "-", width \\ 60) do
    muted(String.duplicate(char, width))
  end

  # ============================================================================
  # Command and Code Formatting
  # ============================================================================

  @doc """
  Format a command suggestion.

  ## Examples

      format_command("mix raxol check")
      # => "mix raxol check" in cyan
  """
  def format_command(cmd) do
    info(cmd)
  end

  @doc """
  Format a fix suggestion with command.

  ## Examples

      format_fix("Run the formatter", "mix format")
  """
  def format_fix(description, command) do
    "#{description}: #{format_command(command)}"
  end

  @doc """
  Format a "Did you mean?" suggestion.

  ## Examples

      format_suggestion("chek", "check")
      # => "Did you mean: check?"
  """
  def format_suggestion(typo, suggestion) do
    "Unknown: '#{typo}'. Did you mean: #{accent(suggestion)}?"
  end

  # ============================================================================
  # Progress and Timing
  # ============================================================================

  @doc """
  Format a timing result.

  ## Examples

      format_timing("Compilation", 1234)
      # => "Compilation completed in 1.23s"
  """
  def format_timing(operation, milliseconds) when milliseconds < 1000 do
    "#{operation} completed in #{muted("#{milliseconds}ms")}"
  end

  def format_timing(operation, milliseconds) do
    seconds = Float.round(milliseconds / 1000, 2)
    "#{operation} completed in #{muted("#{seconds}s")}"
  end

  @doc """
  Format a step in a multi-step process.

  ## Examples

      format_step(1, 5, "Compiling")
      # => "[1/5] Compiling"
  """
  def format_step(current, total, description) do
    "#{muted("[#{current}/#{total}]")} #{description}"
  end

  # ============================================================================
  # Box Drawing (for consistent ASCII art)
  # ============================================================================

  @doc "Box drawing characters for consistent styling"
  def box do
    %{
      top_left: "+",
      top_right: "+",
      bottom_left: "+",
      bottom_right: "+",
      horizontal: "-",
      vertical: "|",
      cross: "+",
      t_down: "+",
      t_up: "+",
      t_right: "+",
      t_left: "+"
    }
  end

  @doc """
  Draw a simple box around text.

  ## Examples

      draw_box("Hello World", width: 20)
  """
  def draw_box(text, opts \\ []) do
    width = Keyword.get(opts, :width, String.length(text) + 4)
    border_color = Keyword.get(opts, :border_color, &muted/1)
    b = box()

    top =
      border_color.(
        b.top_left <> String.duplicate(b.horizontal, width - 2) <> b.top_right
      )

    bottom =
      border_color.(
        b.bottom_left <>
          String.duplicate(b.horizontal, width - 2) <> b.bottom_right
      )

    padding = width - 4 - String.length(text)
    left_pad = div(padding, 2)
    right_pad = padding - left_pad

    middle =
      border_color.(b.vertical) <>
        String.duplicate(" ", left_pad + 1) <>
        text <>
        String.duplicate(" ", right_pad + 1) <>
        border_color.(b.vertical)

    """
    #{top}
    #{middle}
    #{bottom}
    """
    |> String.trim_trailing()
  end
end
