defmodule Raxol.Terminal.CharacterSets do
  @moduledoc """
  Handles character set management and translation for the terminal emulator.

  This module defines the character set state, including designated G0-G3 sets
  and active GL/GR sets. It also provides translation tables for different
  character sets and functions to translate characters based on the active set.
  """

  alias Raxol.Terminal.CharacterSets.Translator
  require Logger

  # Default character set
  @default_charset :us_ascii

  # Define the structure for character set state
  defstruct [
    # Designated character sets (G0-G3)
    g_sets: %{
      g0: @default_charset,
      g1: @default_charset,
      g2: @default_charset,
      g3: @default_charset
    },
    # Active character sets (GL and GR mapping)
    gl: :g0,
    gr: :g1,
    # Currently active set for direct use
    active_set: @default_charset,
    # Single shift state (for SS2, SS3)
    single_shift: nil,
    # Locking shift state
    locked_shift: false
  ]

  @type charset_state :: %__MODULE__{
          g_sets: %{
            g0: atom(),
            g1: atom(),
            g2: atom(),
            g3: atom()
          },
          gl: atom(),
          gr: atom(),
          active_set: atom(),
          single_shift: atom() | nil,
          locked_shift: boolean()
        }

  @doc """
  Creates a new character set state with default values (US-ASCII).
  """
  @spec new() :: charset_state()
  def new() do
    %__MODULE__{}
  end

  @doc """
  Designates a character set for a specific target (G0-G3).
  `target_set` should be :g0, :g1, :g2, or :g3.
  `charset` is the atom representing the character set.
  """
  @spec set_designator(charset_state(), atom(), atom()) :: charset_state()
  def set_designator(%__MODULE__{g_sets: g_sets} = state, target_set, charset)
      when target_set in [:g0, :g1, :g2, :g3] do
    new_g_sets = Map.put(g_sets, target_set, charset)
    %{state | g_sets: new_g_sets}
  end

  def set_designator(state, _target_set, _charset) do
    Logger.warning("Invalid character set designator target")
    state
  end

  @doc """
  Invokes a designated character set as GL or GR.
  Handles SI (invokes G0 as GL), SO (invokes G1 as GL),
  ESC ~ (invokes G1 as GR), ESC } (invokes G2 as GR), ESC | (invokes G3 as GR).
  """
  @spec invoke_designator(charset_state(), atom()) :: charset_state()
  def invoke_designator(%__MODULE__{g_sets: g_sets} = state, gset_atom)
      when gset_atom in [:g0, :g1, :g2, :g3] do
    charset_to_activate = Map.get(g_sets, gset_atom, @default_charset)

    case gset_atom do
      :g0 ->
        # SI invokes G0 into GL
        %{state | gl: :g0, active_set: charset_to_activate}

      :g1 ->
        # SO invokes G1 into GL
        %{state | gl: :g1, active_set: charset_to_activate}

      :g2 ->
        # ESC } invokes G2 into GR
        %{state | gr: :g2, active_set: charset_to_activate}

      :g3 ->
        # ESC | invokes G3 into GR
        %{state | gr: :g3, active_set: charset_to_activate}
    end
  end

  def invoke_designator(state, _gset_atom) do
    Logger.warning("Invalid character set invocation target")
    state
  end

  @doc """
  Sets a single shift for the next character.
  SS2 invokes G2, SS3 invokes G3.
  """
  @spec set_single_shift(charset_state(), :ss2 | :ss3) :: charset_state()
  def set_single_shift(%__MODULE__{g_sets: g_sets} = state, :ss2) do
    charset = Map.get(g_sets, :g2, @default_charset)
    %{state | single_shift: charset}
  end

  def set_single_shift(%__MODULE__{g_sets: g_sets} = state, :ss3) do
    charset = Map.get(g_sets, :g3, @default_charset)
    %{state | single_shift: charset}
  end

  @doc """
  Clears any active single shift.
  """
  @spec clear_single_shift(charset_state()) :: charset_state()
  def clear_single_shift(state) do
    %{state | single_shift: nil}
  end

  @doc """
  Translates a codepoint based on the currently active character set in the state.
  """
  @spec translate_active(charset_state(), non_neg_integer()) :: non_neg_integer()
  def translate_active(%__MODULE__{single_shift: single_shift} = state, codepoint)
      when not is_nil(single_shift) do
    # Single shift takes precedence
    Translator.translate_codepoint(codepoint, single_shift)
  end

  def translate_active(%__MODULE__{active_set: active_set}, codepoint) do
    Translator.translate_codepoint(codepoint, active_set)
  end

  @doc """
  Translates a string using the current character set state.
  Handles single shifts correctly for the first applicable character.
  """
  @spec translate_string(charset_state(), String.t()) :: {String.t(), charset_state()}
  def translate_string(state, string) do
    if String.length(string) == 0 do
      {"", state}
    else
      first_char_binary = String.at(string, 0)
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
          active_charset = get_active_charset(next_state)
          translated_rest = Translator.translate_string(rest_of_string, active_charset)
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
  Translates a single character and returns the translated character and updated state.
  """
  @spec translate_char(charset_state(), char()) :: {char(), charset_state()}
  def translate_char(%__MODULE__{single_shift: single_shift} = state, char)
      when not is_nil(single_shift) do
    # Single shift takes precedence
    translated = Translator.translate_codepoint(char, single_shift)
    {translated, clear_single_shift(state)}
  end

  def translate_char(%__MODULE__{active_set: active_set} = state, char) do
    translated = Translator.translate_codepoint(char, active_set)
    {translated, state}
  end

  @doc """
  Gets the active character set based on the current state.
  """
  @spec get_active_charset(charset_state()) :: atom()
  def get_active_charset(%__MODULE__{single_shift: single_shift})
      when not is_nil(single_shift) do
    single_shift
  end

  def get_active_charset(%__MODULE__{active_set: active_set}) do
    active_set
  end
end
