defmodule Raxol.Examples.ColorSystemDemo do
  @moduledoc """
  Demonstrates the color system capabilities using the Application behaviour.
  """

  use Raxol.Core.Runtime.Application
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI
  alias Raxol.UI.Theming.Theme
  alias Raxol.Style.Colors.{Color, Utilities}
  alias Raxol.Style.Colors.Adaptive

  defstruct theme: nil

  @doc """
  Starts the Color System Demo application.
  """
  def run do
    Raxol.Core.Runtime.Log.info("Starting Color System Demo Application...")
    Raxol.Core.Runtime.Lifecycle.start_application(__MODULE__, %{})
  end

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    Raxol.Core.Runtime.Log.info("Initializing Color System Demo...")
    demo_theme = create_demo_theme()
    {:ok, %__MODULE__{theme: demo_theme}}
  end

  @doc """
  Render the color system demo UI.
  """
  @impl Raxol.Core.Runtime.Application
  @dialyzer {:nowarn_function, view: 1}
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
              [UI.label(content: "--- Theme Info ---")] ++
                Enum.map(render_theme_info(theme), fn str ->
                  %{type: :label, attrs: [content: str]}
                end)
            end
          end,

          # Palette View Section
          UI.box border: :single do
            UI.column do
              [UI.label(content: "--- Palette View ---")] ++
                Enum.map(render_palette_view(theme.colors), fn str ->
                  %{type: :label, attrs: [content: str]}
                end)
            end
          end,

          # Color Adaptation Section
          UI.box border: :single do
            UI.column do
              [UI.label(content: "--- Color Adaptation ---")] ++
                Enum.map(
                  render_color_adaptation_view(theme, adapted_theme),
                  fn str -> %{type: :label, attrs: [content: str]} end
                )
            end
          end,

          # Accessibility View Section
          UI.box border: :single do
            UI.column do
              [UI.label(content: "--- Accessibility View ---")] ++
                Enum.map(render_accessibility_view(theme), fn str ->
                  %{type: :label, attrs: [content: str]}
                end)
            end
          end
        ]
      end
    end
  end

  @impl Raxol.Core.Runtime.Application
  def update(msg, state) do
    Raxol.Core.Runtime.Log.debug("Unhandled update: #{inspect(msg)}")
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(event) do
    Raxol.Core.Runtime.Log.debug(
      "ColorSystemDemo received unhandled event (handle_event/1): #{inspect(event)}"
    )

    # Return empty list of commands
    []
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(msg, state) do
    Raxol.Core.Runtime.Log.debug("Unhandled handle_message: #{inspect(msg)}")
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
    Raxol.Core.Runtime.Log.info(
      "Terminating Color System Demo: #{inspect(reason)}"
    )

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
