defmodule Raxol.Plugins.HyperlinkPlugin do
  @moduledoc """
  Plugin that detects URLs in terminal output and makes them clickable.
  """

  @behaviour Raxol.Plugins.Plugin
  alias Raxol.Plugins.Plugin

  # Require Raxol.Core.Runtime.Log for logging macros
  require Raxol.Core.Runtime.Log

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
  def handle_output(%Raxol.Plugins.HyperlinkPlugin{} = plugin, output) do
    # Find URLs using a simple regex (could be more robust)
    # Basic URL regex (adjust as needed)
    url_regex = ~r{(https?://[\w./?=&\-]+)}

    # Simpler check: Does the output contain a potential URL?
    if String.contains?(output, "http://") or
         String.contains?(output, "https://") do
      # Attempt replacement if potential URL found
      modified_output =
        String.replace(output, url_regex, fn url ->
          create_hyperlink(url)
        end)

      # Return 3-tuple only if replacement actually happened
      if modified_output != output do
        {:ok, plugin, modified_output}
      else
        # If replace didn't change anything (e.g., malformed URL), return 2-tuple
        {:ok, plugin}
      end
    else
      # No http:// or https:// found, definitely no change
      # Return 2-tuple
      {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(%__MODULE__{} = plugin_state, event, rendered_cells) do
    # Only handle left clicks for now
    case event do
      %{type: :mouse, button: :left, x: click_x, y: click_y, modifiers: []} ->
        # Look up cell data using the passed rendered_cells map
        case Map.get(rendered_cells, {click_x, click_y}) do
          %{style: %{hyperlink: url}} when is_binary(url) and url != "" ->
            Raxol.Core.Runtime.Log.debug(
              "[HyperlinkPlugin] Clicked on hyperlink: #{url}"
            )

            # Attempt to open the URL
            case open_url(url) do
              :ok ->
                # URL opened successfully, halt event propagation
                {:ok, plugin_state}

              {:error, _reason} ->
                # Failed to open, propagate event (maybe app wants to handle it?)
                {:ok, plugin_state}
            end

          _ ->
            # Click was not on a cell with a hyperlink style
            {:ok, plugin_state}
        end

      _ ->
        # Ignore other mouse events (right click, wheel, etc.)
        {:ok, plugin_state}
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

  # Opens the given URL using the OS-specific command.
  defp open_url(url) do
    command =
      case :os.type() do
        {:unix, :darwin} -> "open"
        # Covers Linux and other Unix-like
        {:unix, _} -> "xdg-open"
        {:win32, _} -> "start"
      end

    case System.cmd(command, [url], stderr_to_stdout: true) do
      {_output, 0} ->
        Raxol.Core.Runtime.Log.info("[HyperlinkPlugin] Opened URL: #{url}")
        :ok

      {output, exit_code} ->
        Raxol.Core.Runtime.Log.error(
          "[HyperlinkPlugin] Failed to open URL '#{url}' with command '#{command}'. Exit code: #{exit_code}, Output: #{output}"
        )

        {:error, :command_failed}
    end
  end
end
