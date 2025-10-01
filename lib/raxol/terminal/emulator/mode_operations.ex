defmodule Raxol.Terminal.Emulator.ModeOperations do
  @moduledoc """
  Mode operation functions extracted from the main emulator module.
  Handles terminal mode setting and resetting operations.
  """
  alias Raxol.Terminal.Emulator
  alias Raxol.Core.Runtime.Log

  @type emulator :: Emulator.t()

  @doc """
  Sets a terminal mode using the mode manager.
  """
  @spec set_mode(emulator(), atom()) :: {:ok, emulator()} | {:error, term()}
  def set_mode(emulator, mode) do
    Log.module_debug(
      "ModeOperations.set_mode called with mode=#{inspect(mode)}"
    )

    Log.module_debug(
      "ModeOperations.set_mode: about to call ModeManager.set_mode"
    )

    result = Raxol.Terminal.ModeManager.set_mode(emulator, [mode])

    Log.module_debug(
      "ModeOperations.set_mode: ModeManager.set_mode returned #{inspect(result)}"
    )

    case result do
      {:ok, new_emulator} ->
        Log.module_debug(
          "ModeOperations.set_mode: returning {:ok, new_emulator}"
        )

        {:ok, new_emulator}

      {:error, reason} ->
        Log.module_debug(
          "ModeOperations.set_mode: ModeManager.set_mode returned {:error, #{inspect(reason)}}"
        )

        {:error, reason}
    end
  end

  @doc """
  Resets a terminal mode using the mode manager.
  """
  @spec reset_mode(emulator(), atom()) :: {:ok, emulator()} | {:error, term()}
  def reset_mode(emulator, mode) do
    Log.module_debug(
      "ModeOperations.reset_mode called with mode=#{inspect(mode)}"
    )

    Log.module_debug(
      "ModeOperations.reset_mode: about to call ModeManager.reset_mode"
    )

    result = Raxol.Terminal.ModeManager.reset_mode(emulator, [mode])

    Log.module_debug(
      "ModeOperations.reset_mode: ModeManager.reset_mode returned #{inspect(result)}"
    )

    case result do
      {:ok, new_emulator} ->
        Log.module_debug(
          "ModeOperations.reset_mode: returning {:ok, new_emulator}"
        )

        {:ok, new_emulator}

      {:error, reason} ->
        Log.module_debug(
          "ModeOperations.reset_mode: returning {:error, #{inspect(reason)}}"
        )

        {:error, reason}
    end
  end
end
