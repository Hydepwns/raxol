defmodule Raxol.Terminal.ANSI.CharacterSets.Translator do
  @moduledoc """
  Handles character set translations and mappings.
  Delegates per-charset data lookups to CharsetData.
  """

  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.CharacterSets.CharsetData}
  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.CharacterSets.StateManager}

  alias Raxol.Terminal.ANSI.CharacterSets.{CharsetData, StateManager}

  @doc """
  Translates a character using the active character set (2-parameter version).
  Returns a tuple of {translated_char, new_charset_state}.
  """
  def translate_char(codepoint, state)
      when is_integer(codepoint) and is_map(state) do
    active_set = StateManager.get_active(state)
    single_shift = Map.get(state, :single_shift)
    translated = translate_char(codepoint, active_set, single_shift)

    # Clear single shift after use
    new_state =
      if single_shift do
        Map.put(state, :single_shift, nil)
      else
        state
      end

    {translated, new_state}
  end

  @doc """
  Translates a character using the named character set and optional single shift.
  """
  def translate_char(codepoint, active_set, single_shift)
      when is_integer(codepoint) do
    set = single_shift || active_set
    charset_name = StateManager.resolve_charset_name(set)
    CharsetData.translate(codepoint, charset_name)
  end

  @doc """
  Translates a string using the specified character set and single shift.
  """
  def translate_string(string, charset, single_shift)
      when is_binary(string) do
    string
    |> String.to_charlist()
    |> Enum.map(&translate_char(&1, charset, single_shift))
    |> List.to_string()
  end
end
