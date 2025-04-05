defmodule Raxol.Plugins.HyperlinkPlugin do
  @moduledoc """
  Plugin that detects URLs in terminal output and makes them clickable.
  """

  @behaviour Raxol.Plugins.Plugin

  @url_pattern ~r/https?:\/\/[^\s<>"]+|www\.[^\s<>"]+/i

  defstruct [:name, :enabled, :config]

  @impl true
  def init(config \\ %{}) do
    {:ok, %__MODULE__{
      name: "hyperlink",
      enabled: true,
      config: config
    }}
  end

  @impl true
  def handle_output(plugin, output) when is_binary(output) do
    case Regex.scan(@url_pattern, output) do
      [] ->
        {:ok, plugin}
      urls ->
        new_output = Enum.reduce(urls, output, fn [url], acc ->
          String.replace(acc, url, create_hyperlink(url))
        end)
        {:ok, plugin, new_output}
    end
  end

  @impl true
  def handle_input(plugin, input) do
    # Process input for hyperlink-related commands
    case input do
      "link " <> url ->
        # Create and display a hyperlink
        hyperlink = create_hyperlink(url)
        {:ok, plugin, hyperlink}
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def handle_mouse(plugin, event) do
    # Handle mouse events for hyperlink interaction
    case event do
      {:click, x, y} ->
        # Check if click is within any hyperlink bounds
        case find_hyperlink_at_position(plugin, x, y) do
          nil -> {:ok, plugin}
          hyperlink -> handle_hyperlink_click(plugin, hyperlink, x, y)
        end
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def get_name(plugin) do
    plugin.name
  end

  @impl true
  def is_enabled?(plugin) do
    plugin.enabled
  end

  @impl true
  def enable(plugin) do
    %{plugin | enabled: true}
  end

  @impl true
  def disable(plugin) do
    %{plugin | enabled: false}
  end

  # Private functions

  defp create_hyperlink(url) do
    # OSC 8 escape sequence for hyperlinks
    # Format: \e]8;;URL\e\\text\e]8;;\e\\
    "\e]8;;#{url}\e\\#{url}\e]8;;\e\\"
  end

  defp find_hyperlink_at_position(_plugin, _x, _y) do
    # TODO: Implement hyperlink position tracking
    # For now, return nil to indicate no hyperlink found at position
    nil
  end

  defp handle_hyperlink_click(plugin, _hyperlink, _x, _y) do
    # TODO: Implement hyperlink click handling
    # For now, just return the plugin unchanged
    {:ok, plugin}
  end
end 