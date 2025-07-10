defmodule Raxol.Plugins.ThemePlugin do
  @moduledoc """
  Plugin that manages terminal themes and color schemes.
  Allows users to apply predefined themes or create custom color schemes.
  """

  @behaviour Raxol.Plugins.Plugin
  @behaviour Raxol.Plugins.LifecycleBehaviour

  defstruct [
    :name,
    :version,
    :description,
    :enabled,
    :config,
    :dependencies,
    :api_version,
    :current_theme,
    state: %{}
  ]

  alias Raxol.UI.Theming.Theme

  @impl Raxol.Plugins.Plugin
  def init(config \\ %{}) do
    # Initialize the plugin struct with required fields
    metadata = get_metadata()
    current_theme = get_current_theme_from_config(config)

    plugin_state =
      struct(
        __MODULE__,
        Map.merge(
          %{
            name: metadata.name,
            version: metadata.version,
            description:
              "Plugin that manages terminal themes and color schemes.",
            enabled: true,
            config: config,
            dependencies: metadata.dependencies,
            api_version: get_api_version(),
            current_theme: current_theme,
            state: %{}
          },
          config
        )
      )

    {:ok, plugin_state}
  end

  @impl Raxol.Plugins.Plugin
  def handle_input(%__MODULE__{} = plugin, input) do
    case input do
      {:command, command} -> handle_theme_command(plugin, command)
      _ -> {:ok, plugin}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_output(%__MODULE__{} = plugin, _output) do
    # This plugin doesn't modify output, just passes it through
    {:ok, plugin}
  end

  defp handle_theme_command(plugin, command) do
    case String.slice(command, 0..6//1) do
      "theme: " -> apply_theme(plugin, String.slice(command, 7..-1//1))
      _ -> {:ok, plugin}
    end
  end

  defp apply_theme(plugin, theme_name) do
    case Theme.get(theme_name) do
      nil -> {:ok, plugin}
      theme -> {:ok, %{plugin | current_theme: theme}}
    end
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(%__MODULE__{} = plugin, _event, _emulator_state) do
    # This plugin doesn't handle mouse events
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    # This plugin doesn't need to react to resize
    {:ok, plugin}
  end

  def get_name(plugin), do: plugin.name
  def enabled?(plugin), do: plugin.enabled
  def enable(plugin), do: %{plugin | enabled: true}
  def disable(plugin), do: %{plugin | enabled: false}

  @impl Raxol.Plugins.Plugin
  def cleanup(_plugin), do: :ok

  @impl Raxol.Plugins.Plugin
  def get_api_version, do: "1.0.0"

  @impl Raxol.Plugins.Plugin
  def get_dependencies, do: []

  @doc """
  Changes the current theme to the specified theme name.
  """
  def change_theme(plugin, theme_name) do
    # Check if the theme actually exists in the application environment
    current_themes = Application.get_env(:raxol, :themes, %{})

    case Map.get(current_themes, theme_name) do
      nil -> {:error, "Theme \"#{theme_name}\" not found"}
      theme -> {:ok, %{plugin | current_theme: theme}}
    end
  end

  @doc """
  Gets the current theme.
  """
  def get_theme(plugin), do: plugin.current_theme

  @doc """
  Gets a list of available themes.
  """
  def list_themes do
    Theme.list_themes()
  end

  @doc """
  Registers a new theme.
  Can accept either a map of theme attributes or an existing Theme struct.
  """
  def register_theme(theme_input) do
    theme_to_register =
      case theme_input do
        %Raxol.UI.Theming.Theme{} = existing_theme ->
          existing_theme

        attrs when is_map(attrs) ->
          Theme.new(attrs)

        _ ->
          Raxol.Core.Runtime.Log.error(
            "[#{__MODULE__}] Invalid input to register_theme: #{inspect(theme_input)}"
          )

          nil
      end

    if theme_to_register do
      Theme.register(theme_to_register)
    else
      {:error, :invalid_theme_input_for_registration}
    end
  end

  @doc """
  Returns metadata for the plugin.
  """
  def get_metadata do
    %{
      name: "theme",
      version: "0.1.0",
      dependencies: []
    }
  end

  defp get_current_theme_from_config(config) do
    theme_name = Map.get(config, :theme, :default)

    if theme_name == :default do
      # Always use the default theme for consistency
      Theme.default_theme()
    else
      # For specific themes, try to get them, fallback to default
      Theme.get(theme_name) || Theme.default_theme()
    end
  end
end
