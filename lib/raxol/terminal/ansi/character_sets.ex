defmodule Raxol.Terminal.ANSI.CharacterSets do
  @moduledoc """
  Manages character set switching and translation for the terminal emulator.
  Supports G0, G1, G2, G3 character sets and their switching operations.
  """

  alias Raxol.Terminal.ANSI.CharacterTranslations
  alias Logger
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
  Translates a character using the active character set.
  """
  @spec translate_char(codepoint, charset_state()) :: char()
  def translate_char(codepoint, state) do
    Translator.translate_char(codepoint, get_active_charset(state), state.single_shift)
  end

  @doc """
  Translates a string using the active character set.
  """
  @spec translate_string(String.t(), charset_state()) :: String.t()
  def translate_string(string, state) do
    Translator.translate_string(string, get_active_charset(state), state.single_shift)
  end

  @doc """
  Sets the active character set.
  """
  @spec set_active(charset_state(), charset()) :: charset_state()
  def set_active(state, set) do
    %{state | active: set}
  end

  @doc """
  Sets the locking shift character set.
  """
  @spec set_locking_shift(charset_state(), charset()) :: charset_state()
  def set_locking_shift(state, _set) do
    %{state | locked_shift: true}
  end

  @doc """
  Sets the character set designator.
  """
  @spec set_designator(charset_state(), :g0 | :g1 | :g2 | :g3, charset()) :: charset_state()
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
  Invokes a character set designator.
  """
  @spec invoke_designator(charset_state(), :g0 | :g1 | :g2 | :g3) :: charset_state()
  def invoke_designator(state, gset) when gset in [:g0, :g1, :g2, :g3] do
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
