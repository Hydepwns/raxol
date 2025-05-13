defmodule Raxol.Examples.ColorSystemDemo do
  @moduledoc """
  Demonstrates the color system capabilities using the Application behaviour.
  """

  # Add Application behaviour and required aliases/requires
  use Raxol.Core.Runtime.Application
  require Logger
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI
  alias Raxol.Style.Colors.{Color, Palette, Theme, Utilities}
  # Adaptive module alias might be needed later
  alias Raxol.Style.Colors.Adaptive

  # Define application state to hold the demo theme
  defstruct theme: nil

  # --- Application Lifecycle ---

  @doc """
  Starts the Color System Demo application.
  """
  def run do
    Logger.info("Starting Color System Demo Application...")
    Raxol.Core.Runtime.Lifecycle.start_application(__MODULE__, %{})
  end

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    Logger.info("Initializing Color System Demo...")
    # Create the demo theme during initialization
    demo_theme = create_demo_theme()
    {:ok, %__MODULE__{theme: demo_theme}}
  end

  # --- Application Behaviour Callbacks ---

  @impl Raxol.Core.Runtime.Application
  def view(state) do
    theme = state.theme
    # Get adapted theme
    adapted_theme = Adaptive.adapt_theme(theme)

    UI.box padding: 1 do
      UI.column spacing: 1 do
        [
          # Theme Info Section
          UI.box border: :single do
            UI.column do
              ([UI.label(content: "--- Theme Info ---")] ++
                 render_theme_info(theme))
              |> Enum.map(&UI.label(&1))
            end
          end,

          # Palette View Section
          UI.box border: :single do
            UI.column do
              ([UI.label(content: "--- Palette View ---")] ++
                 render_palette_view(theme.colors))
              |> Enum.map(&UI.label(&1))
            end
          end,

          # Color Adaptation Section
          UI.box border: :single do
            UI.column do
              ([UI.label(content: "--- Color Adaptation ---")] ++
                 render_color_adaptation_view(theme, adapted_theme))
              |> Enum.map(&UI.label(&1))
            end
          end,

          # Accessibility View Section
          UI.box border: :single do
            UI.column do
              ([UI.label(content: "--- Accessibility View ---")] ++
                 render_accessibility_view(theme))
              |> Enum.map(&UI.label(&1))
            end
          end
        ]
      end
    end
  end

  @impl Raxol.Core.Runtime.Application
  def update(msg, state) do
    Logger.debug("Unhandled update: #{inspect(msg)}")
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(event) do
    Logger.debug(
      "ColorSystemDemo received unhandled event (handle_event/1): #{inspect(event)}"
    )

    # Return empty list of commands
    []
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(msg, state) do
    Logger.debug("Unhandled handle_message: #{inspect(msg)}")
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_tick(state) do
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state), do: []

  @impl Raxol.Core.Runtime.Application
  def terminate(reason, _state) do
    Logger.info("Terminating Color System Demo: #{inspect(reason)}")
    :ok
  end

  # --- Helper Functions (Modified) ---

  defp create_demo_theme do
    Theme.new(%{
      name: "Demo",
      colors: %{
        primary: Color.from_hex("#0077CC"),
        secondary: Color.from_hex("#00AA00"),
        accent: Color.from_hex("#FF0000"),
        text: Color.from_hex("#333333"),
        background: Color.from_hex("#FFFFFF")
      },
      styles: %{},
      dark_mode: false,
      high_contrast: false
    })
  end

  # Modified to return list of strings
  defp render_theme_info(theme) do
    [
      "Theme: #{theme.name}",
      "Background: #{inspect(theme.colors.background)}",
      "Primary: #{inspect(theme.colors.primary)}",
      "Secondary: #{inspect(theme.colors.secondary)}",
      "Accent: #{inspect(theme.colors.accent)}",
      "Text: #{inspect(theme.colors.text)}"
    ]
  end

  # Modified to return list of strings
  defp render_palette_view(colors) do
    [
      "Colors:"
    ] ++ render_color_list(colors)
  end

  # Returns list of strings
  defp render_color_list(colors) do
    colors
    |> Enum.map(fn {name, color} ->
      hex = if is_struct(color, Color), do: color.hex, else: inspect(color)
      "  #{name}: #{hex}"
    end)
  end

  # Modified to return list of strings and accept adapted_theme
  defp render_color_adaptation_view(original_theme, adapted_theme) do
    [
      "Original Theme:",
      "----------------"
    ] ++
      render_theme_info(original_theme) ++
      ["", "Adapted Theme:", "---------------"] ++
      render_theme_info(adapted_theme)
  end

  # Modified to return list of strings
  defp render_accessibility_view(theme) do
    [
      "Background-Text Contrast: #{check_contrast(theme.colors.background, theme.colors.text)}",
      "Background-Primary Contrast: #{check_contrast(theme.colors.background, theme.colors.primary)}",
      "Background-Secondary Contrast: #{check_contrast(theme.colors.background, theme.colors.secondary)}",
      "Background-Accent Contrast: #{check_contrast(theme.colors.background, theme.colors.accent)}"
    ]
  end

  # Kept as is, returns string
  defp check_contrast(color1, color2) do
    ratio = Utilities.contrast_ratio(color1, color2)

    cond do
      ratio >= 7.0 -> "AAA (#{ratio |> Float.round(2)})"
      ratio >= 4.5 -> "AA (#{ratio |> Float.round(2)})"
      true -> "Insufficient (#{ratio |> Float.round(2)})"
    end
  end
end
