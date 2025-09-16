defmodule Raxol.Terminal.Plugin.Theme do
  def apply_theme(config) do
    %{
      colors: Map.get(config, :colors, %{}),
      font: Map.get(config, :font, "monospace"),
      background: Map.get(config, :background, "#000000"),
      foreground: Map.get(config, :foreground, "#ffffff")
    }
  end
end
