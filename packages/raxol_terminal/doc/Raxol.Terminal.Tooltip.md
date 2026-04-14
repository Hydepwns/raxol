# `Raxol.Terminal.Tooltip`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/tooltip.ex#L1)

Tooltip display functionality for terminal UI.

This module provides tooltip rendering capabilities for terminal applications,
allowing contextual help text to appear on hover or focus.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `handle_manager_info`

# `hide`

```elixir
@spec hide() :: :ok
```

Hides the currently displayed tooltip.

## Examples

    Raxol.Terminal.Tooltip.hide()

# `init_manager`

Starts the tooltip server.

# `show`

```elixir
@spec show(String.t()) :: :ok
```

Shows a tooltip with the given text at the current cursor position.

## Parameters
  - `text` - The text to display in the tooltip

## Examples

    Raxol.Terminal.Tooltip.show("Click to submit")

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
