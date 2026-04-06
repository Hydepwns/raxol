defmodule Raxol.Plugin.Manifest do
  @moduledoc """
  Cross-package-safe manifest builder for Raxol plugins.

  Wraps the core `Raxol.Core.Runtime.Plugins.Manifest` struct as a plain
  map so that consumers in separate packages do not need a compile-time
  dependency on the struct definition.

  ## Usage

      manifest = Raxol.Plugin.Manifest.new(
        id: :my_plugin,
        name: "My Plugin",
        version: "1.0.0",
        module: MyPlugin
      )

      case Raxol.Plugin.Manifest.validate(manifest) do
        :ok -> IO.puts("valid")
        {:error, errors} -> IO.inspect(errors)
      end
  """

  @compile {:no_warn_undefined, Raxol.Core.Runtime.Plugins.Manifest}

  @type t :: %{
          id: atom(),
          name: String.t(),
          version: String.t(),
          author: String.t(),
          api_version: String.t(),
          description: String.t(),
          module: module(),
          depends_on: [{atom(), String.t()}],
          conflicts_with: [atom()],
          provides: [atom()],
          requires: [atom()],
          resource_budget: map()
        }

  @supported_api_versions ["1.0", "1.1", "2.0"]

  @default_budget %{
    max_memory_mb: 50,
    max_cpu_percent: 10,
    max_ets_tables: 2,
    max_processes: 20
  }

  @required_fields [:id, :name, :version, :module]

  @doc """
  Builds a manifest map from keyword options.

  Returns a plain map (not a struct) for cross-package compatibility.

  ## Required keys

    * `:id` - Plugin identifier (atom)
    * `:name` - Human-readable name
    * `:version` - Semver version string
    * `:module` - Plugin module

  ## Optional keys

    * `:author` - Author name (default: `""`)
    * `:api_version` - API version (default: `"1.0"`)
    * `:description` - Description (default: `""`)
    * `:depends_on` - Dependencies as `[{atom, version_string}]` (default: `[]`)
    * `:conflicts_with` - Conflicting plugin IDs (default: `[]`)
    * `:provides` - Capabilities provided (default: `[]`)
    * `:requires` - Capabilities required (default: `[]`)
    * `:resource_budget` - Resource limits map (default: standard budget)
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    %{
      id: Keyword.get(opts, :id),
      name: Keyword.get(opts, :name),
      version: Keyword.get(opts, :version),
      author: Keyword.get(opts, :author, ""),
      api_version: Keyword.get(opts, :api_version, "1.0"),
      description: Keyword.get(opts, :description, ""),
      module: Keyword.get(opts, :module),
      depends_on: Keyword.get(opts, :depends_on, []),
      conflicts_with: Keyword.get(opts, :conflicts_with, []),
      provides: Keyword.get(opts, :provides, []),
      requires: Keyword.get(opts, :requires, []),
      resource_budget: Map.merge(@default_budget, Keyword.get(opts, :resource_budget, %{}))
    }
  end

  @doc """
  Validates a manifest map for completeness and correctness.

  Returns `:ok` or `{:error, [String.t()]}` with a list of validation errors.
  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(manifest) when is_map(manifest) do
    errors =
      []
      |> check_required_fields(manifest)
      |> check_version_format(manifest[:version])
      |> check_api_version(manifest[:api_version])
      |> check_no_self_dependency(manifest)

    case errors do
      [] -> :ok
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  @doc """
  Returns the default resource budget.
  """
  @spec default_budget() :: map()
  def default_budget, do: @default_budget

  @doc """
  Returns the list of supported API versions.
  """
  @spec supported_api_versions() :: [String.t()]
  def supported_api_versions, do: @supported_api_versions

  # -- Private ---------------------------------------------------------------

  defp check_required_fields(errors, manifest) do
    Enum.reduce(@required_fields, errors, fn field, acc ->
      if is_nil(Map.get(manifest, field)) do
        ["#{field} is required" | acc]
      else
        acc
      end
    end)
  end

  defp check_version_format(errors, nil), do: errors

  defp check_version_format(errors, version) do
    case Version.parse(version) do
      {:ok, _} -> errors
      :error -> ["version must be valid semver, got: #{version}" | errors]
    end
  end

  defp check_api_version(errors, nil), do: errors

  defp check_api_version(errors, api) do
    if api in @supported_api_versions do
      errors
    else
      ["unsupported api_version: #{api}" | errors]
    end
  end

  defp check_no_self_dependency(errors, %{id: id, depends_on: deps})
       when is_list(deps) and not is_nil(id) do
    dep_ids = Enum.map(deps, fn {dep_id, _} -> dep_id end)

    if id in dep_ids do
      ["plugin cannot depend on itself" | errors]
    else
      errors
    end
  end

  defp check_no_self_dependency(errors, _manifest), do: errors
end
