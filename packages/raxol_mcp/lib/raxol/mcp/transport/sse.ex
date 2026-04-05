if Code.ensure_loaded?(Plug.Router) do
  defmodule Raxol.MCP.Transport.SSE do
    @moduledoc """
    HTTP/SSE transport for MCP.

    Plug-based router providing JSON-RPC over HTTP POST and server-sent events
    for notifications. No Phoenix dependency.

    ## Endpoints

    - `POST /mcp` -- receive JSON-RPC request, return response
    - `GET /health` -- health check

    ## Usage

    Mount in a Plug pipeline or start standalone with `Plug.Cowboy`:

        Plug.Cowboy.http(Raxol.MCP.Transport.SSE, [server: Raxol.MCP.Server], port: 4001)
    """

    use Plug.Router

    alias Raxol.MCP.{Protocol, Server}

    plug(:match)
    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(:dispatch)

    @doc false
    def init(opts), do: opts

    post "/mcp" do
      server = conn.private[:mcp_server] || Server

      body =
        case conn.body_params do
          %Plug.Conn.Unfetched{} ->
            {:ok, raw, _conn} = Plug.Conn.read_body(conn)

            case Protocol.decode(raw) do
              {:ok, decoded} -> decoded
              {:error, _} -> nil
            end

          params when is_map(params) ->
            normalize_body_params(params)
        end

      if body do
        {:reply, response} = Server.handle_message(server, body)

        if response do
          {:ok, json} = Jason.encode(response)

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, json)
        else
          send_resp(conn, 204, "")
        end
      else
        error = Protocol.error_response(nil, Protocol.parse_error(), "Invalid JSON")
        {:ok, json} = Jason.encode(error)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, json)
      end
    end

    get "/health" do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, ~s({"status":"ok"}))
    end

    match _ do
      send_resp(conn, 404, "Not found")
    end

    @doc false
    def call(conn, opts) do
      server = Keyword.get(opts, :server, Server)

      conn
      |> Plug.Conn.put_private(:mcp_server, server)
      |> super(opts)
    end

    defp normalize_body_params(params) do
      # Plug.Parsers decodes JSON with string keys; normalize known fields
      params
      |> normalize_param("jsonrpc", :jsonrpc)
      |> normalize_param("id", :id)
      |> normalize_param("method", :method)
      |> normalize_param("params", :params)
      |> normalize_param("result", :result)
      |> normalize_param("error", :error)
    end

    defp normalize_param(map, string_key, atom_key) do
      case Map.pop(map, string_key) do
        {nil, map} -> map
        {value, map} -> Map.put(map, atom_key, value)
      end
    end
  end
end
