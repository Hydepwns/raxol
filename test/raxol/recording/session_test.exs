defmodule Raxol.Recording.SessionTest do
  use ExUnit.Case, async: true

  alias Raxol.Recording.Session

  describe "new/1" do
    test "creates session with default dimensions" do
      session = Session.new()
      assert session.width > 0
      assert session.height > 0
      assert session.events == []
      assert %DateTime{} = session.started_at
      assert session.ended_at == nil
    end

    test "creates session with custom dimensions" do
      session = Session.new(width: 120, height: 40)
      assert session.width == 120
      assert session.height == 40
    end

    test "creates session with title" do
      session = Session.new(title: "My Demo")
      assert session.title == "My Demo"
    end

    test "includes TERM in env" do
      session = Session.new()
      assert is_binary(session.env["TERM"])
    end
  end

  describe "duration/1" do
    test "returns 0 for empty session" do
      assert Session.duration(Session.new()) == 0.0
    end

    test "returns duration from last event" do
      session = %{Session.new() | events: [
        {0, :output, "a"},
        {1_000_000, :output, "b"},
        {3_500_000, :output, "c"}
      ]}
      assert Session.duration(session) == 3.5
    end
  end

  describe "event_count/1" do
    test "returns 0 for empty session" do
      assert Session.event_count(Session.new()) == 0
    end

    test "returns count of events" do
      session = %{Session.new() | events: [
        {0, :output, "a"},
        {100_000, :output, "b"}
      ]}
      assert Session.event_count(session) == 2
    end
  end
end
