defmodule Raxol.Terminal.Commands.DeviceHandlers do
  @moduledoc """
  Handles device status and attribute related CSI commands.

  This module contains handlers for device status reports (DSR) and device
  attributes (DA). Each function takes the current emulator state and parsed
  parameters, returning the updated emulator state.
  """

  alias Raxol.Terminal.Emulator
  require Logger

  @doc "Handles Device Status Report (DSR - 'n')"
  @spec handle_n(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_n(emulator, params) do
    code = get_valid_non_neg_param(params, 0, 0)
    response = generate_dsr_response(code, emulator)

    if response do
      %{emulator | output: emulator.output <> response}
    else
      emulator
    end
  end

  @doc "Handles Device Attributes (DA - 'c')"
  @spec handle_c(Emulator.t(), list(integer()), String.t()) :: Emulator.t()
  def handle_c(emulator, _params, intermediates_buffer) do
    response = generate_da_response(intermediates_buffer)
    %{emulator | output: emulator.output <> response}
  end

  @doc "Handles Device Status Report (CPR - '6n') (stub)."
  @spec handle_6n(Emulator.t(), list(integer())) :: Emulator.t()
  def handle_6n(emulator, _params) do
    # Stub: Implement actual logic if needed
    emulator
  end

  # Helper function to generate DSR response based on code
  @spec generate_dsr_response(non_neg_integer(), Emulator.t()) ::
          String.t() | nil
  defp generate_dsr_response(code, emulator) do
    case code do
      # Report cursor position (CPR)
      6 ->
        {col, row} = emulator.cursor.position
        # Convert to 1-based for response
        "\e[#{row + 1};#{col + 1}R"

      # Report device status (DSR)
      5 ->
        # Device ready
        "\e[0n"

      _ ->
        Logger.warning("Unknown DSR code: #{code}")
        nil
    end
  end

  # Helper function to generate DA response based on intermediate buffer
  @spec generate_da_response(String.t()) :: String.t()
  defp generate_da_response(intermediates_buffer) do
    case intermediates_buffer do
      # Secondary DA: VT100 with no options
      ">" -> "\e[>0;0;0c"
      # Primary DA: VT100 with no options
      _ -> "\e[?1;0c"
    end
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
        Logger.warning(
          "Invalid parameter value at index #{index}, using default #{default}"
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
end
