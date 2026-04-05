defmodule Raxol.MCP.Server do
  @moduledoc """
  Transport-agnostic MCP server.

  Receives decoded JSON-RPC messages, dispatches to the Registry for tool/resource
  operations, and returns response maps. Transports (stdio, SSE) call
  `handle_message/2` and write the response back over their I/O channel.

  ## Supported Methods

  - `initialize` -- MCP handshake, returns server capabilities
  - `notifications/initialized` -- client acknowledgement (no reply)
  - `ping` -- health check
  - `tools/list` -- list registered tools
  - `tools/call` -- invoke a tool
  - `resources/list` -- list registered resources
  - `resources/read` -- read a resource
  """

  use GenServer

  alias Raxol.MCP.Protocol
  alias Raxol.MCP.Registry

  defstruct [
    :registry,
    initialized: false
  ]

  @type t :: %__MODULE__{
          registry: GenServer.server(),
          initialized: boolean()
        }

  # -- Client API ---------------------------------------------------------------

  @doc "Start the server, linked to the calling process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Handle a decoded JSON-RPC message.

  Returns `{:reply, response_map}` for requests or `{:reply, nil}` for
  notifications (no response needed).
  """
  @spec handle_message(GenServer.server(), map()) :: {:reply, map() | nil}
  def handle_message(server \\ __MODULE__, message) do
    GenServer.call(server, {:handle_message, message})
  end

  # -- GenServer Callbacks -------------------------------------------------------

  @impl true
  def init(opts) do
    registry = Keyword.get(opts, :registry, Registry)
    {:ok, %__MODULE__{registry: registry}}
  end

  @impl true
  def handle_call({:handle_message, message}, _from, state) do
    {response, state} = dispatch(message, state)
    {:reply, {:reply, response}, state}
  end

  # -- Dispatch -----------------------------------------------------------------

  defp dispatch(%{method: "initialize", id: id}, state) do
    result = %{
      protocolVersion: Protocol.mcp_protocol_version(),
      capabilities: capabilities(),
      serverInfo: server_info()
    }

    {Protocol.response(id, result), %{state | initialized: true}}
  end

  defp dispatch(%{method: "notifications/initialized"}, state) do
    {nil, state}
  end

  defp dispatch(%{method: "ping", id: id}, state) do
    {Protocol.response(id, %{}), state}
  end

  defp dispatch(%{method: "tools/list", id: id}, state) do
    tools = Registry.list_tools(state.registry)
    {Protocol.response(id, %{tools: tools}), state}
  end

  defp dispatch(%{method: "tools/call", id: id, params: params}, state) do
    name = Map.get(params, "name") || Map.get(params, :name, "")
    arguments = Map.get(params, "arguments") || Map.get(params, :arguments, %{})

    case Registry.call_tool(state.registry, name, arguments) do
      {:ok, result} ->
        content = normalize_content(result)
        {Protocol.response(id, %{content: content}), state}

      {:error, :tool_not_found} ->
        error =
          Protocol.error_response(id, Protocol.method_not_found(), "Tool not found: #{name}")

        {error, state}

      {:error, reason} ->
        content = [%{type: "text", text: "Error: #{inspect(reason)}"}]
        {Protocol.response(id, %{content: content, isError: true}), state}
    end
  end

  defp dispatch(%{method: "resources/list", id: id}, state) do
    resources = Registry.list_resources(state.registry)
    {Protocol.response(id, %{resources: resources}), state}
  end

  defp dispatch(%{method: "resources/read", id: id, params: params}, state) do
    uri = Map.get(params, "uri") || Map.get(params, :uri, "")

    case Registry.read_resource(state.registry, uri) do
      {:ok, content} ->
        text = if is_binary(content), do: content, else: inspect(content, pretty: true)

        result = %{
          contents: [%{uri: uri, text: text, mimeType: "text/plain"}]
        }

        {Protocol.response(id, result), state}

      {:error, :resource_not_found} ->
        error =
          Protocol.error_response(id, Protocol.invalid_params(), "Resource not found: #{uri}")

        {error, state}

      {:error, reason} ->
        error = Protocol.error_response(id, Protocol.internal_error(), inspect(reason))
        {error, state}
    end
  end

  # Notifications we don't handle -- no response
  defp dispatch(%{method: _method} = msg, state) when not is_map_key(msg, :id) do
    {nil, state}
  end

  # Unknown method with an id -- error response
  defp dispatch(%{method: method, id: id}, state) do
    error = Protocol.error_response(id, Protocol.method_not_found(), "Unknown method: #{method}")
    {error, state}
  end

  # Malformed message
  defp dispatch(%{id: id}, state) do
    error = Protocol.error_response(id, Protocol.invalid_request(), "Missing method")
    {error, state}
  end

  defp dispatch(_msg, state) do
    {nil, state}
  end

  # -- Helpers ------------------------------------------------------------------

  defp capabilities do
    %{
      tools: %{listChanged: true},
      resources: %{subscribe: false}
    }
  end

  defp server_info do
    %{name: "raxol", version: RaxolMcp.version()}
  end

  defp normalize_content(result) when is_list(result), do: result
  defp normalize_content(text) when is_binary(text), do: [%{type: "text", text: text}]
  defp normalize_content(other), do: [%{type: "text", text: inspect(other, pretty: true)}]
end
