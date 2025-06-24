defmodule Raxol.Terminal.Commands.WindowHandlers do
  @moduledoc """
  Handles window-related commands and operations for the terminal.
  """

  alias Raxol.Terminal.Emulator

  @spec default_char_width_px() :: non_neg_integer()
  def default_char_width_px, do: 8

  @spec default_char_height_px() :: non_neg_integer()
  def default_char_height_px, do: 16

  @spec calculate_width_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_width_chars(pixel_width) do
    div(pixel_width, default_char_width_px())
  end

  @spec calculate_height_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_height_chars(pixel_height) do
    div(pixel_height, default_char_height_px())
  end

  @spec handle_t(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_t(emulator, params) do
    op = Enum.at(params, 0, 0)

    case op do
      1 -> handle_deiconify(emulator)
      2 -> handle_iconify(emulator)
      3 -> handle_move(emulator, params)
      4 -> handle_resize(emulator, params)
      5 -> handle_raise(emulator)
      6 -> handle_lower(emulator)
      7 -> handle_refresh(emulator)
      9 -> handle_maximize(emulator)
      10 -> handle_restore(emulator)
      11 -> handle_report_state(emulator)
      13 -> handle_report_size_pixels(emulator)
      14 -> handle_report_position(emulator)
      18 -> handle_report_text_area_size(emulator)
      19 -> handle_report_desktop_size(emulator)
      _ -> {:ok, emulator}
    end
  end

  defp handle_deiconify(emulator) do
    {:ok, emulator}
  end

  defp handle_iconify(emulator) do
    {:ok, emulator}
  end

  defp handle_move(emulator, params) do
    _x = Enum.at(params, 1, 0)
    _y = Enum.at(params, 2, 0)
    {:ok, emulator}
  end

  defp handle_resize(emulator, params) do
    _width_px = Enum.at(params, 1, 0)
    _height_px = Enum.at(params, 2, 0)
    {:ok, emulator}
  end

  defp handle_raise(emulator) do
    {:ok, emulator}
  end

  defp handle_lower(emulator) do
    {:ok, emulator}
  end

  defp handle_refresh(emulator) do
    {:ok, emulator}
  end

  defp handle_maximize(emulator) do
    {:ok, emulator}
  end

  defp handle_restore(emulator) do
    {:ok, emulator}
  end

  defp handle_report_state(emulator) do
    {:ok, emulator}
  end

  defp handle_report_size_pixels(emulator) do
    {:ok, emulator}
  end

  defp handle_report_position(emulator) do
    {:ok, emulator}
  end

  defp handle_report_text_area_size(emulator) do
    {:ok, emulator}
  end

  defp handle_report_desktop_size(emulator) do
    {:ok, emulator}
  end
end
