defmodule Raxol.Terminal.Clipboard.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Clipboard.Manager

  setup do
    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/0" do
    test "creates a new clipboard manager with default values" do
      manager = Manager.new()
      assert manager.content == ""
      assert manager.mode == :normal
    end
  end

  describe "get_content/1 and set_content/2" do
    test "sets and gets clipboard content", %{manager: manager} do
      content = "test content"
      manager = Manager.set_content(manager, content)
      assert Manager.get_content(manager) == content
    end

    test "handles empty content", %{manager: manager} do
      manager = Manager.set_content(manager, "")
      assert Manager.get_content(manager) == ""
    end
  end

  describe "get_mode/1 and set_mode/2" do
    test "sets and gets clipboard mode", %{manager: manager} do
      manager = Manager.set_mode(manager, :bracketed)
      assert Manager.get_mode(manager) == :bracketed
    end

    test "defaults to normal mode", %{manager: manager} do
      assert Manager.get_mode(manager) == :normal
    end
  end

  describe "clear/1" do
    test "clears clipboard content", %{manager: manager} do
      manager = Manager.set_content(manager, "test content")
      manager = Manager.clear(manager)
      assert Manager.get_content(manager) == ""
    end
  end

  describe "append/2" do
    test "appends text to clipboard content", %{manager: manager} do
      manager = Manager.set_content(manager, "hello")
      manager = Manager.append(manager, " world")
      assert Manager.get_content(manager) == "hello world"
    end

    test "appends to empty clipboard", %{manager: manager} do
      manager = Manager.append(manager, "test")
      assert Manager.get_content(manager) == "test"
    end
  end

  describe "prepend/2" do
    test "prepends text to clipboard content", %{manager: manager} do
      manager = Manager.set_content(manager, "world")
      manager = Manager.prepend(manager, "hello ")
      assert Manager.get_content(manager) == "hello world"
    end

    test "prepends to empty clipboard", %{manager: manager} do
      manager = Manager.prepend(manager, "test")
      assert Manager.get_content(manager) == "test"
    end
  end

  describe "empty?/1" do
    test "returns true for empty clipboard", %{manager: manager} do
      assert Manager.empty?(manager) == true
    end

    test "returns false for non-empty clipboard", %{manager: manager} do
      manager = Manager.set_content(manager, "test")
      assert Manager.empty?(manager) == false
    end
  end

  describe "length/1" do
    test "returns correct length of clipboard content", %{manager: manager} do
      assert Manager.length(manager) == 0
      manager = Manager.set_content(manager, "test")
      assert Manager.length(manager) == 4
    end
  end

  describe "reset/1" do
    test "resets clipboard to initial state", %{manager: manager} do
      manager = Manager.set_content(manager, "test content")
      manager = Manager.set_mode(manager, :bracketed)
      manager = Manager.reset(manager)
      assert Manager.get_content(manager) == ""
      assert Manager.get_mode(manager) == :normal
    end
  end
end
