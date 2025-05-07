defmodule Raxol.Terminal.ANSI.CharacterSets do
  @moduledoc """
  Manages character set switching and translation for the terminal emulator.
  Supports G0, G1, G2, G3 character sets and their switching operations.
  """

  alias Raxol.Terminal.ANSI.CharacterTranslations
  alias Logger

  @type charset ::
          :us_ascii
          | :uk
          | :french
          | :german
          | :swedish
          | :swiss
          | :italian
          | :spanish
          | :portuguese
          | :japanese
          | :korean
          | :latin1
          | :latin2
          | :latin3
          | :latin4
          | :latin5
          | :latin6
          | :latin7
          | :latin8
          | :latin9
          | :latin10
          | :latin11
          | :latin12
          | :latin13
          | :latin14
          | :latin15

  @type gset_name :: :g0 | :g1 | :g2 | :g3
  @type gl_gr_target :: :gl | :gr

  @type charset_state :: %__MODULE__{
          g0: charset(),
          g1: charset(),
          g2: charset(),
          g3: charset(),
          gl: gset_name(),
          gr: gset_name(),
          single_shift: char() | nil,
          locked_shift: boolean()
        }

  defstruct g0: :us_ascii,
            g1: :us_ascii,
            g2: :us_ascii,
            g3: :us_ascii,
            gl: :g0,
            gr: :g1,
            single_shift: nil,
            locked_shift: false

  @doc """
  Creates a new character set state with default values.
  """
  @spec new() :: charset_state()
  def new() do
    %__MODULE__{}
  end

  @doc """
  Switches the specified character set to the given charset.
  """
  @spec switch_charset(charset_state(), :g0 | :g1 | :g2 | :g3, charset()) ::
          charset_state()
  def switch_charset(state, set, charset) do
    %{state | set => charset}
  end

  @doc """
  Sets the GL (left) character set.
  """
  @spec set_gl(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
  def set_gl(state, set) do
    %{state | gl: set}
  end

  @doc """
  Sets the GR (right) character set.
  """
  @spec set_gr(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
  def set_gr(state, set) do
    %{state | gr: set}
  end

  @doc """
  Gets the active character set based on the current state.
  """
  @spec get_active_charset(charset_state()) :: charset()
  def get_active_charset(state) do
    cond do
      state.locked_shift ->
        Map.get(state, state.gr)

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

  @doc """
  Designates a character set for a specific G-set (G0-G3).
  `gset_index` is 0, 1, 2, or 3.
  `charset_code` is the character byte following ESC (, ESC ), ESC *, or ESC +.
  """
  @spec designate_charset(charset_state(), 0..3, byte()) :: charset_state()
  def designate_charset(state, gset_index, charset_code) do
    charset_atom = charset_code_to_atom(charset_code)
    target_g_set = index_to_gset(gset_index)

    if charset_atom && target_g_set do
      # Assign the result of Map.put back
      new_state = Map.put(state, target_g_set, charset_atom)
      new_state # Return the new state
    else
      # Log or ignore unknown charset code / gset index
      state
    end
  end

  @doc """
  Invokes a character set as the GL (left) character set.
  This is used by SI/SO (Shift In/Shift Out) control codes.

  ## Examples

      iex> state = Raxol.Terminal.ANSI.CharacterSets.new()
      iex> state = Raxol.Terminal.ANSI.CharacterSets.switch_charset(state, :g1, :dec_special_graphics)
      iex> state = Raxol.Terminal.ANSI.CharacterSets.invoke_charset(state, :g1)
      iex> state.gl
      :g1
  """
  @spec invoke_charset(charset_state(), :g0 | :g1 | :g2 | :g3) ::
          charset_state()
  def invoke_charset(state, gset) when gset in [:g0, :g1, :g2, :g3] do
    # Set the specified G-set as the GL (left) charset
    %{state | gl: gset}
  end

  # --- Private Helpers ---

  # Map G-set index (0-3) to map key (:g0-:g3)
  defp index_to_gset(0), do: :g0
  defp index_to_gset(1), do: :g1
  defp index_to_gset(2), do: :g2
  defp index_to_gset(3), do: :g3
  defp index_to_gset(_), do: nil

  # Map character code byte to charset atom (Based on escape_sequence.ex)
  defp charset_code_to_atom(?B), do: :us_ascii
  defp charset_code_to_atom(?0), do: :dec_special_graphics
  defp charset_code_to_atom(?A), do: :uk
  # Often same as US ASCII initially
  defp charset_code_to_atom(?<), do: :dec_supplemental
  defp charset_code_to_atom(?>), do: :dec_technical
  # TODO: Add mappings for other national/special charsets (?F, ?K, etc.)
  # Return nil for unknown codes
  defp charset_code_to_atom(_), do: nil
end
