defmodule Raxol.Core.Runtime.Plugins.MissionProfile do
  @moduledoc """
  Named set of plugins with configuration overrides.

  A mission profile is analogous to a Brewfile or Docker Compose file
  for plugins -- it declares which plugins to load and how to configure them.

  Profiles support inheritance (a child profile inherits its parent's plugins)
  and diff-based hot-swapping (switching profiles only loads/unloads the delta).
  """

  alias Raxol.Core.Runtime.Plugins.{DependencyResolver, Manifest}
  alias Raxol.Core.Runtime.Plugins.PluginLifecycle

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          description: String.t(),
          plugins: [{atom(), map()}],
          inherits: atom() | nil
        }

  defstruct [
    :id,
    :name,
    :inherits,
    description: "",
    plugins: []
  ]

  @profiles_table :raxol_mission_profiles

  @doc """
  Initializes the profiles ETS table. Call once at startup.
  """
  @spec init() :: :ok
  def init do
    if :ets.whereis(@profiles_table) == :undefined do
      :ets.new(@profiles_table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true
      ])
    end

    :ok
  end

  @doc """
  Registers a profile so it can be loaded by id.
  """
  @spec register(t()) :: :ok
  def register(%__MODULE__{id: id} = profile) do
    init()
    :ets.insert(@profiles_table, {id, profile})
    :ok
  end

  @doc """
  Loads a registered profile by id.
  """
  @spec load(atom()) :: {:ok, t()} | {:error, :not_found}
  def load(id) do
    init()

    case :ets.lookup(@profiles_table, id) do
      [{^id, profile}] -> {:ok, profile}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns the fully resolved plugin list, including inherited plugins.

  Child plugins override parent plugins with the same id.
  """
  @spec resolve_plugins(t()) :: [{atom(), map()}]
  def resolve_plugins(%__MODULE__{plugins: plugins, inherits: nil}), do: plugins

  def resolve_plugins(%__MODULE__{plugins: plugins, inherits: parent_id}) do
    case load(parent_id) do
      {:ok, parent} ->
        parent_plugins = resolve_plugins(parent)
        child_ids = MapSet.new(Enum.map(plugins, fn {id, _} -> id end))

        inherited =
          Enum.reject(parent_plugins, fn {id, _} -> id in child_ids end)

        inherited ++ plugins

      {:error, _} ->
        plugins
    end
  end

  @doc """
  Activates a profile: resolves dependencies and loads plugins in order.

  `manifest_lookup` is a function `(atom() -> {:ok, Manifest.t()} | {:error, term()})`
  that retrieves the manifest for a given plugin id.
  """
  @spec activate(t(), (atom() -> {:ok, Manifest.t()} | {:error, term()})) ::
          {:ok, [atom()]} | {:error, term()}
  def activate(%__MODULE__{} = profile, manifest_lookup) do
    resolved_plugins = resolve_plugins(profile)

    with {:ok, manifests} <-
           collect_manifests(resolved_plugins, manifest_lookup),
         {:ok, load_order} <- DependencyResolver.resolve(manifests) do
      config_map = Map.new(resolved_plugins)
      load_plugins_in_order(load_order, manifests, config_map)
    end
  end

  @doc """
  Deactivates a profile by unloading all its plugins.
  """
  @spec deactivate(t()) :: :ok
  def deactivate(%__MODULE__{} = profile) do
    resolved_plugins = resolve_plugins(profile)

    Enum.each(resolved_plugins, fn {plugin_id, _} ->
      PluginLifecycle.unload(plugin_id)
    end)

    :ok
  end

  @doc """
  Computes the diff between two profiles.

  Returns a map with `:add`, `:remove`, and `:reconfigure` keys.
  """
  @spec diff(t(), t()) :: %{
          add: [atom()],
          remove: [atom()],
          reconfigure: [atom()]
        }
  def diff(%__MODULE__{} = from, %__MODULE__{} = to) do
    from_plugins = Map.new(resolve_plugins(from))
    to_plugins = Map.new(resolve_plugins(to))

    from_ids = MapSet.new(Map.keys(from_plugins))
    to_ids = MapSet.new(Map.keys(to_plugins))

    add = MapSet.difference(to_ids, from_ids) |> MapSet.to_list()
    remove = MapSet.difference(from_ids, to_ids) |> MapSet.to_list()

    reconfigure =
      MapSet.intersection(from_ids, to_ids)
      |> Enum.filter(fn id ->
        Map.get(from_plugins, id) != Map.get(to_plugins, id)
      end)

    %{add: add, remove: remove, reconfigure: reconfigure}
  end

  @doc """
  Switches from one profile to another, only loading/unloading the delta.
  """
  @spec switch(t(), t(), (atom() -> {:ok, Manifest.t()} | {:error, term()})) ::
          {:ok, [atom()]} | {:error, term()}
  def switch(%__MODULE__{} = from, %__MODULE__{} = to, manifest_lookup) do
    delta = diff(from, to)

    Enum.each(delta.remove, fn plugin_id ->
      PluginLifecycle.unload(plugin_id)
    end)

    to_plugins = Map.new(resolve_plugins(to))

    add_plugins =
      Enum.map(delta.add, fn id -> {id, Map.get(to_plugins, id, %{})} end)

    with {:ok, manifests} <- collect_manifests(add_plugins, manifest_lookup),
         {:ok, load_order} <-
           DependencyResolver.resolve_incremental(manifests, []),
         {:ok, loaded} <-
           load_plugins_in_order(load_order, manifests, to_plugins) do
      Enum.each(delta.reconfigure, fn plugin_id ->
        config = Map.get(to_plugins, plugin_id, %{})
        PluginLifecycle.reload(plugin_id, config)
      end)

      {:ok, loaded}
    end
  end

  # -- Private ---------------------------------------------------------------

  defp collect_manifests(plugin_list, manifest_lookup) do
    results =
      Enum.reduce_while(plugin_list, {:ok, []}, fn {plugin_id, _config},
                                                   {:ok, acc} ->
        case manifest_lookup.(plugin_id) do
          {:ok, manifest} ->
            {:cont, {:ok, [manifest | acc]}}

          {:error, reason} ->
            {:halt, {:error, {:manifest_not_found, plugin_id, reason}}}
        end
      end)

    case results do
      {:ok, manifests} -> {:ok, Enum.reverse(manifests)}
      error -> error
    end
  end

  defp load_plugins_in_order(load_order, manifests, config_map) do
    manifest_map = Map.new(manifests, fn m -> {m.id, m} end)

    results =
      Enum.reduce_while(load_order, {:ok, []}, fn plugin_id, {:ok, loaded} ->
        manifest = Map.fetch!(manifest_map, plugin_id)
        config = Map.get(config_map, plugin_id, %{})

        case PluginLifecycle.load(plugin_id, manifest.module, config) do
          :ok ->
            {:cont, {:ok, [plugin_id | loaded]}}

          {:error, reason} ->
            {:halt, {:error, {:load_failed, plugin_id, reason}}}
        end
      end)

    case results do
      {:ok, loaded} -> {:ok, Enum.reverse(loaded)}
      error -> error
    end
  end
end
