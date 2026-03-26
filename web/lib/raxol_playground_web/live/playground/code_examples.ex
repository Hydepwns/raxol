defmodule RaxolPlaygroundWeb.Playground.CodeExamples do
  @moduledoc """
  Code example access for the playground. Delegates to the shared Catalog.
  """

  alias Raxol.Playground.Catalog

  @doc "Returns all Catalog components."
  def list_components, do: Catalog.list_components()

  @doc "Returns the code snippet for a Catalog component."
  def get_code(%{code_snippet: snippet}), do: snippet
  def get_code(_), do: "# No code example available"
end
