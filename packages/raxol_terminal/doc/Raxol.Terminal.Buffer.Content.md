# `Raxol.Terminal.Buffer.Content`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/content.ex#L1)

Compatibility adapter for buffer content operations.
Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.

# `write_at`

```elixir
@spec write_at(
  term(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  map()
) :: term()
```

Writes content at a specific position in the buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
