defmodule Raxol.Plugins.HyperlinkPlugin do
  @moduledoc """
  Plugin that detects URLs in terminal output and makes them clickable.
  """

  @behaviour Raxol.Plugins.Plugin
  alias Raxol.Plugins.Plugin

  # Require Logger for logging macros
  require Logger

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
  defstruct name: "hyperlink",
            version: "0.1.0",
            description:
              "Detects URLs in terminal output and makes them clickable.",
            enabled: true,
            config: %{},
            dependencies: [],
            api_version: "1.0.0"

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
        new_output =
          Enum.reduce(urls, output, fn [url], acc ->
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

      _ ->
        {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(%__MODULE__{} = plugin, event, _emulator_state) do
    # Only handle left clicks for now
    case event do
      %{type: :mouse, button: :left, x: click_x, y: click_y, modifiers: []} ->
        # TODO: Resolve how to get the Cell at (click_x, click_y) from _emulator_state.
        # The Cell's style map should contain the hyperlink URL if the renderer
        # correctly processes OSC 8 sequences.
        # Once cell data is available, extract the URL and call open_url(url).
        # Example placeholder logic:
        # case get_cell_at(_emulator_state, click_x, click_y) do
        #   %Raxol.Terminal.Cell{style: %{hyperlink: url}} when is_binary(url) ->
        #     open_url(url)
        #   _ ->
        #     :ok # Click was not on a hyperlink
        # end
        Logger.debug("[HyperlinkPlugin] Mouse click detected at (#{click_x}, #{click_y}). URL opening disabled until cell data retrieval is fixed.")
        {:ok, plugin}

      _ ->
        # Ignore other mouse events (right click, wheel, etc.)
        {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    # This plugin might not need to react to resize
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

  # credo:disable-for-next-line UnusedFunction
  defp open_url(url) do
    command =
      case :os.type() do
        {:unix, :darwin} -> "open"
        {:unix, _} -> "xdg-open" # Covers Linux and other Unix-like
        {:win32, _} -> "start"
      end

    case System.cmd(command, [url], stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("[HyperlinkPlugin] Opened URL: #{url}")
        :ok
      {output, exit_code} ->
        Logger.error("[HyperlinkPlugin] Failed to open URL '#{url}' with command '#{command}'. Exit code: #{exit_code}, Output: #{output}")
        {:error, :command_failed}
    end
  end
end
