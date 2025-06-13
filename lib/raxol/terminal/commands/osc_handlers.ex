defmodule Raxol.Terminal.Commands.OSCHandlers do
  @moduledoc """
  Handles OSC (Operating System Command) sequences for the terminal.
  These are sequences that start with ESC] and are used for window manipulation,
  color settings, and other system-level functions.
  """

  alias Raxol.Terminal.{Emulator, ModeManager, Window}
  alias Raxol.Terminal.ANSI.{TextFormatting, Colors}
  require Raxol.Core.Runtime.Log

  @doc """
  Handles an OSC sequence by dispatching to the appropriate handler based on the command.
  """
  @spec handle_osc_sequence(Emulator.t(), String.t(), String.t()) :: Emulator.t()
  def handle_osc_sequence(emulator, command, data) do
    case command do
      # Window Title
      "0" -> handle_window_title(emulator, data)
      "1" -> handle_icon_name(emulator, data)
      "2" -> handle_window_title(emulator, data)

      # Color Settings
      "4" -> handle_color_setting(emulator, data)
      "10" -> handle_foreground_color(emulator, data)
      "11" -> handle_background_color(emulator, data)
      "12" -> handle_cursor_color(emulator, data)
      "13" -> handle_mouse_foreground_color(emulator, data)
      "14" -> handle_mouse_background_color(emulator, data)
      "15" -> handle_highlight_foreground_color(emulator, data)
      "16" -> handle_highlight_background_color(emulator, data)
      "17" -> handle_highlight_cursor_color(emulator, data)
      "18" -> handle_highlight_mouse_foreground_color(emulator, data)
      "19" -> handle_highlight_mouse_background_color(emulator, data)

      # Font Settings
      "50" -> handle_font(emulator, data)

      # Clipboard
      "52" -> handle_clipboard(emulator, data)

      # Cursor Shape
      "1337" -> handle_cursor_shape(emulator, data)

      # Unknown command
      _ ->
        Raxol.Core.Runtime.Log.debug("Unhandled OSC command: #{command} with data: #{inspect(data)}")
        emulator
    end
  end

  # Window Title Handlers

  defp handle_window_title(emulator, title) do
    Window.set_title(emulator.window, title)
    emulator
  end

  defp handle_icon_name(emulator, name) do
    Window.set_icon_name(emulator.window, name)
    emulator
  end

  # Color Setting Handlers

  defp handle_color_setting(emulator, data) do
    case String.split(data, ";") do
      [index, value] ->
        handle_osc4_color(emulator, String.to_integer(index), value)
      _ ->
        Raxol.Core.Runtime.Log.warning("Invalid color setting format: #{data}")
        emulator
    end
  end

  defp handle_osc4_color(emulator, index, value) when index >= 0 and index <= 255 do
    color = Colors.parse_color(value)
    Colors.set_color(emulator.colors, index, color)
    emulator
  end

  defp handle_osc4_color(emulator, _index, _value) do
    Raxol.Core.Runtime.Log.warning("Invalid color index: #{_index}")
    emulator
  end

  defp handle_foreground_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_foreground(emulator.colors, color)
    emulator
  end

  defp handle_background_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_background(emulator.colors, color)
    emulator
  end

  defp handle_cursor_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_cursor_color(emulator.colors, color)
    emulator
  end

  defp handle_mouse_foreground_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_mouse_foreground(emulator.colors, color)
    emulator
  end

  defp handle_mouse_background_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_mouse_background(emulator.colors, color)
    emulator
  end

  defp handle_highlight_foreground_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_highlight_foreground(emulator.colors, color)
    emulator
  end

  defp handle_highlight_background_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_highlight_background(emulator.colors, color)
    emulator
  end

  defp handle_highlight_cursor_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_highlight_cursor(emulator.colors, color)
    emulator
  end

  defp handle_highlight_mouse_foreground_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_highlight_mouse_foreground(emulator.colors, color)
    emulator
  end

  defp handle_highlight_mouse_background_color(emulator, color) do
    color = Colors.parse_color(color)
    Colors.set_highlight_mouse_background(emulator.colors, color)
    emulator
  end

  # Font Handler

  defp handle_font(emulator, font) do
    Window.set_font(emulator.window, font)
    emulator
  end

  # Clipboard Handler

  defp handle_clipboard(emulator, data) do
    case String.split(data, ";") do
      ["c", base64_data] -> handle_clipboard_set(emulator, base64_data)
      ["p", base64_data] -> handle_clipboard_get(emulator, base64_data)
      _ ->
        Raxol.Core.Runtime.Log.warning("Invalid clipboard operation: #{data}")
        emulator
    end
  end

  defp handle_clipboard_set(emulator, base64_data) do
    case Base.decode64(base64_data) do
      {:ok, content} ->
        Window.set_clipboard(emulator.window, content)
        emulator
      :error ->
        Raxol.Core.Runtime.Log.warning("Invalid base64 clipboard data")
        emulator
    end
  end

  defp handle_clipboard_get(emulator, _base64_data) do
    content = Window.get_clipboard(emulator.window)
    base64 = Base.encode64(content)
    Emulator.write(emulator, "\e]52;c;#{base64}\a")
    emulator
  end

  # Cursor Shape Handler

  defp handle_cursor_shape(emulator, shape) do
    Window.set_cursor_shape(emulator.window, shape)
    emulator
  end

  @doc "Handles Set Window Title (0 or 2)"
  def handle_0_or_2(emulator, title) do
    {:ok, %{emulator | window_title: title}}
  end

  @doc "Handles Set Icon Name (1)"
  def handle_1(emulator, name) do
    {:ok, %{emulator | icon_name: name}}
  end

  @doc "Handles Set Window Title (2)"
  def handle_2(emulator, title) do
    {:ok, %{emulator | window_title: title}}
  end

  @doc "Handles Set Color (4)"
  def handle_4(emulator, color_spec) do
    case parse_color_spec(color_spec) do
      {:ok, index, color} ->
        {:ok, update_color(emulator, index, color)}
      :error ->
        {:error, :invalid_color_spec, emulator}
    end
  end

  @doc "Handles Set Cursor Style (7)"
  def handle_7(emulator, style) do
    case style do
      "block" -> {:ok, %{emulator | cursor_style: :block}}
      "underline" -> {:ok, %{emulator | cursor_style: :underline}}
      "bar" -> {:ok, %{emulator | cursor_style: :bar}}
      _ -> {:ok, emulator}
    end
  end

  @doc "Handles Set Hyperlink (8)"
  def handle_8(emulator, hyperlink) do
    case hyperlink do
      "" -> {:ok, %{emulator | current_hyperlink: nil}}
      url -> {:ok, %{emulator | current_hyperlink: url}}
    end
  end

  @doc "Handles Set Clipboard (52)"
  def handle_52(emulator, clipboard_data) do
    case clipboard_data do
      "c;" <> data ->
        # Handle clipboard data
        {:ok, %{emulator | clipboard: data}}
      _ ->
        {:ok, emulator}
    end
  end

  # Helper function to parse color specification
  defp parse_color_spec(spec) do
    case String.split(spec, ";") do
      [index, color] ->
        case Integer.parse(index) do
          {index, _} when index in 0..255 ->
            {:ok, index, color}
          _ ->
            :error
        end
      _ ->
        :error
    end
  end

  # Helper function to update color in emulator
  defp update_color(emulator, index, color) do
    colors = emulator.colors || %{}
    colors = Map.put(colors, index, color)
    %{emulator | colors: colors}
  end
end
