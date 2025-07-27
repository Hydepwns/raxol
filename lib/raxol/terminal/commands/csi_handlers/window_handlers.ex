defmodule Raxol.Terminal.Commands.CSIHandlers.WindowHandlers do
  @moduledoc """
  Handlers for window-related CSI commands.
  """

  @doc """
  Handles window maximize command.
  """
  def handle_window_maximize(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [9]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window unmaximize command.
  """
  def handle_window_unmaximize(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [10]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window minimize command.
  """
  def handle_window_minimize(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [2]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window unminimize command.
  """
  def handle_window_unminimize(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [1]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window iconify command.
  """
  def handle_window_iconify(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [2]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window deiconify command.
  """
  def handle_window_deiconify(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [1]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window raise command.
  """
  def handle_window_raise(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [5]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window lower command.
  """
  def handle_window_lower(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [6]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window fullscreen command.
  """
  def handle_window_fullscreen(emulator) do
    # Set stacking order to fullscreen
    updated_window_state = %{
      emulator.window_state
      | stacking_order: :fullscreen
    }

    %{emulator | window_state: updated_window_state}
  end

  @doc """
  Handles window unfullscreen command.
  """
  def handle_window_unfullscreen(emulator) do
    # Set stacking order to normal
    updated_window_state = %{emulator.window_state | stacking_order: :normal}
    %{emulator | window_state: updated_window_state}
  end

  @doc """
  Handles window title command.
  """
  def handle_window_title(emulator) do
    # Get title from emulator.window_title or use empty string
    title = emulator.window_title || ""

    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [0, title]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window icon name command.
  """
  def handle_window_icon_name(emulator) do
    # Get icon name from window_state if available
    icon_name = Map.get(emulator.window_state, :icon_name, "")

    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [
           8,
           icon_name
         ]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window icon title command.
  """
  def handle_window_icon_title(emulator) do
    # Icon title should be the same as window title
    title = emulator.window_title || ""
    output = "\x1b]2;#{title}\x07"
    %{emulator | output_buffer: output}
  end

  @doc """
  Handles window icon title name command.
  """
  def handle_window_icon_title_name(emulator) do
    # Icon title and name should be window title and icon name
    title = emulator.window_title || ""
    icon_name = Map.get(emulator.window_state, :icon_name, "")
    output = "\x1b]3;#{title};#{icon_name}\x07"
    %{emulator | output_buffer: output}
  end

  @doc """
  Handles window save title command.
  """
  def handle_window_save_title(emulator) do
    # Save current size
    current_size = emulator.window_state.size
    updated_window_state = %{emulator.window_state | saved_size: current_size}
    %{emulator | window_state: updated_window_state}
  end

  @doc """
  Handles window restore title command.
  """
  def handle_window_restore_title(emulator) do
    # Restore saved size or use default
    saved_size = Map.get(emulator.window_state, :saved_size, {80, 24})
    updated_window_state = %{emulator.window_state | size: saved_size}
    %{emulator | window_state: updated_window_state}
  end

  @doc """
  Handles window size report command.
  """
  def handle_window_size_report(emulator) do
    case Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, [18]) do
      {:ok, updated_emulator} -> updated_emulator
      {:error, _, emulator} -> emulator
    end
  end

  @doc """
  Handles window size pixels command.
  """
  def handle_window_size_pixels(emulator) do
    {w, h} = emulator.window_state.size

    width_px =
      w * Raxol.Terminal.Commands.WindowHandlers.default_char_width_px()

    height_px =
      h * Raxol.Terminal.Commands.WindowHandlers.default_char_height_px()

    output = "\x1b[4;#{height_px};#{width_px}t"
    %{emulator | output_buffer: output}
  end
end
