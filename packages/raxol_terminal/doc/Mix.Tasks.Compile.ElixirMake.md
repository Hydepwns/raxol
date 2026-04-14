# `mix compile.elixir_make`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/../../lib/termbox2_nif/deps/elixir_make/lib/mix/tasks/compile.elixir_make.ex#L1)

Runs `make` in the current project.

This task runs `make` in the current project; any output coming from `make` is
printed in real-time on stdout.

## Configuration

This compiler can be configured through the return value of the `project/0`
function in `mix.exs`; for example:

    def project() do
      [app: :myapp,
       make_executable: "make",
       make_makefile: "Othermakefile",
       compilers: [:elixir_make] ++ Mix.compilers,
       deps: deps()]
    end

The following options are available:

  * `:make_executable` - (binary or `:default`) it's the executable to use as the
    `make` program. If not provided or if `:default`, it defaults to `"nmake"`
    on Windows, `"gmake"` on FreeBSD, OpenBSD and NetBSD, and `"make"` on everything
    else. You can, for example, customize which executable to use on a
    specific OS and use `:default` for every other OS. If the `MAKE`
    environment variable is present, that is used as the value of this option.

  * `:make_makefile` - (binary or `:default`) it's the Makefile to
    use. Defaults to `"Makefile"` for Unix systems and `"Makefile.win"` for
    Windows systems if not provided or if `:default`.

  * `:make_targets` - (list of binaries) it's the list of Make targets that
    should be run. Defaults to `[]`, meaning `make` will run the first target.

  * `:make_clean` - (list of binaries) it's a list of Make targets to be run
    when `mix clean` is run. It's only run if a non-`nil` value for
    `:make_clean` is provided. Defaults to `nil`.

  * `:make_cwd` - (binary) it's the directory where `make` will be run,
    relative to the root of the project.

  * `:make_env` - (map of binary to binary) it's a map of extra environment
    variables to be passed to `make`. You can also pass a function in here in
    case `make_env` needs access to things that are not available during project
    setup; the function should return a map of binary to binary. Many default
    environment variables are set, see section below

  * `:make_error_message` - (binary or `:default`) it's a custom error message
    that can be used to give instructions as of how to fix the error (e.g., it
    can be used to suggest installing `gcc` if you're compiling a C
    dependency).

  * `:make_args` - (list of binaries) it's a list of extra arguments to be passed.

The following options configure precompilation:

  * `:make_precompiler` - a two-element tuple with the precompiled type
    and module to use. The precompile type is either `:nif` or `:port`
    and then the precompilation module. If the type is a `:nif`, it looks
    for a DDL or a shared object as precompilation target given by
    `:make_precompiler_filename` and the current NIF version is part of
    the precompiled archive. If `:port`, it looks for an executable with
    `:make_precompiler_filename`.

  * `:make_precompiler_url` - the download URL template. Defaults to none.
    Required when `make_precompiler` is set.

  * `:make_precompiler_filename` - the filename of the compiled artefact
    without its extension. Defaults to the app name.

  * `:make_precompiler_downloader` - a module implementing the `ElixirMake.Downloader`
    behaviour. You can use this to customize how the precompiled artefacts
    are downloaded, for example, to add HTTP authentication or to download
    from an SFTP server. The default implementation uses `:httpc`.

  * `:make_force_build` - if build should be forced even if precompiled artefacts
    are available. Defaults to true if the app has a `-dev` version flag.

## Default environment variables

There are also several default environment variables set:

  * `MIX_TARGET`
  * `MIX_ENV`
  * `MIX_BUILD_PATH` - same as `Mix.Project.build_path/0`
  * `MIX_APP_PATH` - same as `Mix.Project.app_path/0`
  * `MIX_COMPILE_PATH` - same as `Mix.Project.compile_path/0`
  * `MIX_CONSOLIDATION_PATH` - same as `Mix.Project.consolidation_path/0`
  * `MIX_DEPS_PATH` - same as `Mix.Project.deps_path/0`
  * `MIX_MANIFEST_PATH` - same as `Mix.Project.manifest_path/0`
  * `ERL_EI_LIBDIR`
  * `ERL_EI_INCLUDE_DIR`
  * `ERTS_INCLUDE_DIR`
  * `ERL_INTERFACE_LIB_DIR`
  * `ERL_INTERFACE_INCLUDE_DIR`

These may also be overwritten with the `make_env` option.

## Compilation artifacts and working with priv directories

Generally speaking, compilation artifacts are written to the `priv`
directory, as that the only directory, besides `ebin`, which are
available to Erlang/OTP applications.

However, note that Mix projects supports the `:build_embedded`
configuration, which controls if assets in the `_build` directory
are symlinked (when `false`, the default) or copied (`true`).
In order to support both options for `:build_embedded`, it is
important to follow the given guidelines:

  * The "priv" directory must not exist in the source code
  * The Makefile should copy any artifact to `$MIX_APP_PATH/priv`
    or, even better, to `$MIX_APP_PATH/priv/$MIX_TARGET`
  * If there are static assets, the Makefile should copy them over
    from a directory at the project root (not named "priv")

---

*Consult [api-reference.md](api-reference.md) for complete listing*
