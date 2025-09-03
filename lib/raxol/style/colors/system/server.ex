defmodule Raxol.Style.Colors.System.Server do
  @moduledoc """
  GenServer implementation for the color system in Raxol.

  This server manages color themes, high contrast settings, and provides
  color resolution services while eliminating Process dictionary usage.

  ## Features
  - Theme management and switching
  - High contrast mode support
  - Automatic accessibility adjustments
  - Color caching and resolution
  - Event-driven theme changes
  """

  use GenServer
  require Logger

  alias Raxol.Style.Colors.{Color, Utilities}
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.Events.Manager, as: EventManager

  @default_theme :default

  # Client API

  @doc """
  Starts the Color System server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns a child specification for this server.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  # Public API

  @doc """
  Initialize the color system with a theme and settings.
  """
  def init_system(opts \\ []) do
    GenServer.call(__MODULE__, {:init_system, opts})
  end

  @doc """
  Get a color from the current theme.
  """
  def get_color(color_name, variant \\ :base) do
    GenServer.call(__MODULE__, {:get_color, color_name, variant})
  end

  @doc """
  Get the current theme.
  """
  def get_current_theme do
    GenServer.call(__MODULE__, :get_current_theme)
  end

  @doc """
  Get the current theme name.
  """
  def get_current_theme_name do
    GenServer.call(__MODULE__, :get_current_theme_name)
  end

  @doc """
  Check if high contrast mode is enabled.
  """
  def get_high_contrast do
    GenServer.call(__MODULE__, :get_high_contrast)
  end

  @doc """
  Apply a theme to the color system.
  """
  def apply_theme(theme_name, opts \\ []) do
    GenServer.call(__MODULE__, {:apply_theme, theme_name, opts})
  end

  @doc """
  Register a custom theme.
  """
  def register_theme(theme_attrs) do
    GenServer.call(__MODULE__, {:register_theme, theme_attrs})
  end

  @doc """
  Handle high contrast mode changes.
  """
  def handle_high_contrast(event) do
    GenServer.cast(__MODULE__, {:handle_high_contrast, event})
  end

  @doc """
  Get a UI color by role.
  """
  def get_ui_color(ui_role) do
    GenServer.call(__MODULE__, {:get_ui_color, ui_role})
  end

  @doc """
  Get all UI colors for the current theme.
  """
  def get_all_ui_colors do
    GenServer.call(__MODULE__, :get_all_ui_colors)
  end

  @doc """
  Get accessibility options from the server.
  """
  def get_accessibility_options do
    GenServer.call(__MODULE__, :get_accessibility_options)
  end

  @doc """
  Set accessibility options.
  """
  def set_accessibility_options(options) do
    GenServer.call(__MODULE__, {:set_accessibility_options, options})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Initialize with default theme
    initial_theme_id = Keyword.get(opts, :theme, @default_theme)
    initial_theme = Theme.get(initial_theme_id)

    # Get high contrast setting
    high_contrast = Keyword.get(opts, :high_contrast, false)

    # Get accessibility options if provided
    accessibility_options =
      Keyword.get(opts, :accessibility_options, %{
        high_contrast: high_contrast
      })

    state = %{
      current_theme: initial_theme,
      current_theme_name: initial_theme_id,
      high_contrast: high_contrast,
      accessibility_options: accessibility_options,
      color_cache: %{},
      registered_themes: %{}
    }

    # Register event handler for accessibility changes
    EventManager.register_handler(
      :accessibility_high_contrast,
      __MODULE__,
      :handle_high_contrast
    )

    {:ok, state}
  end

  # Handle system initialization
  @impl true
  def handle_call({:init_system, opts}, _from, state) do
    initial_theme_id = Keyword.get(opts, :theme, state.current_theme_name)
    initial_theme = Theme.get(initial_theme_id)

    # Check for accessibility options
    high_contrast =
      case state.accessibility_options do
        nil ->
          Keyword.get(opts, :high_contrast, false)

        accessibility_options ->
          Keyword.get(
            opts,
            :high_contrast,
            accessibility_options[:high_contrast]
          )
      end

    updated_state = %{
      state
      | current_theme: initial_theme,
        current_theme_name: initial_theme_id,
        high_contrast: high_contrast,
        # Clear cache on reinit
        color_cache: %{}
    }

    # Dispatch theme change event
    EventManager.dispatch(
      {:theme_changed,
       %{
         theme: initial_theme,
         high_contrast: high_contrast
       }}
    )

    {:reply, :ok, updated_state}
  end

  # Handle color retrieval
  @impl true
  def handle_call({:get_color, color_name, variant}, _from, state) do
    # Check cache first
    cache_key = {color_name, variant, state.high_contrast}

    color =
      case Map.get(state.color_cache, cache_key) do
        nil ->
          # Calculate color
          calculated_color =
            if state.high_contrast do
              get_high_contrast_color(state.current_theme, color_name, variant)
            else
              get_standard_color(state.current_theme, color_name, variant)
            end

          # Convert to Color struct if needed
          final_color =
            case calculated_color do
              %Color{} = c -> c
              hex when is_binary(hex) -> Color.from_hex(hex)
              _ -> nil
            end

          # Cache the result
          updated_cache = Map.put(state.color_cache, cache_key, final_color)
          updated_state = %{state | color_cache: updated_cache}

          {final_color, updated_state}

        cached_color ->
          {cached_color, state}
      end

    case color do
      {color_value, new_state} -> {:reply, color_value, new_state}
      color_value -> {:reply, color_value, state}
    end
  end

  # Handle theme retrieval
  @impl true
  def handle_call(:get_current_theme, _from, state) do
    {:reply, state.current_theme, state}
  end

  @impl true
  def handle_call(:get_current_theme_name, _from, state) do
    {:reply, state.current_theme_name, state}
  end

  @impl true
  def handle_call(:get_high_contrast, _from, state) do
    {:reply, state.high_contrast, state}
  end

  # Handle theme application
  @impl true
  def handle_call({:apply_theme, theme_name, opts}, _from, state) do
    high_contrast = Keyword.get(opts, :high_contrast, state.high_contrast)
    theme = Theme.get(theme_name)

    updated_state = %{
      state
      | current_theme: theme,
        current_theme_name: theme_name,
        high_contrast: high_contrast,
        # Clear cache on theme change
        color_cache: %{}
    }

    # Dispatch theme change event
    EventManager.dispatch(
      {:theme_changed,
       %{
         theme: theme,
         high_contrast: high_contrast
       }}
    )

    {:reply, :ok, updated_state}
  end

  # Handle theme registration
  @impl true
  def handle_call({:register_theme, theme_attrs}, _from, state) do
    theme = Theme.new(theme_attrs)
    Theme.register(theme)

    updated_themes = Map.put(state.registered_themes, theme.name, theme)
    updated_state = %{state | registered_themes: updated_themes}

    {:reply, :ok, updated_state}
  end

  # Handle UI color retrieval
  @impl true
  def handle_call({:get_ui_color, ui_role}, _from, state) do
    color =
      case Map.fetch(state.current_theme.ui_mappings || %{}, ui_role) do
        {:ok, color_name} when is_atom(color_name) ->
          resolve_color(state, color_name, :base)

        {:ok, color_name} when is_binary(color_name) ->
          resolve_color(state, String.to_atom(color_name), :base)

        _ ->
          nil
      end

    {:reply, color, state}
  end

  @impl true
  def handle_call(:get_all_ui_colors, _from, state) do
    colors =
      if state.current_theme do
        (state.current_theme.ui_mappings || %{})
        |> Enum.map(fn {role, color_name} ->
          color_atom =
            if is_atom(color_name),
              do: color_name,
              else: String.to_atom(color_name)

          {role, resolve_color(state, color_atom, :base)}
        end)
        |> Enum.into(%{})
      else
        %{}
      end

    {:reply, colors, state}
  end

  # Handle accessibility options
  @impl true
  def handle_call(:get_accessibility_options, _from, state) do
    {:reply, state.accessibility_options, state}
  end

  @impl true
  def handle_call({:set_accessibility_options, options}, _from, state) do
    updated_state = %{state | accessibility_options: options}

    # Update high contrast if it changed
    if options[:high_contrast] != state.high_contrast do
      updated_state = %{
        updated_state
        | high_contrast: options[:high_contrast],
          # Clear cache on high contrast change
          color_cache: %{}
      }

      EventManager.dispatch({:high_contrast_changed, options[:high_contrast]})
    end

    {:reply, :ok, updated_state}
  end

  # Handle high contrast events
  @impl true
  def handle_cast(
        {:handle_high_contrast, {:accessibility_high_contrast, enabled}},
        state
      ) do
    updated_state = %{
      state
      | high_contrast: enabled,
        # Clear cache on high contrast change
        color_cache: %{}
    }

    # Dispatch high contrast change event
    EventManager.dispatch({:high_contrast_changed, enabled})

    # Re-apply current theme with new high contrast setting
    EventManager.dispatch(
      {:theme_changed,
       %{
         theme: state.current_theme,
         high_contrast: enabled
       }}
    )

    {:noreply, updated_state}
  end

  # Private helper functions

  defp resolve_color(state, color_name, variant) do
    if state.high_contrast do
      get_high_contrast_color(state.current_theme, color_name, variant)
    else
      get_standard_color(state.current_theme, color_name, variant)
    end
    |> case do
      %Color{} = c -> c
      hex when is_binary(hex) -> Color.from_hex(hex)
      _ -> nil
    end
  end

  defp get_standard_color(nil, _color_name, _variant), do: nil

  defp get_standard_color(theme, color_name, variant) do
    val =
      Map.get(theme.variants || %{}, {color_name, variant}) ||
        Map.get(theme.colors, color_name) ||
        Map.get(
          theme.variants || %{},
          {to_string(color_name), to_string(variant)}
        ) ||
        Map.get(theme.colors, to_string(color_name))

    case val do
      %Color{} = c -> c.hex
      hex when is_binary(hex) -> hex
      _ -> nil
    end
  end

  defp get_high_contrast_color(theme, color_name, variant) do
    # First try to get a specific high contrast variant
    val = get_high_contrast_variant(theme, color_name, variant)

    case val do
      %Color{} = c ->
        c.hex

      hex when is_binary(hex) ->
        hex

      _ ->
        # Generate high contrast version from standard color
        standard_color = get_standard_color(theme, color_name, variant)

        case standard_color do
          nil ->
            nil

          hex when is_binary(hex) ->
            color = Color.from_hex(hex)
            background_color = get_background_color(theme)

            high_contrast_color =
              generate_high_contrast_color(color, background_color)

            high_contrast_color.hex

          _ ->
            standard_color
        end
    end
  end

  defp get_high_contrast_variant(theme, color_name, variant) do
    Map.get(theme.variants || %{}, {color_name, variant, :high_contrast}) ||
      Map.get(
        theme.variants || %{},
        {to_string(color_name), to_string(variant), "high_contrast"}
      )
  end

  defp get_background_color(theme) do
    background = get_standard_color(theme, :background, :base)

    if background do
      Color.from_hex(background)
    else
      Color.from_hex("#000000")
    end
  end

  defp generate_high_contrast_color(color, background_color) do
    current_ratio = Utilities.contrast_ratio(color, background_color)
    # AAA level
    target_ratio = 7.0

    if current_ratio >= target_ratio do
      Utilities.increase_contrast(color)
    else
      adjusted_color =
        Utilities.adjust_for_contrast(color, background_color, :aaa, :normal)

      if adjusted_color.hex == color.hex do
        Utilities.increase_contrast(color)
      else
        adjusted_color
      end
    end
  end
end
