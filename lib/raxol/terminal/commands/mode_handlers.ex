defmodule Raxol.Terminal.Commands.ModeHandlers do
  @moduledoc """
  Handles mode setting and resetting related CSI commands.

  This module contains handlers for setting and resetting terminal modes,
  both standard ANSI modes and DEC private modes. Each function takes the
  current emulator state and parsed parameters, returning the updated
  emulator state.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager
  require Raxol.Core.Runtime.Log

  @doc """
  Handles Set Mode (SM - `h`) or Reset Mode (RM - `l`).

  Dispatches to `ModeManager` to handle both standard ANSI modes and
  DEC private modes (prefixed with `?`).
  """
  @spec handle_h_or_l(Emulator.t(), list(integer()), String.t(), char()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_h_or_l(emulator, params, intermediates_buffer, final_byte) do
    action = if final_byte == ?h, do: :set, else: :reset

    apply_mode_func =
      if action == :set,
        do: &ModeManager.set_mode/2,
        else: &ModeManager.reset_mode/2

    result =
      if intermediates_buffer == "?" do
        handle_dec_private_mode(emulator, params, apply_mode_func)
      else
        handle_standard_mode(emulator, params, apply_mode_func)
      end

    {:ok, result}
  end

  # Helper function to handle DEC private modes
  @spec handle_dec_private_mode(
          Emulator.t(),
          list(integer()),
          fun()
        ) :: Emulator.t()
  defp handle_dec_private_mode(emulator, params, apply_mode_func) do
    Enum.reduce(
      params,
      emulator,
      &handle_dec_private_mode_param(&1, &2, apply_mode_func)
    )
  end

  @spec handle_dec_private_mode_param(integer(), Emulator.t(), fun()) ::
          Emulator.t()
  defp handle_dec_private_mode_param(param_code, emulator, apply_mode_func) do
    mode_atom = ModeManager.lookup_private(param_code)

    if mode_atom do
      apply_mode_func.(emulator, [mode_atom])
    else
      Raxol.Core.Runtime.Log.warning_with_context(
        "Unknown DEC private mode code: ?#{param_code}",
        %{}
      )

      emulator
    end
  end

  # Helper function to handle standard ANSI modes
  @spec handle_standard_mode(
          Emulator.t(),
          list(integer()),
          fun()
        ) :: Emulator.t()
  defp handle_standard_mode(emulator, params, apply_mode_func) do
    Enum.reduce(
      params,
      emulator,
      &handle_standard_mode_param(&1, &2, apply_mode_func)
    )
  end

  @spec handle_standard_mode_param(integer(), Emulator.t(), fun()) ::
          Emulator.t()
  defp handle_standard_mode_param(param_code, emulator, apply_mode_func) do
    mode_atom = ModeManager.lookup_standard(param_code)

    if mode_atom do
      apply_mode_func.(emulator, [mode_atom])
    else
      handle_unknown_standard_mode(param_code, emulator)
    end
  end

  @spec handle_unknown_standard_mode(integer(), Emulator.t()) :: Emulator.t()
  defp handle_unknown_standard_mode(param_code, emulator) do
    case param_code do
      2 ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Standard mode code 2 (KAM) not directly in ModeManager's map. Effect depends on ModeManager internals.",
          %{}
        )

        emulator

      12 ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Standard mode code 12 (SRM) not directly in ModeManager's map. Effect depends on ModeManager internals.",
          %{}
        )

        emulator

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown standard mode code: #{param_code}",
          %{}
        )

        emulator
    end
  end

  @doc """
  Handles Set Mode (SM - CSI h).
  Calls handle_h_or_l/4 with final_byte ?h and no intermediates.
  """
  @spec handle_h(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_h(emulator, params) do
    handle_h_or_l(emulator, params, "", ?h)
  end

  @doc """
  Handles Reset Mode (RM - CSI l).
  Calls handle_h_or_l/4 with final_byte ?l and no intermediates.
  """
  @spec handle_l(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_l(emulator, params) do
    handle_h_or_l(emulator, params, "", ?l)
  end
end
