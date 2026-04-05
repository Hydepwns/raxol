defmodule Raxol.MCP.SupervisorTest do
  use ExUnit.Case

  alias Raxol.MCP.{Registry, Server}

  setup do
    registry_name = :"registry_#{System.unique_integer([:positive])}"
    server_name = :"server_#{System.unique_integer([:positive])}"

    {:ok, sup} =
      Raxol.MCP.Supervisor.start_link(
        registry_name: registry_name,
        server_name: server_name
      )

    on_exit(fn ->
      try do
        Supervisor.stop(sup)
      catch
        :exit, _ -> :ok
      end
    end)

    %{sup: sup, registry: registry_name, server: server_name}
  end

  test "starts registry and server", %{registry: r, server: s} do
    assert Process.whereis(r)
    assert Process.whereis(s)
  end

  test "server can list tools from registry", %{registry: r, server: s} do
    tool = %{
      name: "sup_test",
      description: "Supervisor test tool",
      inputSchema: %{type: "object"},
      callback: fn _args -> {:ok, "worked"} end
    }

    Registry.register_tools(r, [tool])

    msg = %{id: 1, method: "tools/list", params: %{}}
    {:reply, resp} = Server.handle_message(s, msg)

    assert length(resp.result.tools) == 1
    assert hd(resp.result.tools).name == "sup_test"
  end

  test "server can call tools via registry", %{registry: r, server: s} do
    tool = %{
      name: "add",
      description: "Add",
      inputSchema: %{type: "object"},
      callback: fn args -> {:ok, "sum: #{args["a"] + args["b"]}"} end
    }

    Registry.register_tools(r, [tool])

    msg = %{
      id: 2,
      method: "tools/call",
      params: %{"name" => "add", "arguments" => %{"a" => 1, "b" => 2}}
    }

    {:reply, resp} = Server.handle_message(s, msg)
    [content] = resp.result.content
    assert content.text == "sum: 3"
  end
end
