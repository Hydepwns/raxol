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
  to have loaded; everything else is answered from a table or by shape.

  These cover both halves: that resolution is correct and load-order
  independent, and that nothing on the hot path is shaped like a module.
  """
  use ExUnit.Case, async: true

  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.CharacterSets.StateManager

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

    test "every charset code maps to a module the table knows" do
      for code <- [?B, ?0, ?A] do
        module = CharacterSets.charset_code_to_module(code)
        refute StateManager.resolve_charset_name(module) == module
      end
    end
  end

  describe "pass-through" do
    test "an already-resolved name is returned unchanged" do
      for name <- [:us_ascii, :dec_special_graphics, :uk, :us] do
        assert StateManager.resolve_charset_name(name) == name
      end
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
    # The cost this guards against came from reaching the code server with
    # atoms that are not modules: a load MISS is an uncached full code-path
    # search, and `nil` and `:us_ascii` are the two commonest arguments here.
    #
    # `module_atom?/1` is the discriminator that keeps them off it, so the
    # property is asserted directly on that predicate rather than through a
    # wall-clock measurement, which would be a flake.
    test "nothing that reaches the hot path is shaped like a module" do
      for argument <- [nil, :us_ascii, :dec_special_graphics, :uk, :us] do
        refute StateManager.module_atom?(argument),
               "#{inspect(argument)} would be handed to the code server, and a " <>
                 "miss there is an uncached code-path search per character"
      end
    end

    test "a module atom is the only thing that may reach the loader" do
      assert StateManager.module_atom?(CharacterSets.ASCII)
      refute StateManager.module_atom?(:no_such_module_anywhere)
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
    # Nothing else in the suite references this module or this code path entry,
    # so unloading it cannot disturb a concurrently running test. The previous
    # version purged `CharacterSets.Translator`, a production module on the
    # character path, out from under an `async: true` suite.
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
      dir = Path.join(System.tmp_dir!(), "charset_probe_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      source = Path.join(dir, "on_disk_probe_charset.ex")

      File.write!(source, """
      defmodule #{inspect(module)} do
        @moduledoc false
        def name, do: :on_disk_probe
      end
      """)

      Kernel.ParallelCompiler.compile_to_path([source], dir, return_diagnostics: true)
      Code.prepend_path(dir)

      on_exit(fn ->
        Code.delete_path(dir)
        :code.purge(module)
        :code.delete(module)
        File.rm_rf!(dir)
      end)

      module
    end
  end
end
