defmodule Raxol.Terminal.ANSI.CharacterSets do
  @moduledoc """
  Manages character set switching and translation for the terminal emulator.
  Supports G0, G1, G2, G3 character sets and their switching operations.
  """

  alias Raxol.Terminal.ANSI.CharacterSets.{
    ASCII,
    DEC,
    UK
  }

  alias Raxol.Terminal.ANSI.CharacterSets.Translator

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
          | :dec_supplemental
          | :dec_technical
          | :dec_special_graphics
          | :dec_supplementary
          | :dec_supplemental_graphics
          | :dec_supplemental_technical

  @type gset_name :: :g0 | :g1 | :g2 | :g3
  @type gl_gr_target :: :gl | :gr

  @type charset_state :: %{
          g0: module(),
          g1: module(),
          g2: module(),
          g3: module(),
          current: module(),
          gl: gset_name(),
          gr: gset_name(),
          # single_shift will store the actual charset (:us_ascii, :german, etc.)
          # that is active for the next character due to SS2/SS3.
          # It's nil if no single shift is active.
          single_shift: module() | nil,
          locked_shift: boolean()
        }

  @doc """
  Creates a new character set state with default values.
  """
  def new do
    %{
      g0: ASCII,
      g1: DEC,
      g2: UK,
      g3: UK,
      current: ASCII,
      gl: :g0,
      gr: :g1,
      single_shift: nil,
      locked_shift: false
    }
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
  @spec switch_charset(charset_state(), :g0 | :g1 | :g2 | :g3, module()) ::
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
  @spec get_active_charset(charset_state()) :: atom()
  def get_active_charset(%{single_shift: single_shift} = _state)
      when single_shift != nil do
    single_shift
  end

  def get_active_charset(%{active: active} = _state) do
    active
  end

  def get_active_charset(%{locked_shift: true, gr: gr} = state) do
    get_charset_for_gset(state, gr)
  end

  def get_active_charset(%{gl: gl} = state) do
    get_charset_for_gset(state, gl)
  end

  def get_active_charset(state) do
    get_charset_for_gset(state, Map.get(state, :gl, :g0))
  end

  defp get_charset_for_gset(state, gset) do
    Map.get(state, gset, ASCII)
  end

  defp module_to_atom(module_or_atom) do
    case module_or_atom do
      ASCII -> :us_ascii
      DEC -> :dec_special_graphics
      UK -> :uk
      :us_ascii -> :us_ascii
      :dec_special_graphics -> :dec_special_graphics
      :uk -> :uk
      _ -> :us_ascii
    end
  end

  @doc """
  Translates a character using the active character set.
  Returns {codepoint, new_state} as expected by the tests.
  """
  @spec translate_char(codepoint, charset_state()) ::
          {codepoint(), charset_state()}
  def translate_char(codepoint, state) when is_integer(codepoint) do
    active_charset = get_active_charset(state)
    charset_atom = module_to_atom(active_charset)

    single_shift_atom =
      case state.single_shift do
        nil -> nil
        mod -> module_to_atom(mod)
      end

    result =
      Translator.translate_char(
        codepoint,
        charset_atom,
        single_shift_atom
      )

    new_state = clear_single_shift(state)
    {result, new_state}
  end

  # Handle case where arguments are swapped (state, codepoint)
  def translate_char(state, codepoint) when is_integer(codepoint) do
    translate_char(codepoint, state)
  end

  # Helper for just the codepoint value
  @spec translate_char_value(codepoint, charset_state()) :: codepoint()
  def translate_char_value(codepoint, state) do
    {value, _} = translate_char(codepoint, state)
    value
  end

  @doc """
  Translates a string using the active character set.
  """
  @spec translate_string(String.t(), charset_state()) :: String.t()
  def translate_string(string, state) do
    active_charset = get_active_charset(state)
    charset_atom = module_to_atom(active_charset)

    single_shift_atom =
      case state.single_shift do
        nil -> nil
        mod -> module_to_atom(mod)
      end

    Translator.translate_string(
      string,
      charset_atom,
      single_shift_atom
    )
  end

  @doc """
  Sets the active character set.
  """
  @spec set_active(charset_state(), module()) :: charset_state()
  def set_active(state, set) do
    %{state | current: set}
  end

  @doc """
  Sets the locking shift character set.
  """
  @spec set_locking_shift(charset_state(), module()) :: charset_state()
  def set_locking_shift(state, _set) do
    %{state | locked_shift: true}
  end

  @doc """
  Sets the character set designator.
  """
  @spec set_designator(charset_state(), :g0 | :g1 | :g2 | :g3, module()) ::
          charset_state()
  def set_designator(state, designator, set) do
    case designator do
      :G0 -> %{state | g0: set}
      :G1 -> %{state | g1: set}
      :G2 -> %{state | g2: set}
      :G3 -> %{state | g3: set}
      _ -> state
    end
  end

  @doc """
  Map G-set index (0-3) to map key (:g0-:g3).
  Public for use in tests and other modules.
  """
  def index_to_gset(0), do: :g0
  def index_to_gset(1), do: :g1
  def index_to_gset(2), do: :g2
  def index_to_gset(3), do: :g3
  def index_to_gset(_), do: nil

  @doc """
  Map character code byte to charset atom (Based on escape_sequence.ex).
  Public for use in tests and other modules.
  """
  def charset_code_to_atom(?B), do: :us_ascii
  def charset_code_to_atom(?0), do: :dec_special_graphics
  def charset_code_to_atom(?A), do: :uk
  # Often same as US ASCII initially
  def charset_code_to_atom(?<), do: :dec_supplemental
  def charset_code_to_atom(?>), do: :dec_technical
  def charset_code_to_atom(?F), do: :german
  def charset_code_to_atom(?K), do: :swedish
  def charset_code_to_atom(?L), do: :czech_sorbian
  def charset_code_to_atom(?M), do: :danish_norwegian
  def charset_code_to_atom(?N), do: :portuguese
  def charset_code_to_atom(?O), do: :icelandic
  def charset_code_to_atom(?P), do: :polish
  def charset_code_to_atom(?Q), do: :romanian
  def charset_code_to_atom(?R), do: :chinese_simplified
  def charset_code_to_atom(?S), do: :chinese_traditional
  def charset_code_to_atom(?T), do: :greek
  def charset_code_to_atom(?U), do: :hebrew
  def charset_code_to_atom(?V), do: :turkish
  def charset_code_to_atom(?W), do: :vietnamese
  def charset_code_to_atom(?X), do: :greek_polytonic
  def charset_code_to_atom(?Y), do: :yiddish
  def charset_code_to_atom(?Z), do: :japanese
  # Return nil for unknown codes
  def charset_code_to_atom(_), do: nil

  @doc """
  Map character code byte to charset module.
  """
  # Based on typical VT100/VT220 assignments for SCS
  # ASCII (typically designated by ?B)
  def charset_code_to_module(?B), do: Raxol.Terminal.ANSI.CharacterSets.ASCII
  # DEC Special Graphics and Character Set (typically designated by ?0)
  def charset_code_to_module(?0), do: Raxol.Terminal.ANSI.CharacterSets.DEC
  # UK National Character Set (typically designated by ?A)
  def charset_code_to_module(?A), do: Raxol.Terminal.ANSI.CharacterSets.UK
  # DEC Supplemental (often ?<) - Placeholder, actual module may vary
  def charset_code_to_module(?<), do: Raxol.Terminal.ANSI.CharacterSets.DEC
  # DEC Technical (often ?>) - Placeholder, actual module may vary
  def charset_code_to_module(?>),
    do: Raxol.Terminal.ANSI.CharacterSets.DEC

  # Add other specific mappings as needed based on actual available modules
  # For codes mentioned in tests if they differ or need specific modules:
  # For "1" -> :dec_supplementary. Need a module for this.
  # For "16" -> :dec_special_graphics. ?0 already maps to DEC.
  # For Portuguese code (?' or ?I in StateManager)
  # def charset_code_to_module(?'), do: Raxol.Terminal.ANSI.CharacterSets.Portuguese # If such a module exists
  # def charset_code_to_module(??), do: Raxol.Terminal.ANSI.CharacterSets.DECTechnical # If such a module exists
  # Default for unmapped codes
  def charset_code_to_module(_), do: nil

  @doc """
  Invokes a character set designator into GL or GR.
  By default, invokes into GL (left). If the second argument is :gr, invokes into GR (right).
  """
  @spec invoke_designator(charset_state(), :g0 | :g1 | :g2 | :g3, :gl | :gr) ::
          charset_state()
  def invoke_designator(state, gset, target \\ :gl)
      when gset in [:g0, :g1, :g2, :g3] do
    case target do
      :gl -> %{state | gl: gset}
      :gr -> %{state | gr: gset}
      _ -> state
    end
  end

  @doc """
  Delegates to Handler.designate_charset/3 for designating a character set for a specific G-set.
  """
  def designate_charset(state, gset_index, code) do
    Raxol.Terminal.ANSI.CharacterSets.Handler.designate_charset(
      state,
      gset_index,
      code
    )
  end

  @typedoc """
  Character set state struct for terminal emulation (G0-G3, GL/GR, single/locked shift).
  """
  @type t :: charset_state()
end

defmodule Raxol.Terminal.ANSI.CharacterSets.ASCII do
  @moduledoc "ASCII character set translation module."
  def translate_char(codepoint), do: codepoint
  def translate_string(string), do: string
end

defmodule Raxol.Terminal.ANSI.CharacterSets.DEC do
  @moduledoc "DEC character set translation module."
  def translate_char(codepoint), do: codepoint
  def translate_string(string), do: string
end

defmodule Raxol.Terminal.ANSI.CharacterSets.UK do
  @moduledoc "UK character set translation module."
  def translate_char(codepoint), do: codepoint
  def translate_string(string), do: string
end
