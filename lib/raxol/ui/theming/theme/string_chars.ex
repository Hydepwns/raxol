defimpl String.Chars, for: Raxol.UI.Theming.Theme do
  def to_string(theme) do
    "#<Theme name=#{inspect(theme.name)} colors=#{inspect(Map.keys(theme.colors))}>"
  end
end
