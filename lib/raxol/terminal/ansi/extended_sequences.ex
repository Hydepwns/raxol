defmodule Raxol.Terminal.ANSI.ExtendedSequences do
  @moduledoc """
  Handles extended ANSI sequences and provides improved integration with the screen buffer.
  Functional Programming Version - All try/catch blocks replaced with with statements.
  
  This module adds support for:
  - Extended SGR attributes (90-97, 100-107)
  - True color support (24-bit RGB)
  - Unicode handling
  - Terminal state management
  - Improved cursor control
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.{Monitor}

  # --- Types ---

  @type color :: {0..255, 0..255, 0..255} | 0..255
  @type attribute ::
          :bold
          | :faint
          | :italic
          | :underline
          | :blink
          | :rapid_blink
          | :inverse
          | :conceal
          | :strikethrough
          | :normal_intensity
          | :no_italic
          | :no_underline
          | :no_blink
          | :no_inverse
          | :no_conceal
          | :no_strikethrough
          | :foreground
          | :background
          | :foreground_basic
          | :background_basic

  # --- Public API ---

  @doc """
  Processes extended SGR (Select Graphic Rendition) parameters.
  Supports:
  - Extended colors (90-97, 100-107)
  - True color (24-bit RGB)
  - Additional attributes
  """
  @spec process_extended_sgr(list(String.t()), ScreenBuffer.t()) ::
          ScreenBuffer.t()
  def process_extended_sgr(params, buffer) do
    with {:ok, result} <- safe_process_sgr_params(params, buffer) do
      result
    else
      {:error, error} ->
        Monitor.record_error("", "Extended SGR error: #{inspect(error)}", %{
          params: params
        })
        buffer
    end
  end

  @doc """
  Processes true color sequences (24-bit RGB).
  """
  @spec process_true_color(String.t(), String.t(), ScreenBuffer.t()) ::
          ScreenBuffer.t()
  def process_true_color(type, color_str, buffer) do
    with {:ok, {r, g, b}} <- safe_parse_true_color(color_str),
         {:ok, style} <- build_color_style(type, {r, g, b}, buffer) do
      %{buffer | default_style: style}
    else
      {:error, error} ->
        Monitor.record_error("", "True color error: #{inspect(error)}", %{
          type: type,
          color: color_str
        })
        buffer
    end
  end

  @doc """
  Handles Unicode character sequences.
  """
  @spec process_unicode(String.t(), ScreenBuffer.t()) :: ScreenBuffer.t()
  def process_unicode(char, buffer) do
    with {:ok, processed_buffer} <- safe_process_unicode_char(char, buffer) do
      processed_buffer
    else
      {:error, error} ->
        Monitor.record_error("", "Unicode processing error: #{inspect(error)}", %{
          char: char
        })
        buffer
    end
  end

  @doc """
  Processes extended cursor control sequences.
  """
  @spec process_extended_cursor(String.t(), list(String.t()), ScreenBuffer.t()) ::
          ScreenBuffer.t()
  def process_extended_cursor(command, params, buffer) do
    with {:ok, processed_buffer} <- safe_process_cursor_command(command, params, buffer) do
      processed_buffer
    else
      {:error, error} ->
        Monitor.record_error("", "Extended cursor error: #{inspect(error)}", %{
          command: command,
          params: params
        })
        buffer
    end
  end

  # --- Private Helper Functions ---

  defp safe_process_sgr_params(params, buffer) do
    Task.async(fn ->
      Enum.reduce(params, buffer, &process_sgr_param/2)
    end)
    |> Task.yield(1000)
    |> case do
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, {:exit, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_parse_true_color(color_str) do
    Task.async(fn -> parse_true_color(color_str) end)
    |> Task.yield(500)
    |> case do
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, {:exit, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_process_unicode_char(char, buffer) do
    Task.async(fn ->
      # Validate Unicode character
      if String.valid?(char) do
        # Process the character based on its category
        case Unicode.category(char) do
          :control -> handle_control_character(char, buffer)
          :combining -> handle_combining_character(char, buffer)
          _ -> handle_printable_character(char, buffer)
        end
      else
        {:error, :invalid_unicode}
      end
    end)
    |> Task.yield(500)
    |> case do
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:exit, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_process_cursor_command(command, params, buffer) do
    Task.async(fn ->
      case command do
        "DECSCUSR" -> set_cursor_style(params, buffer)
        "DECSTR" -> soft_terminal_reset(buffer)
        "DECKPAM" -> set_keypad_application_mode(buffer)
        "DECKPNM" -> set_keypad_numeric_mode(buffer)
        _ -> {:error, {:unknown_command, command}}
      end
    end)
    |> Task.yield(500)
    |> case do
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:exit, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp build_color_style(type, {r, g, b}, buffer) do
    style =
      case type do
        "38" -> %{buffer.default_style | foreground: {r, g, b}}
        "48" -> %{buffer.default_style | background: {r, g, b}}
        _ -> buffer.default_style
      end

    {:ok, style}
  end

  # --- SGR Parameter Processing ---

  defp process_sgr_param(param_str, buffer) do
    case Integer.parse(param_str) do
      {param, ""} -> apply_sgr_attribute(param, buffer)
      _ -> buffer
    end
  end

  defp apply_sgr_attribute(param, buffer) when param >= 90 and param <= 97 do
    # Bright foreground colors
    color_index = param - 90 + 8
    style = %{buffer.default_style | foreground: color_index}
    %{buffer | default_style: style}
  end

  defp apply_sgr_attribute(param, buffer) when param >= 100 and param <= 107 do
    # Bright background colors
    color_index = param - 100 + 8
    style = %{buffer.default_style | background: color_index}
    %{buffer | default_style: style}
  end

  defp apply_sgr_attribute(_param, buffer), do: buffer

  # --- Color Parsing ---

  defp parse_true_color(color_str) do
    case String.split(color_str, ";") do
      [r_str, g_str, b_str] ->
        with {r, ""} <- Integer.parse(r_str),
             {g, ""} <- Integer.parse(g_str),
             {b, ""} <- Integer.parse(b_str),
             true <- r >= 0 and r <= 255,
             true <- g >= 0 and g <= 255,
             true <- b >= 0 and b <= 255 do
          {r, g, b}
        else
          _ -> {:error, :invalid_color_format}
        end

      _ ->
        {:error, :invalid_color_format}
    end
  end

  # --- Unicode Character Handling ---

  defp handle_control_character(_char, buffer) do
    # Control characters are typically handled elsewhere
    {:ok, buffer}
  end

  defp handle_combining_character(char, buffer) do
    # Combining characters modify the previous character
    # For now, we'll just ignore them
    {:ok, buffer}
  end

  defp handle_printable_character(char, buffer) do
    # Add the character to the current cursor position
    x = buffer.cursor_x
    y = buffer.cursor_y

    if x < buffer.width and y < buffer.height do
      new_buffer = ScreenBuffer.write_char(buffer, x, y, char, buffer.default_style)
      {:ok, %{new_buffer | cursor_x: x + 1}}
    else
      {:ok, buffer}
    end
  end

  # --- Extended Cursor Commands ---

  defp set_cursor_style(params, buffer) do
    style =
      case params do
        [] -> :default
        ["0"] -> :default
        ["1"] -> :blinking_block
        ["2"] -> :steady_block
        ["3"] -> :blinking_underline
        ["4"] -> :steady_underline
        ["5"] -> :blinking_bar
        ["6"] -> :steady_bar
        _ -> :default
      end

    {:ok, %{buffer | cursor_style: style}}
  end

  defp soft_terminal_reset(buffer) do
    # Reset terminal to initial state
    reset_buffer = %{
      buffer
      | cursor_x: 0,
        cursor_y: 0,
        default_style: ScreenBuffer.default_style(),
        insert_mode: false,
        auto_wrap_mode: true
    }

    {:ok, reset_buffer}
  end

  defp set_keypad_application_mode(buffer) do
    {:ok, %{buffer | keypad_mode: :application}}
  end

  defp set_keypad_numeric_mode(buffer) do
    {:ok, %{buffer | keypad_mode: :numeric}}
  end
end