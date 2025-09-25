defmodule Raxol.Terminal.ANSI.CharacterSets do
  @moduledoc """
  Consolidated character set management for the terminal emulator.
  Combines: Handler, StateManager, Translator, and core CharacterSets functionality.
  Supports G0, G1, G2, G3 character sets and their switching operations.
  """

  defmodule Handler do
    @moduledoc """
    Handles character set control sequences and state changes.
    """

    alias Raxol.Terminal.ANSI.CharacterSets.StateManager

    @doc """
    Handles a character set control sequence.
    """
    def handle_sequence(state, sequence) do
      case sequence do
        # Designate G-sets
        [?/, code] ->
          handle_designation(state, 0, code)

        [?), code] ->
          handle_designation(state, 1, code)

        [?*, code] ->
          handle_designation(state, 2, code)

        [?+, code] ->
          handle_designation(state, 3, code)

        # Locking shifts
        [char] when char in [?N, ?O, ?P, ?Q] ->
          handle_locking_shift(state, char)

        # Single shifts
        [char] when char in [?R, ?S] ->
          handle_single_shift(state, char)

        # Invoke charsets
        [char] when char in [?T, ?U, ?V, ?W] ->
          handle_invoke(state, char)

        # Unknown sequence
        _ ->
          state
      end
    end

    defp handle_designation(state, gset_index, code) do
      designate_charset(state, gset_index, code)
    end

    defp handle_locking_shift(state, char) do
      case char do
        # LS2
        ?N -> StateManager.set_gl(state, :g2)
        # LS3
        ?O -> StateManager.set_gl(state, :g3)
        # LS2R
        ?P -> StateManager.set_gr(state, :g2)
        # LS3R
        ?Q -> StateManager.set_gr(state, :g3)
      end
    end

    defp handle_single_shift(state, char) do
      case char do
        # SS2
        ?R -> StateManager.set_single_shift(state, :g2)
        # SS3
        ?S -> StateManager.set_single_shift(state, :g3)
      end
    end

    defp handle_invoke(state, char) do
      case char do
        # LS0
        ?T -> StateManager.set_gl(state, :g0)
        # LS1
        ?U -> StateManager.set_gl(state, :g1)
        # LS0R
        ?V -> StateManager.set_gr(state, :g0)
        # LS1R
        ?W -> StateManager.set_gr(state, :g1)
      end
    end

    defp designate_charset(state, gset_index, code) do
      charset = code_to_charset(code)

      case gset_index do
        0 -> StateManager.set_g0(state, charset)
        1 -> StateManager.set_g1(state, charset)
        2 -> StateManager.set_g2(state, charset)
        3 -> StateManager.set_g3(state, charset)
        _ -> state
      end
    end

    defp code_to_charset(code) do
      case code do
        ?B -> :us_ascii
        ?0 -> :dec_special_graphics
        ?A -> :uk
        ?C -> :finnish
        ?R -> :french
        ?Q -> :french_canadian
        ?K -> :german
        ?Y -> :italian
        ?E -> :norwegian_danish
        ?6 -> :portuguese
        ?Z -> :spanish
        ?H -> :swedish
        ?= -> :swiss
        _ -> :us_ascii
      end
    end
  end

  defmodule StateManager do
    @moduledoc """
    Manages character set state and operations.
    """

    @type charset ::
            :us_ascii
            | :dec_special_graphics
            | :uk
            | :us
            | :finnish
            | :french
            | :french_canadian
            | :german
            | :italian
            | :norwegian_danish
            | :portuguese
            | :spanish
            | :swedish
            | :swiss

    @type charset_state :: %{
            active: charset(),
            single_shift: charset() | nil,
            g0: charset(),
            g1: charset(),
            g2: charset(),
            g3: charset(),
            gl: :g0 | :g1 | :g2 | :g3,
            gr: :g0 | :g1 | :g2 | :g3
          }

    @doc """
    Creates a new character set state with default values.
    """
    @spec new() :: charset_state()
    def new do
      %{
        active: :us_ascii,
        single_shift: nil,
        g0: :us_ascii,
        g1: :dec_special_graphics,
        g2: :us_ascii,
        g3: :us_ascii,
        gl: :g0,
        gr: :g1
      }
    end

    @doc """
    Sets the G0 character set.
    """
    @spec set_g0(charset_state(), charset()) :: charset_state()
    def set_g0(state, charset) do
      %{state | g0: charset}
      |> update_active()
    end

    @doc """
    Sets the G1 character set.
    """
    @spec set_g1(charset_state(), charset()) :: charset_state()
    def set_g1(state, charset) do
      %{state | g1: charset}
      |> update_active()
    end

    @doc """
    Sets the G2 character set.
    """
    @spec set_g2(charset_state(), charset()) :: charset_state()
    def set_g2(state, charset) do
      %{state | g2: charset}
      |> update_active()
    end

    @doc """
    Sets the G3 character set.
    """
    @spec set_g3(charset_state(), charset()) :: charset_state()
    def set_g3(state, charset) do
      %{state | g3: charset}
      |> update_active()
    end

    @doc """
    Sets the GL (graphics left) designation.
    """
    @spec set_gl(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
    def set_gl(state, gset) do
      %{state | gl: gset}
      |> update_active()
    end

    @doc """
    Sets the GR (graphics right) designation.
    """
    @spec set_gr(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
    def set_gr(state, gset) do
      %{state | gr: gset}
      |> update_active()
    end

    @doc """
    Sets a single shift character set.
    """
    @spec set_single_shift(charset_state(), charset()) :: charset_state()
    def set_single_shift(state, charset) do
      %{state | single_shift: charset}
      |> update_active()
    end

    @doc """
    Clears the single shift.
    """
    @spec clear_single_shift(charset_state()) :: charset_state()
    def clear_single_shift(state) do
      %{state | single_shift: nil}
      |> update_active()
    end

    @doc """
    Gets the current active character set.
    """
    @spec get_active(charset_state()) :: charset()
    def get_active(%{active: active}), do: active
    def get_active(_), do: :us_ascii

    @doc """
    Gets the active character set by resolving the current GL setting.
    Returns the actual charset, not the g-set reference.
    """
    def get_active_charset(state) do
      # Get the active g-set (gl setting)
      active_g_set = Map.get(state, :gl, :g0)
      # Resolve to the actual charset assigned to that g-set
      Map.get(state, active_g_set, :us_ascii)
    end

    @doc """
    Gets the single shift character set if any.
    """
    @spec get_single_shift(charset_state()) :: charset() | nil
    def get_single_shift(%{single_shift: single_shift}), do: single_shift

    # Updates the active character set based on current GL setting
    defp update_active(state) do
      active_charset =
        case state.gl do
          :g0 -> state.g0
          :g1 -> state.g1
          :g2 -> state.g2
          :g3 -> state.g3
        end

      %{state | active: active_charset}
    end

    @doc """
    Validates character set state.
    """
    def validate_state(state) when is_map(state) do
      required_keys = [:g0, :g1, :g2, :g3, :gl, :gr, :active]

      if Enum.all?(required_keys, &Map.has_key?(state, &1)) do
        {:ok, state}
      else
        {:error, :invalid_state}
      end
    end

    def validate_state(_), do: {:error, :invalid_state}
  end

  defmodule Translator do
    @moduledoc """
    Handles character set translations and mappings.
    """

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
      new_state = if single_shift do
        Map.put(state, :single_shift, nil)
      else
        state
      end

      {translated, new_state}
    end

    @doc """
    Translates a character using the active character set.
    """
    def translate_char(codepoint, active_set, single_shift)
        when is_integer(codepoint) do
      set = single_shift || active_set

      case set do
        :us_ascii -> codepoint
        :dec_special_graphics -> translate_dec_special_graphics(codepoint)
        :uk -> translate_uk(codepoint)
        :us -> translate_us(codepoint)
        :finnish -> translate_finnish(codepoint)
        :french -> translate_french(codepoint)
        :french_canadian -> translate_french_canadian(codepoint)
        :german -> translate_german(codepoint)
        :italian -> translate_italian(codepoint)
        :norwegian_danish -> translate_norwegian_danish(codepoint)
        :portuguese -> translate_portuguese(codepoint)
        :spanish -> translate_spanish(codepoint)
        :swedish -> translate_swedish(codepoint)
        :swiss -> translate_swiss(codepoint)
        _ -> codepoint
      end
    end

    # DEC Special Character Set Graphics
    defp translate_dec_special_graphics(codepoint) do
      case codepoint do
        # Line drawing characters
        # Diamond
        0x60 -> 0x25C6
        # Checkerboard
        0x61 -> 0x2592
        # HT
        0x62 -> 0x2409
        # FF
        0x63 -> 0x240C
        # CR
        0x64 -> 0x240D
        # LF
        0x65 -> 0x240A
        # Degree symbol
        0x66 -> 0x00B0
        # Plus/minus
        0x67 -> 0x00B1
        # NL
        0x68 -> 0x2424
        # VT
        0x69 -> 0x240B
        # Lower right corner
        0x6A -> 0x2518
        # Upper right corner
        0x6B -> 0x2510
        # Upper left corner
        0x6C -> 0x250C
        # Lower left corner
        0x6D -> 0x2514
        # Crossing lines
        0x6E -> 0x253C
        # Scan line 1
        0x6F -> 0x23BA
        # Scan line 3
        0x70 -> 0x23BB
        # Horizontal line
        0x71 -> 0x2500
        # Scan line 7
        0x72 -> 0x23BC
        # Scan line 9
        0x73 -> 0x23BD
        # Left "T"
        0x74 -> 0x251C
        # Right "T"
        0x75 -> 0x2524
        # Bottom "T"
        0x76 -> 0x2534
        # Top "T"
        0x77 -> 0x252C
        # Vertical line
        0x78 -> 0x2502
        # Less than or equal
        0x79 -> 0x2264
        # Greater than or equal
        0x7A -> 0x2265
        # Pi
        0x7B -> 0x03C0
        # Not equal
        0x7C -> 0x2260
        # UK pound
        0x7D -> 0x00A3
        # Bullet
        0x7E -> 0x00B7
        _ -> codepoint
      end
    end

    # UK Character Set (ISO 646-GB)
    defp translate_uk(codepoint) do
      case codepoint do
        # Pound sign
        0x23 -> 0x00A3
        _ -> codepoint
      end
    end

    # US Character Set
    defp translate_us(codepoint), do: codepoint

    # Finnish Character Set
    defp translate_finnish(codepoint) do
      case codepoint do
        # Ä
        0x5B -> 0x00C4
        # Ö
        0x5C -> 0x00D6
        # Å
        0x5D -> 0x00C5
        # Ü
        0x5E -> 0x00DC
        # é
        0x60 -> 0x00E9
        # ä
        0x7B -> 0x00E4
        # ö
        0x7C -> 0x00F6
        # å
        0x7D -> 0x00E5
        # ü
        0x7E -> 0x00FC
        _ -> codepoint
      end
    end

    # French Character Set
    defp translate_french(codepoint) do
      case codepoint do
        # £
        0x23 -> 0x00A3
        # à
        0x40 -> 0x00E0
        # °
        0x5B -> 0x00B0
        # ç
        0x5C -> 0x00E7
        # §
        0x5D -> 0x00A7
        # é
        0x7B -> 0x00E9
        # ù
        0x7C -> 0x00F9
        # è
        0x7D -> 0x00E8
        # ¨
        0x7E -> 0x00A8
        _ -> codepoint
      end
    end

    # French Canadian Character Set
    defp translate_french_canadian(codepoint) do
      case codepoint do
        # à
        0x40 -> 0x00E0
        # â
        0x5B -> 0x00E2
        # ç
        0x5C -> 0x00E7
        # ê
        0x5D -> 0x00EA
        # î
        0x5E -> 0x00EE
        # ô
        0x60 -> 0x00F4
        # é
        0x7B -> 0x00E9
        # ù
        0x7C -> 0x00F9
        # è
        0x7D -> 0x00E8
        # û
        0x7E -> 0x00FB
        _ -> codepoint
      end
    end

    # German Character Set
    defp translate_german(codepoint) do
      case codepoint do
        # §
        0x40 -> 0x00A7
        # Ä
        0x5B -> 0x00C4
        # Ö
        0x5C -> 0x00D6
        # Ü
        0x5D -> 0x00DC
        # ä
        0x7B -> 0x00E4
        # ö
        0x7C -> 0x00F6
        # ü
        0x7D -> 0x00FC
        # ß
        0x7E -> 0x00DF
        _ -> codepoint
      end
    end

    # Italian Character Set
    defp translate_italian(codepoint) do
      case codepoint do
        # £
        0x23 -> 0x00A3
        # §
        0x40 -> 0x00A7
        # °
        0x5B -> 0x00B0
        # ç
        0x5C -> 0x00E7
        # é
        0x5D -> 0x00E9
        # ù
        0x60 -> 0x00F9
        # à
        0x7B -> 0x00E0
        # ò
        0x7C -> 0x00F2
        # è
        0x7D -> 0x00E8
        # ì
        0x7E -> 0x00EC
        _ -> codepoint
      end
    end

    # Norwegian/Danish Character Set
    defp translate_norwegian_danish(codepoint) do
      case codepoint do
        # Ä
        0x40 -> 0x00C4
        # Æ
        0x5B -> 0x00C6
        # Ø
        0x5C -> 0x00D8
        # Å
        0x5D -> 0x00C5
        # Ü
        0x5E -> 0x00DC
        # ä
        0x60 -> 0x00E4
        # æ
        0x7B -> 0x00E6
        # ø
        0x7C -> 0x00F8
        # å
        0x7D -> 0x00E5
        # ü
        0x7E -> 0x00FC
        _ -> codepoint
      end
    end

    # Portuguese Character Set
    defp translate_portuguese(codepoint) do
      case codepoint do
        # Ã
        0x5B -> 0x00C3
        # Ç
        0x5C -> 0x00C7
        # Õ
        0x5D -> 0x00D5
        # ã
        0x7B -> 0x00E3
        # ç
        0x7C -> 0x00E7
        # õ
        0x7D -> 0x00F5
        _ -> codepoint
      end
    end

    # Spanish Character Set
    defp translate_spanish(codepoint) do
      case codepoint do
        # £
        0x23 -> 0x00A3
        # §
        0x40 -> 0x00A7
        # ¡
        0x5B -> 0x00A1
        # Ñ
        0x5C -> 0x00D1
        # ¿
        0x5D -> 0x00BF
        # °
        0x7B -> 0x00B0
        # ñ
        0x7C -> 0x00F1
        # ç
        0x7D -> 0x00E7
        _ -> codepoint
      end
    end

    # Swedish Character Set
    defp translate_swedish(codepoint) do
      case codepoint do
        # É
        0x40 -> 0x00C9
        # Ä
        0x5B -> 0x00C4
        # Ö
        0x5C -> 0x00D6
        # Å
        0x5D -> 0x00C5
        # Ü
        0x5E -> 0x00DC
        # é
        0x60 -> 0x00E9
        # ä
        0x7B -> 0x00E4
        # ö
        0x7C -> 0x00F6
        # å
        0x7D -> 0x00E5
        # ü
        0x7E -> 0x00FC
        _ -> codepoint
      end
    end

    # Swiss Character Set
    defp translate_swiss(codepoint) do
      case codepoint do
        # ù
        0x23 -> 0x00F9
        # à
        0x40 -> 0x00E0
        # é
        0x5B -> 0x00E9
        # ç
        0x5C -> 0x00E7
        # ê
        0x5D -> 0x00EA
        # î
        0x5E -> 0x00EE
        # è
        0x5F -> 0x00E8
        # ô
        0x60 -> 0x00F4
        # ä
        0x7B -> 0x00E4
        # ö
        0x7C -> 0x00F6
        # ü
        0x7D -> 0x00FC
        # û
        0x7E -> 0x00FB
        _ -> codepoint
      end
    end
  end

  # Main CharacterSets module functionality
  alias Raxol.Terminal.ANSI.CharacterSets.{Handler, StateManager, Translator}

  @type codepoint :: non_neg_integer()

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
          | :cyrillic
          | :arabic
          | :greek
          | :hebrew
          | :thai
          | :dec_special_graphics
          | :dec_supplemental_graphics
          | :dec_technical
          | :dec_multinational

  @doc """
  Switches the character set for a given G-set.
  """
  def switch_charset(emulator, charset, gset \\ :g0) do
    state = get_charset_state(emulator)

    new_state =
      case gset do
        :g0 -> StateManager.set_g0(state, charset)
        :g1 -> StateManager.set_g1(state, charset)
        :g2 -> StateManager.set_g2(state, charset)
        :g3 -> StateManager.set_g3(state, charset)
        _ -> state
      end

    put_charset_state(emulator, new_state)
  end

  @doc """
  Translates a character using the current character set state.
  """
  def translate_character(emulator, char) when is_integer(char) do
    state = get_charset_state(emulator)
    active = StateManager.get_active(state)
    single_shift = StateManager.get_single_shift(state)

    Translator.translate_char(char, active, single_shift)
  end

  @doc """
  Handles a character set control sequence.
  """
  def handle_control_sequence(emulator, sequence) do
    state = get_charset_state(emulator)
    new_state = Handler.handle_sequence(state, sequence)
    put_charset_state(emulator, new_state)
  end

  @doc """
  Creates a new character set state.
  """
  def new_state, do: StateManager.new()

  # Private helper functions
  defp get_charset_state(emulator) do
    Map.get(emulator, :charset_state, StateManager.new())
  end

  defp put_charset_state(emulator, state) do
    Map.put(emulator, :charset_state, state)
  end

  # Convenience delegates for backward compatibility
  defdelegate handle_sequence(state, sequence), to: Handler

  defdelegate translate_char(codepoint, active_set, single_shift),
    to: Translator

  # Note: translate_char/2 now returns {translated_char, new_state} tuple
  defdelegate translate_char(codepoint, state), to: Translator
  defdelegate new(), to: StateManager
  defdelegate set_g0(state, charset), to: StateManager
  defdelegate set_g1(state, charset), to: StateManager
  defdelegate get_active(state), to: StateManager
  defdelegate get_active_charset(state), to: StateManager

  @doc """
  Translates a string using the active character set.
  """
  def translate_string(string, charset_state) when is_binary(string) do
    {chars, _final_state} =
      string
      |> String.to_charlist()
      |> Enum.map_reduce(charset_state, fn codepoint, state ->
        {translated, new_state} = Translator.translate_char(codepoint, state)
        {translated, new_state}
      end)

    List.to_string(chars)
  end

  @doc """
  Designates a character set for a G-set.
  """
  def designate_charset(state, gset_index, charset_code) do
    # Map gset index to the appropriate character set designator
    designator = case gset_index do
      :g0 -> ?(
      :g1 -> ?)
      :g2 -> ?*
      :g3 -> ?+
      _ -> ?(  # Default to G0
    end
    Handler.handle_sequence(state, [designator, charset_code])
  end

  @doc """
  Invokes a character set designator.
  """
  def invoke_designator(state, gset) do
    case gset do
      :g0 -> StateManager.set_gl(state, :g0)
      :g1 -> StateManager.set_gl(state, :g1)
      :g2 -> StateManager.set_gl(state, :g2)
      :g3 -> StateManager.set_gl(state, :g3)
      _ -> state
    end
  end
end
