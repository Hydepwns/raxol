# `Raxol.Core.Focus`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/focus.ex#L1)

Convenience module for focus management in TEA applications.

Wraps `Raxol.Core.FocusManager` with a simpler API designed for use
inside `init/1` and `view/1` callbacks. Opt-in: if `setup_focus/1` is
never called, FocusServer is never started and all queries return safe
defaults (nil / false).

## Usage

    def init(_context) do
      setup_focus([
        {"username", 0},
        {"password", 1},
        {"submit", 2}
      ])
      %{username: "", password: ""}
    end

    def view(model) do
      # focused?/1 is safe to call even if FocusServer isn't running
      text_input(id: "username", focused: focused?("username"))
    end

# `current_focus`

```elixir
@spec current_focus() :: binary() | nil
```

Returns the ID of the currently focused element, or nil.

Safe to call at any time -- returns nil if FocusServer is not running.

# `focused?`

```elixir
@spec focused?(binary()) :: boolean()
```

Returns true if the given element currently has focus.

Safe to call from `view/1` -- returns false if FocusServer is not running.

# `setup_focus`

```elixir
@spec setup_focus([{binary(), integer()} | {binary(), integer(), keyword()}]) :: :ok
```

Registers focusable elements and sets initial focus to the first one.

Accepts a list of tuples:
  - `{id, tab_index}` -- register with default opts
  - `{id, tab_index, opts}` -- register with custom opts

Elements are sorted by `tab_index`; the lowest gets initial focus.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
