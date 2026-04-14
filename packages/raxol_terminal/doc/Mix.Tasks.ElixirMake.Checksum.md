# `mix elixir_make.checksum`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/../../lib/termbox2_nif/deps/elixir_make/lib/mix/tasks/elixir_make.checksum.ex#L1)

A task responsible for downloading the precompiled NIFs for a given module.

This task must only be used by package creators who want to ship the
precompiled NIFs. The goal is to download the precompiled packages and
generate a checksum to check-in alongside the project in the the Hex repository.
This is done by passing the `--all` flag.

You can also use the `--only-local` flag to download only the precompiled
package for use during development.

You can use the `--ignore-unavailable` flag to ignore any NIFs that are not available.
This is useful when you are developing a new NIF that does not support all platforms.

This task also accept the `--print` flag to print the checksums.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
