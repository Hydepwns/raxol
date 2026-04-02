defmodule Raxol.Agent.McpClient.MessageTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.McpClient.Message

  describe "request/3" do
    test "builds a valid JSON-RPC request" do
      msg = Message.request(1, "tools/list")
      assert msg.jsonrpc == "2.0"
      assert msg.id == 1
      assert msg.method == "tools/list"
      assert msg.params == %{}
    end

    test "includes params when provided" do
      msg = Message.request(2, "tools/call", %{name: "read_file", arguments: %{path: "/tmp"}})
      assert msg.params == %{name: "read_file", arguments: %{path: "/tmp"}}
    end
  end

  describe "notification/2" do
    test "builds a notification without id" do
      msg = Message.notification("notifications/initialized")
      assert msg.jsonrpc == "2.0"
      assert msg.method == "notifications/initialized"
      refute Map.has_key?(msg, :id)
    end
  end

  describe "encode/1 and decode/1" do
    test "round-trips a request" do
      original = Message.request(42, "tools/list", %{cursor: nil})
      {:ok, encoded} = Message.encode(original)
      json = IO.iodata_to_binary(encoded)

      assert String.ends_with?(json, "\n")

      {:ok, decoded} = Message.decode(String.trim(json))
      assert decoded.id == 42
      assert decoded.method == "tools/list"
    end

    test "round-trips a notification" do
      original = Message.notification("test/event", %{data: "hello"})
      {:ok, encoded} = Message.encode(original)
      {:ok, decoded} = Message.decode(String.trim(IO.iodata_to_binary(encoded)))

      assert decoded.method == "test/event"
      assert decoded.params == %{"data" => "hello"}
      refute Map.has_key?(decoded, :id)
    end

    test "decodes a response with result" do
      json = ~s({"jsonrpc":"2.0","id":1,"result":{"tools":[]}})
      {:ok, decoded} = Message.decode(json)

      assert decoded.id == 1
      assert decoded.result == %{"tools" => []}
    end

    test "decodes an error response" do
      json = ~s({"jsonrpc":"2.0","id":1,"error":{"code":-32600,"message":"Invalid Request"}})
      {:ok, decoded} = Message.decode(json)

      assert decoded.id == 1
      assert decoded.error == %{"code" => -32600, "message" => "Invalid Request"}
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Message.decode("not json")
    end
  end

  describe "response?/1" do
    test "true for result response" do
      assert Message.response?(%{id: 1, result: %{}})
    end

    test "true for error response" do
      assert Message.response?(%{id: 1, error: %{code: -1, message: "fail"}})
    end

    test "false for notification" do
      refute Message.response?(%{method: "test"})
    end

    test "false for request" do
      refute Message.response?(%{id: 1, method: "test"})
    end
  end

  describe "error?/1" do
    test "true for error response" do
      assert Message.error?(%{id: 1, error: %{}})
    end

    test "false for result response" do
      refute Message.error?(%{id: 1, result: %{}})
    end
  end

  describe "notification?/1" do
    test "true for message with method and no id" do
      assert Message.notification?(%{method: "test"})
    end

    test "false for request (has id)" do
      refute Message.notification?(%{id: 1, method: "test"})
    end
  end
end
