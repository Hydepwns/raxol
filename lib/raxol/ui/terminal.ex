defmodule Raxol.UI.Terminal do
  @moduledoc '''
  A terminal UI rendering module for Raxol.

  This module provides basic terminal rendering capabilities for Raxol applications,
  with support for accessibility features, internationalization, and color system
  integration.

  ## Features

  - Terminal screen management (clearing, cursor positioning)
  - Text rendering with colors and styles
  - Input handling with support for keyboard shortcuts
  - Basic UI elements (boxes, lines, progress bars)
  - RTL rendering support
  - Accessibility-friendly output formatting
  '''

  alias Raxol.Style.Colors.System, as: ColorSystem
  alias Raxol.Core.I18n

  @spec clear() :: :ok
  @doc '''
  Clear the terminal screen.

  ## Examples

      iex> Terminal.clear()
      :ok
  '''
  def clear do
    IO.write("\e[2J\e[H")
    :ok
  end

  @spec move_cursor(integer(), integer()) :: :ok
  @doc '''
  Move the cursor to a specific position.

  ## Parameters

  * `row` - The row (1-indexed)
  * `col` - The column (1-indexed)

  ## Examples

      iex> Terminal.move_cursor(1, 1)
      :ok
  '''
  def move_cursor(row, col) do
    IO.write("\e[#{row};#{col}H")
    :ok
  end

  @spec print(String.t(), keyword()) :: :ok
  @doc '''
  Print text with optional styling.

  ## Options

  * `:color` - The text color (hex string or color name)
  * `:background` - The background color (hex string or color name)
  * `:bold` - Whether to display the text in bold (default: false)
  * `:italic` - Whether to display the text in italic (default: false)
  * `:underline` - Whether to underline the text (default: false)
  * `:dim` - Whether to display the text dimmed (default: false)
  * `:blink` - Whether to make the text blink (default: false)
  * `:rtl` - Whether to render the text right-to-left (default: from I18n)

  ## Examples

      iex> Terminal.print("Hello", color: "#FF0000", bold: true)
      :ok
  '''
  def print(text, opts \\ []) do
    # Get RTL setting
    rtl = Keyword.get(opts, :rtl) || I18n.rtl?()

    # Format text for RTL if needed
    formatted_text =
      if rtl do
        # Basic RTL formatting - in a real implementation this would be more sophisticated
        String.reverse(text)
      else
        text
      end

    # Apply styles
    styled_text = apply_styles(formatted_text, opts)

    # Print the styled text
    IO.write(styled_text)
    :ok
  end

  @spec println(String.t(), keyword()) :: :ok
  @doc '''
  Print text followed by a newline.

  Takes the same options as `print/2`.

  ## Examples

      iex> Terminal.println("Hello", color: "#FF0000", bold: true)
      :ok
  '''
  def println(text \\ "", opts \\ []) do
    print(text, opts)
    IO.write("\n")
    :ok
  end

  @spec print_centered(String.t(), keyword()) :: :ok
  @doc '''
  Print centered text.

  ## Options

  Takes the same options as `print/2`.

  ## Examples

      iex> Terminal.print_centered("Title", color: "#FF0000", bold: true)
      :ok
  '''
  def print_centered(text, opts \\ []) do
    # Get terminal width
    width = get_terminal_size().width

    # Calculate padding
    padding = max(0, div(width - String.length(text), 2))

    # Print with padding
    print(String.duplicate(" ", padding) <> text, opts)
    :ok
  end

  @spec print_horizontal_line(keyword()) :: :ok
  @doc '''
  Print a horizontal line spanning the terminal width.

  ## Options

  * `:char` - The character to use for the line (default: "─")
  * Other options are passed to `print/2`

  ## Examples

      iex> Terminal.print_horizontal_line(char: "-", color: "#CCCCCC")
      :ok
  '''
  def print_horizontal_line(opts \\ []) do
    # Get terminal width
    width = get_terminal_size().width

    # Get line character
    char = Keyword.get(opts, :char, "─")

    # Print the line
    print(String.duplicate(char, width), opts)
    :ok
  end

  @spec read_key(keyword()) :: {:ok, term()} | :timeout | {:error, term()}
  @doc '''
  Read a keypress from the user.

  ## Options

  * `:timeout` - Timeout in milliseconds (default: :infinity)

  ## Returns

  * `{:ok, key}` - Where key is the key pressed
  * `:timeout` - If no key was pressed within the timeout
  * `{:error, reason}` - If an error occurred

  ## Examples

      iex> Terminal.read_key()
      {:ok, :enter}

      iex> Terminal.read_key(timeout: 1000)
      :timeout
  '''
  def read_key(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, :infinity)
    original_opts = :io.getopts()

    _ = :io.setopts([{:binary, true}, {:echo, false}, {:raw, true}])

    result =
      receive do
        {:io_request, from, reply_as, {:get_chars, _, _, 1}} ->
          # Ideally, we'd read just one char, but :io interacts strangely.
          # Instead, we read what's available immediately.
          chars = :io.get_chars("", 1)
          send(from, {:io_reply, reply_as, chars})

          case chars do
            :eof -> {:error, :eof}
            {:error, reason} -> {:error, reason}
            data when is_binary(data) -> {:ok, parse_key(data)}
            _ -> {:error, :unknown_reply}
          end

        {:io_request, from, reply_as, req} ->
          # Forward other IO requests
          reply = :io.request(req)
          send(from, {:io_reply, reply_as, reply})
          # Re-enter receive to wait for our char or timeout
          read_key(opts)
      after
        timeout -> :timeout
      end

    _ = :io.setopts(original_opts)
    result
  end

  @spec print_box(String.t(), keyword()) :: :ok
  @doc '''
  Print a box with content.

  ## Parameters

  * `content` - The text content to display inside the box
  * `opts` - Styling options

  ## Options

  * `:width` - Box width (default: content width + 4)
  * `:height` - Box height (default: content lines + 2)
  * `:border_color` - Color for the border
  * `:title` - Optional title for the box
  * `:title_color` - Color for the title
  * `:centered` - Whether to center the box horizontally (default: false)

  ## Examples

      iex> Terminal.print_box("Hello\nWorld", title: "Greeting", border_color: "#0000FF")
      :ok
  '''
  def print_box(content, opts \\ []) do
    # Parse content into lines
    lines = String.split(content, "\n")

    # Calculate dimensions
    content_width = Enum.max_by(lines, &String.length/1) |> String.length()
    content_height = length(lines)

    width = Keyword.get(opts, :width, content_width + 4)
    _height = Keyword.get(opts, :height, content_height + 2)

    # Get title
    title = Keyword.get(opts, :title)

    # Get colors
    border_color = Keyword.get(opts, :border_color)
    title_color = Keyword.get(opts, :title_color, border_color)

    # Get centering option
    centered = Keyword.get(opts, :centered, false)

    # Print top border
    border_top = "┌" <> String.duplicate("─", width - 2) <> "┐"

    if centered do
      print_centered(border_top, color: border_color)
      println()
    else
      println(border_top, color: border_color)
    end

    # Print title if provided
    if title do
      title_line = "│ " <> String.pad_trailing(title, width - 4) <> " │"

      if centered do
        print_centered(title_line, color: title_color)
        println()

        # Print separator
        separator = "├" <> String.duplicate("─", width - 2) <> "┤"
        print_centered(separator, color: border_color)
        println()
      else
        println(title_line, color: title_color)

        println("├" <> String.duplicate("─", width - 2) <> "┤",
          color: border_color
        )
      end
    end

    # Print content
    # Prefixed with underscore to avoid unused variable warning
    _content_padding = div(width - 2 - content_width, 2)

    Enum.each(lines, fn line ->
      line_str = "│ " <> String.pad_trailing(line, width - 4) <> " │"

      if centered do
        print_centered(line_str, color: border_color)
        println()
      else
        println(line_str, color: border_color)
      end
    end)

    # Print bottom border
    border_bottom = "└" <> String.duplicate("─", width - 2) <> "┘"

    if centered do
      print_centered(border_bottom, color: border_color)
      println()
    else
      println(border_bottom, color: border_color)
    end

    :ok
  end

  # Private functions

  defp apply_styles(text, opts) do
    # Start with an empty list of style codes
    style_codes = []

    # Add color codes if provided
    style_codes =
      case Keyword.get(opts, :color) do
        nil ->
          style_codes

        color when is_atom(color) ->
          # Resolve color from ColorSystem if it's an atom
          hex = ColorSystem.get_color(color)
          [fg_color_code(hex) | style_codes]

        hex ->
          # Use the hex color directly
          [fg_color_code(hex) | style_codes]
      end

    # Add background color codes if provided
    style_codes =
      case Keyword.get(opts, :background) do
        nil ->
          style_codes

        color when is_atom(color) ->
          # Resolve color from ColorSystem if it's an atom
          hex = ColorSystem.get_color(color)
          [bg_color_code(hex) | style_codes]

        hex ->
          # Use the hex color directly
          [bg_color_code(hex) | style_codes]
      end

    # Add other style codes
    style_codes =
      if Keyword.get(opts, :bold, false),
        do: ["1" | style_codes],
        else: style_codes

    style_codes =
      if Keyword.get(opts, :italic, false),
        do: ["3" | style_codes],
        else: style_codes

    style_codes =
      if Keyword.get(opts, :underline, false),
        do: ["4" | style_codes],
        else: style_codes

    style_codes =
      if Keyword.get(opts, :dim, false),
        do: ["2" | style_codes],
        else: style_codes

    style_codes =
      if Keyword.get(opts, :blink, false),
        do: ["5" | style_codes],
        else: style_codes

    # Format the text with style codes
    if Enum.empty?(style_codes) do
      text
    else
      # Join codes and wrap text
      codes = Enum.join(style_codes, ";")
      "\e[#{codes}m#{text}\e[0m"
    end
  end

  defp fg_color_code(hex) do
    {r, g, b} = hex_to_rgb(hex)
    "38;2;#{r};#{g};#{b}"
  end

  defp bg_color_code(hex) do
    {r, g, b} = hex_to_rgb(hex)
    "48;2;#{r};#{g};#{b}"
  end

  defp hex_to_rgb(hex) do
    hex = String.replace(hex, ~r/^#/, "")

    r = String.slice(hex, 0..1) |> String.to_integer(16)
    g = String.slice(hex, 2..3) |> String.to_integer(16)
    b = String.slice(hex, 4..5) |> String.to_integer(16)

    {r, g, b}
  end

  defp parse_key(data) do
    case data do
      # Control keys
      "\r" -> :enter
      "\n" -> :enter
      " " -> :space
      "\t" -> :tab
      "\e" -> :escape
      "\b" -> :backspace
      "\x7F" -> :backspace
      "\x03" -> :ctrl_c
      "\x04" -> :ctrl_d
      # Arrow keys
      "\e[A" -> {:arrow, :up}
      "\e[B" -> {:arrow, :down}
      "\e[C" -> {:arrow, :right}
      "\e[D" -> {:arrow, :left}
      # Function keys
      "\e[11~" -> :f1
      "\e[12~" -> :f2
      "\e[13~" -> :f3
      "\e[14~" -> :f4
      # Default - regular character
      <<char::utf8, _rest::binary>> -> {:char, <<char::utf8>>}
      _ -> {:unknown, data}
    end
  end

  defp get_terminal_size do
    case :io.columns() do
      {:ok, width} ->
        case :io.rows() do
          {:ok, height} -> %{width: width, height: height}
          # Default height
          _ -> %{width: 80, height: 24}
        end

      # Default size
      _ ->
        %{width: 80, height: 24}
    end
  end
end
