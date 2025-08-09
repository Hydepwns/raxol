defmodule Raxol.Terminal.ANSI.SequenceHandlers do
  @moduledoc """
  Handles parsing and processing of ANSI escape sequences.
  This module extracts the ANSI sequence parsing logic from the main emulator.
  """

  @doc """
  Parses ANSI sequences from input and returns the parsed result.
  """
  @spec parse_ansi_sequence(binary()) :: {:incomplete, nil} | tuple()
  def parse_ansi_sequence(rest) do
    # Disabled for performance
    # File.write!(
    #   "tmp/parse_ansi_sequence.log",
    #   "parse_ansi_sequence input: #{inspect(rest)}\n",
    #   [:append]
    # )

    case find_matching_parser(rest) do
      nil ->
        # Disabled for performance
        # File.write!(
        #   "tmp/parse_ansi_sequence.log",
        #   "parse_ansi_sequence result: nil\n",
        #   [:append]
        # )

        {:incomplete, nil}

      result ->
        # Disabled for performance
        # File.write!(
        #   "tmp/parse_ansi_sequence.log",
        #   "parse_ansi_sequence result: #{inspect(result)}\n",
        #   [:append]
        # )

        result
    end
  end

  @doc """
  Parses OSC (Operating System Command) sequences.
  """
  @spec parse_osc(binary()) :: {:osc, binary(), nil} | nil
  def parse_osc(<<0x1B, 0x5D, 0x30, 0x3B, remaining::binary>>) do
    case String.split(remaining, <<0x07>>, parts: 2) do
      [_title, rest] -> {:osc, rest, nil}
      _ -> nil
    end
  end

  def parse_osc(_), do: nil

  @doc """
  Parses DCS (Device Control String) sequences.
  """
  @spec parse_dcs(binary()) :: {:dcs, binary(), nil} | nil
  def parse_dcs(<<0x1B, 0x50, 0x30, 0x3B, remaining::binary>>) do
    case String.split(remaining, <<0x07>>, parts: 2) do
      [_params, rest] -> {:dcs, rest, nil}
      _ -> nil
    end
  end

  def parse_dcs(_), do: nil

  @doc """
  Parses CSI cursor position sequences.
  """
  @spec parse_csi_cursor_pos(binary()) ::
          {:csi_cursor_pos, binary(), binary(), nil} | nil
  def parse_csi_cursor_pos(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x48>>, parts: 2) do
      [params, rest] -> {:csi_cursor_pos, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_pos(_), do: nil

  @doc """
  Parses CSI cursor up sequences.
  """
  @spec parse_csi_cursor_up(binary()) ::
          {:csi_cursor_up, binary(), binary(), nil} | nil
  def parse_csi_cursor_up(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x41>>, parts: 2) do
      [params, rest] -> {:csi_cursor_up, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_up(_), do: nil

  @doc """
  Parses CSI cursor down sequences.
  """
  @spec parse_csi_cursor_down(binary()) ::
          {:csi_cursor_down, binary(), binary(), nil} | nil
  def parse_csi_cursor_down(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x42>>, parts: 2) do
      [params, rest] -> {:csi_cursor_down, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_down(_), do: nil

  @doc """
  Parses CSI cursor forward sequences.
  """
  @spec parse_csi_cursor_forward(binary()) ::
          {:csi_cursor_forward, binary(), binary(), nil} | nil
  def parse_csi_cursor_forward(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x43>>, parts: 2) do
      [params, rest] -> {:csi_cursor_forward, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_forward(_), do: nil

  @doc """
  Parses CSI cursor back sequences.
  """
  @spec parse_csi_cursor_back(binary()) ::
          {:csi_cursor_back, binary(), binary(), nil} | nil
  def parse_csi_cursor_back(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, <<0x44>>, parts: 2) do
      [params, rest] -> {:csi_cursor_back, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_cursor_back(_), do: nil

  @doc """
  Parses CSI cursor show sequences.
  """
  @spec parse_csi_cursor_show(binary()) ::
          {:csi_cursor_show, binary(), nil} | nil
  def parse_csi_cursor_show(
        <<0x1B, 0x5B, 0x3F, 0x32, 0x35, 0x68, remaining::binary>>
      ),
      do: {:csi_cursor_show, remaining, nil}

  def parse_csi_cursor_show(_), do: nil

  @doc """
  Parses CSI cursor hide sequences.
  """
  @spec parse_csi_cursor_hide(binary()) ::
          {:csi_cursor_hide, binary(), nil} | nil
  def parse_csi_cursor_hide(
        <<0x1B, 0x5B, 0x3F, 0x32, 0x35, 0x6C, remaining::binary>>
      ),
      do: {:csi_cursor_hide, remaining, nil}

  def parse_csi_cursor_hide(_), do: nil

  @doc """
  Parses CSI clear screen sequences.
  """
  @spec parse_csi_clear_screen(binary()) ::
          {:csi_clear_screen, binary(), nil} | nil
  def parse_csi_clear_screen(<<0x1B, 0x5B, 0x32, 0x4A, remaining::binary>>),
    do: {:csi_clear_screen, remaining, nil}

  def parse_csi_clear_screen(_), do: nil

  @doc """
  Parses CSI clear line sequences.
  """
  @spec parse_csi_clear_line(binary()) :: {:csi_clear_line, binary(), nil} | nil
  def parse_csi_clear_line(<<0x1B, 0x5B, 0x32, 0x4B, remaining::binary>>),
    do: {:csi_clear_line, remaining, nil}

  def parse_csi_clear_line(_), do: nil

  @doc """
  Parses CSI set mode sequences.
  """
  @spec parse_csi_set_mode(binary()) ::
          {:csi_set_mode, binary(), binary(), nil} | nil
  def parse_csi_set_mode(<<0x1B, 0x5B, 0x3F, remaining::binary>>) do
    case String.split(remaining, "h", parts: 2) do
      [params, rest] -> {:csi_set_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_set_mode(_), do: nil

  @doc """
  Parses CSI reset mode sequences.
  """
  @spec parse_csi_reset_mode(binary()) ::
          {:csi_reset_mode, binary(), binary(), nil} | nil
  def parse_csi_reset_mode(<<0x1B, 0x5B, 0x3F, remaining::binary>>) do
    case String.split(remaining, "l", parts: 2) do
      [params, rest] -> {:csi_reset_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_reset_mode(_), do: nil

  @doc """
  Parses CSI set standard mode sequences.
  """
  @spec parse_csi_set_standard_mode(binary()) ::
          {:csi_set_standard_mode, binary(), binary(), nil} | nil
  def parse_csi_set_standard_mode(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, "h", parts: 2) do
      [params, rest] -> {:csi_set_standard_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_set_standard_mode(_), do: nil

  @doc """
  Parses CSI reset standard mode sequences.
  """
  @spec parse_csi_reset_standard_mode(binary()) ::
          {:csi_reset_standard_mode, binary(), binary(), nil} | nil
  def parse_csi_reset_standard_mode(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, "l", parts: 2) do
      [params, rest] -> {:csi_reset_standard_mode, params, rest, nil}
      _ -> nil
    end
  end

  def parse_csi_reset_standard_mode(_), do: nil

  @doc """
  Parses ESC equals sequences.
  """
  @spec parse_esc_equals(binary()) :: {:esc_equals, binary(), nil} | nil
  def parse_esc_equals(<<0x1B, 0x3D, remaining::binary>>),
    do: {:esc_equals, remaining, nil}

  def parse_esc_equals(_), do: nil

  @doc """
  Parses ESC greater than sequences.
  """
  @spec parse_esc_greater(binary()) :: {:esc_greater, binary(), nil} | nil
  def parse_esc_greater(<<0x1B, 0x3E, remaining::binary>>),
    do: {:esc_greater, remaining, nil}

  def parse_esc_greater(_), do: nil

  @doc """
  Parses CSI set scroll region sequences.
  """
  @spec parse_csi_set_scroll_region(binary()) ::
          {:csi_set_scroll_region, binary(), binary(), nil} | nil
  def parse_csi_set_scroll_region(<<0x1B, 0x5B, remaining::binary>>) do
    case String.split(remaining, "r", parts: 2) do
      [params, rest] when is_binary(params) ->
        {:csi_set_scroll_region, params, rest, nil}

      _ ->
        nil
    end
  end

  def parse_csi_set_scroll_region(_), do: nil

  @doc """
  Parses CSI general sequences.
  """
  @spec parse_csi_general(binary()) ::
          {:csi_general, binary(), binary(), binary(), binary()} | nil
  def parse_csi_general(<<0x1B, 0x5B, remaining::binary>>) do
    # Match all before final byte, then final byte, then rest
    case Regex.run(~r|^([^A-Za-z]*)([A-Za-z])(.*)|, remaining) do
      [_, before_final, final_byte, rest] ->
        # Reverse, take all digits/;/: from the end as params, rest as intermediates, then reverse both
        rev = String.reverse(before_final)

        {rev_params, rev_intermediates} =
          Regex.run(~r/^([\d;:]*)(.*)/, rev, capture: :all_but_first)
          |> case do
            [ps, ints] -> {ps, ints}
            _ -> {rev, ""}
          end

        params = String.reverse(rev_params)
        intermediates = String.reverse(rev_intermediates)
        {:csi_general, params, intermediates, final_byte, rest}

      _ ->
        nil
    end
  end

  def parse_csi_general(_), do: nil

  @doc """
  Parses SGR (Select Graphic Rendition) sequences.
  """
  @spec parse_sgr(binary()) :: {:sgr, binary(), binary(), nil} | nil
  def parse_sgr(<<0x1B, 0x5B, remaining::binary>>) do
    # Only match if the remaining part contains 'm'
    case String.split(remaining, "m", parts: 2) do
      [params, rest] when is_binary(params) ->
        # Validate that params contains only digits, semicolons, and colons, or is empty (reset)
        if params == "" or String.match?(params, ~r/^[\d;:]*$/) do
          # Disabled for performance
          # File.write!(
          #   "tmp/parse_sgr.log",
          #   "parse_sgr MATCH: params=#{inspect(params)}, rest=#{inspect(rest)}\n",
          #   [:append]
          # )

          {:sgr, params, rest, nil}
        else
          # Disabled for performance
          # File.write!(
          #   "tmp/parse_sgr.log",
          #   "parse_sgr NO_MATCH: params=#{inspect(params)} (invalid format)\n",
          #   [:append]
          # )

          nil
        end

      _ ->
        # Disabled for performance
        # File.write!(
        #   "tmp/parse_sgr.log",
        #   "parse_sgr NO_MATCH: no 'm' found in #{inspect(remaining)}\n",
        #   [:append]
        # )

        nil
    end
  end

  def parse_sgr(_input) do
    # Disabled for performance
    # File.write!(
    #   "tmp/parse_sgr.log",
    #   "parse_sgr NO_MATCH: input=#{inspect(input)} (no ESC[)\n",
    #   [:append]
    # )

    nil
  end

  @doc """
  Parses unknown escape sequences.
  """
  @spec parse_unknown(binary()) :: {:unknown, binary(), nil} | nil
  def parse_unknown(<<0x1B, remaining::binary>>) do
    # Skip one character after ESC
    case remaining do
      <<_char, rest::binary>> -> {:unknown, rest, nil}
      _ -> nil
    end
  end

  def parse_unknown(_), do: nil

  @doc """
  Parses mouse event sequences in the format ESC[M<button><x><y>.
  """
  @spec parse_mouse_event(binary()) ::
          {:mouse_event, binary(), binary(), nil} | nil
  def parse_mouse_event(<<0x1B, ?[, ?M, rest::binary>>) do
    # Mouse event format: ESC[M<button><x><y>
    # where button, x, y are single bytes
    case rest do
      <<button, x, y, remaining::binary>> ->
        {:mouse_event, <<button, x, y>>, remaining, nil}

      _ ->
        nil
    end
  end

  def parse_mouse_event(_), do: nil

  # Private functions

  defp find_matching_parser(rest) do
    Enum.find_value(ansi_parsers(), & &1.(rest))
  end

  defp ansi_parsers do
    get_parser_functions()
    |> Enum.map(&Function.capture(__MODULE__, &1, 1))
  end

  defp get_parser_functions do
    [
      :parse_osc,
      :parse_dcs,
      :parse_sgr,
      :parse_csi_cursor_pos,
      :parse_csi_cursor_up,
      :parse_csi_cursor_down,
      :parse_csi_cursor_forward,
      :parse_csi_cursor_back,
      :parse_csi_cursor_show,
      :parse_csi_cursor_hide,
      :parse_csi_clear_screen,
      :parse_csi_clear_line,
      :parse_csi_set_scroll_region,
      :parse_csi_set_mode,
      :parse_csi_reset_mode,
      :parse_csi_set_standard_mode,
      :parse_csi_reset_standard_mode,
      :parse_csi_general,
      :parse_esc_equals,
      :parse_esc_greater,
      :parse_mouse_event,
      :parse_unknown
    ]
  end
end
