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
          # single_shift will store the actual charset (:us_ascii, :german, etc.)
          # that is active for the next character due to SS2/SS3.
          # It's nil if no single shift is active.
          single_shift: charset() | nil,
          locked_shift: boolean()
        }

  defstruct g0: :us_ascii,
            g1: :us_ascii,
            g2: :us_ascii,
            g3: :us_ascii,
            gl: :g0,
            gr: :g1,
            # Stays as is, will hold the target charset
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
  Activates a single shift for the next character.
  SS2 invokes the G2 character set.
  SS3 invokes the G3 character set.
  """
  @spec set_single_shift(charset_state(), :ss2 | :ss3) :: charset_state()
  def set_single_shift(state, :ss2) do
    %{state | single_shift: state.g2}
  end

  def set_single_shift(state, :ss3) do
    %{state | single_shift: state.g3}
  end

  @doc """
  Clears any active single shift. This should be called after processing
  a character that was interpreted using a single-shifted charset.
  """
  @spec clear_single_shift(charset_state()) :: charset_state()
  def clear_single_shift(state) do
    %{state | single_shift: nil}
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
  Note: This function does not consume an active single shift.
  The caller is responsible for calling clear_single_shift after processing
  the character if a single shift was active.
  """
  @spec get_active_charset(charset_state()) :: charset()
  def get_active_charset(state) do
    cond do
      # If a single shift is active, it takes precedence
      state.single_shift != nil ->
        state.single_shift

      state.locked_shift ->
        # Get the charset designated to GR
        Map.get(state, state.gr)

      true ->
        # Get the charset designated to GL
        Map.get(state, state.gl)
    end
  end

  @doc """
  Translates a character based on the active character set.
  If a single shift was used, it returns the translated character
  and the new state with the single shift cleared. Otherwise,
  it returns the translated char and the original state.
  """
  @spec translate_char(charset_state(), char()) :: {char(), charset_state()}
  def translate_char(state, char) do
    active_charset = get_active_charset(state)
    translated = CharacterTranslations.translate_char(char, active_charset)

    new_state =
      if state.single_shift != nil do
        clear_single_shift(state)
      else
        state
      end

    {translated, new_state}
  end

  @doc """
  Translates a string using the current character set state.
  Handles single shifts correctly for the first applicable character.
  Returns the translated string and the final character set state.
  This function is more complex due to the stateful nature of single shifts
  per character. For precise control, process char by char using translate_char/2.
  """
  @spec translate_string(charset_state(), String.t()) ::
          {String.t(), charset_state()}
  def translate_string(state, string) do
    if String.length(string) == 0 do
      {"", state}
    else
      first_char_binary = String.at(string, 0)
      # Ensure char is an integer codepoint for translate_char
      first_char =
        if first_char_binary do
          String.to_charlist(first_char_binary) |> List.first()
        else
          nil
        end

      if first_char do
        {translated_first_char_code, next_state} =
          translate_char(state, first_char)

        translated_first_char_string = <<translated_first_char_code::utf8>>

        rest_of_string = String.slice(string, 1, String.length(string) - 1)

        if String.length(rest_of_string) > 0 do
          # The rest of the string is translated with the 'next_state',
          # which has single_shift consumed if it was active for the first char.
          # CharacterTranslations.translate_string takes the string and the charset atom.
          active_charset_for_rest = get_active_charset(next_state)

          translated_rest =
            CharacterTranslations.translate_string(
              rest_of_string,
              active_charset_for_rest
            )

          {translated_first_char_string <> translated_rest, next_state}
        else
          {translated_first_char_string, next_state}
        end
      else
        {"", state}
      end
    end
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
      # Return the new state
      new_state
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
