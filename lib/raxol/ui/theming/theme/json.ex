defimpl Jason.Encoder, for: Raxol.UI.Theming.Theme do
  def encode(theme, opts) do
    Jason.Encode.map(theme, opts)
  end
end
