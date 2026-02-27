defmodule Raxol.Terminal.Mode.Manager do
  @moduledoc """
  Deprecated: Use `Raxol.Terminal.ModeManager` instead.

  This module is maintained for backward compatibility only.
  The main mode management functionality is in `Raxol.Terminal.ModeManager`.
  """

  # Delegate to the canonical ModeManager
  defdelegate new(), to: Raxol.Terminal.ModeManager
  defdelegate get_manager(emulator), to: Raxol.Terminal.ModeManager
  defdelegate update_manager(emulator, manager), to: Raxol.Terminal.ModeManager
  defdelegate mode_set?(manager, mode), to: Raxol.Terminal.ModeManager
  defdelegate get_set_modes(manager), to: Raxol.Terminal.ModeManager
  defdelegate reset_all_modes(manager), to: Raxol.Terminal.ModeManager
  defdelegate save_modes(manager), to: Raxol.Terminal.ModeManager
  defdelegate restore_modes(manager), to: Raxol.Terminal.ModeManager

  # Compatibility shim for the different set_mode signature
  def set_mode(manager, mode, true) do
    modes = manager.modes || %{}
    %{manager | modes: Map.put(modes, mode, true)}
  end

  def set_mode(manager, mode, false) do
    modes = manager.modes || %{}
    %{manager | modes: Map.delete(modes, mode)}
  end

  def reset_mode(manager, mode) do
    modes = manager.modes || %{}
    %{manager | modes: Map.delete(modes, mode)}
  end
end
