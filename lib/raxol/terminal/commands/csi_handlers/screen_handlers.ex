defmodule Raxol.Terminal.Commands.CSIHandlers.ScreenHandlers do
  @moduledoc """
  Handlers for screen-related CSI commands.
  """

  alias Raxol.Terminal.Commands.CSIHandlers.Screen

  @doc """
  Handles erase display command.
  """
  def handle_erase_display(emulator, mode) do
    # Only valid modes are 0, 1, and 2
    if mode in [0, 1, 2] do
      Screen.handle_command(
        emulator,
        [mode],
        ?J
      )
    else
      # Invalid mode, return emulator unchanged
      emulator
    end
  end

  @doc """
  Handles erase line command.
  """
  def handle_erase_line(emulator, mode) do
    Screen.handle_command(
      emulator,
      [mode],
      ?K
    )
  end

  @doc """
  Handles screen clear with parameter parsing.
  """
  def handle_screen_clear(emulator, params) do
    case params do
      [] -> handle_erase_display(emulator, 0)
      [0] -> handle_erase_display(emulator, 0)
      [1] -> handle_erase_display(emulator, 1)
      [2] -> handle_erase_display(emulator, 2)
      _ -> {:ok, emulator}
    end
  end

  @doc """
  Handles line clear with parameter parsing.
  """
  def handle_line_clear(emulator, params) do
    case params do
      [] -> handle_erase_line(emulator, 0)
      [0] -> handle_erase_line(emulator, 0)
      [1] -> handle_erase_line(emulator, 1)
      [2] -> handle_erase_line(emulator, 2)
      _ -> {:ok, emulator}
    end
  end

  @doc """
  Handles scroll up command.
  """
  def handle_scroll_up(emulator, lines) do
    Screen.handle_command(
      emulator,
      [lines],
      ?S
    )
  end

  @doc """
  Handles scroll down command.
  """
  def handle_scroll_down(emulator, lines) do
    Screen.handle_command(
      emulator,
      [lines],
      ?T
    )
  end

  @doc """
  Handles scrolling region command.
  """
  def handle_r(emulator, params) do
    case params do
      [] -> Screen.handle_command(emulator, [], ?r)
      [top] -> Screen.handle_command(emulator, [top], ?r)
      [top, bottom] -> Screen.handle_command(emulator, [top, bottom], ?r)
      _ -> emulator
    end
  end
end
