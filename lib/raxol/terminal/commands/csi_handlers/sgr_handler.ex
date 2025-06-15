defmodule Raxol.Terminal.Commands.CSIHandlers.SGRHandler do
  @moduledoc """
  Handles Select Graphic Rendition (SGR) commands.
  """

  alias Raxol.Terminal.Emulator

  @sgr_mode_map %{
    # code c >= 2, using (c - 2) mod 13
    0 => {:cursor_keys, :application},
    1 => {:cursor_keys, :normal},
    2 => {:ansi_mode, false},
    3 => {:column_mode, false},
    4 => {:smooth_scroll, false},
    5 => {:reverse_video, false},
    6 => {:origin_mode, false},
    7 => {:wrap_mode, false},
    8 => {:auto_repeat, false},
    9 => {:interlacing, false},
    10 => {:cursor_blink, false},
    11 => {:cursor_visible, false},
    12 => {:alternate_screen, false}
  }

  @doc """
  Handle Select Graphic Rendition (SGR) command.
  Sets terminal modes based on the given parameters.
  """
  def handle(emulator, params) do
    new_emulator =
      Enum.reduce(params, emulator, fn param, acc_emulator ->
        update_emulator_for_sgr(acc_emulator, param)
      end)

    {:ok, new_emulator}
  end

  defp update_emulator_for_sgr(emulator, 0) do
    %{
      emulator
      | ansi_mode: false,
        column_mode: false,
        smooth_scroll: false,
        reverse_video: false,
        origin_mode: false,
        wrap_mode: false,
        auto_repeat: false,
        interlacing: false,
        cursor_blink: false,
        cursor_visible: false,
        alternate_screen: false
    }
  end

  defp update_emulator_for_sgr(emulator, 1) do
    %{
      emulator
      | ansi_mode: true,
        column_mode: true,
        smooth_scroll: true,
        reverse_video: true,
        origin_mode: true,
        wrap_mode: true,
        auto_repeat: true,
        interlacing: true,
        cursor_blink: true,
        cursor_visible: true,
        alternate_screen: true
    }
  end

  defp update_emulator_for_sgr(emulator, code) when code >= 2 do
    key = rem(code - 2, 13)

    case Map.get(@sgr_mode_map, key) do
      {field, value} -> Emulator.set_attribute(emulator, field, value)
      nil -> emulator
    end
  end

  defp update_emulator_for_sgr(emulator, _code), do: emulator
end
