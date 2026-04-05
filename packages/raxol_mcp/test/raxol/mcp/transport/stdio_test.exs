defmodule Raxol.MCP.Transport.StdioTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.{Protocol, Registry, Server, Transport}

  setup do
    registry_name = :"registry_#{System.unique_integer([:positive])}"
    server_name = :"server_#{System.unique_integer([:positive])}"

    {:ok, _registry} = Registry.start_link(name: registry_name)
    {:ok, _server} = Server.start_link(name: server_name, registry: registry_name)

    %{server: server_name, registry: registry_name}
  end

  defp start_stdio(server, input_lines) do
    # Create a StringIO device with the input lines
    input = Enum.join(input_lines, "\n") <> "\n"
    {:ok, input_device} = StringIO.open(input)
    {:ok, output_device} = StringIO.open("")

    {:ok, pid} =
      Transport.Stdio.start_link(
        server: server,
        io_device: input_device,
        output_device: output_device
      )

    # Wait for reader to process and hit EOF
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      2000 -> :ok
    end

    # Read output
    {_input_remaining, output} = StringIO.contents(output_device)
    output
  end

  describe "stdio transport" do
    test "handles initialize request", %{server: s} do
      request = Protocol.request(1, "initialize", %{protocolVersion: "2024-11-05"})
      {:ok, line} = Protocol.encode(request)

      output = start_stdio(s, [IO.iodata_to_binary(line)])

      lines = String.split(output, "\n", trim: true)
      assert length(lines) >= 1

      {:ok, resp} = Protocol.decode(hd(lines))
      assert resp.id == 1
      # After JSON round-trip, result keys are strings
      assert resp.result["protocolVersion"] == "2024-11-05"
    end

    test "handles multiple requests", %{server: s} do
      req1 = Protocol.request(1, "initialize", %{protocolVersion: "2024-11-05"})
      req2 = Protocol.request(2, "ping")

      {:ok, line1} = Protocol.encode(req1)
      {:ok, line2} = Protocol.encode(req2)

      output =
        start_stdio(s, [
          IO.iodata_to_binary(line1),
          IO.iodata_to_binary(line2)
        ])

      lines = String.split(output, "\n", trim: true)
      assert length(lines) >= 2

      {:ok, resp1} = Protocol.decode(Enum.at(lines, 0))
      {:ok, resp2} = Protocol.decode(Enum.at(lines, 1))

      assert resp1.id == 1
      assert resp2.id == 2
      assert resp2.result == %{}
    end

    test "skips notifications (no response)", %{server: s} do
      notif = Protocol.notification("notifications/initialized")
      {:ok, notif_line} = Protocol.encode(notif)

      req = Protocol.request(1, "ping")
      {:ok, req_line} = Protocol.encode(req)

      output =
        start_stdio(s, [
          IO.iodata_to_binary(notif_line),
          IO.iodata_to_binary(req_line)
        ])

      lines = String.split(output, "\n", trim: true)
      # Only the ping response, not the notification
      assert length(lines) == 1
      {:ok, resp} = Protocol.decode(hd(lines))
      assert resp.id == 1
    end

    test "ignores blank lines", %{server: s} do
      req = Protocol.request(1, "ping")
      {:ok, line} = Protocol.encode(req)

      output = start_stdio(s, ["", IO.iodata_to_binary(line), ""])

      lines = String.split(output, "\n", trim: true)
      assert length(lines) == 1
    end

    test "handles tools/list with registered tools", %{server: s, registry: r} do
      tool = %{
        name: "test_tool",
        description: "A tool",
        inputSchema: %{type: "object"},
        callback: fn _args -> {:ok, "result"} end
      }

      Registry.register_tools(r, [tool])

      req = Protocol.request(1, "tools/list")
      {:ok, line} = Protocol.encode(req)

      output = start_stdio(s, [IO.iodata_to_binary(line)])
      lines = String.split(output, "\n", trim: true)
      {:ok, resp} = Protocol.decode(hd(lines))

      assert length(resp.result["tools"]) == 1
      assert hd(resp.result["tools"])["name"] == "test_tool"
    end
  end
end
