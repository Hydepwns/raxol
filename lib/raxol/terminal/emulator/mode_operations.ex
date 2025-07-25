defmodule Raxol.Terminal.Emulator.ModeOperations do
  @moduledoc """
  Mode operation functions extracted from the main emulator module.
  Handles terminal mode setting and resetting operations.
  """

  require Logger
  
  alias Raxol.Terminal.Emulator

  @type emulator :: Emulator.t()

  @doc """
  Sets a terminal mode using the mode manager.
  """
  @spec set_mode(emulator(), atom()) :: emulator()
  def set_mode(emulator, mode) do
    Logger.debug("Emulator.set_mode/2 called with mode=#{inspect(mode)}")
    Logger.debug("Emulator.set_mode/2: about to call ModeManager.set_mode")
    result = Raxol.Terminal.ModeManager.set_mode(emulator, [mode])

    Logger.debug(
      "Emulator.set_mode/2: ModeManager.set_mode returned #{inspect(result)}"
    )

    case result do
      {:ok, new_emulator} ->
        Logger.debug("Emulator.set_mode/2: returning new_emulator")
        new_emulator

      {:error, reason} ->
        Logger.debug(
          "Emulator.set_mode/2: ModeManager.set_mode returned {:error, #{inspect(reason)}}"
        )

        emulator
    end
  end

  @doc """
  Resets a terminal mode using the mode manager.
  """
  @spec reset_mode(emulator(), atom()) :: emulator()
  def reset_mode(emulator, mode) do
    case Raxol.Terminal.ModeManager.reset_mode(emulator, [mode]) do
      {:ok, new_emulator} -> new_emulator
      {:error, _} -> emulator
    end
  end
end