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
    Enum.reduce(params, emulator, fn param_code, acc_emulator ->
      mode_atom = ModeManager.lookup_private(param_code)

      if mode_atom do
        apply_mode_func.(acc_emulator, [mode_atom])
      else
        Raxol.Core.Runtime.Log.warning_with_context("Unknown DEC private mode code: ?#{param_code}", %{})
        acc_emulator
      end
    end)
  end

  # Helper function to handle standard ANSI modes
  @spec handle_standard_mode(
          Emulator.t(),
          list(integer()),
          fun()
        ) :: Emulator.t()
  defp handle_standard_mode(emulator, params, apply_mode_func) do
    Enum.reduce(params, emulator, fn param_code, acc_emulator ->
      mode_atom = ModeManager.lookup_standard(param_code)

      if mode_atom do
        apply_mode_func.(acc_emulator, [mode_atom])
      else
        # Fallback for codes not directly in ModeManager.@standard_modes but might be aliases
        # This section is to maintain previous explicit mappings if they are not in ModeManager's tables
        # but were handled by ModeManager.do_set_mode/do_reset_mode via different atoms.
        # Ideally, ModeManager's tables should be comprehensive.
        case param_code do
          # Keyboard Action Mode (KAM) - ModeManager does not list, but might handle :keyboard_action
          2 ->
            # Assuming ModeManager might handle a generic :keyboard_action if sent
            # This is speculative and depends on ModeManager's internal handling.
            # For now, we'll log if not in ModeManager's map.
            Raxol.Core.Runtime.Log.warning_with_context(
              "Standard mode code 2 (KAM) not directly in ModeManager's map. Effect depends on ModeManager internals.",
              %{}
            )

            # Or attempt apply_mode_func.(acc_emulator, [:keyboard_action]) if confident
            acc_emulator

          # Send/Receive Mode (SRM) - ModeManager does not list
          12 ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "Standard mode code 12 (SRM) not directly in ModeManager's map. Effect depends on ModeManager internals.",
              %{}
            )

            acc_emulator

          _ ->
            Raxol.Core.Runtime.Log.warning_with_context("Unknown standard mode code: #{param_code}", %{})
            acc_emulator
        end
      end
    end)
  end

  # --- Parameter Validation Helpers ---

  @doc """
  Gets a parameter value with validation.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_param(
          list(integer() | nil),
          non_neg_integer(),
          integer(),
          integer(),
          integer()
        ) :: integer()
  defp get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid parameter value at index #{index}, using default #{default}",
          %{}
        )

        default
    end
  end

  @doc """
  Gets a parameter value with validation for non-negative integers.
  Returns the parameter value if valid, or the default value if invalid.
  """
  @spec get_valid_non_neg_param(
          list(integer() | nil),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp get_valid_non_neg_param(params, index, default) do
    get_valid_param(params, index, default, 0, 9999)
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
