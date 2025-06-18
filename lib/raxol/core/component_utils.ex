defmodule Raxol.Core.ComponentUtils do
  @moduledoc """
  Utility functions for component-related logic shared across Raxol modules.
  """

  @doc """
  Determines if a component is considered important (e.g., header, navigation, menu).
  This is used for performance optimizations and gesture prioritization.
  """
  @spec is_important_component?(String.t(), any()) :: boolean()
  def is_important_component?(component_name, _state) do
    String.contains?(component_name, "header") or
      String.contains?(component_name, "navigation") or
      String.contains?(component_name, "menu")
  end
end
