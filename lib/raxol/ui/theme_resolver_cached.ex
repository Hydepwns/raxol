defmodule Raxol.UI.ThemeResolverCached do
  @moduledoc """
  Cached theme resolution module providing backward compatibility.

  This module delegates to Raxol.UI.ThemeResolver with caching enabled by default.
  All functions in this module use caching to provide optimal performance.
  """

  alias Raxol.UI.ThemeResolver

  @doc """
  Resolves styles with caching enabled.
  Returns {fg_color, bg_color, style_attrs}.
  """
  def resolve_styles(attrs, component_type, theme) do
    ThemeResolver.resolve_styles(attrs, component_type, theme, cache: true)
  end

  @doc """
  Resolves element theme with caching enabled.
  """
  def resolve_element_theme(element_theme, default_theme) do
    ThemeResolver.resolve_element_theme(element_theme, default_theme, cache: true)
  end

  @doc """
  Merges themes for inheritance.
  """
  def merge_themes_for_inheritance(parent_theme, child_theme) do
    ThemeResolver.merge_themes_for_inheritance(parent_theme, child_theme)
  end

  @doc """
  Resolves foreground color with caching.
  """
  def resolve_fg_color(attrs, component_styles, theme) do
    ThemeResolver.resolve_fg_color(attrs, component_styles, theme)
  end

  @doc """
  Resolves background color with caching.
  """
  def resolve_bg_color(attrs, component_styles, theme) do
    ThemeResolver.resolve_bg_color(attrs, component_styles, theme)
  end

  @doc """
  Resolves variant color with caching.
  """
  def resolve_variant_color(attrs, theme, color_type) do
    ThemeResolver.resolve_variant_color(attrs, theme, color_type)
  end

  @doc """
  Gets component styles with caching.
  """
  def get_component_styles(component_type, theme) do
    ThemeResolver.get_component_styles(component_type, theme)
  end

  @doc """
  Clears all cached theme and style data.
  """
  def clear_cache do
    ThemeResolver.clear_cache()
  end

  @doc """
  Gets the default theme with caching enabled.
  """
  def get_default_theme do
    ThemeResolver.get_default_theme(cache: true)
  end
end