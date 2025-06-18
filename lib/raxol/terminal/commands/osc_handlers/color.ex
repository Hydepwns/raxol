defmodule Raxol.Terminal.Commands.OSCHandlers.Color do
  @moduledoc """
  Handles color-related OSC commands.

  This handler manages terminal colors, including:
  - Foreground color
  - Background color
  - Cursor color
  - Selection colors

  ## Supported Commands

  - OSC 10: Set/Query foreground color
  - OSC 11: Set/Query background color
  - OSC 12: Set/Query cursor color
  - OSC 17: Set/Query selection background color
  - OSC 19: Set/Query selection foreground color
  """

  alias Raxol.Terminal.{Emulator, Colors, Commands.OSCHandlers.ColorParser}
  require Raxol.Core.Runtime.Log

  @doc """
  Handles OSC 10 command to set/query foreground color.
  """
  @spec handle_10(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_10(emulator, data) do
    case data do
      "?" -> handle_color_query(emulator, 10, &Colors.get_foreground/1)
      color_spec -> set_color(emulator, color_spec, &Colors.set_foreground/2)
    end
  end

  @doc """
  Handles OSC 11 command to set/query background color.
  """
  @spec handle_11(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_11(emulator, data) do
    case data do
      ~c"?" -> handle_color_query(emulator, 11, &Colors.get_background/1)
      color_spec -> set_color(emulator, color_spec, &Colors.set_background/2)
    end
  end

  @doc """
  Handles OSC 12 command to set/query cursor color.
  """
  @spec handle_12(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_12(emulator, data) do
    case data do
      ~c"?" -> handle_color_query(emulator, 12, &Colors.get_cursor_color/1)
      color_spec -> set_color(emulator, color_spec, &Colors.set_cursor_color/2)
    end
  end

  @doc """
  Handles OSC 17 command to set/query selection background color.
  """
  @spec handle_17(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_17(emulator, data) do
    case data do
      ~c"?" ->
        handle_color_query(emulator, 17, &Colors.get_selection_background/1)

      color_spec ->
        set_color(emulator, color_spec, &Colors.set_selection_background/2)
    end
  end

  @doc """
  Handles OSC 19 command to set/query selection foreground color.
  """
  @spec handle_19(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_19(emulator, data) do
    case data do
      ~c"?" ->
        handle_color_query(emulator, 19, &Colors.get_selection_foreground/1)

      color_spec ->
        set_color(emulator, color_spec, &Colors.set_selection_foreground/2)
    end
  end

  @doc """
  Handles OSC 110 command to reset foreground color.
  """
  @spec handle_110(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_110(emulator, _data) do
    {:ok, new_colors} = Colors.reset_foreground(emulator.colors)
    {:ok, %{emulator | colors: new_colors}}
  end

  @doc """
  Handles OSC 111 command to reset background color.
  """
  @spec handle_111(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_111(emulator, _data) do
    {:ok, new_colors} = Colors.reset_background(emulator.colors)
    {:ok, %{emulator | colors: new_colors}}
  end

  @doc """
  Handles OSC 112 command to reset cursor color.
  """
  @spec handle_112(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_112(emulator, _data) do
    {:ok, new_colors} = Colors.reset_cursor_color(emulator.colors)
    {:ok, %{emulator | colors: new_colors}}
  end

  @doc """
  Handles OSC 117 command to reset selection background color.
  """
  @spec handle_117(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_117(emulator, _data) do
    {:ok, new_colors} = Colors.reset_selection_background(emulator.colors)
    {:ok, %{emulator | colors: new_colors}}
  end

  @doc """
  Handles OSC 119 command to reset selection foreground color.
  """
  @spec handle_119(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_119(emulator, _data) do
    {:ok, new_colors} = Colors.reset_selection_foreground(emulator.colors)
    {:ok, %{emulator | colors: new_colors}}
  end

  # Private Helpers

  defp handle_color_query(emulator, command, getter_fn) do
    color = getter_fn.(emulator.colors)
    response = format_color_response(command, color)
    {:ok, %{emulator | output_buffer: response}}
  end

  defp set_color(emulator, color_spec, setter_fn) do
    with {:ok, color} <- ColorParser.parse(color_spec) do
      new_colors = setter_fn.(emulator.colors, color)
      {:ok, %{emulator | colors: new_colors}}
    else
      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Failed to set color: #{inspect(reason)}"
        )

        {:error, reason, emulator}
    end
  end

  defp format_color_response(command, color) do
    # Format: OSC command;rgb:r/g/b
    # Scale up to 16-bit range (0-65535)
    {r, g, b} = parse_hex_color(color)

    r_scaled =
      Integer.to_string(div(r * 65_535, 255), 16) |> String.pad_leading(4, "0")

    g_scaled =
      Integer.to_string(div(g * 65_535, 255), 16) |> String.pad_leading(4, "0")

    b_scaled =
      Integer.to_string(div(b * 65_535, 255), 16) |> String.pad_leading(4, "0")

    "\x1b]#{command};rgb:#{r_scaled}/#{g_scaled}/#{b_scaled}\x07"
  end

  defp parse_hex_color("#" <> hex) do
    {r, hex} = String.split_at(hex, 2)
    {g, b} = String.split_at(hex, 2)

    {String.to_integer(r, 16), String.to_integer(g, 16),
     String.to_integer(b, 16)}
  end
end
