defmodule Raxol.Terminal.Commands.ModeHandlers do
  @moduledoc false

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ModeManager
  require Raxol.Core.Runtime.Log

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
      case apply_mode_func.(emulator, [mode_atom]) do
        {:ok, updated_emulator} -> updated_emulator
        {:error, _reason} -> emulator
      end
    else
      Raxol.Core.Runtime.Log.warning_with_context(
        "Unknown DEC private mode code: ?#{param_code}",
        %{}
      )

      emulator
    end
  end

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
      case apply_mode_func.(emulator, [mode_atom]) do
        {:ok, updated_emulator} -> updated_emulator
        {:error, _reason} -> emulator
      end
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

  @spec handle_h(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_h(emulator, params) do
    handle_h_or_l(emulator, params, "", ?h)
  end

  @spec handle_l(Emulator.t(), list(integer())) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_l(emulator, params) do
    handle_h_or_l(emulator, params, "", ?l)
  end
end
