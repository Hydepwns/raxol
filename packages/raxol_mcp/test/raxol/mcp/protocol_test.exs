defmodule Raxol.MCP.ProtocolTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.Protocol

  describe "request/3" do
    test "builds a JSON-RPC request" do
      req = Protocol.request(1, "tools/list", %{cursor: nil})
      assert req.jsonrpc == "2.0"
      assert req.id == 1
      assert req.method == "tools/list"
      assert req.params == %{cursor: nil}
    end

    test "defaults params to empty map" do
      req = Protocol.request(42, "ping")
      assert req.params == %{}
    end
  end

  describe "notification/2" do
    test "builds a notification without id" do
      notif = Protocol.notification("notifications/initialized", %{})
      assert notif.jsonrpc == "2.0"
      assert notif.method == "notifications/initialized"
      refute Map.has_key?(notif, :id)
    end
  end

  describe "response/2" do
    test "builds a success response" do
      resp = Protocol.response(1, %{"tools" => []})
      assert resp.jsonrpc == "2.0"
      assert resp.id == 1
      assert resp.result == %{"tools" => []}
    end
  end

  describe "error_response/4" do
    test "builds an error response" do
      resp = Protocol.error_response(1, Protocol.method_not_found(), "Method not found")
      assert resp.jsonrpc == "2.0"
      assert resp.id == 1
      assert resp.error.code == -32_601
      assert resp.error.message == "Method not found"
      refute Map.has_key?(resp.error, :data)
    end

    test "includes data when provided" do
      resp = Protocol.error_response(1, Protocol.internal_error(), "Oops", %{detail: "boom"})
      assert resp.error.data == %{detail: "boom"}
    end

    test "allows nil id for parse errors" do
      resp = Protocol.error_response(nil, Protocol.parse_error(), "Parse error")
      assert resp.id == nil
    end
  end

  describe "encode/1 and decode/1" do
    test "round-trips a request" do
      original = Protocol.request(1, "tools/list", %{"cursor" => nil})
      {:ok, encoded} = Protocol.encode(original)
      {:ok, decoded} = Protocol.decode(IO.iodata_to_binary(encoded))
      assert decoded.id == 1
      assert decoded.method == "tools/list"
      assert decoded.params == %{"cursor" => nil}
    end

    test "round-trips a response" do
      original = Protocol.response(5, %{"tools" => []})
      {:ok, encoded} = Protocol.encode(original)
      {:ok, decoded} = Protocol.decode(IO.iodata_to_binary(encoded))
      assert decoded.id == 5
      assert decoded.result == %{"tools" => []}
    end

    test "round-trips an error response" do
      original = Protocol.error_response(3, -32_601, "Not found")
      {:ok, encoded} = Protocol.encode(original)
      {:ok, decoded} = Protocol.decode(IO.iodata_to_binary(encoded))
      assert decoded.id == 3
      assert decoded.error == %{"code" => -32_601, "message" => "Not found"}
    end

    test "round-trips a notification" do
      original = Protocol.notification("tools/list_changed")
      {:ok, encoded} = Protocol.encode(original)
      {:ok, decoded} = Protocol.decode(IO.iodata_to_binary(encoded))
      assert decoded.method == "tools/list_changed"
      refute Map.has_key?(decoded, :id)
    end

    test "encode appends newline" do
      {:ok, encoded} = Protocol.encode(%{jsonrpc: "2.0", id: 1, result: "ok"})
      binary = IO.iodata_to_binary(encoded)
      assert String.ends_with?(binary, "\n")
    end

    test "decode returns error for invalid JSON" do
      assert {:error, _} = Protocol.decode("not json")
    end
  end

  describe "encode!/1" do
    test "returns iodata" do
      result = Protocol.encode!(Protocol.response(1, "ok"))
      assert is_list(result)
      binary = IO.iodata_to_binary(result)
      assert String.ends_with?(binary, "\n")
    end

    test "raises on unencodable input" do
      assert_raise Elixir.Protocol.UndefinedError, fn ->
        Protocol.encode!(%{bad: self()})
      end
    end
  end

  describe "predicates" do
    test "response? identifies responses" do
      assert Protocol.response?(%{id: 1, result: "ok"})
      assert Protocol.response?(%{id: 1, error: %{code: -1, message: "err"}})
      refute Protocol.response?(%{method: "ping"})
      refute Protocol.response?(%{})
    end

    test "error? identifies error responses" do
      assert Protocol.error?(%{id: 1, error: %{code: -1, message: "err"}})
      refute Protocol.error?(%{id: 1, result: "ok"})
      refute Protocol.error?(%{})
    end

    test "notification? identifies notifications" do
      assert Protocol.notification?(%{method: "tools/list_changed", params: %{}})
      refute Protocol.notification?(%{id: 1, method: "tools/list"})
      refute Protocol.notification?(%{})
    end

    test "request? identifies requests" do
      assert Protocol.request?(%{id: 1, method: "tools/list"})
      refute Protocol.request?(%{method: "tools/list_changed"})
      refute Protocol.request?(%{id: 1, result: "ok"})
      refute Protocol.request?(%{})
    end
  end

  describe "error codes" do
    test "parse_error is -32700" do
      assert Protocol.parse_error() == -32_700
    end

    test "invalid_request is -32600" do
      assert Protocol.invalid_request() == -32_600
    end

    test "method_not_found is -32601" do
      assert Protocol.method_not_found() == -32_601
    end

    test "invalid_params is -32602" do
      assert Protocol.invalid_params() == -32_602
    end

    test "internal_error is -32603" do
      assert Protocol.internal_error() == -32_603
    end
  end

  describe "mcp_protocol_version/0" do
    test "returns the MCP version" do
      assert Protocol.mcp_protocol_version() == "2024-11-05"
    end
  end
end
