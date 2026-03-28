defmodule Raxol.Terminal.Escape.Parsers.SCSParser do
  @moduledoc """
  Parser for SCS (Select Character Set) escape sequences.

  SCS sequences are used to designate character sets to G0-G3 graphic sets.
  They follow the pattern ESC ( x, ESC ) x, ESC * x, or ESC + x
  where the intermediate character determines which G-set to modify.
  """

  alias Raxol.Terminal.Escape.Parsers.BaseParser

  @doc """
  Parses an SCS sequence after the ESC and intermediate character.

  ## Parameters
    - intermediate: The intermediate character ('(', ')', '*', '+')
    - input: The remaining input after the intermediate

  ## Returns
    - `{:ok, command, remaining}` - Successfully parsed command
    - `{:incomplete, input}` - Input is incomplete
    - `{:error, reason, input}` - Parse error
  """
  @spec parse(char(), String.t()) ::
          {:ok, term(), String.t()}
          | {:incomplete, String.t()}
          | {:error, atom(), String.t()}
  def parse(intermediate, <<final, rest::binary>>) do
    case decode_scs(intermediate, final) do
      {:ok, command} ->
        {:ok, command, rest}

      {:error, reason} ->
        {:error, reason, <<final, rest::binary>>}
    end
  end

  def parse(_intermediate, "") do
    {:incomplete, ""}
  end

  # Private decoding functions

  defp decode_scs(intermediate, final) do
    g_set = get_g_set(intermediate)
    charset = get_charset(final)

    case {g_set, charset} do
      {nil, _} ->
        {:error, :invalid_intermediate}

      {_, nil} ->
        BaseParser.log_unknown_sequence("SCS", <<intermediate, final>>)
        {:error, :unknown_charset}

      {set, char} ->
        {:ok, {:designate_charset, set, char}}
    end
  end

  defp get_g_set(?(), do: :g0
  defp get_g_set(?)), do: :g1
  defp get_g_set(?*), do: :g2
  defp get_g_set(?+), do: :g3
  defp get_g_set(_), do: nil

  # DEC Special Character and Line Drawing Set
  defp get_charset(?0), do: :dec_special_graphics
  # UK ASCII
  defp get_charset(?A), do: :uk_ascii
  # US ASCII
  defp get_charset(?B), do: :us_ascii
  # Dutch
  defp get_charset(?4), do: :dutch
  # Finnish
  defp get_charset(?C), do: :finnish
  # Finnish (alternate)
  defp get_charset(?5), do: :finnish
  # French
  defp get_charset(?R), do: :french
  # French Canadian
  defp get_charset(?Q), do: :french_canadian
  # German
  defp get_charset(?K), do: :german
  # Italian
  defp get_charset(?Y), do: :italian
  # Norwegian/Danish
  defp get_charset(?E), do: :norwegian_danish
  # Norwegian/Danish (alternate)
  defp get_charset(?6), do: :norwegian_danish

  # defp get_charset(?%5), do: :portuguese  # Portuguese - special case
  # Spanish
  defp get_charset(?Z), do: :spanish
  # Swedish
  defp get_charset(?H), do: :swedish
  # Swedish (alternate)
  defp get_charset(?7), do: :swedish
  # Swiss
  defp get_charset(?=), do: :swiss

  # defp get_charset(?<), do: :dec_supplemental    # DEC Supplemental - special char
  # defp get_charset(?>), do: :dec_technical       # DEC Technical - special char
  defp get_charset(_), do: nil
end
