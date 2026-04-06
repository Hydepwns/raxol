defmodule Raxol.MCP.ResourceRouter do
  @moduledoc """
  Routes `raxol://` resource URIs to the appropriate data source.

  Parses structured URIs and dispatches to the Registry for registered
  resources, or to well-known handlers for pattern-based URIs.

  ## URI Patterns

  - `raxol://session/{id}/model/{key}` -- model projection
  - `raxol://session/{id}/widgets` -- widget tree
  - `raxol://session/{id}/tools` -- available tools
  - `raxol://session/{id}/context` -- full context tree
  """

  alias Raxol.MCP.Registry

  @type parsed :: %{
          scheme: String.t(),
          session: String.t(),
          path: [String.t()]
        }

  @doc """
  Parse a `raxol://` URI into structured components.

  Returns `{:ok, parsed}` or `{:error, :invalid_uri}`.
  """
  @spec parse(String.t()) :: {:ok, parsed()} | {:error, :invalid_uri}
  def parse("raxol://session/" <> rest) do
    case String.split(rest, "/", parts: 2) do
      [session_id] ->
        {:ok, %{scheme: "raxol", session: session_id, path: []}}

      [session_id, path_str] ->
        segments = String.split(path_str, "/") |> Enum.reject(&(&1 == ""))
        {:ok, %{scheme: "raxol", session: session_id, path: segments}}
    end
  end

  def parse("raxol://" <> _), do: {:error, :invalid_uri}
  def parse(_), do: {:error, :invalid_uri}

  @doc """
  Resolve a resource URI to its content.

  First tries a direct Registry lookup (for explicitly registered resources).
  Falls back to pattern-based resolution for well-known URI structures.
  """
  @spec resolve(GenServer.server(), String.t()) :: {:ok, term()} | {:error, term()}
  def resolve(registry, uri) do
    case Registry.read_resource(registry, uri) do
      {:ok, _} = ok ->
        ok

      {:error, :resource_not_found} ->
        resolve_pattern(registry, uri)

      error ->
        error
    end
  end

  # -- Pattern-based resolution ------------------------------------------------

  defp resolve_pattern(registry, uri) do
    case parse(uri) do
      {:ok, %{path: ["tools"]}} ->
        {:ok, Registry.list_tools(registry)}

      {:ok, %{path: ["resources"]}} ->
        {:ok, Registry.list_resources(registry)}

      {:ok, %{path: ["prompts"]}} ->
        {:ok, Registry.list_prompts(registry)}

      {:ok, _parsed} ->
        {:error, :resource_not_found}

      {:error, _} ->
        {:error, :resource_not_found}
    end
  end
end
