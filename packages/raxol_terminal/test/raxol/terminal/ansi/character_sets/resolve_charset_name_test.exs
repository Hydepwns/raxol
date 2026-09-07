defmodule Raxol.Terminal.ANSI.CharacterSets.ResolveCharsetNameTest do
  @moduledoc """
  `resolve_charset_name/1` runs up to three times per translated character, so
  what it costs is part of its contract, not an implementation detail.

  It used to ask `Code.ensure_loaded/1`, a synchronous call into the single
  global `:code_server`. The two commonest arguments on that path are `nil` (no
  single shift) and an already-resolved name like `:us_ascii`, neither of which
  is a module, so each call was a guaranteed load MISS -- and misses are not
  cached, so every character re-walked the code path on disk. Measured at ~0.32ms
  per call for `:us_ascii` against ~94ns for a loaded module, serialized through
  one process.

  The fix is not "never reach the loader" -- it is "never reach it with
  something that cannot be a module". A charset module still resolves through
  `Code.ensure_loaded?/1`, so its answer does not depend on what the VM happens
  to have loaded; every NAME is answered from a table.

  These cover both halves: that resolution is correct and load-order
  independent, and that no charset name the emulator can designate reaches the
  loader -- asserted through an Erlang module that shares a charset name's
  spelling, which is observable, rather than through wall-clock time, which
  would flake.

  `async: false`: two tests mutate the node-global code path and purge modules.
  """
  # Not async: `Code.prepend_path/1` and `:code.purge/1` are node-global.
  use ExUnit.Case, async: false

  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager

  # The closed codomain of `charset_code_to_atom/1`, plus `:us` from the
  # module's own `@type charset`. Every one of these must be answered without
  # touching the loader, and the ten national replacement sets are the ones a
  # three-entry table silently missed.
  @charset_names [
    :us_ascii,
    :dec_special_graphics,
    :uk,
    :us,
    :finnish,
    :french,
    :french_canadian,
    :german,
    :italian,
    :norwegian_danish,
    :portuguese,
    :spanish,
    :swedish,
    :swiss
  ]

  describe "resolving the charset modules" do
    test "each module `charset_code_to_module/1` can produce resolves to its name" do
      assert StateManager.resolve_charset_name(CharacterSets.ASCII) == :us_ascii

      assert StateManager.resolve_charset_name(CharacterSets.DEC) ==
               :dec_special_graphics

      assert StateManager.resolve_charset_name(CharacterSets.UK) == :uk
    end

    test "the table agrees with the modules' own name/0" do
      # The table is the fast path and `name/0` is the declaration. If they ever
      # disagree, the fast path is silently translating against the wrong set.
      for module <- [CharacterSets.ASCII, CharacterSets.DEC, CharacterSets.UK] do
        assert StateManager.resolve_charset_name(module) == module.name()
      end
    end

    test "the three module-backed codes resolve to their declared names" do
      # Only these three codes have a module: `charset_code_to_module/1` returns
      # nil for the other twelve, and `resolve_charset_name(nil)` is nil, so a
      # loop over every code could not assert anything here. Asserting the
      # expected name rather than `refute result == module` also catches a table
      # entry pointing a code at the wrong set.
      for {code, name} <- [
            {?B, :us_ascii},
            {?0, :dec_special_graphics},
            {?A, :uk}
          ] do
        module = CharacterSets.charset_code_to_module(code)
        assert StateManager.resolve_charset_name(module) == name
      end
    end
  end

  describe "pass-through" do
    test "every charset name the emulator can designate is returned unchanged" do
      for name <- @charset_names do
        assert StateManager.resolve_charset_name(name) == name
      end
    end

    test "the pass-through set covers what charset_code_to_atom/1 produces" do
      # Guards against the two halves drifting: a code whose name is missing
      # from the table would still resolve correctly, just slowly, so no other
      # test in this file would notice.
      produced =
        for code <- 0..255,
            name = StateManager.charset_code_to_atom(code),
            not is_nil(name),
            uniq: true,
            do: name

      assert produced != []
      assert Enum.sort(produced -- @charset_names) == []
    end

    test "nil, the usual single_shift, is returned unchanged" do
      assert StateManager.resolve_charset_name(nil) == nil
    end

    test "a non-atom is returned unchanged" do
      assert StateManager.resolve_charset_name("us_ascii") == "us_ascii"
      assert StateManager.resolve_charset_name(42) == 42
    end
  end

  describe "the loader is off the hot path" do
    test "a charset name is answered by the table even when a module shares its spelling" do
      # The observable consequence of asking the loader about a NAME: an Erlang
      # module can be spelled exactly like one, so a stray `german.beam`
      # anywhere on the code path would hijack the German replacement set and
      # translate against whatever its `name/0` returns.
      #
      # This is a cost assertion made behavioural. Timing it would flake; the
      # hijack either happens or it does not.
      module = compile_erlang_module(:german, :hijacked)

      assert Code.ensure_loaded?(module),
             "precondition: the impostor must be loadable, or this proves nothing"

      assert function_exported?(module, :name, 0)
      assert module.name() == :hijacked

      assert StateManager.resolve_charset_name(:german) == :german
    end

    test "an unloadable atom resolves without consulting the loader" do
      assert StateManager.resolve_charset_name(:no_such_module_anywhere) ==
               :no_such_module_anywhere
    end
  end

  describe "the dynamic contract for a charset the table does not know" do
    defmodule CustomCharset do
      @moduledoc false
      def name, do: :custom
    end

    test "a loaded module exporting name/0 still resolves through it" do
      assert StateManager.resolve_charset_name(CustomCharset) == :custom
    end

    test "a loaded module without name/0 is returned unchanged" do
      assert StateManager.resolve_charset_name(Enum) == Enum
    end

    test "an Erlang module exporting name/0 resolves through it too" do
      # The original contract was "any loadable module exporting name/0", not
      # "any Elixir-namespaced one". A shape test on the `Elixir.` prefix made
      # this branch unreachable for Erlang modules, which then fell through to
      # `CharsetData.translate/2`'s nil branch and identity-translated with no
      # error, no log and no crash.
      module = compile_erlang_module(:raxol_erlang_probe_charset, :erlang_probe)

      assert StateManager.resolve_charset_name(module) == :erlang_probe
    end

    # The regression this replaces a purge-the-world test with. An earlier fix
    # used `:erlang.module_loaded/1` here, which answers "in memory right now"
    # rather than "is this a charset module", so this same call returned the
    # module atom before anything had loaded it and its name afterwards -- a
    # wrong glyph that reproduces only sometimes, which is worse than a slow
    # one. Resolution must not depend on VM load order.
    #
    # The probe is compiled to a temp directory rather than declared inline: a
    # module defined in an .exs file exists only in memory, so purging it makes
    # it unloadABLE, not merely unloaded, and the test would prove nothing.
    test "an unloaded charset module resolves to its name, not to itself" do
      module = compile_probe_charset()

      :code.purge(module)
      :code.delete(module)
      :code.purge(module)

      refute :erlang.module_loaded(module),
             "precondition: the module must start unloaded"

      assert StateManager.resolve_charset_name(module) == :on_disk_probe
    end

    defp compile_probe_charset do
      module = Raxol.Terminal.ANSI.CharacterSets.OnDiskProbeCharset
      dir = temp_dir("charset_probe")

      source = Path.join(dir, "on_disk_probe_charset.ex")

      File.write!(source, """
      defmodule #{inspect(module)} do
        @moduledoc false
        def name, do: :on_disk_probe
      end
      """)

      # Matched, not discarded: a probe that fails to compile would otherwise be
      # swallowed, and the test would fail later at the resolution assertion
      # with a message pointing at resolve_charset_name/1 rather than at the
      # fixture. `return_diagnostics: true` is also dead configuration if the
      # result is ignored.
      assert {:ok, [^module], _diagnostics} =
               Kernel.ParallelCompiler.compile_to_path([source], dir, return_diagnostics: true)

      Code.prepend_path(dir)

      on_exit(fn ->
        Code.delete_path(dir)
        unload(module)
        File.rm_rf!(dir)
      end)

      module
    end
  end

  # An Erlang module, so the atom is bare (`:german`) rather than
  # `Elixir.`-prefixed. That is the only way to spell a module that collides
  # with a charset name.
  defp compile_erlang_module(module, name) do
    dir = temp_dir("erl_probe")
    source = Path.join(dir, "#{module}.erl")

    File.write!(source, """
    -module(#{module}).
    -export([name/0]).
    name() -> #{name}.
    """)

    assert {:ok, ^module} =
             :compile.file(String.to_charlist(source), [
               {:outdir, String.to_charlist(dir)},
               :return_errors
             ])

    Code.prepend_path(dir)

    on_exit(fn ->
      Code.delete_path(dir)
      unload(module)
      File.rm_rf!(dir)
    end)

    module
  end

  # purge / delete / purge: delete moves current code to the old slot, and only
  # a second purge reclaims it. Stopping after delete leaves the chunk resident
  # for the life of the VM.
  defp unload(module) do
    :code.purge(module)
    :code.delete(module)
    :code.purge(module)
    :ok
  end

  defp temp_dir(prefix) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "#{prefix}_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end
end
