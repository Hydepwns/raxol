defmodule Raxol.Terminal.ANSI.CharacterSets do
  @moduledoc """
  Consolidated character set management for the terminal emulator.
  Combines: Handler, StateManager, Translator, and core CharacterSets functionality.
  Supports G0, G1, G2, G3 character sets and their switching operations.

  Sub-modules:
  - `CharacterSets.Handler`     -- control sequence handling
  - `CharacterSets.StateManager` -- G-set state management
  - `CharacterSets.Translator`   -- codepoint translation
  - `CharacterSets.CharsetData`  -- per-charset translation maps
  """

  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.CharacterSets.Handler}
  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.CharacterSets.StateManager}
  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.CharacterSets.Translator}

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
  Switches the character set for a given G-set in a charset state map.
  """
  def switch_charset(%{g0: _} = state, gset, charset_module \\ :us_ascii)
      when is_atom(gset) do
    state
    |> set_gset(gset, charset_module)
    |> StateManager.update_active()
  end

  @doc """
  Switches the character set for a given G-set in an emulator.
  """
  def switch_charset_emulator(emulator, charset, gset \\ :g0) do
    emulator
    |> get_charset_state()
    |> set_gset_via_manager(gset, charset)
    |> then(&put_charset_state(emulator, &1))
  end

  defp set_gset(state, :g0, charset), do: %{state | g0: charset}
  defp set_gset(state, :g1, charset), do: %{state | g1: charset}
  defp set_gset(state, :g2, charset), do: %{state | g2: charset}
  defp set_gset(state, :g3, charset), do: %{state | g3: charset}
  defp set_gset(state, _gset, _charset), do: state

  defp set_gset_via_manager(state, :g0, charset),
    do: StateManager.set_g0(state, charset)

  defp set_gset_via_manager(state, :g1, charset),
    do: StateManager.set_g1(state, charset)

  defp set_gset_via_manager(state, :g2, charset),
    do: StateManager.set_g2(state, charset)

  defp set_gset_via_manager(state, :g3, charset),
    do: StateManager.set_g3(state, charset)

  defp set_gset_via_manager(state, _gset, _charset), do: state

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

  # Module constants for backward compatibility with tests
  def __using__(_opts) do
    quote do
      @ascii Raxol.Terminal.ANSI.CharacterSets.ASCII
      @dec Raxol.Terminal.ANSI.CharacterSets.DEC
      @uk Raxol.Terminal.ANSI.CharacterSets.UK
    end
  end

  # Module constants for character sets
  defmodule ASCII do
    @moduledoc """
    US ASCII character set identifier.
    """
    def name, do: :us_ascii
  end

  defmodule DEC do
    @moduledoc """
    DEC Special Graphics character set identifier.
    """
    def name, do: :dec_special_graphics
  end

  defmodule UK do
    @moduledoc """
    UK character set identifier.
    """
    def name, do: :uk
  end

  # Convenience delegates for backward compatibility
  defdelegate handle_sequence(state, sequence), to: Handler

  defdelegate translate_char(codepoint, active_set, single_shift),
    to: Translator

  def translate_char(codepoint, state) do
    # Get the active charset - prefer the direct active field if set, otherwise use G-set logic
    active_charset =
      Map.get(state, :active, StateManager.get_active_gset(state))

    single_shift = Map.get(state, :single_shift, nil)

    active_charset_atom = StateManager.resolve_charset_name(active_charset)
    single_shift_charset = StateManager.resolve_charset_name(single_shift)

    # Use the proper Translator module to handle translation
    translated =
      Translator.translate_char(
        codepoint,
        active_charset_atom,
        single_shift_charset
      )

    # Clear single shift after using it
    new_state =
      if state.single_shift != nil do
        %{state | single_shift: nil}
      else
        state
      end

    {translated, new_state}
  end

  # Override new() to match test expectations
  def new do
    %{
      g0: Raxol.Terminal.ANSI.CharacterSets.ASCII,
      g1: Raxol.Terminal.ANSI.CharacterSets.DEC,
      g2: Raxol.Terminal.ANSI.CharacterSets.UK,
      g3: Raxol.Terminal.ANSI.CharacterSets.UK,
      current: Raxol.Terminal.ANSI.CharacterSets.ASCII,
      gl: :g0,
      gr: :g1,
      single_shift: nil,
      locked_shift: false,
      # Also keep internal format for actual operations
      active: :us_ascii
    }
  end

  defdelegate set_g0(state, charset), to: StateManager
  defdelegate set_g1(state, charset), to: StateManager
  defdelegate set_g2(state, charset), to: StateManager
  defdelegate set_g3(state, charset), to: StateManager
  defdelegate set_gl(state, gset), to: StateManager
  defdelegate set_gr(state, gset), to: StateManager

  def set_single_shift(state, :ss2), do: %{state | single_shift: state.g2}
  def set_single_shift(state, :ss3), do: %{state | single_shift: state.g3}

  def set_single_shift(state, charset),
    do: StateManager.set_single_shift(state, charset)

  defdelegate clear_single_shift(state), to: StateManager
  defdelegate get_active(state), to: StateManager

  # Override get_active_charset to properly handle test expectations
  def get_active_charset(state) do
    # Check for single shift first
    case state.single_shift do
      nil ->
        # Check if locked_shift is true, use gr charset
        if Map.get(state, :locked_shift, false) and Map.has_key?(state, :gr) do
          Map.get(state, state.gr, state.g0)
        else
          # Use the current gl charset
          gl = Map.get(state, :gl, :g0)
          Map.get(state, gl, state.g0)
        end

      shift ->
        shift
    end
  end

  @doc """
  Translates a string using the active character set.
  """
  def translate_string(string, charset_state) when is_binary(string) do
    # Get the active charset - prefer the direct active field if set, otherwise use G-set logic
    active_charset =
      Map.get(
        charset_state,
        :active,
        StateManager.get_active_gset(charset_state)
      )

    single_shift = Map.get(charset_state, :single_shift, nil)

    Translator.translate_string(string, active_charset, single_shift)
  end

  @doc """
  Designates a character set for a G-set.
  """
  def designate_charset(state, gset_index, charset_code) do
    # Map gset index to the appropriate character set designator
    designator =
      case gset_index do
        :g0 -> ?(
        :g1 -> ?)
        :g2 -> ?*
        :g3 -> ?+
        # Default to G0
        _ -> ?(
      end

    Handler.handle_sequence(state, [designator, charset_code])
  end

  @doc """
  Invokes a character set designator.
  """
  def invoke_designator(state, gset)
      when gset in [:g0, :g1, :g2, :g3],
      do: StateManager.set_gl(state, gset)

  def invoke_designator(state, _gset), do: state

  @doc """
  Maps a character set code to module (for backward compatibility).
  """
  def charset_code_to_module(?B), do: Raxol.Terminal.ANSI.CharacterSets.ASCII
  def charset_code_to_module(?0), do: Raxol.Terminal.ANSI.CharacterSets.DEC
  def charset_code_to_module(?A), do: Raxol.Terminal.ANSI.CharacterSets.UK
  def charset_code_to_module(_), do: nil

  @doc """
  Maps an index to a gset name.
  """
  def index_to_gset(0), do: :g0
  def index_to_gset(1), do: :g1
  def index_to_gset(2), do: :g2
  def index_to_gset(3), do: :g3
  def index_to_gset(_), do: nil
end
