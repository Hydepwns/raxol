defmodule Raxol.Terminal.Commands.CSIHandler.Cursor do
  @moduledoc """
  Cursor command delegation module for CSI handler.
  """

  alias Raxol.Terminal.Commands.CursorHandler

  @doc """
  Delegates cursor commands to the appropriate handler based on the command byte.
  """
  def handle_command(emulator, params, byte) do
    case byte do
      ?A -> CursorHandler.handle_A(emulator, params)
      ?B -> CursorHandler.handle_B(emulator, params)
      ?C -> CursorHandler.handle_C(emulator, params)
      ?D -> CursorHandler.handle_D(emulator, params)
      ?E -> CursorHandler.handle_E(emulator, params)
      ?F -> CursorHandler.handle_f_alias(emulator, params)
      ?G -> CursorHandler.handle_G(emulator, params)
      ?H -> CursorHandler.handle_cup(emulator, params)
      ?d -> CursorHandler.handle_d(emulator, params)
      ?f -> CursorHandler.handle_f(emulator, params)
      ?g -> CursorHandler.handle_g(emulator, params)
      _ -> {:error, :unknown_cursor_command, emulator}
    end
  end
end
