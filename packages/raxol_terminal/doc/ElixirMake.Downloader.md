# `ElixirMake.Downloader`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/../../lib/termbox2_nif/deps/elixir_make/lib/elixir_make/downloader.ex#L1)

The behaviour for downloader modules.

# `download`

```elixir
@callback download(url :: String.t()) :: {:ok, iolist() | binary()} | {:error, String.t()}
```

This callback should download the artefact from the given URL.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
