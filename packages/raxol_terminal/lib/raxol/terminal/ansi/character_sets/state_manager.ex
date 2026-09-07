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
  Sets the G0 character set.
  """
  def set_g0(state, charset) do
    %{state | g0: charset}
    |> update_active()
  end

  @doc """
  Sets the G1 character set.
  """
  def set_g1(state, charset) do
    %{state | g1: charset}
    |> update_active()
  end

  @doc """
  Sets the G2 character set.
  """
  def set_g2(state, charset) do
    %{state | g2: charset}
    |> update_active()
  end

  @doc """
  Sets the G3 character set.
  """
  def set_g3(state, charset) do
    %{state | g3: charset}
    |> update_active()
  end

  @doc """
  Sets the GL (graphics left) designation.
  """
  def set_gl(state, gset) do
    %{state | gl: gset}
    |> update_active()
  end

  @doc """
  Sets the GR (graphics right) designation.
  """
  def set_gr(state, gset) do
    %{state | gr: gset}
    |> update_active()
  end

  @doc """
  Sets a single shift to the specified G-set.
  """
  def set_single_shift(state, gset_or_charset) do
    # Handle both gset references and direct charset names
    charset =
      case gset_or_charset do
        gset when gset in [:g0, :g1, :g2, :g3] ->
          # Resolve the charset from the gset
          Map.get(state, gset, :us_ascii)

        charset_name ->
          # Direct charset name
          charset_name
      end

    %{state | single_shift: charset}
    |> update_active()
  end

  @doc """
  Clears the single shift.
  """
  def clear_single_shift(state) do
    %{state | single_shift: nil}
    |> update_active()
  end

  @doc """
  Gets the current active character set.
  """
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
  def get_single_shift(%{single_shift: single_shift}), do: single_shift

  @doc """
  Updates the active character set based on current GL setting.
  """
  def update_active(state) do
    active_charset =
      case state.gl do
        :g0 -> state.g0
        :g1 -> state.g1
        :g2 -> state.g2
        :g3 -> state.g3
      end

    %{state | active: resolve_charset_name(active_charset)}
  end

  # The closed set this resolves. `charset_code_to_module/1` produces exactly
  # these three, and they are the only modules in the package defining `name/0`.
  @charset_module_names %{
    Raxol.Terminal.ANSI.CharacterSets.ASCII => :us_ascii,
    Raxol.Terminal.ANSI.CharacterSets.DEC => :dec_special_graphics,
    Raxol.Terminal.ANSI.CharacterSets.UK => :uk
  }

  @doc false
  # Runs up to three times per TRANSLATED CHARACTER: `CharacterSets.translate_char/2`
  # resolves the active set and the single shift, then `Translator.translate_char/3`
  # resolves once more.
  #
  # It used to do that with `Code.ensure_loaded/1`, a synchronous call into the
  # single global `:code_server`. For a module already loaded that is merely
  # wasteful, but the two commonest arguments on this path are `nil` (no single
  # shift) and an already-resolved short name like `:us_ascii` -- neither of
  # which is a module, so each call was a guaranteed load MISS. The code server
  # does not cache misses, so every character re-walked the whole code path on
  # disk: measured at ~0.32ms for `:us_ascii` and ~0.17ms for `nil`, against
  # ~94ns for a loaded module. Roughly half a millisecond per character, and
  # serialized through one process, so parallel tests queued behind each other
  # and ANSI-heavy suites timed out.
  #
  # A table lookup answers the real question for the closed set, and the two
  # commonest arguments -- `nil` and an already-resolved short name -- are
  # answered by a second table rather than by asking anything about modules.
  #
  # The dynamic branch below is what a custom charset module reaches, and it is
  # deliberately NOT `:erlang.module_loaded/1`. That predicate answers "is this
  # module in memory right now", not "is this a charset module", so a custom
  # module that happened not to be loaded yet resolved to the module atom, and
  # the same call after something else loaded it resolved to its name. Making
  # the value depend on VM load order is a worse defect than the cost this
  # change removes: it turns a wrong glyph into a wrong glyph that reproduces
  # only sometimes. The loader is consulted, restoring the original contract.
  #
  # The cost that made the loader unusable is gone anyway, because it was never
  # the loader itself -- it was reaching the loader with atoms that are not
  # modules. `Code.ensure_loaded?/1` on a NAME is an uncached full code-path
  # search, ~0.32ms, every character. On an Elixir module atom it is a hit or a
  # single load, ~94ns thereafter. `module_atom?/1` is what keeps the former off
  # the path: only an `Elixir.`-prefixed atom can name a module, so `nil`,
  # `:us_ascii` and anything else short-circuit before the loader is involved.
  @resolved_names Map.new(Map.values(@charset_module_names), &{&1, &1})

  def resolve_charset_name(charset)
      when is_map_key(@charset_module_names, charset),
      do: :erlang.map_get(charset, @charset_module_names)

  def resolve_charset_name(charset)
      when is_map_key(@resolved_names, charset),
      do: charset

  def resolve_charset_name(nil), do: nil

  def resolve_charset_name(charset) when is_atom(charset) do
    if module_atom?(charset) and Code.ensure_loaded?(charset) and
         function_exported?(charset, :name, 0),
       do: charset.name(),
       else: charset
  end

  def resolve_charset_name(charset), do: charset

  @doc """
  Whether `atom` is shaped like an Elixir module name.

  Public so the property the fast path depends on is testable directly: every
  atom this answers `false` for is one `resolve_charset_name/1` returns without
  reaching the code server. Asserting that through timing would be a flake.
  """
  @spec module_atom?(atom()) :: boolean()
  def module_atom?(atom) when is_atom(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> _rest -> true
      _not_a_module -> false
    end
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

  @doc """
  Sets the active character set directly.
  """
  def set_active(state, charset) do
    %{state | active: charset}
  end

  @doc """
  Sets a specific G-set character set.
  """
  def set_gset(state, gset, charset) do
    case gset do
      :g0 -> set_g0(state, charset)
      :g1 -> set_g1(state, charset)
      :g2 -> set_g2(state, charset)
      :g3 -> set_g3(state, charset)
      _ -> state
    end
  end

  @doc """
  Gets the current GL (graphics left) setting.
  """
  def get_gl(%{gl: gl}), do: gl
  def get_gl(_), do: :g0

  @doc """
  Gets the current GR (graphics right) setting.
  """
  def get_gr(%{gr: gr}), do: gr
  def get_gr(_), do: :g1

  @doc """
  Converts a character set code to an atom.
  """
  def charset_code_to_atom(code) do
    case code do
      ?0 -> :dec_special_graphics
      ?A -> :uk
      ?B -> :us_ascii
      ?4 -> :finnish
      ?5 -> :french
      ?C -> :french_canadian
      ?7 -> :german
      ?9 -> :italian
      ?E -> :norwegian_danish
      ?6 -> :portuguese
      ?Z -> :spanish
      ?H -> :swedish
      ?= -> :swiss
      _ -> nil
    end
  end

  @doc """
  Gets a specific G-set character set.
  """
  def get_gset(state, gset) do
    case gset do
      :g0 -> Map.get(state, :g0, :us_ascii)
      :g1 -> Map.get(state, :g1, :us_ascii)
      :g2 -> Map.get(state, :g2, :us_ascii)
      :g3 -> Map.get(state, :g3, :us_ascii)
      _ -> :us_ascii
    end
  end

  @doc """
  Gets the active G-set character set (the charset of the current GL).
  """
  def get_active_gset(state) do
    gl_gset = Map.get(state, :gl, :g0)
    get_gset(state, gl_gset)
  end

  @doc """
  Converts G-set index to atom.
  """
  def index_to_gset(index) do
    case index do
      0 -> :g0
      1 -> :g1
      2 -> :g2
      3 -> :g3
      _ -> :g0
    end
  end
end
