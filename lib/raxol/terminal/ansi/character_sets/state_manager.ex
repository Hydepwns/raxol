defmodule Raxol.Terminal.ANSI.CharacterSets.StateManager do
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
  def new do
    %{
      active: :us_ascii,
      single_shift: nil,
      g0: :us_ascii,
      g1: :us_ascii,
      g2: :us_ascii,
      g3: :us_ascii,
      gl: :g0,
      gr: :g2
    }
  end

  @doc """
  Gets the active character set.
  """
  def get_active(state), do: state.active

  @doc """
  Sets the active character set.
  """
  def set_active(state, set) do
    %{state | active: set}
  end

  @doc """
  Gets the single shift character set.
  """
  def get_single_shift(state), do: state.single_shift

  @doc """
  Sets the single shift character set.
  """
  def set_single_shift(state, set) do
    %{state | single_shift: set}
  end

  @doc """
  Clears the single shift character set.
  """
  def clear_single_shift(state) do
    %{state | single_shift: nil}
  end

  @doc """
  Gets a G-set character set.
  """
  def get_gset(state, gset) do
    Map.get(state, gset)
  end

  @doc """
  Sets a G-set character set.
  """
  def set_gset(state, gset, set) when gset in [:g0, :g1, :g2, :g3] do
    Map.put(state, gset, set)
  end

  @doc """
  Gets the GL (left) character set.
  """
  def get_gl(state), do: state.gl

  @doc """
  Sets the GL (left) character set.
  """
  def set_gl(state, gset) when gset in [:g0, :g1, :g2, :g3] do
    %{state | gl: gset}
  end

  @doc """
  Gets the GR (right) character set.
  """
  def get_gr(state), do: state.gr

  @doc """
  Sets the GR (right) character set.
  """
  def set_gr(state, gset) when gset in [:g0, :g1, :g2, :g3] do
    %{state | gr: gset}
  end

  @doc """
  Gets the active G-set character set.
  """
  def get_active_gset(state) do
    case state.gl do
      :g0 -> state.g0
      :g1 -> state.g1
      :g2 -> state.g2
      :g3 -> state.g3
    end
  end

  @doc """
  Gets the active GR character set.
  """
  def get_active_gr(state) do
    case state.gr do
      :g0 -> state.g0
      :g1 -> state.g1
      :g2 -> state.g2
      :g3 -> state.g3
    end
  end

  @doc """
  Converts a character set code to an atom.
  """
  def charset_code_to_atom(code) do
    case code do
      ?0 -> :dec_special_graphics
      ?A -> :uk
      ?B -> :us_ascii
      ?C -> :finnish
      ?D -> :french
      ?E -> :french_canadian
      ?F -> :german
      ?G -> :italian
      ?H -> :norwegian_danish
      ?I -> :portuguese
      ?J -> :spanish
      ?K -> :swedish
      ?L -> :swiss
      _ -> nil
    end
  end

  @doc """
  Converts a G-set index to an atom.
  """
  def index_to_gset(index) when index in 0..3//1 do
    case index do
      0 -> :g0
      1 -> :g1
      2 -> :g2
      3 -> :g3
    end
  end

  def index_to_gset(index) when is_integer(index) do
    nil
  end

  @doc """
  Gets the mode manager from the emulator state.
  """
  def get_mode_manager(emulator) do
    emulator.mode_manager
  end

  @doc """
  Updates the mode manager in the emulator state.
  """
  def update_mode_manager(emulator, mode_manager) do
    %{emulator | mode_manager: mode_manager}
  end

  @doc """
  Gets the charset state from the emulator state.
  """
  def get_charset_state(emulator) do
    emulator.charset_state
  end

  @doc """
  Updates the charset state in the emulator state.
  """
  def update_charset_state(emulator, charset_state) do
    %{emulator | charset_state: charset_state}
  end

  @doc """
  Translates a character using the active character set.
  Returns {codepoint, new_state} as expected by the tests.
  """
  def translate_char(codepoint, state) when is_integer(codepoint) do
    active_charset = get_active(state)
    single_shift = get_single_shift(state)

    result =
      Raxol.Terminal.ANSI.CharacterSets.Translator.translate_char(
        codepoint,
        active_charset,
        single_shift
      )

    new_state = clear_single_shift(state)
    {result, new_state}
  end

  @doc """
  Translates a string using the active character set.
  """
  def translate_string(string, state) do
    active_charset = get_active(state)
    single_shift = get_single_shift(state)

    Raxol.Terminal.ANSI.CharacterSets.Translator.translate_string(
      string,
      active_charset,
      single_shift
    )
  end

  @doc """
  Validates a character set state.
  Returns :ok if valid, or {:error, reason} if invalid.
  """

  def validate_state(state) when is_map(state) do
    required_keys = [:active, :single_shift, :g0, :g1, :g2, :g3, :gl, :gr]

    case Enum.all?(required_keys, &Map.has_key?(state, &1)) do
      true -> :ok
      false -> {:error, :missing_required_keys}
    end
  end

  def validate_state(_), do: {:error, :invalid_state}
end
