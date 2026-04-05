defmodule Raxol.MCP.Transport.SSETest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Raxol.MCP.{Protocol, Registry, Server, Transport}

  setup do
    registry_name = :"registry_#{System.unique_integer([:positive])}"
    server_name = :"server_#{System.unique_integer([:positive])}"

    {:ok, _registry} = Registry.start_link(name: registry_name)
    {:ok, _server} = Server.start_link(name: server_name, registry: registry_name)

    %{server: server_name, registry: registry_name}
  end

  defp post_mcp(server, message) do
    {:ok, body} = Jason.encode(message)

    :post
    |> conn("/mcp", body)
    |> put_req_header("content-type", "application/json")
    |> Transport.SSE.call(server: server)
  end

  describe "POST /mcp" do
    test "handles initialize", %{server: s} do
      req = Protocol.request(1, "initialize", %{protocolVersion: "2024-11-05"})
      conn = post_mcp(s, req)

      assert conn.status == 200
      {:ok, resp} = Jason.decode(conn.resp_body)
      assert resp["id"] == 1
      assert resp["result"]["protocolVersion"] == "2024-11-05"
    end

    test "handles ping", %{server: s} do
      req = Protocol.request(2, "ping")
      conn = post_mcp(s, req)

      assert conn.status == 200
      {:ok, resp} = Jason.decode(conn.resp_body)
      assert resp["id"] == 2
      assert resp["result"] == %{}
    end

    test "handles tools/list", %{server: s, registry: r} do
      tool = %{
        name: "test",
        description: "Test tool",
        inputSchema: %{type: "object"},
        callback: fn _args -> {:ok, "ok"} end
      }

      Registry.register_tools(r, [tool])

      req = Protocol.request(3, "tools/list")
      conn = post_mcp(s, req)

      assert conn.status == 200
      {:ok, resp} = Jason.decode(conn.resp_body)
      assert length(resp["result"]["tools"]) == 1
    end

    test "handles tools/call", %{server: s, registry: r} do
      tool = %{
        name: "echo",
        description: "Echo input",
        inputSchema: %{type: "object"},
        callback: fn args -> {:ok, "echo: #{args["msg"]}"} end
      }

      Registry.register_tools(r, [tool])

      req = Protocol.request(4, "tools/call", %{name: "echo", arguments: %{msg: "hi"}})
      conn = post_mcp(s, req)

      assert conn.status == 200
      {:ok, resp} = Jason.decode(conn.resp_body)
      [content] = resp["result"]["content"]
      assert content["text"] =~ "echo: hi"
    end

    test "returns 204 for notification", %{server: s} do
      notif = Protocol.notification("notifications/initialized")
      conn = post_mcp(s, notif)

      assert conn.status == 204
    end

    test "returns error for unknown method", %{server: s} do
      req = Protocol.request(5, "unknown/method")
      conn = post_mcp(s, req)

      assert conn.status == 200
      {:ok, resp} = Jason.decode(conn.resp_body)
      assert resp["error"]["code"] == Protocol.method_not_found()
    end
  end

  describe "GET /health" do
    test "returns ok" do
      conn =
        :get
        |> conn("/health")
        |> Transport.SSE.call([])

      assert conn.status == 200
      {:ok, body} = Jason.decode(conn.resp_body)
      assert body["status"] == "ok"
    end
  end

  describe "unknown routes" do
    test "returns 404" do
      conn =
        :get
        |> conn("/unknown")
        |> Transport.SSE.call([])

      assert conn.status == 404
    end
  end
end
