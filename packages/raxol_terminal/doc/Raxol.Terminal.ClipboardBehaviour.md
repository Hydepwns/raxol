# `Raxol.Terminal.ClipboardBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard_behaviour.ex#L1)

Defines the behaviour for clipboard operations in the terminal.

This behaviour specifies the callbacks that must be implemented by any module
that wants to handle clipboard operations in the terminal emulator.

# `clear`

```elixir
@callback clear(clipboard :: term()) :: {:ok, term()} | {:error, term()}
```

Clears the clipboard content.

Returns `{:ok, updated_clipboard}` on success, or `{:error, reason}` on failure.

# `get_content`

```elixir
@callback get_content(clipboard :: term()) :: {:ok, String.t()} | {:error, term()}
```

Gets the current content of the clipboard.

Returns `{:ok, content}` on success, or `{:error, reason}` on failure.

# `get_selection`

```elixir
@callback get_selection(clipboard :: term()) :: {:ok, String.t()} | {:error, term()}
```

Gets the current selection content.

Returns `{:ok, content}` on success, or `{:error, reason}` on failure.

# `set_content`

```elixir
@callback set_content(clipboard :: term(), content :: String.t()) ::
  {:ok, term()} | {:error, term()}
```

Sets the content of the clipboard.

Returns `{:ok, updated_clipboard}` on success, or `{:error, reason}` on failure.

# `set_selection`

```elixir
@callback set_selection(clipboard :: term(), content :: String.t()) ::
  {:ok, term()} | {:error, term()}
```

Sets the selection content.

Returns `{:ok, updated_clipboard}` on success, or `{:error, reason}` on failure.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
