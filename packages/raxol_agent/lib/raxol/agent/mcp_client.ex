defmodule Raxol.Agent.McpClient do
  @moduledoc """
  MCP client for consuming external tool servers.

  This module delegates to `Raxol.MCP.Client`. Use `Raxol.MCP.Client`
  directly for new code.
  """

  @compile {:no_warn_undefined, Raxol.MCP.Client}

  @type tool :: Raxol.MCP.Client.tool()
  @type call_result :: Raxol.MCP.Client.call_result()

  @doc "Start an MCP client. Delegates to `Raxol.MCP.Client.start_link/1`."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    # Use Agent.Registry for via-tuple backward compat
    _name = Keyword.fetch!(opts, :name)
    opts = Keyword.put(opts, :registry, Raxol.Agent.Registry)

    if Code.ensure_loaded?(Raxol.MCP.Client) do
      Raxol.MCP.Client.start_link(opts)
    else
      # Fallback: start a bare GenServer that returns errors
      {:error, :raxol_mcp_not_available}
    end
  end

  @doc "List tools. Delegates to `Raxol.MCP.Client.list_tools/1`."
  @spec list_tools(GenServer.server()) :: {:ok, [tool()]} | {:error, term()}
  defdelegate list_tools(server), to: Raxol.MCP.Client

  @doc "Call a tool. Delegates to `Raxol.MCP.Client.call_tool/3`."
  @spec call_tool(GenServer.server(), String.t(), map()) ::
          {:ok, call_result()} | {:error, term()}
  defdelegate call_tool(server, tool_name, arguments \\ %{}), to: Raxol.MCP.Client

  @doc "Get client status. Delegates to `Raxol.MCP.Client.status/1`."
  @spec status(GenServer.server()) :: map()
  defdelegate status(server), to: Raxol.MCP.Client

  @doc "Stop the client. Delegates to `Raxol.MCP.Client.stop/1`."
  @spec stop(GenServer.server()) :: :ok
  defdelegate stop(server), to: Raxol.MCP.Client

  @doc "Build a namespaced tool name. Delegates to `Raxol.MCP.Client.tool_name/2`."
  @spec tool_name(atom(), String.t()) :: String.t()
  defdelegate tool_name(server_name, tool), to: Raxol.MCP.Client

  @doc "Parse a namespaced tool name. Delegates to `Raxol.MCP.Client.parse_tool_name/1`."
  @spec parse_tool_name(String.t()) :: {:ok, {String.t(), String.t()}} | :error
  defdelegate parse_tool_name(name), to: Raxol.MCP.Client
end
