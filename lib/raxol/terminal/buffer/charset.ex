defmodule Raxol.Terminal.Buffer.Charset do
  @moduledoc """
  Manages character set state and operations for the screen buffer.
  This module handles character set designations, G-sets, and single shifts.
  """

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
          g0: atom(),
          g1: atom(),
          g2: atom(),
          g3: atom(),
          gl: atom(),
          gr: atom(),
          single_shift: atom() | nil
        }

  defstruct [
    :g0,
    :g1,
    :g2,
    :g3,
    :gl,
    :gr,
    :single_shift
  ]

  @doc """
  Initializes a new charset state with default values.
  """
  @spec init() :: t()
  def init do
    %__MODULE__{
      g0: :us_ascii,
      g1: :us_ascii,
      g2: :us_ascii,
      g3: :us_ascii,
      gl: :g0,
      gr: :g1,
      single_shift: nil
    }
  end

  @doc """
  Designates a character set to a specific slot.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `slot` - The slot to designate (:g0, :g1, :g2, or :g3)
  * `charset` - The character set to designate

  ## Returns

  The updated screen buffer with new charset designation.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Charset.designate(buffer, :g0, :us_ascii)
      iex> Charset.get_designated(buffer, :g0)
      :us_ascii
  """
  @spec designate(ScreenBuffer.t(), atom(), atom()) :: ScreenBuffer.t()
  def designate(buffer, slot, charset) when slot in [:g0, :g1, :g2, :g3] do
    new_charset_state = %{buffer.charset_state | slot => charset}
    %{buffer | charset_state: new_charset_state}
  end

  @doc """
  Gets the designated character set for a specific slot.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `slot` - The slot to query (:g0, :g1, :g2, or :g3)

  ## Returns

  The designated character set for the slot.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Charset.get_designated(buffer, :g0)
      :us_ascii
  """
  @spec get_designated(ScreenBuffer.t(), atom()) :: atom()
  def get_designated(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    Map.get(buffer.charset_state, slot)
  end

  @doc """
  Invokes a G-set for the left or right side.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `slot` - The G-set to invoke (:g0, :g1, :g2, or :g3)

  ## Returns

  The updated screen buffer with new G-set invocation.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Charset.invoke_g_set(buffer, :g1)
      iex> Charset.get_current_g_set(buffer)
      :g1
  """
  @spec invoke_g_set(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def invoke_g_set(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    new_charset_state = %{buffer.charset_state | gl: slot}
    %{buffer | charset_state: new_charset_state}
  end

  @doc """
  Gets the current G-set.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The current G-set.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Charset.get_current_g_set(buffer)
      :g0
  """
  @spec get_current_g_set(ScreenBuffer.t()) :: atom()
  def get_current_g_set(buffer) do
    buffer.charset_state.gl
  end

  @doc """
  Applies a single shift to a specific G-set.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `slot` - The G-set to shift to (:g0, :g1, :g2, or :g3)

  ## Returns

  The updated screen buffer with new single shift.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Charset.apply_single_shift(buffer, :g1)
      iex> Charset.get_single_shift(buffer)
      :g1
  """
  @spec apply_single_shift(ScreenBuffer.t(), atom()) :: ScreenBuffer.t()
  def apply_single_shift(buffer, slot) when slot in [:g0, :g1, :g2, :g3] do
    new_charset_state = %{buffer.charset_state | single_shift: slot}
    %{buffer | charset_state: new_charset_state}
  end

  @doc """
  Gets the current single shift.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The current single shift or nil if none is active.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Charset.get_single_shift(buffer)
      nil
  """
  @spec get_single_shift(ScreenBuffer.t()) :: atom() | nil
  def get_single_shift(buffer) do
    buffer.charset_state.single_shift
  end

  @doc """
  Resets the charset state to default values.

  ## Parameters

  * `buffer` - The screen buffer to modify

  ## Returns

  The updated screen buffer with reset charset state.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = Charset.reset(buffer)
      iex> Charset.get_current_g_set(buffer)
      :g0
  """
  @spec reset(ScreenBuffer.t()) :: ScreenBuffer.t()
  def reset(buffer) do
    %{buffer | charset_state: init()}
  end

  @doc """
  Translates a character according to the current charset state.

  ## Parameters

  * `buffer` - The screen buffer to use for translation
  * `char` - The character to translate

  ## Returns

  The translated character.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Charset.translate_char(buffer, "A")
      "A"
  """
  @spec translate_char(ScreenBuffer.t(), String.t()) :: String.t()
  def translate_char(buffer, char) do
    charset = get_active_charset(buffer)
    apply_charset_translation(charset, char)
  end

  defp get_active_charset(buffer) do
    case get_single_shift(buffer) do
      nil -> get_designated(buffer, get_current_g_set(buffer))
      shift -> get_designated(buffer, shift)
    end
  end

  defp apply_charset_translation(charset, char) do
    %{
      us_ascii: char,
      dec_special_graphics: translate_dec_special_graphics(char),
      uk: translate_uk(char),
      us: translate_us(char),
      dutch: translate_dutch(char),
      finnish: translate_finnish(char),
      french: translate_french(char),
      french_canadian: translate_french_canadian(char),
      german: translate_german(char),
      italian: translate_italian(char),
      norwegian_danish: translate_norwegian_danish(char),
      spanish: translate_spanish(char),
      swedish: translate_swedish(char),
      swiss: translate_swiss(char)
    }[charset] || char
  end

  defp translate_dec_special_graphics(char) do
    %{
      "`" => "◆",
      "a" => "▒",
      "b" => "␉",
      "c" => "␌",
      "d" => "␍",
      "e" => "␊",
      "f" => "°",
      "g" => "±",
      "h" => "␤",
      "i" => "␋",
      "j" => "┘",
      "k" => "┐",
      "l" => "┌",
      "m" => "└",
      "n" => "┼",
      "o" => "⎺",
      "p" => "⎻",
      "q" => "─",
      "r" => "⎼",
      "s" => "⎽",
      "t" => "├",
      "u" => "┤",
      "v" => "┴",
      "w" => "┬",
      "x" => "│",
      "y" => "≤",
      "z" => "≥",
      "{" => "π",
      "|" => "≠",
      "}" => "£",
      "~" => "·"
    }[char] || char
  end

  defp translate_uk(char), do: char
  defp translate_us(char), do: char
  defp translate_dutch(char), do: char
  defp translate_finnish(char), do: char
  defp translate_french(char), do: char
  defp translate_french_canadian(char), do: char
  defp translate_german(char), do: char
  defp translate_italian(char), do: char
  defp translate_norwegian_danish(char), do: char
  defp translate_spanish(char), do: char
  defp translate_swedish(char), do: char
  defp translate_swiss(char), do: char
end
