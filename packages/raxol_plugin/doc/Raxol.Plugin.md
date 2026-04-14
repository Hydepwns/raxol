# `Raxol.Plugin`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/plugin.ex#L1)

Convenience macro for building Raxol plugins.

Sets `@behaviour Raxol.Core.Runtime.Plugins.Plugin` and provides
overridable defaults for all optional callbacks. Only `init/1` must
be implemented by the consumer.

## Usage

    defmodule MyPlugin do
      use Raxol.Plugin

      @impl true
      def init(config) do
        {:ok, %{config: config}}
      end
    end

All other callbacks (`terminate/2`, `enable/1`, `disable/1`,
`filter_event/2`, `handle_command/3`, `get_commands/0`) have safe
defaults that can be overridden with `@impl true`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
