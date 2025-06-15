defmodule Raxol.Terminal.Escape.Parsers.SCSParser do
  @moduledoc """
  Parser for Select Character Set (SCS) escape sequences.

  Handles sequences like:
  - ESC ( C -> Designate G0 as Charset C
  - ESC ) C -> Designate G1 as Charset C
  - ESC * C -> Designate G2 as Charset C
  - ESC + C -> Designate G3 as Charset C
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Escape.Parsers.BaseParser

  @doc """
  Parses a Select Character Set sequence.
  Returns {:ok, command, remaining} or {:incomplete, remaining} or {:error, reason, remaining}
  """
  @spec parse(char(), String.t()) ::
          {:ok, {:designate_charset, :g0 | :g1 | :g2 | :g3, atom()}, String.t()}
          | {:incomplete, String.t()}
          | {:error, atom(), String.t()}
  def parse(designator_char, <<charset_code, rest::binary>>) do
    with {:ok, target_g_set} <- designate_char_to_gset(designator_char),
         {:ok, charset_atom} <- charset_code_to_atom(charset_code) do
      {:ok, {:designate_charset, target_g_set, charset_atom}, rest}
    else
      {:error, reason} ->
        BaseParser.log_unknown_sequence("SCS", <<charset_code, rest::binary>>)
        {:error, reason, <<charset_code, rest::binary>>}
    end
  end

  def parse(_designator_char, "") do
    {:incomplete, ""}
  end

  @doc """
  Maps a designator character to its corresponding G-set.
  """
  @spec designate_char_to_gset(char()) ::
          {:ok, :g0 | :g1 | :g2 | :g3} | {:error, :invalid_designator}
  def designate_char_to_gset(?() do
    {:ok, :g0}
  end

  def designate_char_to_gset(?)) do
    {:ok, :g1}
  end

  def designate_char_to_gset(?*) do
    {:ok, :g2}
  end

  def designate_char_to_gset(?+) do
    {:ok, :g3}
  end

  def designate_char_to_gset(_) do
    {:error, :invalid_designator}
  end

  @doc """
  Maps a character code byte to its corresponding charset atom.
  Reference: https://vt100.net/docs/vt510-rm/SCS.html
  """
  @spec charset_code_to_atom(char()) ::
          {:ok, atom()} | {:error, :invalid_charset}
  def charset_code_to_atom(?B) do
    {:ok, :us_ascii}
  end

  def charset_code_to_atom(?0) do
    {:ok, :dec_special_graphics}
  end

  def charset_code_to_atom(?A) do
    {:ok, :uk}
  end

  def charset_code_to_atom(?<) do
    {:ok, :dec_supplemental}
  end

  def charset_code_to_atom(?>) do
    {:ok, :dec_technical}
  end

  def charset_code_to_atom(_) do
    {:error, :invalid_charset}
  end
end
