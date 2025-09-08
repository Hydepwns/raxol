defmodule Raxol.Terminal.Commands.OSCHandler do
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
    command_groups = [
      {[0, 1, 2, 7, 8, 1337], :window},
      {[9, 52], :clipboard},
      {[10, 11, 17, 19], :color},
      {[12, 50, 112], :cursor},
      {[4, 51], :standalone}
    ]

    result =
      Enum.find_value(command_groups, fn {commands, group} ->
        case command in commands do
          true -> {group, command}
          false -> nil
        end
      end)

    result || :unsupported
  end

  defp handle_standalone_ops(emulator, command, data) do
    case command do
      4 -> OSCHandler.ColorPalette.handle_4(emulator, data)
      51 -> OSCHandler.Selection.handle_51(emulator, data)
    end
  end

  defp handle_window_ops(emulator, command, data) do
    case command do
      0 -> OSCHandler.Window.handle_0(emulator, data)
      1 -> OSCHandler.Window.handle_1(emulator, data)
      2 -> OSCHandler.Window.handle_2(emulator, data)
      7 -> OSCHandler.Window.handle_7(emulator, data)
      8 -> OSCHandler.Window.handle_8(emulator, data)
      1337 -> OSCHandler.Window.handle_1337(emulator, data)
    end
  end

  defp handle_clipboard_ops(emulator, command, data) do
    case command do
      9 -> OSCHandler.Clipboard.handle_9(emulator, data)
      52 -> OSCHandler.Clipboard.handle_52(emulator, data)
    end
  end

  defp handle_color_ops(emulator, command, data) do
    case command do
      10 -> OSCHandler.Color.handle_10(emulator, data)
      11 -> OSCHandler.Color.handle_11(emulator, data)
      17 -> OSCHandler.Color.handle_17(emulator, data)
      19 -> OSCHandler.Color.handle_19(emulator, data)
    end
  end

  defp handle_cursor_ops(emulator, command, data) do
    case command do
      12 -> OSCHandler.Cursor.handle_12(emulator, data)
      50 -> OSCHandler.Cursor.handle_50(emulator, data)
      112 -> OSCHandler.Cursor.handle_112(emulator, data)
    end
  end

  def handle_window_title(emulator, data),
    do: {:ok, %{emulator | window_title: data}}

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
