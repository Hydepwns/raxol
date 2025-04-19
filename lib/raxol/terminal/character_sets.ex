defmodule Raxol.Terminal.CharacterSets do
  @moduledoc """
  Handles character set management and translation for the terminal emulator.

  This module defines the character set state, including designated G0-G3 sets
  and active GL/GR sets. It also provides translation tables for different
  character sets and functions to translate characters based on the active set.
  """

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
    # GL maps to G0, G1, G2, or G3
    # GR maps to G0, G1, G2, or G3
    # We also track the currently active set for direct use (result of LS0, LS1, SS2, SS3 etc.)
    gl: :g0,
    # Default often maps GR to G1
    gr: :g1,
    # Initially GL (G0 which is US-ASCII)
    active_set: @default_charset
    # single_shift: nil # For SS2, SS3 state if needed
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
          active_set: atom()
          # single_shift: atom() | nil
        }

  @doc """
  Creates a new character set state with default values (US-ASCII).
  """
  @spec new() :: charset_state()
  def new() do
    # Use defaults defined in defstruct
    %__MODULE__{}
  end

  @doc """
  Designates a character set for a specific target (G0-G3).
  `target_set` should be :g0, :g1, :g2, or :g3.
  `charset` is the atom representing the character set (e.g., :us_ascii, :dec_special_graphics).
  """
  @spec set_designator(charset_state(), atom(), atom()) :: charset_state()
  def set_designator(%__MODULE__{g_sets: g_sets} = state, target_set, charset)
      when target_set in [:g0, :g1, :g2, :g3] do
    new_g_sets = Map.put(g_sets, target_set, charset)
    %{state | g_sets: new_g_sets}
  end

  # Handle invalid target_set atom
  def set_designator(state, _target_set, _charset) do
    # Log error or just return unchanged state
    state
  end

  @doc """
  Invokes a designated character set as GL or GR.
  Handles SI (invokes G0 as GL), SO (invokes G1 as GL),
  ESC ~ (invokes G1 as GR), ESC } (invokes G2 as GR), ESC | (invokes G3 as GR).
  Updates the `active_set` based on the new GL mapping.
  Note: This implementation assumes basic SO/SI for GL.
  More complex shift functions (LS*, SS*) modify `active_set` differently.
  """
  @spec invoke_designator(charset_state(), atom()) :: charset_state()
  def invoke_designator(%__MODULE__{g_sets: g_sets} = state, gset_atom)
      when gset_atom in [:g0, :g1, :g2, :g3] do
    # Determine the actual charset atom from the g_sets map
    _charset_to_activate = Map.get(g_sets, gset_atom, @default_charset)

    # Simple SO/SI model: Invoke G0/G1 into GL
    # A more complete model would handle LS/SS sequences and GR invocation
    case gset_atom do
      :g0 ->
        # SI invokes G0 into GL
        %{state | gl: :g0, active_set: Map.get(g_sets, :g0)}

      :g1 ->
        # SO invokes G1 into GL
        %{state | gl: :g1, active_set: Map.get(g_sets, :g1)}

      # TODO: Implement GR invocation logic (ESC ~, ESC }, ESC |) if needed
      # These would update state.gr
      # TODO: Implement Locking Shift (LS) and Single Shift (SS) logic
      # These would update state.active_set directly or via state.single_shift
      _ ->
        # For now, other invocations don't change GL/active_set
        state
    end
  end

  # Handle invalid invocation atom
  def invoke_designator(state, _gset_atom) do
    state
  end

  @doc """
  Translates a codepoint based on the *currently active* character set in the state.
  """
  # TODO: Update Emulator to call this function instead of the old translate/2
  @spec translate_active(charset_state(), non_neg_integer()) :: String.t()
  def translate_active(%__MODULE__{active_set: active_set}, codepoint) do
    # Delegate to the appropriate translation function based on the active set
    # The old translate/2 function needs to be adapted or replaced.
    # For now, let's assume a helper translate_codepoint/2 exists.
    translate_codepoint(codepoint, active_set)
  end

  @doc false
  # This is the old function, maybe keep it for direct translation?
  # Or rename/refactor into translate_codepoint/2 used by translate_active/2.
  def translate(char, charset) do
    case charset do
      :us_ascii -> char
      :latin1 -> translate_latin1(char)
      :latin2 -> translate_latin2(char)
      :latin3 -> translate_latin3(char)
      :latin4 -> translate_latin4(char)
      :latin5 -> translate_latin5(char)
      :latin6 -> translate_latin6(char)
      :latin7 -> translate_latin7(char)
      :latin8 -> translate_latin8(char)
      :latin9 -> translate_latin9(char)
      :latin10 -> translate_latin10(char)
      :latin11 -> translate_latin11(char)
      :latin12 -> translate_latin12(char)
      :latin13 -> translate_latin13(char)
      :latin14 -> translate_latin14(char)
      :latin15 -> translate_latin15(char)
      :uk -> translate_uk(char)
      :french -> translate_french(char)
      :german -> translate_german(char)
      :swedish -> translate_swedish(char)
      :swiss -> translate_swiss(char)
      :italian -> translate_italian(char)
      :spanish -> translate_spanish(char)
      :portuguese -> translate_portuguese(char)
      :japanese -> translate_japanese(char)
      :korean -> translate_korean(char)
      _ -> char
    end
  end

  # Maps a codepoint based on the target charset
  # Placeholder implementation - needs actual translation logic based on charset
  defp translate_codepoint(codepoint, _charset) do
    # Placeholder: return original codepoint for now
    # In a real implementation, you'd look up 'charset' and apply rules
    codepoint
  end

  # Latin-1 (ISO-8859-1) translation table
  # Maps control characters and special characters
  defp translate_latin1(char) do
    case char do
      # Control characters (0x00-0x1F)
      <<0x00>> -> " "
      <<0x01>> -> " "
      <<0x02>> -> " "
      <<0x03>> -> " "
      <<0x04>> -> " "
      <<0x05>> -> " "
      <<0x06>> -> " "
      <<0x07>> -> " "
      <<0x08>> -> " "
      <<0x09>> -> "\t"
      <<0x0A>> -> "\n"
      <<0x0B>> -> " "
      <<0x0C>> -> " "
      <<0x0D>> -> "\r"
      <<0x0E>> -> " "
      <<0x0F>> -> " "
      <<0x10>> -> " "
      <<0x11>> -> " "
      <<0x12>> -> " "
      <<0x13>> -> " "
      <<0x14>> -> " "
      <<0x15>> -> " "
      <<0x16>> -> " "
      <<0x17>> -> " "
      <<0x18>> -> " "
      <<0x19>> -> " "
      <<0x1A>> -> " "
      <<0x1B>> -> " "
      <<0x1C>> -> " "
      <<0x1D>> -> " "
      <<0x1E>> -> " "
      <<0x1F>> -> " "
      # Special characters (0x7F-0xFF)
      <<0x7F>> -> " "
      # Non-breaking space
      <<0xA0>> -> " "
      # Inverted exclamation mark
      <<0xA1>> -> "¡"
      # Cent sign
      <<0xA2>> -> "¢"
      # Pound sign
      <<0xA3>> -> "£"
      # Currency sign
      <<0xA4>> -> "¤"
      # Yen sign
      <<0xA5>> -> "¥"
      # Broken vertical bar
      <<0xA6>> -> "¦"
      # Section sign
      <<0xA7>> -> "§"
      # Diaeresis
      <<0xA8>> -> "¨"
      # Copyright sign
      <<0xA9>> -> "©"
      # Feminine ordinal indicator
      <<0xAA>> -> "ª"
      # Left-pointing double angle quotation mark
      <<0xAB>> -> "«"
      # Not sign
      <<0xAC>> -> "¬"
      # Soft hyphen
      <<0xAD>> -> "­"
      # Registered sign
      <<0xAE>> -> "®"
      # Macron
      <<0xAF>> -> "¯"
      # Degree sign
      <<0xB0>> -> "°"
      # Plus-minus sign
      <<0xB1>> -> "±"
      # Superscript two
      <<0xB2>> -> "²"
      # Superscript three
      <<0xB3>> -> "³"
      # Acute accent
      <<0xB4>> -> "´"
      # Micro sign
      <<0xB5>> -> "µ"
      # Pilcrow sign
      <<0xB6>> -> "¶"
      # Middle dot
      <<0xB7>> -> "·"
      # Cedilla
      <<0xB8>> -> "¸"
      # Superscript one
      <<0xB9>> -> "¹"
      # Masculine ordinal indicator
      <<0xBA>> -> "º"
      # Right-pointing double angle quotation mark
      <<0xBB>> -> "»"
      # Vulgar fraction one quarter
      <<0xBC>> -> "¼"
      # Vulgar fraction one half
      <<0xBD>> -> "½"
      # Vulgar fraction three quarters
      <<0xBE>> -> "¾"
      # Inverted question mark
      <<0xBF>> -> "¿"
      # Latin capital letter A with grave
      <<0xC0>> -> "À"
      # Latin capital letter A with acute
      <<0xC1>> -> "Á"
      # Latin capital letter A with circumflex
      <<0xC2>> -> "Â"
      # Latin capital letter A with tilde
      <<0xC3>> -> "Ã"
      # Latin capital letter A with diaeresis
      <<0xC4>> -> "Ä"
      # Latin capital letter A with ring above
      <<0xC5>> -> "Å"
      # Latin capital letter AE
      <<0xC6>> -> "Æ"
      # Latin capital letter C with cedilla
      <<0xC7>> -> "Ç"
      # Latin capital letter E with grave
      <<0xC8>> -> "È"
      # Latin capital letter E with acute
      <<0xC9>> -> "É"
      # Latin capital letter E with circumflex
      <<0xCA>> -> "Ê"
      # Latin capital letter E with diaeresis
      <<0xCB>> -> "Ë"
      # Latin capital letter I with grave
      <<0xCC>> -> "Ì"
      # Latin capital letter I with acute
      <<0xCD>> -> "Í"
      # Latin capital letter I with circumflex
      <<0xCE>> -> "Î"
      # Latin capital letter I with diaeresis
      <<0xCF>> -> "Ï"
      # Latin capital letter Eth
      <<0xD0>> -> "Ð"
      # Latin capital letter N with tilde
      <<0xD1>> -> "Ñ"
      # Latin capital letter O with grave
      <<0xD2>> -> "Ò"
      # Latin capital letter O with acute
      <<0xD3>> -> "Ó"
      # Latin capital letter O with circumflex
      <<0xD4>> -> "Ô"
      # Latin capital letter O with tilde
      <<0xD5>> -> "Õ"
      # Latin capital letter O with diaeresis
      <<0xD6>> -> "Ö"
      # Multiplication sign
      <<0xD7>> -> "×"
      # Latin capital letter O with stroke
      <<0xD8>> -> "Ø"
      # Latin capital letter U with grave
      <<0xD9>> -> "Ù"
      # Latin capital letter U with acute
      <<0xDA>> -> "Ú"
      # Latin capital letter U with circumflex
      <<0xDB>> -> "Û"
      # Latin capital letter U with diaeresis
      <<0xDC>> -> "Ü"
      # Latin capital letter Y with acute
      <<0xDD>> -> "Ý"
      # Latin capital letter Thorn
      <<0xDE>> -> "Þ"
      # Latin small letter sharp s
      <<0xDF>> -> "ß"
      # Latin small letter a with grave
      <<0xE0>> -> "à"
      # Latin small letter a with acute
      <<0xE1>> -> "á"
      # Latin small letter a with circumflex
      <<0xE2>> -> "â"
      # Latin small letter a with tilde
      <<0xE3>> -> "ã"
      # Latin small letter a with diaeresis
      <<0xE4>> -> "ä"
      # Latin small letter a with ring above
      <<0xE5>> -> "å"
      # Latin small letter ae
      <<0xE6>> -> "æ"
      # Latin small letter c with cedilla
      <<0xE7>> -> "ç"
      # Latin small letter e with grave
      <<0xE8>> -> "è"
      # Latin small letter e with acute
      <<0xE9>> -> "é"
      # Latin small letter e with circumflex
      <<0xEA>> -> "ê"
      # Latin small letter e with diaeresis
      <<0xEB>> -> "ë"
      # Latin small letter i with grave
      <<0xEC>> -> "ì"
      # Latin small letter i with acute
      <<0xED>> -> "í"
      # Latin small letter i with circumflex
      <<0xEE>> -> "î"
      # Latin small letter i with diaeresis
      <<0xEF>> -> "ï"
      # Latin small letter eth
      <<0xF0>> -> "ð"
      # Latin small letter n with tilde
      <<0xF1>> -> "ñ"
      # Latin small letter o with grave
      <<0xF2>> -> "ò"
      # Latin small letter o with acute
      <<0xF3>> -> "ó"
      # Latin small letter o with circumflex
      <<0xF4>> -> "ô"
      # Latin small letter o with tilde
      <<0xF5>> -> "õ"
      # Latin small letter o with diaeresis
      <<0xF6>> -> "ö"
      # Division sign
      <<0xF7>> -> "÷"
      # Latin small letter o with stroke
      <<0xF8>> -> "ø"
      # Latin small letter u with grave
      <<0xF9>> -> "ù"
      # Latin small letter u with acute
      <<0xFA>> -> "ú"
      # Latin small letter u with circumflex
      <<0xFB>> -> "û"
      # Latin small letter u with diaeresis
      <<0xFC>> -> "ü"
      # Latin small letter y with acute
      <<0xFD>> -> "ý"
      # Latin small letter thorn
      <<0xFE>> -> "þ"
      # Latin small letter y with diaeresis
      <<0xFF>> -> "ÿ"
      # Default case: return the character as is
      _ -> char
    end
  end

  # Latin-2 (ISO-8859-2) translation table
  # Maps Central European characters
  defp translate_latin2(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-2 character set
    char
  end

  # Latin-3 (ISO-8859-3) translation table
  # Maps Turkish characters
  defp translate_latin3(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-3 character set
    char
  end

  # Latin-4 (ISO-8859-4) translation table
  # Maps Baltic characters
  defp translate_latin4(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-4 character set
    char
  end

  # Latin-5 (ISO-8859-9) translation table
  # Maps Turkish characters
  defp translate_latin5(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-5 character set
    char
  end

  # Latin-6 (ISO-8859-10) translation table
  # Maps Nordic characters
  defp translate_latin6(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-6 character set
    char
  end

  # Latin-7 (ISO-8859-13) translation table
  # Maps Baltic characters
  defp translate_latin7(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-7 character set
    char
  end

  # Latin-8 (ISO-8859-14) translation table
  # Maps Celtic characters
  defp translate_latin8(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-8 character set
    char
  end

  # Latin-9 (ISO-8859-15) translation table
  # Maps Western European characters
  defp translate_latin9(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-9 character set
    char
  end

  # Latin-10 (ISO-8859-16) translation table
  # Maps South-Eastern European characters
  defp translate_latin10(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-10 character set
    char
  end

  # Latin-11 (ISO-8859-11) translation table
  # Maps Thai characters
  defp translate_latin11(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-11 character set
    char
  end

  # Latin-12 (ISO-8859-12) translation table
  # Maps Indian characters
  defp translate_latin12(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-12 character set
    char
  end

  # Latin-13 (ISO-8859-13) translation table
  # Maps Baltic characters
  defp translate_latin13(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-13 character set
    char
  end

  # Latin-14 (ISO-8859-14) translation table
  # Maps Celtic characters
  defp translate_latin14(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-14 character set
    char
  end

  # Latin-15 (ISO-8859-15) translation table
  # Maps Western European characters
  defp translate_latin15(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Latin-15 character set
    char
  end

  # UK translation table
  # Maps UK-specific characters
  defp translate_uk(char) do
    case char do
      # Add specific UK translations
      # Default case returns string
      _ -> <<char>>
    end
  end

  # French translation table
  # Maps French-specific characters
  defp translate_french(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the French character set
    char
  end

  # German translation table
  # Maps German-specific characters
  defp translate_german(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the German character set
    char
  end

  # Swedish translation table
  # Maps Swedish-specific characters
  defp translate_swedish(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Swedish character set
    char
  end

  # Swiss translation table
  # Maps Swiss-specific characters
  defp translate_swiss(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Swiss character set
    char
  end

  # Italian translation table
  # Maps Italian-specific characters
  defp translate_italian(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Italian character set
    char
  end

  # Spanish translation table
  # Maps Spanish-specific characters
  defp translate_spanish(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Spanish character set
    char
  end

  # Portuguese translation table
  # Maps Portuguese-specific characters
  defp translate_portuguese(char) do
    # For now, we'll just return the character as is
    # In a real implementation, we would translate based on the Portuguese character set
    char
  end

  # Japanese translation table
  # Maps Japanese-specific characters
  defp translate_japanese(char) do
    case char do
      # Add specific Japanese translations
      # Default case returns string
      _ -> <<char>>
    end
  end

  # Korean translation table
  # Maps Korean-specific characters
  defp translate_korean(char) do
    case char do
      # Add specific Korean translations
      # Default case returns string
      _ -> <<char>>
    end
  end
end
