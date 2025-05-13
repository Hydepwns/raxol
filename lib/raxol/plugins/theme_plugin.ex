defmodule Raxol.Plugins.ThemePlugin do
  @moduledoc """
  Plugin that manages terminal themes and color schemes.
  Allows users to apply predefined themes or create custom color schemes.
  """

  @behaviour Raxol.Plugins.Plugin

  defstruct [
    :name,
    :enabled,
    :config,
    :current_theme,
    :api_version,
    :dependencies
  ]

  alias Raxol.UI.Theming.Theme

  @impl true
  def init(config \\ %{}) do
    theme_name = Map.get(config, :theme, :default)
    theme = Theme.get(theme_name)

    {:ok,
     %__MODULE__{
       name: "theme",
       enabled: true,
       config: config,
       current_theme: theme,
       api_version: get_api_version(),
       dependencies: get_dependencies()
     }}
  end

  @impl true
  def handle_output(plugin, _output), do: {:ok, plugin}

  @impl Raxol.Plugins.Plugin
  def handle_mouse(plugin, _event, _emulator_state) do
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def handle_resize(plugin, _width, _height) do
    {:ok, plugin}
  end

  @impl true
  def handle_input(plugin, input) do
    case input do
      {:command, command} ->
        case String.slice(command, 0..6//1) do
          "theme: " ->
            theme_name = String.slice(command, 7..-1//1)

            case Theme.get(theme_name) do
              nil -> plugin
              theme -> %{plugin | current_theme: theme}
            end

          _ ->
            plugin
        end

      _ ->
        plugin
    end
  end

  def get_name(plugin), do: plugin.name
  def is_enabled?(plugin), do: plugin.enabled
  def enable(plugin), do: %{plugin | enabled: true}
  def disable(plugin), do: %{plugin | enabled: false}

  @impl true
  def cleanup(_plugin), do: :ok

  @impl true
  def get_api_version, do: "1.0.0"

  @impl true
  def get_dependencies, do: []

  @doc """
  Changes the current theme to the specified theme name.
  """
  def change_theme(plugin, theme_name) do
    case Theme.get(theme_name) do
      nil -> {:error, "Theme '#{theme_name}' not found"}
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
  """
  def register_theme(theme_attrs) do
    theme = Theme.new(theme_attrs)
    Theme.register(theme)
  end
end
