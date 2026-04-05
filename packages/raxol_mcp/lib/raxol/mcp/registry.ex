defmodule Raxol.MCP.Registry do
  @moduledoc """
  ETS-backed registry for MCP tools and resources.

  Any module can register tools and resources. The registry stores definitions
  alongside callback functions that are invoked when tools are called or
  resources are read.

  Reads (`list_tools`, `call_tool`, `list_resources`, `read_resource`) go
  directly to ETS with `read_concurrency: true` -- no GenServer bottleneck.
  Writes (`register_*`, `unregister_*`) serialize through the GenServer.

  ## Tool Registration

      tools = [
        %{
          name: "raxol_screenshot",
          description: "Capture a screenshot",
          inputSchema: %{type: "object", properties: %{id: %{type: "string"}}},
          callback: fn args -> {:ok, [%{type: "text", text: "screenshot data"}]} end
        }
      ]
      Registry.register_tools(registry, tools)

  ## Resource Registration

      resources = [
        %{
          uri: "raxol://session/demo/model",
          name: "Session Model",
          description: "Current TEA model state",
          callback: fn -> {:ok, %{counter: 5}} end
        }
      ]
      Registry.register_resources(registry, resources)
  """

  use GenServer

  @type tool_def :: %{
          name: String.t(),
          description: String.t(),
          inputSchema: map(),
          callback: (map() -> {:ok, term()} | {:error, term()})
        }

  @type resource_def :: %{
          uri: String.t(),
          name: String.t(),
          description: String.t(),
          callback: (-> {:ok, term()} | {:error, term()})
        }

  # -- Client API ---------------------------------------------------------------

  @doc "Start the registry, linked to the calling process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Register one or more tools."
  @spec register_tools(GenServer.server(), [tool_def()]) :: :ok
  def register_tools(registry \\ __MODULE__, tools) do
    GenServer.call(registry, {:register_tools, tools})
  end

  @doc "Unregister tools by name."
  @spec unregister_tools(GenServer.server(), [String.t()]) :: :ok
  def unregister_tools(registry \\ __MODULE__, names) do
    GenServer.call(registry, {:unregister_tools, names})
  end

  @doc "List all registered tools (definitions without callbacks)."
  @spec list_tools(GenServer.server()) :: [map()]
  def list_tools(registry \\ __MODULE__) do
    table = get_table(registry)

    :ets.select(table, [
      {{:"$1", {:tool, :"$2", :"$3", :_}}, [], [:"$3"]}
    ])
  end

  @doc "Call a registered tool by name with arguments."
  @spec call_tool(GenServer.server(), String.t(), map()) ::
          {:ok, term()} | {:error, term()}
  def call_tool(registry \\ __MODULE__, name, arguments) do
    table = get_table(registry)

    case :ets.lookup(table, tool_key(name)) do
      [{_key, {:tool, ^name, _def, callback}}] ->
        try do
          callback.(arguments)
        rescue
          e -> {:error, Exception.message(e)}
        end

      [] ->
        {:error, :tool_not_found}
    end
  end

  @doc "Register one or more resources."
  @spec register_resources(GenServer.server(), [resource_def()]) :: :ok
  def register_resources(registry \\ __MODULE__, resources) do
    GenServer.call(registry, {:register_resources, resources})
  end

  @doc "Unregister resources by URI."
  @spec unregister_resources(GenServer.server(), [String.t()]) :: :ok
  def unregister_resources(registry \\ __MODULE__, uris) do
    GenServer.call(registry, {:unregister_resources, uris})
  end

  @doc "List all registered resources (definitions without callbacks)."
  @spec list_resources(GenServer.server()) :: [map()]
  def list_resources(registry \\ __MODULE__) do
    table = get_table(registry)

    :ets.select(table, [
      {{:"$1", {:resource, :"$2", :"$3", :_}}, [], [:"$3"]}
    ])
  end

  @doc "Read a registered resource by URI."
  @spec read_resource(GenServer.server(), String.t()) ::
          {:ok, term()} | {:error, term()}
  def read_resource(registry \\ __MODULE__, uri) do
    table = get_table(registry)

    case :ets.lookup(table, resource_key(uri)) do
      [{_key, {:resource, ^uri, _def, callback}}] ->
        try do
          callback.()
        rescue
          e -> {:error, Exception.message(e)}
        end

      [] ->
        {:error, :resource_not_found}
    end
  end

  # -- GenServer Callbacks -------------------------------------------------------

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, :raxol_mcp_registry)

    table =
      :ets.new(table_name, [
        :set,
        :public,
        read_concurrency: true
      ])

    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register_tools, tools}, _from, state) do
    for tool <- tools do
      entry = {:tool, tool.name, tool_definition(tool), tool.callback}
      :ets.insert(state.table, {tool_key(tool.name), entry})
    end

    :telemetry.execute(
      [:raxol, :mcp, :registry, :tools_changed],
      %{count: length(tools)},
      %{action: :register, names: Enum.map(tools, & &1.name)}
    )

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister_tools, names}, _from, state) do
    for name <- names do
      :ets.delete(state.table, tool_key(name))
    end

    :telemetry.execute(
      [:raxol, :mcp, :registry, :tools_changed],
      %{count: length(names)},
      %{action: :unregister, names: names}
    )

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:register_resources, resources}, _from, state) do
    for resource <- resources do
      entry = {:resource, resource.uri, resource_definition(resource), resource.callback}
      :ets.insert(state.table, {resource_key(resource.uri), entry})
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister_resources, uris}, _from, state) do
    for uri <- uris do
      :ets.delete(state.table, resource_key(uri))
    end

    {:reply, :ok, state}
  end

  # -- Private -----------------------------------------------------------------

  defp tool_key(name), do: {:tool, name}
  defp resource_key(uri), do: {:resource, uri}

  defp tool_definition(tool) do
    Map.take(tool, [:name, :description, :inputSchema])
  end

  defp resource_definition(resource) do
    Map.take(resource, [:uri, :name, :description])
  end

  # Resolve a registry name/pid to its ETS table reference.
  # The GenServer stores the table ref in its state, but we need it
  # from client processes. We use :sys.get_state for named processes.
  @table_cache :raxol_mcp_registry_tables

  defp get_table(registry) when is_atom(registry) do
    # Try the cache first (ETS lookup by registry name)
    case :persistent_term.get({@table_cache, registry}, nil) do
      nil ->
        # Fall back to asking the GenServer for its table
        %{table: table} = :sys.get_state(registry)
        :persistent_term.put({@table_cache, registry}, table)
        table

      table ->
        table
    end
  end

  defp get_table(registry) do
    %{table: table} = :sys.get_state(registry)
    table
  end
end
