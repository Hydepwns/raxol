defmodule Raxol.Core.Runtime.Plugins.Manifest do
  @moduledoc """
  Declarative plugin metadata struct.

  Replaces ad-hoc metadata maps with a typed struct consumed by
  the validator, dependency resolver, and mission profile system.

  Plugins declare a `manifest/0` function returning a map, which
  `from_module/1` normalizes into this struct.
  """

  @type t :: %__MODULE__{
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
          resource_budget: resource_budget()
        }

  @type resource_budget :: %{
          max_memory_mb: number(),
          max_cpu_percent: number(),
          max_ets_tables: non_neg_integer(),
          max_processes: non_neg_integer()
        }

  @default_budget %{
    max_memory_mb: 50,
    max_cpu_percent: 10,
    max_ets_tables: 2,
    max_processes: 20
  }

  defstruct [
    :id,
    :name,
    :version,
    :author,
    :module,
    api_version: "1.0",
    description: "",
    depends_on: [],
    conflicts_with: [],
    provides: [],
    requires: [],
    resource_budget: @default_budget
  ]

  @doc """
  Builds a Manifest from a module that implements `manifest/0`.

  Returns `{:error, :no_manifest}` if the module doesn't export it.
  """
  @spec from_module(module()) :: {:ok, t()} | {:error, term()}
  def from_module(module) when is_atom(module) do
    if function_exported?(module, :manifest, 0) do
      raw = module.manifest()
      build_from_map(raw, module)
    else
      {:error, :no_manifest}
    end
  end

  @doc """
  Validates a manifest struct for completeness and correctness.
  """
  @spec validate(t()) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = m) do
    errors =
      []
      |> check_required(:id, m.id)
      |> check_required(:name, m.name)
      |> check_required(:version, m.version)
      |> check_required(:module, m.module)
      |> check_version_format(m.version)
      |> check_api_version(m.api_version)
      |> check_no_self_dependency(m)

    case errors do
      [] -> :ok
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  @doc """
  Checks whether two manifests are compatible (no conflicts).
  """
  @spec compatible?(t(), t()) :: boolean()
  def compatible?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.id not in b.conflicts_with and b.id not in a.conflicts_with
  end

  # -- Private ---------------------------------------------------------------

  defp build_from_map(raw, module) when is_map(raw) do
    id = raw[:id] || module_to_id(module)
    name = raw[:name] || to_string(id)

    depends_on =
      normalize_depends_on(raw[:depends_on] || raw[:dependencies] || [])

    manifest = %__MODULE__{
      id: id,
      name: name,
      version: raw[:version] || "0.0.0",
      author: raw[:author] || "",
      api_version: raw[:api_version] || "1.0",
      description: raw[:description] || "",
      module: module,
      depends_on: depends_on,
      conflicts_with: raw[:conflicts_with] || [],
      provides: raw[:provides] || raw[:capabilities] || [],
      requires: raw[:requires] || [],
      resource_budget: Map.merge(@default_budget, raw[:resource_budget] || %{})
    }

    {:ok, manifest}
  end

  defp module_to_id(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp normalize_depends_on(deps) when is_map(deps) do
    Enum.map(deps, fn
      {name, version} when is_binary(name) -> {String.to_atom(name), version}
      {name, version} when is_atom(name) -> {name, version}
    end)
  end

  defp normalize_depends_on(deps) when is_list(deps) do
    Enum.map(deps, fn
      {name, version} when is_atom(name) -> {name, version}
      {name, version} when is_binary(name) -> {String.to_atom(name), version}
      name when is_atom(name) -> {name, ">= 0.0.0"}
      name when is_binary(name) -> {String.to_atom(name), ">= 0.0.0"}
    end)
  end

  defp check_required(errors, field, nil),
    do: ["#{field} is required" | errors]

  defp check_required(errors, _field, _value), do: errors

  defp check_version_format(errors, nil), do: errors

  defp check_version_format(errors, version) do
    case Version.parse(version) do
      {:ok, _} -> errors
      :error -> ["version must be valid semver, got: #{version}" | errors]
    end
  end

  defp check_api_version(errors, api) do
    if api in ["1.0", "1.1", "2.0"] do
      errors
    else
      ["unsupported api_version: #{api}" | errors]
    end
  end

  defp check_no_self_dependency(errors, %__MODULE__{id: id, depends_on: deps}) do
    dep_ids = Enum.map(deps, fn {dep_id, _} -> dep_id end)

    if id in dep_ids do
      ["plugin cannot depend on itself" | errors]
    else
      errors
    end
  end
end
