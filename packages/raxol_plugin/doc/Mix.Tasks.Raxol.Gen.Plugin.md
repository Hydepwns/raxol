# `mix raxol.gen.plugin`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/mix/tasks/raxol.gen.plugin.ex#L1)

Generates a skeleton Raxol plugin.

    $ mix raxol.gen.plugin MyPlugin
    $ mix raxol.gen.plugin MyApp.Plugins.Logger

Creates:

  * `lib/<path>.ex` - Plugin module with `use Raxol.Plugin` and `init/1`
  * `test/<path>_test.exs` - ExUnit test with lifecycle smoke test

---

*Consult [api-reference.md](api-reference.md) for complete listing*
