defmodule Raxol.Terminal.ANSI.Parser do
  @moduledoc """
  ANSI escape sequence parser for terminal emulation.

  This module provides high-performance parsing of ANSI escape sequences,
  supporting CSI, OSC, DCS, and other control sequences.
  """

  @type parsed_token ::
          {:text, binary()}
          | {:csi, binary(), binary()}
          | {:osc, binary()}
          | {:dcs, binary()}
          | {:escape, binary()}

  @doc """
  Parses ANSI escape sequences from input.

  Returns a list of parsed tokens.
  """
  @spec parse(binary()) :: list(parsed_token())
  def parse(input) when is_binary(input) do
    parse_bytes(input, [], [])
    |> Enum.reverse()
  end

  def parse(_), do: []

  # Parse bytes recursively
  defp parse_bytes(<<>>, [], acc), do: acc

  defp parse_bytes(<<>>, text_acc, acc) do
    text = text_acc |> Enum.reverse() |> IO.iodata_to_binary()
    [{:text, text} | acc]
  end

  # ESC sequence start
  defp parse_bytes(<<0x1B, rest::binary>>, text_acc, acc) do
    acc =
      if text_acc == [] do
        acc
      else
        text = text_acc |> Enum.reverse() |> IO.iodata_to_binary()
        [{:text, text} | acc]
      end

    parse_escape_sequence(rest, acc)
  end

  # Regular text
  defp parse_bytes(<<byte, rest::binary>>, text_acc, acc) do
    parse_bytes(rest, [<<byte>> | text_acc], acc)
  end

  # Parse escape sequence
  defp parse_escape_sequence(<<"[", rest::binary>>, acc) do
    parse_csi(rest, [], acc)
  end

  defp parse_escape_sequence(<<"]", rest::binary>>, acc) do
    parse_osc(rest, [], acc)
  end

  defp parse_escape_sequence(<<"P", rest::binary>>, acc) do
    parse_dcs(rest, [], acc)
  end

  defp parse_escape_sequence(<<char, rest::binary>>, acc)
       when char >= ?@ and char <= ?_ do
    parse_bytes(rest, [], [{:escape, <<char>>} | acc])
  end

  defp parse_escape_sequence(rest, acc) do
    # Invalid escape sequence, treat as text
    parse_bytes(rest, [<<0x1B>>], acc)
  end

  # Parse CSI sequence
  defp parse_csi(<<>>, _params, acc) do
    [{:text, <<0x1B, "[">>} | acc]
  end

  defp parse_csi(<<char, rest::binary>>, params, acc)
       when char >= ?0 and char <= ?? do
    parse_csi(rest, [<<char>> | params], acc)
  end

  defp parse_csi(<<char, rest::binary>>, params, acc)
       when char >= ?@ and char <= ?~ do
    params_str = params |> Enum.reverse() |> IO.iodata_to_binary()
    parse_bytes(rest, [], [{:csi, params_str, <<char>>} | acc])
  end

  defp parse_csi(rest, _params, acc) do
    # Invalid CSI sequence
    parse_bytes(rest, [<<0x1B, "[">>], acc)
  end

  # Parse OSC sequence
  defp parse_osc(<<>>, _text, acc) do
    [{:text, <<0x1B, "]">>} | acc]
  end

  defp parse_osc(<<0x07, rest::binary>>, text, acc) do
    text_str = text |> Enum.reverse() |> IO.iodata_to_binary()
    parse_bytes(rest, [], [{:osc, text_str} | acc])
  end

  defp parse_osc(<<0x1B, "\\", rest::binary>>, text, acc) do
    text_str = text |> Enum.reverse() |> IO.iodata_to_binary()
    parse_bytes(rest, [], [{:osc, text_str} | acc])
  end

  defp parse_osc(<<char, rest::binary>>, text, acc) do
    parse_osc(rest, [<<char>> | text], acc)
  end

  # Parse DCS sequence
  defp parse_dcs(<<>>, _text, acc) do
    [{:text, <<0x1B, "P">>} | acc]
  end

  defp parse_dcs(<<0x1B, "\\", rest::binary>>, text, acc) do
    text_str = text |> Enum.reverse() |> IO.iodata_to_binary()
    parse_bytes(rest, [], [{:dcs, text_str} | acc])
  end

  defp parse_dcs(<<char, rest::binary>>, text, acc) do
    parse_dcs(rest, [<<char>> | text], acc)
  end

  @doc """
  Strips ANSI escape sequences from input.
  """
  @spec strip_ansi(binary()) :: binary()
  def strip_ansi(input) when is_binary(input) do
    input
    |> parse()
    |> Enum.filter(fn
      {:text, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:text, text} -> text end)
    |> IO.iodata_to_binary()
  end

  def strip_ansi(input), do: to_string(input)
end
