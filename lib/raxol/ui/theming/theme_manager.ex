defmodule Raxol.UI.Theming.ThemeManager do
  @moduledoc """
  Manages themes and theme switching for the UI system.
  """

  use GenServer
  require Logger

  defstruct [
    :current_theme,
    :available_themes,
    :theme_cache
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_theme(manager \\ __MODULE__, theme_id) do
    GenServer.call(manager, {:get_theme, theme_id})
  end

  def set_theme(manager \\ __MODULE__, theme_id) do
    GenServer.call(manager, {:set_theme, theme_id})
  end

  def list_themes(manager \\ __MODULE__) do
    GenServer.call(manager, :list_themes)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      current_theme: :default,
      available_themes: %{
        default: %{
          name: "Default",
          colors: %{primary: "#007acc", secondary: "#666"},
          fonts: %{main: "monospace"}
        },
        dark: %{
          name: "Dark",
          colors: %{primary: "#0078d4", secondary: "#888"},
          fonts: %{main: "monospace"}
        }
      },
      theme_cache: %{}
    }

    Logger.info("Theme manager initialized")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:get_theme, theme_id}, _from, state) do
    theme = Map.get(state.available_themes, theme_id)
    {:reply, theme, state}
  end

  @impl GenServer
  def handle_call({:set_theme, theme_id}, _from, state) do
    case Map.has_key?(state.available_themes, theme_id) do
      true ->
        new_state = %{state | current_theme: theme_id}
        {:reply, :ok, new_state}
      false ->
        {:reply, {:error, :theme_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_themes, _from, state) do
    themes = Map.keys(state.available_themes)
    {:reply, themes, state}
  end
end
