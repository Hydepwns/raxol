defmodule Raxol.Terminal.Commands.OSCHandlers do
  @moduledoc false

  alias Raxol.Terminal.{Emulator, Commands.OSCHandlers}
  require Raxol.Core.Runtime.Log

  @spec handle(Emulator.t(), non_neg_integer(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle(emulator, command, data) do
    case get_command_group(command) do
      {:window, cmd} ->
        handle_window_ops(emulator, cmd, data)

      {:clipboard, cmd} ->
        handle_clipboard_ops(emulator, cmd, data)

      {:color, cmd} ->
        handle_color_ops(emulator, cmd, data)

      {:cursor, cmd} ->
        handle_cursor_ops(emulator, cmd, data)

      {:standalone, cmd} ->
        handle_standalone_ops(emulator, cmd, data)

      :unsupported ->
        Raxol.Core.Runtime.Log.warning("Unsupported OSC command: #{command}")
        {:error, :unsupported_command, emulator}
    end
  end

  defp get_command_group(command) do
    cond do
      command in [0, 1, 2, 7, 8, 1337] -> {:window, command}
      command in [9, 52] -> {:clipboard, command}
      command in [10, 11, 17, 19] -> {:color, command}
      command in [12, 50, 112] -> {:cursor, command}
      command in [4, 51] -> {:standalone, command}
      true -> :unsupported
    end
  end

  defp handle_standalone_ops(emulator, command, data) do
    case command do
      4 -> OSCHandlers.ColorPalette.handle_4(emulator, data)
      51 -> OSCHandlers.Selection.handle_51(emulator, data)
    end
  end

  defp handle_window_ops(emulator, command, data) do
    case command do
      0 -> OSCHandlers.Window.handle_0(emulator, data)
      1 -> OSCHandlers.Window.handle_1(emulator, data)
      2 -> OSCHandlers.Window.handle_2(emulator, data)
      7 -> OSCHandlers.Window.handle_7(emulator, data)
      8 -> OSCHandlers.Window.handle_8(emulator, data)
      1337 -> OSCHandlers.Window.handle_1337(emulator, data)
    end
  end

  defp handle_clipboard_ops(emulator, command, data) do
    case command do
      9 -> OSCHandlers.Clipboard.handle_9(emulator, data)
      52 -> OSCHandlers.Clipboard.handle_52(emulator, data)
    end
  end

  defp handle_color_ops(emulator, command, data) do
    case command do
      10 -> OSCHandlers.Color.handle_10(emulator, data)
      11 -> OSCHandlers.Color.handle_11(emulator, data)
      17 -> OSCHandlers.Color.handle_17(emulator, data)
      19 -> OSCHandlers.Color.handle_19(emulator, data)
    end
  end

  defp handle_cursor_ops(emulator, command, data) do
    case command do
      12 -> OSCHandlers.Cursor.handle_12(emulator, data)
      50 -> OSCHandlers.Cursor.handle_50(emulator, data)
      112 -> OSCHandlers.Cursor.handle_112(emulator, data)
    end
  end

  def handle_window_title(emulator, data), do: {:ok, %{emulator | window_title: data}}
  def handle_icon_name(emulator, _data), do: {:ok, emulator}
  def handle_icon_title(emulator, _data), do: {:ok, emulator}
  def handle_foreground_color(emulator, _data), do: {:ok, emulator}
  def handle_background_color(emulator, _data), do: {:ok, emulator}
  def handle_highlight_background_color(emulator, _data), do: {:ok, emulator}
  def handle_mouse_foreground_color(emulator, _data), do: {:ok, emulator}
  def handle_font(emulator, _data), do: {:ok, emulator}
  def handle_clipboard_set(emulator, _data), do: {:ok, emulator}
  def handle_osc4_color(emulator, _idx, _color), do: {:ok, emulator}

  def handle_4(emulator, _data), do: {:ok, emulator}
  def handle_clipboard_get(emulator), do: {:ok, emulator}
  def handle_cursor_color(emulator, _data), do: {:ok, emulator}
  def handle_cursor_shape(emulator, _data), do: {:ok, emulator}
  def handle_highlight_foreground_color(emulator, _data), do: {:ok, emulator}
  def handle_mouse_background_color(emulator, _data), do: {:ok, emulator}

  def handle_window_fullscreen(emulator) do
    # Update window state to fullscreen
    Raxol.Terminal.Window.Manager.set_window_state(
      emulator.window_manager,
      :fullscreen
    )

    {:ok, emulator}
  end

  def handle_window_maximize(emulator) do
    # Update window state to maximized
    Raxol.Terminal.Window.Manager.set_window_state(
      emulator.window_manager,
      :maximized
    )

    {:ok, emulator}
  end

  def handle_window_size(emulator, width, height) do
    # Update window size
    Raxol.Terminal.Window.Manager.set_window_size(
      emulator.window_manager,
      width,
      height
    )

    {:ok, emulator}
  end

  @doc """
  Handles an OSC sequence with command and data.
  """
  @spec handle_osc_sequence(Emulator.t(), atom(), String.t()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_osc_sequence(emulator, command, data) do
    case command do
      :window_title ->
        handle_window_title(emulator, data)

      :icon_name ->
        handle_icon_name(emulator, data)

      :icon_title ->
        handle_icon_title(emulator, data)

      :foreground_color ->
        handle_foreground_color(emulator, data)

      :background_color ->
        handle_background_color(emulator, data)

      :highlight_background_color ->
        handle_highlight_background_color(emulator, data)

      :mouse_foreground_color ->
        handle_mouse_foreground_color(emulator, data)

      :font ->
        handle_font(emulator, data)

      :clipboard_set ->
        handle_clipboard_set(emulator, data)

      :cursor_color ->
        handle_cursor_color(emulator, data)

      :cursor_shape ->
        handle_cursor_shape(emulator, data)

      :highlight_foreground_color ->
        handle_highlight_foreground_color(emulator, data)

      :mouse_background_color ->
        handle_mouse_background_color(emulator, data)

      _ ->
        {:ok, emulator}
    end
  end
end
