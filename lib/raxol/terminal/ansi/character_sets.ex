defmodule Raxol.Terminal.ANSI.CharacterSets do
  @moduledoc """
  Manages character set switching and translation for the terminal emulator.
  Supports G0, G1, G2, G3 character sets and their switching operations.
  """

  alias Raxol.Terminal.ANSI.CharacterTranslations

  @type charset :: :us_ascii | :uk | :french | :german | :swedish | :swiss | :italian |
                  :spanish | :portuguese | :japanese | :korean | :latin1 | :latin2 |
                  :latin3 | :latin4 | :latin5 | :latin6 | :latin7 | :latin8 | :latin9 |
                  :latin10 | :latin11 | :latin12 | :latin13 | :latin14 | :latin15

  @type charset_state :: %{
    g0: charset(),
    g1: charset(),
    g2: charset(),
    g3: charset(),
    gl: :g0 | :g1 | :g2 | :g3,
    gr: :g0 | :g1 | :g2 | :g3,
    single_shift: :g0 | :g1 | :g2 | :g3 | nil,
    locked_shift: boolean()
  }

  @doc """
  Creates a new character set state with default values.
  """
  @spec new() :: %{
    g0: :us_ascii,
    g1: :us_ascii,
    g2: :us_ascii,
    g3: :us_ascii,
    gl: :g0,
    gr: :g1,
    single_shift: nil,
    locked_shift: false
  }
  def new do
    %{
      g0: :us_ascii,
      g1: :us_ascii,
      g2: :us_ascii,
      g3: :us_ascii,
      gl: :g0,
      gr: :g1,
      single_shift: nil,
      locked_shift: false
    }
  end

  @doc """
  Switches the specified character set to the given charset.
  """
  @spec switch_charset(charset_state(), :g0 | :g1 | :g2 | :g3, charset()) :: charset_state()
  def switch_charset(state, set, charset) do
    Map.put(state, set, charset)
  end

  @doc """
  Sets the GL (left) character set.
  """
  @spec set_gl(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
  def set_gl(state, set) do
    Map.put(state, :gl, set)
  end

  @doc """
  Sets the GR (right) character set.
  """
  @spec set_gr(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
  def set_gr(state, set) do
    Map.put(state, :gr, set)
  end

  @doc """
  Sets the single shift character set.
  """
  @spec set_single_shift(charset_state(), :g0 | :g1 | :g2 | :g3 | nil) :: charset_state()
  def set_single_shift(state, set) do
    Map.put(state, :single_shift, set)
  end

  @doc """
  Gets the active character set based on the current state.
  """
  @spec get_active_charset(charset_state()) :: charset()
  def get_active_charset(state) do
    cond do
      state.locked_shift ->
        Map.get(state, state.gl)
      state.single_shift != nil ->
        Map.get(state, state.single_shift)
      true ->
        Map.get(state, state.gl)
    end
  end

  @doc """
  Translates a character based on the active character set.
  """
  @spec translate_char(charset_state(), char()) :: char()
  def translate_char(state, char) do
    active_charset = get_active_charset(state)
    CharacterTranslations.translate_char(char, active_charset)
  end

  @doc """
  Translates a string using the current character set.
  """
  @spec translate_string(charset_state(), String.t()) :: String.t()
  def translate_string(state, string) do
    active_charset = get_active_charset(state)
    CharacterTranslations.translate_string(string, active_charset)
  end
end
