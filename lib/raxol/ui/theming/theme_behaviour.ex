defmodule Raxol.UI.Theming.ThemeBehaviour do
  @moduledoc """
  Defines the behaviour for Theme services.
  """

  @type theme_t :: Raxol.UI.Theming.Theme.t()

  @doc "Registers a theme."
  @callback register(theme :: theme_t()) :: :ok

  @doc "Gets a theme by ID."
  @callback get(theme_id :: atom()) :: theme_t() | nil

  @doc "Lists all registered themes."
  @callback list() :: list(theme_t())

  @doc "Gets the default theme."
  @callback default_theme() :: theme_t()

  @doc "Gets the dark theme."
  @callback dark_theme() :: theme_t()

  @doc "Gets a component style from a theme."
  @callback component_style(theme :: theme_t(), component_type :: atom()) ::
              map()

  @doc "Gets a color from a theme."
  @callback color(theme :: theme_t(), color_name :: atom()) :: any()

  @doc "Gets a color value considering the theme and an optional variant."
  @callback get_color(
              theme :: theme_t(),
              color_name :: atom(),
              variant_id :: atom() | nil
            ) :: any()

  @doc "Applies a theme to an element tree."
  @callback apply_theme(element :: map() | list(map()), theme :: theme_t()) ::
              map() | list(map())

  # Add init/0 if it's part of the public API used by others
  @doc "Initializes the theme system."
  @callback init() :: :ok

  @doc "Gets the current theme system version as a string."
  @callback current_version() :: String.t()
end
