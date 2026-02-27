defmodule Raxol.Terminal.Formatting.Manager do
  @moduledoc """
  Deprecated: Use `Raxol.Terminal.Format` instead.

  This module is maintained for backward compatibility only.
  All functionality has been moved to `Raxol.Terminal.Format`.
  """

  # Delegate all calls to the new unified module
  defdelegate new(), to: Raxol.Terminal.Format
  defdelegate get_format(state), to: Raxol.Terminal.Format
  defdelegate apply_format(state, format), to: Raxol.Terminal.Format
  defdelegate reset_format(state), to: Raxol.Terminal.Format
  defdelegate save_format(state), to: Raxol.Terminal.Format
  defdelegate restore_format(state), to: Raxol.Terminal.Format
  defdelegate set_foreground(state, color), to: Raxol.Terminal.Format
  defdelegate set_background(state, color), to: Raxol.Terminal.Format
  defdelegate toggle_bold(state), to: Raxol.Terminal.Format
  defdelegate toggle_faint(state), to: Raxol.Terminal.Format
  defdelegate toggle_italic(state), to: Raxol.Terminal.Format
  defdelegate toggle_underline(state), to: Raxol.Terminal.Format
  defdelegate toggle_blink(state), to: Raxol.Terminal.Format
  defdelegate toggle_reverse(state), to: Raxol.Terminal.Format
  defdelegate toggle_conceal(state), to: Raxol.Terminal.Format
  defdelegate toggle_strikethrough(state), to: Raxol.Terminal.Format
  defdelegate set_font(state, font), to: Raxol.Terminal.Format
  defdelegate apply_formatting(state, text), to: Raxol.Terminal.Format
end
