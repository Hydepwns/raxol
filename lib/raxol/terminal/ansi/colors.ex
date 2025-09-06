defmodule Raxol.Terminal.ANSI.Colors do
  @moduledoc """
  Provides ANSI color functionality for terminal output.
  Handles color parsing, setting, and management for terminal text.
  """

  @type color ::
          :black | :red | :green | :yellow | :blue | :magenta | :cyan | :white
  @type color_mode :: :normal | :bright | :dim
  @type rgb :: {0..255, 0..255, 0..255}

  @doc """
  Parses a color specification into a standardized format.
  Accepts named colors, RGB values, and ANSI color codes.
  """
  def parse_color(color) when is_atom(color) do
    case color do
      :black -> {:ok, 0}
      :red -> {:ok, 1}
      :green -> {:ok, 2}
      :yellow -> {:ok, 3}
      :blue -> {:ok, 4}
      :magenta -> {:ok, 5}
      :cyan -> {:ok, 6}
      :white -> {:ok, 7}
      _ -> {:error, :invalid_color}
    end
  end

  def parse_color({r, g, b})
      when is_integer(r) and is_integer(g) and is_integer(b) do
    case {r in 0..255, g in 0..255, b in 0..255} do
      {true, true, true} -> {:ok, {r, g, b}}
      _ -> {:error, :invalid_rgb}
    end
  end

  def parse_color(_), do: {:error, :invalid_color_format}

  @doc """
  Sets a color for the given type (foreground/background) and mode.
  """
  def set_color(type, color, mode \\ :normal) do
    with {:ok, parsed_color} <- parse_color(color) do
      case {type, mode} do
        {:foreground, :normal} -> {:ok, "\e[3#{parsed_color}m"}
        {:foreground, :bright} -> {:ok, "\e[9#{parsed_color}m"}
        {:foreground, :dim} -> {:ok, "\e[2;3#{parsed_color}m"}
        {:background, :normal} -> {:ok, "\e[4#{parsed_color}m"}
        {:background, :bright} -> {:ok, "\e[10#{parsed_color}m"}
        {:background, :dim} -> {:ok, "\e[2;4#{parsed_color}m"}
        _ -> {:error, :invalid_type_or_mode}
      end
    end
  end

  @doc """
  Sets the foreground color.
  """
  def set_foreground(color, mode \\ :normal) do
    set_color(:foreground, color, mode)
  end

  @doc """
  Sets the background color.
  """
  def set_background(color, mode \\ :normal) do
    set_color(:background, color, mode)
  end

  @doc """
  Sets the cursor color.
  """
  def set_cursor_color(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]12;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]12;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]12;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the mouse foreground color.
  """
  def set_mouse_foreground(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]13;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]13;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]13;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the mouse background color.
  """
  def set_mouse_background(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]14;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]14;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]14;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the highlight foreground color.
  """
  def set_highlight_foreground(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]19;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]19;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]19;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the highlight background color.
  """
  def set_highlight_background(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]20;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]20;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]20;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the highlight cursor color.
  """
  def set_highlight_cursor(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]21;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]21;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]21;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the highlight mouse foreground color.
  """
  def set_highlight_mouse_foreground(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]22;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]22;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]22;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end

  @doc """
  Sets the highlight mouse background color.
  """
  def set_highlight_mouse_background(color, mode \\ :normal) do
    with {:ok, {r, g, b}} <- parse_color(color) do
      case mode do
        :normal ->
          {:ok, "\e]23;rgb:#{r}/#{g}/#{b}\e\\"}

        :bright ->
          {:ok,
           "\e]23;rgb:#{min(r + 40, 255)}/#{min(g + 40, 255)}/#{min(b + 40, 255)}\e\\"}

        :dim ->
          {:ok,
           "\e]23;rgb:#{max(r - 40, 0)}/#{max(g - 40, 0)}/#{max(b - 40, 0)}\e\\"}

        _ ->
          {:error, :invalid_mode}
      end
    end
  end
end
