defmodule RaxolPlaygroundWeb.Playground.Helpers do
  @moduledoc """
  Helper functions for the Raxol playground web UI.
  """

  @doc "Returns Tailwind CSS classes for complexity badges."
  def complexity_class(:basic), do: "bg-green-100 text-green-800"
  def complexity_class(:intermediate), do: "bg-yellow-100 text-yellow-800"
  def complexity_class(:advanced), do: "bg-red-100 text-red-800"
  def complexity_class(_), do: "bg-gray-100 text-gray-800"

  @doc "Returns a human-readable label for a complexity atom."
  def complexity_label(:basic), do: "Basic"
  def complexity_label(:intermediate), do: "Intermediate"
  def complexity_label(:advanced), do: "Advanced"
  def complexity_label(other), do: to_string(other)

  @doc "Returns a human-readable label for a category atom."
  def category_label(cat), do: cat |> to_string() |> String.capitalize()
end
