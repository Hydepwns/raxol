defmodule Raxol.Core.ColorSystem do
  @moduledoc """
  Provides access to the application's color palette, considering the current theme
  and accessibility settings (like high contrast mode).

  Components should use `ColorSystem.get/2` to retrieve semantic colors.
  """

  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.Accessibility.ThemeIntegration
  # For color parsing/manipulation if needed
  alias Raxol.UI.Theming.Colors
  require Logger

  @doc """
  Gets the effective color value for a given semantic color name.

  It retrieves the color from the specified theme (by ID), automatically considering
  whether a high contrast variant is active based on accessibility settings.

  Args:
    - `theme_id`: The atom ID of the theme to use (e.g., :default, :dark).
    - `color_name`: The semantic name of the color (e.g., :primary, :background).

  Returns the color value (e.g., :red, {:rgb, r, g, b}) or nil if not found.
  """
  @spec get(atom(), atom()) :: Raxol.Style.Colors.color_value() | nil
  def get(theme_id, color_name)
      when is_atom(theme_id) and is_atom(color_name) do
    # Get the theme struct using the correct alias
    theme = Theme.get(theme_id)

    if theme do
      # Get the active accessibility variant (e.g., :high_contrast)
      active_variant_id = ThemeIntegration.get_active_variant()

      # Check variant palette first, then base palette
      # Get variant palette safely
      variant_palette = theme.variants[active_variant_id] |> Map.get(:palette)
      base_palette = theme.colors

      cond do
        variant_palette && Map.has_key?(variant_palette, color_name) ->
          Map.get(variant_palette, color_name)

        Map.has_key?(base_palette, color_name) ->
          Map.get(base_palette, color_name)

        true ->
          # Color not found in either palette
          nil
      end
    else
      Logger.warning(
        "ColorSystem: Theme with ID '#{theme_id}' not found. Falling back."
      )

      nil
    end
  end

  @doc """
  Gets a color value and ensures it's returned in a specific format (e.g., RGB tuple).
  Useful when a specific color representation is required for rendering.

  Args:
    - `theme_id`: The atom ID of the theme to use.
    - `color_name`: The semantic name of the color.
    - `format`: The desired output format (:rgb_tuple, :hex_string, :term).

  Supported formats: :rgb_tuple, :hex_string, :term
  """
  @spec get_as(atom(), atom(), atom()) :: any() | nil
  def get_as(theme_id, color_name, format \\ :term)
      when is_atom(theme_id) and is_atom(color_name) and is_atom(format) do
    # Pass theme_id to get/2
    color_value = get(theme_id, color_name)

    case color_value do
      nil ->
        nil

      _ ->
        case format do
          :rgb_tuple ->
            Colors.to_rgb(color_value)

          :hex_string ->
            Colors.to_hex(color_value)

          # Return the raw term (:red, {:rgb, ...}, etc.)
          :term ->
            color_value

          _ ->
            # Log warning about unsupported format?
            # Fallback to raw term
            color_value
        end
    end
  end

  # Potential future additions:
  # - Functions to manipulate colors (lighten, darken, mix)
  # - Functions to check color contrast ratios
end
