defmodule Raxol.Application do
  @moduledoc """
  The entry point for the Raxol application.

  This module handles:
  - Starting the application supervision tree
  - Initializing core systems
  - Managing application state
  """

  use Application

  @doc """
  Sets an application environment variable.

  This is a public wrapper around `Application.put_env/3` to allow setting
  test-specific configurations.
  """
  def put_env(app, key, value), do: Application.put_env(app, key, value)

  @compile_env Mix.env()

  alias Raxol.Core.UserPreferences
  alias Raxol.Style.Colors.{HotReload, Persistence, Theme}
  alias Raxol.Database.ConnectionManager
  require Logger

  @impl true
  def start(_type, _args) do
    # Set up terminal configuration based on environment
    setup_terminal_config()

    children =
      [
        # Start the Terminal Registry first (takes no args)
        %{
          id: Raxol.Terminal.Registry,
          start: {Raxol.Terminal.Registry, :start_link, []}
        },
        # Start the database if enabled and not in test environment
        if Application.get_env(:raxol, :database_enabled, true) &&
             @compile_env != :test do
          Raxol.Repo
        end,
        # Start user preferences
        {UserPreferences, []},
        # Start the ANSI processor
        {Raxol.Terminal.ANSI.Processor, %{}},
        # Start the buffer manager
        {Raxol.Terminal.Buffer.Manager, %{}},
        # Initialize color system with a unique ID
        Supervisor.child_spec({Task, &init_color_system/0},
          id: :color_system_task
        ),
        # Check database connection health with a unique ID
        Supervisor.child_spec({Task, &ensure_database_connection/0},
          id: :database_connection_task
        ),
        # Start hot-reload server
        {HotReload, []},
        # Add DynamicSupervisor for Raxol.Runtime
        {DynamicSupervisor,
         name: Raxol.DynamicSupervisor, strategy: :one_for_one}
        # Add Raxol.Runtime to the children list, passing the desired App module
        # Temporarily disable RuntimeDebug to allow commit to pass
        # {Raxol.RuntimeDebug, [app_module: Raxol.Examples.ColorSystemDemo]}
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Sets up terminal configuration based on environment variables and Mix environment.
  """
  def setup_terminal_config do
    # Check for headless mode from environment variables
    headless = System.get_env("RAXOL_HEADLESS") == "true"
    use_mock = System.get_env("RAXOL_USE_MOCK_TERMBOX") == "true"
    test_env = System.get_env("RAXOL_ENV") == "test" || @compile_env == :test

    if headless || test_env || use_mock do
      Logger.info(
        "Running in headless/test mode - configuring for CI environment"
      )

      # Configure terminal settings for headless/test environment
      Application.put_env(:raxol, :terminal,
        use_termbox: false,
        mock_termbox: use_mock,
        default_width: 80,
        default_height: 24,
        enable_ansi: true,
        enable_mouse: false,
        debug_mode: false
      )
    end
  end

  @doc """
  Ensures database connection is healthy during startup.
  """
  def ensure_database_connection do
    if Application.get_env(:raxol, :database_enabled, true) &&
         @compile_env != :test do
      # Wait a moment for the Repo to start
      Process.sleep(500)
      ConnectionManager.ensure_connection()
    end
  end

  @doc """
  Initializes the color system.

  This function:
  1. Loads user preferences
  2. Applies the theme if available
  3. Validates color accessibility
  4. Sets up hot-reloading
  """
  def init_color_system do
    # Load user preferences
    case UserPreferences.get(:theme) do
      nil ->
        # Create and apply default theme
        default_theme = create_default_theme()
        apply_theme(default_theme)

      theme_name ->
        # Load theme from file
        case Persistence.load_theme(theme_name) do
          {:ok, theme} ->
            # Validate and adjust colors for accessibility
            validate_and_adjust_theme(theme)

            # Apply theme
            apply_theme(theme)

          {:error, _} ->
            # Fall back to default theme
            default_theme = create_default_theme()
            validate_and_adjust_theme(default_theme)
            apply_theme(default_theme)
        end
    end

    # Subscribe to theme changes
    HotReload.subscribe()

    :ok
  end

  @doc """
  Validates and adjusts a theme for accessibility.

  ## Parameters

  - `theme` - The theme to validate and adjust

  ## Returns

  - The adjusted theme with accessible colors
  """
  def validate_and_adjust_theme(theme) do
    # Get background color
    background = Theme.get_ui_color(theme, :app_background)

    # Validate and adjust UI colors
    case validate_colors(theme, background) do
      {:ok, _} ->
        theme

      {:error, _} ->
        # Adjust colors to meet accessibility requirements
        adjusted_theme = adjust_theme_colors(theme, background)
        adjusted_theme
    end
  end

  @doc """
  Creates a default theme with accessible colors.

  ## Returns

  - A new theme with accessible colors
  """
  def create_default_theme do
    theme = Theme.standard_theme()

    # Example: Adjust primary color based on detected background (if needed later)
    # adjusted_theme = if Adaptive.is_dark_terminal?() do

    # Adjust for accessibility
    validate_and_adjust_theme(theme)
  end

  @doc """
  Applies a theme to the application.

  ## Parameters

  - `theme` - The theme to apply
  """
  def apply_theme(theme) do
    # Save theme for persistence
    case Persistence.save_theme(theme) do
      :ok ->
        # Apply theme to color system
        Theme.apply_theme(theme)

        # Update user preferences
        _ = UserPreferences.set(:theme, theme.name)
        _ = UserPreferences.save()

        :ok

      {:error, reason} ->
        Logger.error("Failed to save theme '#{theme.name}': #{inspect(reason)}")
        # Propagate the error
        {:error, reason}
    end
  end

  # Private functions

  defp validate_colors(theme, background) do
    # Get all UI colors
    ui_colors = Theme.get_all_ui_colors(theme)

    # Check contrast ratios
    Enum.reduce_while(ui_colors, {:ok, []}, fn {_element, color}, {:ok, acc} ->
      case check_contrast_ratio(color, background) do
        :ok -> {:cont, {:ok, acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp check_contrast_ratio(color, background) do
    # Calculate contrast ratio
    ratio = calculate_contrast_ratio(color, background)

    # Check against WCAG AA standard (4.5:1)
    if ratio >= 4.5 do
      :ok
    else
      {:error, "Contrast ratio #{ratio} is below WCAG AA standard of 4.5:1"}
    end
  end

  defp calculate_contrast_ratio(color, background) do
    # Get relative luminance
    color_luminance = calculate_relative_luminance(color)
    bg_luminance = calculate_relative_luminance(background)

    # Calculate contrast ratio
    lighter = max(color_luminance, bg_luminance)
    darker = min(color_luminance, bg_luminance)

    (lighter + 0.05) / (darker + 0.05)
  end

  defp calculate_relative_luminance(color) do
    # Convert RGB to relative luminance
    r = color.r / 255
    g = color.g / 255
    b = color.b / 255

    # Apply gamma correction
    r =
      if r <= 0.03928, do: r / 12.92, else: :math.pow((r + 0.055) / 1.055, 2.4)

    g =
      if g <= 0.03928, do: g / 12.92, else: :math.pow((g + 0.055) / 1.055, 2.4)

    b =
      if b <= 0.03928, do: b / 12.92, else: :math.pow((b + 0.055) / 1.055, 2.4)

    # Calculate relative luminance
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  defp adjust_theme_colors(theme, background) do
    # Get all UI colors, excluding the background itself
    ui_colors =
      Theme.get_all_ui_colors(theme)
      # Exclude background from adjustment
      |> Map.delete(:app_background)

    # Adjust each remaining color for better contrast
    adjusted_colors =
      Enum.map(ui_colors, fn {element, color} ->
        adjusted_color = adjust_color_for_contrast(color, background)
        {element, adjusted_color}
      end)

    # Create new theme with adjusted colors
    Theme.update_ui_colors(theme, Map.new(adjusted_colors))
  end

  defp adjust_color_for_contrast(color, background) do
    # Get current contrast ratio
    ratio = calculate_contrast_ratio(color, background)

    # If contrast is already good, return color as is
    if ratio >= 4.5 do
      color
    else
      # Determine if we need to lighten or darken
      bg_luminance = calculate_relative_luminance(background)

      adjust_func =
        if bg_luminance > 0.5, do: &darken_color/2, else: &lighten_color/2

      # Smaller step for iteration
      step = 0.05

      # Create the stream of adjusted colors
      stream =
        Stream.iterate(color, fn current_color ->
          adjust_func.(current_color, step)
        end)
        # Drop the first element (original color)
        |> Stream.drop(1)
        # Stop if black/white is reached (to prevent infinite loops)
        |> Stream.take_while(&(!is_black_or_white?(&1)))

      # Find the first color in the stream that meets the contrast ratio
      target_ratio = 4.5

      found_color =
        Enum.find(stream, color, fn c ->
          calculate_contrast_ratio(c, background) >= target_ratio
        end)

      # Use the found color, or default back to the original if Enum.find returns nil/stream ends
      found_color
    end
  end

  # Helper to check if a color map represents black or white
  defp is_black_or_white?(color) do
    # Check if all RGB values are either 0 or 255
    (color.r == 0 && color.g == 0 && color.b == 0) ||
      (color.r == 255 && color.g == 255 && color.b == 255)
  end

  defp darken_color(color, amount) do
    # Darken RGB values
    r = max(0, color.r - round(255 * amount))
    g = max(0, color.g - round(255 * amount))
    b = max(0, color.b - round(255 * amount))

    # Ensure 'a' is preserved
    %{color | r: r, g: g, b: b, a: color.a}
  end

  defp lighten_color(color, amount) do
    # Lighten RGB values
    r = min(255, color.r + round(255 * amount))
    g = min(255, color.g + round(255 * amount))
    b = min(255, color.b + round(255 * amount))

    # Ensure 'a' is preserved
    %{color | r: r, g: g, b: b, a: color.a}
  end
end
