defmodule Raxol.Parser do
  @moduledoc """
  Compatibility layer for ANSI sequence parsing.

  This module provides a simplified API for parsing ANSI escape sequences.
  Delegates to `Raxol.Terminal.ANSI.Parser` for the actual implementation.

  ## Example

      {:ok, tokens} = Raxol.Parser.parse("\e[31mHello\e[0m")
      # => {:ok, [{:csi, "31", "m"}, {:text, "Hello"}, {:csi, "0", "m"}]}
  """

  alias Raxol.Terminal.ANSI.Parser, as: ANSIParser

  @doc """
  Parse an ANSI escape sequence string.

  Returns `{:ok, tokens}` on success where tokens is a list of parsed elements.

  ## Examples

      iex> Raxol.Parser.parse("\e[31mRed\e[0m")
      {:ok, [{:csi, "31", "m"}, {:text, "Red"}, {:csi, "0", "m"}]}

      iex> Raxol.Parser.parse("plain text")
      {:ok, [{:text, "plain text"}]}
  """
  @spec parse(binary()) :: {:ok, list()} | {:error, term()}
  def parse(input) when is_binary(input) do
    {:ok, ANSIParser.parse(input)}
  end

  def parse(_), do: {:error, :invalid_input}

  @doc """
  Parse an ANSI escape sequence string, raising on error.

  ## Examples

      iex> Raxol.Parser.parse!("\e[31mRed\e[0m")
      [{:csi, "31", "m"}, {:text, "Red"}, {:csi, "0", "m"}]
  """
  @type token ::
          {:text, binary()}
          | {:escape, binary()}
          | {:csi, binary(), binary()}
          | {:osc, binary()}
          | {:dcs, binary()}

  @spec parse!(binary()) :: [token()]
  def parse!(input) when is_binary(input) do
    ANSIParser.parse(input)
  end
end
