defmodule Raxol.Terminal.Commands.OSCHandlers.Cursor do
  @moduledoc """
  Handles cursor and font-related OSC commands.

  This handler manages cursor properties and font settings, including:
  - Cursor color
  - Cursor style
  - Cursor blink state
  - Font family and size

  ## Supported Commands

  - OSC 12: Set/Query cursor color
  - OSC 50: Set/Query font
  - OSC 112: Reset cursor color
  """

  alias Raxol.Terminal.{Emulator, Cursor, Font}
  alias Raxol.Terminal.Commands.OSCHandlers.{ColorParser, FontParser}
  require Raxol.Core.Runtime.Log

  @doc """
  Handles OSC 12 command to set/query cursor color.
  """
  @spec handle_12(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_12(emulator, data) do
    case data do
      "?" -> handle_color_query(emulator, 12, &Cursor.get_color/1)
      color_spec -> set_color(emulator, color_spec, &Cursor.set_color/2)
    end
  end

  @doc """
  Handles OSC 50 command to set/query font.

  ## Command Format

  - 50;? - Query current font
  - 50;family - Set font family
  - 50;family;size - Set font family and size
  - 50;family;size;style - Set font family, size, and style

  Where:
  - family: Font family name
  - size: Font size in points
  - style: Font style (normal, bold, italic)
  """
  @spec handle_50(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_50(emulator, data) do
    case FontParser.parse(data) do
      {:query, _} ->
        handle_font_query(emulator)

      {:set, family, size, style} ->
        handle_font_set(emulator, family, size, style)

      {:error, reason} ->
        handle_font_error(emulator, reason, data)
    end
  end

  @doc """
  Handles OSC 112 command to reset cursor color.
  """
  @spec handle_112(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_112(emulator, _data) do
    case Cursor.reset_color(emulator.cursor) do
      {:ok, new_cursor} ->
        {:ok, %{emulator | cursor: new_cursor}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Failed to reset cursor color: #{inspect(reason)}"
        )

        {:error, reason, emulator}
    end
  end

  # Private Helpers

  defp handle_color_query(emulator, command, getter_fn) do
    case getter_fn.(emulator.cursor) do
      {:ok, color} ->
        response = format_color_response(command, color)
        {:ok, %{emulator | output_buffer: response}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Failed to get color: #{inspect(reason)}"
        )

        {:error, reason, emulator}
    end
  end

  defp set_color(emulator, color_spec, setter_fn) do
    with {:ok, color} <- ColorParser.parse(color_spec),
         {:ok, new_cursor} <- setter_fn.(emulator.cursor, color) do
      {:ok, %{emulator | cursor: new_cursor}}
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Failed to set color: #{inspect(reason)}"
        )

        {:error, reason, emulator}
    end
  end

  defp handle_font_query(emulator) do
    case Font.get_current(emulator.font) do
      {:ok, font} ->
        response = format_font_response(font)
        {:ok, %{emulator | output_buffer: response}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning("Failed to get font: #{inspect(reason)}")
        {:error, reason, emulator}
    end
  end

  defp handle_font_set(emulator, family, size, style) do
    case Font.set(emulator.font, family, size, style) do
      {:ok, new_font} ->
        {:ok, %{emulator | font: new_font}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning("Failed to set font: #{inspect(reason)}")
        {:error, reason, emulator}
    end
  end

  defp handle_font_error(emulator, reason, data) do
    Raxol.Core.Runtime.Log.warning("Invalid font command: #{inspect(data)}")
    {:error, reason, emulator}
  end

  defp format_color_response(command, {r, g, b}) do
    # Format: OSC command;rgb:r/g/b
    # Scale up to 16-bit range (0-65535)
    r_scaled =
      Integer.to_string(div(r * 65_535, 255), 16) |> String.pad_leading(4, "0")

    g_scaled =
      Integer.to_string(div(g * 65_535, 255), 16) |> String.pad_leading(4, "0")

    b_scaled =
      Integer.to_string(div(b * 65_535, 255), 16) |> String.pad_leading(4, "0")

    "\e]#{command};rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}\e\\"
  end

  defp format_font_response(font) do
    # Format: OSC 50;family;size;style
    family = font.family || ""
    size = if font.size, do: Integer.to_string(font.size), else: ""
    style = font.style || ""

    parts = [family, size, style] |> Enum.reject(&(&1 == ""))
    "\e]50;#{Enum.join(parts, ";")}\e\\"
  end
end
