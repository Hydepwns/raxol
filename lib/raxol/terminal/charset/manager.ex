defmodule Raxol.Terminal.Charset.Manager do
  @moduledoc """
  Manages terminal character sets and encoding operations.
  """

  alias Raxol.Terminal.Charset.{Types, Maps, Operations}

  defstruct g_sets: %{
              g0: :us_ascii,
              g1: :us_ascii,
              g2: :us_ascii,
              g3: :us_ascii
            },
            current_g_set: :g0,
            single_shift: nil,
            charsets: %{
              us_ascii: &Maps.us_ascii_map/0,
              dec_supplementary: &Maps.dec_supplementary_map/0,
              dec_special: &Maps.dec_special_map/0,
              dec_technical: &Maps.dec_technical_map/0
            }

  @type g_set :: :g0 | :g1 | :g2 | :g3
  @type charset ::
          :us_ascii | :dec_supplementary | :dec_special | :dec_technical
  @type char_map :: %{non_neg_integer() => String.t()}

  @type t :: %__MODULE__{
          g_sets: %{g_set() => charset()},
          current_g_set: g_set(),
          single_shift: g_set() | nil,
          charsets: %{charset() => (-> char_map())}
        }

  @doc """
  Creates a new charset manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the current state of the charset manager.
  """
  def get_state(%__MODULE__{} = state) do
    state
  end

  @doc """
  Updates the state of the charset manager.
  """
  def update_state(%__MODULE__{} = state, new_state) when is_map(new_state) do
    Map.merge(state, new_state)
  end

  @doc """
  Resets the charset state to defaults.
  """
  def reset_state(%__MODULE__{} = state) do
    %{
      state
      | g_sets: %{
          g0: :us_ascii,
          g1: :us_ascii,
          g2: :us_ascii,
          g3: :us_ascii
        },
        current_g_set: :g0,
        single_shift: nil
    }
  end

  @doc """
  Gets the current character set for the specified G-set.
  """
  def get_charset(emulator, g_set) do
    Operations.get_designated_charset(emulator.charset_state, g_set)
  end

  @doc """
  Maps a character using the current character set.
  """
  def map_character(emulator, char) do
    charset = get_charset(emulator, emulator.charset_state.active_set)

    case charset do
      nil ->
        char

      charset_name ->
        char_map = emulator.charset_state.charsets[charset_name].()
        Map.get(char_map, char, char)
    end
  end

  # Delegate operations to the Operations module
  defdelegate designate_charset(state, g_set, charset), to: Operations
  defdelegate invoke_g_set(state, g_set), to: Operations
  defdelegate get_current_g_set(state), to: Operations
  defdelegate get_designated_charset(state, g_set), to: Operations
  defdelegate apply_single_shift(state, g_set), to: Operations
  defdelegate get_single_shift(state), to: Operations

  defdelegate handle_set_charset(emulator, params_buffer, final_byte),
    to: Operations
end
