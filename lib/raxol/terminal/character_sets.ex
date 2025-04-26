defmodule Raxol.Terminal.CharacterSets do
  @moduledoc """
  Handles character set management and translation for the terminal emulator.

  This module defines the character set state, including designated G0-G3 sets
  and active GL/GR sets. It also provides translation tables for different
  character sets and functions to translate characters based on the active set.
  """

  alias Raxol.Terminal.CharacterSets.Translator

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
  @spec translate_active(charset_state(), non_neg_integer()) :: non_neg_integer()
  def translate_active(%__MODULE__{active_set: active_set}, codepoint) do
    # Delegate to the appropriate translation function based on the active set
    Translator.translate_codepoint(codepoint, active_set)
  end
end
