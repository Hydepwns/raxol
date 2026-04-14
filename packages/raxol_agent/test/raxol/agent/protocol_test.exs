defmodule Raxol.Agent.ProtocolTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Protocol

  describe "new/4" do
    test "creates a message with all fields populated" do
      msg = Protocol.new(:scout, :analyst, :directive, "search for files")

      assert msg.from == :scout
      assert msg.to == :analyst
      assert msg.type == :directive
      assert msg.payload == "search for files"
      assert %DateTime{} = msg.timestamp
      assert is_binary(msg.correlation_id)
      assert byte_size(msg.correlation_id) > 0
    end

    test "generates unique correlation ids" do
      msg1 = Protocol.new(:a, :b, :query, "q1")
      msg2 = Protocol.new(:a, :b, :query, "q2")

      assert msg1.correlation_id != msg2.correlation_id
    end

    test "supports broadcast target" do
      msg = Protocol.new(:pilot, :broadcast, :alert, "all stop")

      assert msg.to == :broadcast
    end
  end

  describe "reply/4" do
    test "preserves correlation id from original message" do
      original = Protocol.new(:scout, :pilot, :query, "permission?")
      reply = Protocol.reply(original, :pilot, :response, "granted")

      assert reply.from == :pilot
      assert reply.to == :scout
      assert reply.type == :response
      assert reply.payload == "granted"
      assert reply.correlation_id == original.correlation_id
    end
  end

  describe "encode/1 and decode/1" do
    test "roundtrips a message" do
      original = Protocol.new(:scout, :analyst, :observation, %{files: ["a.ex"]})
      encoded = Protocol.encode(original)

      assert is_map(encoded)
      assert encoded["from"] == "scout"
      assert encoded["to"] == "analyst"
      assert encoded["type"] == "observation"
      assert encoded["payload"] == %{files: ["a.ex"]}

      {:ok, decoded} = Protocol.decode(encoded)

      assert decoded.from == :scout
      assert decoded.to == :analyst
      assert decoded.type == :observation
      assert decoded.payload == %{files: ["a.ex"]}
      assert decoded.correlation_id == original.correlation_id
    end

    test "decode returns error for invalid format" do
      assert {:error, :invalid_format} = Protocol.decode("not a map")
    end

    test "decode returns error for invalid type" do
      assert {:error, {:invalid_type, "also_not_real_atom_456"}} =
               Protocol.decode(%{
                 "from" => "nonexistent_atom_xyz_123",
                 "to" => "another_fake_atom_abc",
                 "type" => "also_not_real_atom_456"
               })
    end

    test "decode keeps unknown from/to as strings instead of creating atoms" do
      {:ok, msg} =
        Protocol.decode(%{
          "from" => "unknown_agent_xyz",
          "to" => "unknown_agent_abc",
          "type" => "directive"
        })

      assert msg.from == "unknown_agent_xyz"
      assert msg.to == "unknown_agent_abc"
      assert msg.type == :directive
    end
  end

  describe "all message types" do
    test "each type is valid" do
      types = [
        :directive,
        :observation,
        :query,
        :response,
        :takeover,
        :release,
        :status_update,
        :alert
      ]

      for type <- types do
        msg = Protocol.new(:a, :b, type, nil)
        assert msg.type == type
      end
    end
  end
end
