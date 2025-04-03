defmodule Raxol.Terminal.InputTest do
  use ExUnit.Case
  alias Raxol.Terminal.Input

  describe "process_input/1" do
    test "processes regular characters" do
      events = Input.process_input("a")
      assert events == [{:key, ?a, []}]
    end

    test "processes arrow keys" do
      events = Input.process_input("\e[A")
      assert events == [{:key, :up, []}]
      
      events = Input.process_input("\e[B")
      assert events == [{:key, :down, []}]
      
      events = Input.process_input("\e[C")
      assert events == [{:key, :right, []}]
      
      events = Input.process_input("\e[D")
      assert events == [{:key, :left, []}]
    end

    test "processes function keys" do
      events = Input.process_input("\eOP")
      assert events == [{:key, :f1, []}]
      
      events = Input.process_input("\eOQ")
      assert events == [{:key, :f2, []}]
    end

    test "processes mouse events" do
      events = Input.process_input("\e[1;2M")
      assert events == [{:mouse, 1, 2, :left, []}]
      
      events = Input.process_input("\e[1;2m")
      assert events == [{:mouse, 1, 2, :release, []}]
    end

    test "ignores unknown sequences" do
      events = Input.process_input("\e[?")
      assert events == []
    end
  end

  describe "buffer_events/2" do
    test "buffers valid events" do
      events = [
        {:key, :a, []},
        {:mouse, 1, 2, :left, []},
        {:unknown, "data"}
      ]
      
      buffered = Input.buffer_events(events)
      assert length(buffered) == 2
      assert {:key, :a, []} in buffered
      assert {:mouse, 1, 2, :left, []} in buffered
    end

    test "maintains event order" do
      events = [
        {:key, :a, []},
        {:key, :b, []},
        {:key, :c, []}
      ]
      
      buffered = Input.buffer_events(events)
      assert buffered == [
        {:key, :a, []},
        {:key, :b, []},
        {:key, :c, []}
      ]
    end
  end

  describe "validate_event/1" do
    test "validates key events" do
      assert {:ok, _} = Input.validate_event({:key, :a, []})
      assert {:ok, _} = Input.validate_event({:key, :up, [:ctrl]})
    end

    test "validates mouse events" do
      assert {:ok, _} = Input.validate_event({:mouse, 1, 2, :left, []})
      assert {:ok, _} = Input.validate_event({:mouse, 10, 20, :right, [:shift]})
    end

    test "rejects invalid events" do
      assert {:error, :invalid_event} = Input.validate_event({:key, "a", []})
      assert {:error, :invalid_event} = Input.validate_event({:mouse, "1", 2, :left, []})
      assert {:error, :invalid_event} = Input.validate_event({:unknown, "data"})
    end
  end
end 