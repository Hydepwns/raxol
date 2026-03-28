defmodule Raxol.Core.FocusTest do
  use ExUnit.Case, async: false

  alias Raxol.Core.Focus
  alias Raxol.Core.FocusManager
  alias Raxol.Core.FocusManager.FocusServer

  setup do
    on_exit(fn ->
      case Process.whereis(FocusServer) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid, :normal, 1000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    :ok
  end

  describe "setup_focus/1" do
    test "registers components and sets initial focus to first by tab_index" do
      Focus.setup_focus([
        {"button_b", 2},
        {"input_a", 0},
        {"input_b", 1}
      ])

      assert Focus.current_focus() == "input_a"
    end

    test "accepts {id, tab_index, opts} tuple format" do
      Focus.setup_focus([
        {"field_1", 0, [group: :form]},
        {"field_2", 1, []}
      ])

      assert Focus.current_focus() == "field_1"
    end

    test "handles empty list without error" do
      assert Focus.setup_focus([]) == :ok
      assert Focus.current_focus() == nil
    end
  end

  describe "focused?/1" do
    test "returns false when FocusServer is not running" do
      assert Process.whereis(FocusServer) == nil
      assert Focus.focused?("anything") == false
    end

    test "returns true for the focused element" do
      Focus.setup_focus([{"a", 0}, {"b", 1}])
      assert Focus.focused?("a") == true
    end

    test "returns false for an unfocused element" do
      Focus.setup_focus([{"a", 0}, {"b", 1}])
      assert Focus.focused?("b") == false
    end
  end

  describe "current_focus/0" do
    test "returns nil when FocusServer is not running" do
      assert Process.whereis(FocusServer) == nil
      assert Focus.current_focus() == nil
    end

    test "returns the focused element ID" do
      Focus.setup_focus([{"x", 0}, {"y", 1}])
      assert Focus.current_focus() == "x"
    end
  end

  describe "focus_next cycling" do
    test "cycles through elements in tab order" do
      Focus.setup_focus([{"a", 0}, {"b", 1}, {"c", 2}])

      assert Focus.current_focus() == "a"

      {:ok, "b"} = FocusManager.focus_next()
      assert Focus.current_focus() == "b"

      {:ok, "c"} = FocusManager.focus_next()
      assert Focus.current_focus() == "c"
    end

    test "wraps around to first element" do
      Focus.setup_focus([{"a", 0}, {"b", 1}])

      {:ok, "b"} = FocusManager.focus_next()
      {:ok, "a"} = FocusManager.focus_next()
      assert Focus.current_focus() == "a"
    end
  end

  describe "focus_previous cycling" do
    test "cycles backwards through elements" do
      Focus.setup_focus([{"a", 0}, {"b", 1}, {"c", 2}])

      # Start at "a", previous wraps to "c"
      {:ok, "c"} = FocusManager.focus_previous()
      assert Focus.current_focus() == "c"

      {:ok, "b"} = FocusManager.focus_previous()
      assert Focus.current_focus() == "b"
    end

    test "wraps around to last element" do
      Focus.setup_focus([{"a", 0}, {"b", 1}])

      # At "a", previous wraps to "b"
      {:ok, "b"} = FocusManager.focus_previous()
      assert Focus.current_focus() == "b"
    end
  end
end
