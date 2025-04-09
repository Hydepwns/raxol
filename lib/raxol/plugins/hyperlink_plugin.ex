defmodule Raxol.Plugins.HyperlinkPlugin do
  @moduledoc """
  Plugin that detects URLs in terminal output and makes them clickable.
  """

  @behaviour Raxol.Plugins.Plugin
  alias Raxol.Plugins.Plugin

  @url_pattern ~r/https?:\/\/[^\s<>"]+|www\.[^\s<>"]+/i

  # Define the struct type matching the Plugin behaviour
  @type t :: %Plugin{
    name: String.t(),
    version: String.t(),
    description: String.t(),
    enabled: boolean(),
    config: map(),
    dependencies: list(map()),
    api_version: String.t()
    # Add plugin-specific fields here if needed
  }

  # Update defstruct to match the Plugin behaviour fields
  defstruct [
    name: "hyperlink",
    version: "0.1.0",
    description: "Detects URLs in terminal output and makes them clickable.",
    enabled: true,
    config: %{},
    dependencies: [],
    api_version: "1.0.0"
  ]

  @impl true
  def init(config \\ %{}) do
    # Initialize the plugin struct, merging provided config
    plugin_state = struct(__MODULE__, config)
    {:ok, plugin_state}
  end

  @impl true
  def handle_output(%__MODULE__{} = plugin, output) when is_binary(output) do
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
  def handle_input(%__MODULE__{} = plugin, input) do
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
  def handle_mouse(%__MODULE__{} = plugin, event) do
    # Handle mouse events for hyperlink interaction
    case event do
      {:click, x, y} ->
        # Check if click is within any hyperlink bounds
        case find_hyperlink_at_position(plugin, x, y) do
          nil -> {:ok, plugin}
          # hyperlink -> handle_hyperlink_click(plugin, hyperlink, x, y) # Unreachable - find_hyperlink_at_position always returns nil
        end
      _ -> {:ok, plugin}
    end
  end

  # Add missing behaviour callbacks
  @impl true
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    # This plugin doesn't need to react to resize
    {:ok, plugin}
  end

  @impl true
  def cleanup(%__MODULE__{} = _plugin) do
    # No cleanup needed for this plugin
    :ok
  end

  @impl true
  def get_dependencies do
    # This plugin has no dependencies
    []
  end

  @impl true
  def get_api_version do
    "1.0.0"
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

  # defp handle_hyperlink_click(%__MODULE__{} = plugin, _hyperlink, _x, _y) do
  #   # TODO: Implement hyperlink click handling (e.g., open in browser)
  #   # For now, just return the plugin unchanged
  #   {:ok, plugin}
  # end
end
