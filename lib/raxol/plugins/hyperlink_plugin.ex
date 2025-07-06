defmodule Raxol.Plugins.HyperlinkPlugin do
  import Raxol.Guards

  @moduledoc """
  Plugin that detects URLs in terminal output and makes them clickable.
  """

  @behaviour Raxol.Plugins.Plugin
  @behaviour Raxol.Plugins.LifecycleBehaviour
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
          api_version: String.t(),
          state: map()
          # Add plugin-specific fields here if needed
        }

  # Update defstruct to match the Plugin behaviour fields
  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :dependencies,
    :api_version,
    state: %{}
  ]

  @impl Raxol.Plugins.Plugin
  def init(config \\ %{}) do
    # Initialize the plugin struct with required fields
    metadata = get_metadata()

    plugin_state =
      struct(
        __MODULE__,
        Map.merge(
          %{
            name: metadata.name,
            version: metadata.version,
            description:
              "Plugin that detects URLs in terminal output and makes them clickable.",
            enabled: true,
            config: config,
            dependencies: metadata.dependencies,
            api_version: get_api_version(),
            state: %{}
          },
          config
        )
      )

    {:ok, plugin_state}
  end

  @impl Raxol.Plugins.Plugin
  def handle_input(%__MODULE__{} = plugin, _plugin_state, input) do
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
  def handle_output(%Raxol.Plugins.HyperlinkPlugin{} = plugin, event) do
    output =
      cond do
        is_binary(event) ->
          event

        is_map(event) and is_binary(Map.get(event, :data)) ->
          Map.get(event, :data)

        true ->
          ""
      end

    # Find URLs using a simple regex (could be more robust)
    url_regex = ~r{(https?://[\w./?=&\-]+)}

    if String.contains?(output, "http://") or
         String.contains?(output, "https://") do
      modified_output =
        String.replace(output, url_regex, fn url ->
          create_hyperlink(url)
        end)

      {:ok, plugin, modified_output}
    else
      {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(%__MODULE__{} = plugin, _plugin_state, event, rendered_cells) do
    case event do
      %{type: :mouse, button: :left, x: click_x, y: click_y, modifiers: []} ->
        handle_left_click(plugin, click_x, click_y, rendered_cells)

      _ ->
        {:ok, plugin}
    end
  end

  defp handle_left_click(plugin, x, y, rendered_cells) do
    case Map.get(rendered_cells, {x, y}) do
      %{style: %{hyperlink: url}} when binary?(url) and url != "" ->
        Raxol.Core.Runtime.Log.debug(
          "[HyperlinkPlugin] Clicked on hyperlink: #{url}"
        )

        case open_url(url) do
          :ok -> {:ok, plugin}
          {:error, _reason} -> {:ok, plugin}
        end

      _ ->
        {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_resize(%__MODULE__{} = plugin, _plugin_state, _width, _height) do
    # This plugin might not need to react to resize
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def cleanup(%Raxol.Plugins.HyperlinkPlugin{} = _plugin) do
    # No cleanup needed for hyperlink plugin
    :ok
  end

  def cleanup(_plugin) when is_map(_plugin) do
    # Handle case where plugin is passed as a map
    :ok
  end

  @impl Raxol.Plugins.Plugin
  def get_dependencies do
    # This plugin has no dependencies
    []
  end

  @impl Raxol.Plugins.Plugin
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

      {_output, _exit_code} ->
        Raxol.Core.Runtime.Log.error(
          # {url}" with command "#{command}". Exit code: #{exit_code}, Output: #{output}"
          "[HyperlinkPlugin] Failed to open URL "
        )

        {:error, :command_failed}
    end
  end

  @doc """
  Returns metadata for the plugin.
  """
  def get_metadata do
    %{
      name: "hyperlink",
      version: "0.1.0",
      dependencies: []
    }
  end
end
