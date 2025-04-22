defmodule Raxol.Terminal.ScreenModes do
  @moduledoc """
  Alias module for Raxol.Terminal.ANSI.ScreenModes.
  This module re-exports the functionality from ANSI.ScreenModes to maintain compatibility.
  """

  # Re-export all functions from the ANSI.ScreenModes module
  defdelegate new(), to: Raxol.Terminal.ANSI.ScreenModes

  defdelegate switch_mode(state, mode_flag, enable),
    to: Raxol.Terminal.ANSI.ScreenModes

  defdelegate switch_mode(state, new_mode), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate set_mode(state, mode_flag), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate reset_mode(state, mode_flag), to: Raxol.Terminal.ANSI.ScreenModes

  defdelegate mode_enabled?(state, mode_flag),
    to: Raxol.Terminal.ANSI.ScreenModes

  defdelegate get_mode(state), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate get_column_width_mode(state), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate get_auto_repeat_mode(state), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate get_interlacing_mode(state), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate lookup_private(code), to: Raxol.Terminal.ANSI.ScreenModes
  defdelegate lookup_standard(code), to: Raxol.Terminal.ANSI.ScreenModes
end
