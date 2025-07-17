defmodule Raxol.Terminal.Commands.CSIHandlers.CharsetHandlers do
  @moduledoc """
  Handlers for charset-related CSI commands.
  """

  @charset_mapping %{
    ?0 => :dec_special_graphics,
    ?1 => :uk,
    ?2 => :us_ascii,
    ?3 => :dec_technical,
    ?4 => :dec_special_graphics,
    ?5 => :dec_special_graphics,
    ?6 => :portuguese,
    ?7 => :dec_special_graphics,
    ?8 => :dec_special_graphics,
    ?9 => :dec_special_graphics,
    ?A => :uk,
    ?B => :us_ascii,
    ?F => :german,
    ?D => :french,
    ?R => :dec_technical,
    ?' => :portuguese,
    ?> => :dec_special_graphics
  }

  @doc """
  Handles SCS (Select Character Set) command.
  """
  def handle_scs(emulator, params_buffer, final_byte) do
    charset_code = parse_charset_code(params_buffer)
    charset = get_charset(charset_code)

    field =
      case final_byte do
        ?( -> :g0
        ?) -> :g1
        ?* -> :g2
        ?+ -> :g3
        _ -> {:error, :invalid_charset_designation, emulator}
      end

    case field do
      {:error, reason, emu} -> {:error, reason, emu}
      _ ->
        updated_charset_state = Map.put(emulator.charset_state, field, charset)
        %{emulator | charset_state: updated_charset_state}
    end
  end

  @doc """
  Handles locking shift G0 command.
  """
  def handle_locking_shift_g0(emulator) do
    # Locking Shift G0 - set GL to G0
    updated_charset_state = %{emulator.charset_state | gl: :g0}
    %{emulator | charset_state: updated_charset_state}
  end

  @doc """
  Handles locking shift G1 command.
  """
  def handle_locking_shift_g1(emulator) do
    # Locking Shift G1 - set GL to G1
    updated_charset_state = %{emulator.charset_state | gl: :g1}
    %{emulator | charset_state: updated_charset_state}
  end

  @doc """
  Handles single shift G2 command.
  """
  def handle_single_shift_g2(emulator) do
    # Single Shift G2 - set single_shift to G2
    updated_charset_state = %{
      emulator.charset_state
      | single_shift: emulator.charset_state.g2
    }

    %{emulator | charset_state: updated_charset_state}
  end

  @doc """
  Handles single shift G3 command.
  """
  def handle_single_shift_g3(emulator) do
    # Single Shift G3 - set single_shift to G3
    updated_charset_state = %{
      emulator.charset_state
      | single_shift: emulator.charset_state.g3
    }

    %{emulator | charset_state: updated_charset_state}
  end

  @doc """
  Parses charset code from parameters.
  """
  defp parse_charset_code(params) do
    case params do
      "" -> ?B
      # Special case: "16" maps to DEC Special Graphics (same as "0")
      "16" -> ?0
      <<code>> when code in ?0..?9 or code in ?A..?Z or code in ?a..?z -> code
      _ -> ?B
    end
  end

  @doc """
  Gets charset from charset code.
  """
  defp get_charset(charset_code) do
    Map.get(@charset_mapping, charset_code, :us_ascii)
  end
end
