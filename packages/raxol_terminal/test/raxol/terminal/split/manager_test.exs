defmodule Raxol.Terminal.Split.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Split.SplitManager, as: Manager

  setup do
    {:ok, pid} = Manager.start_link()
    %{pid: pid}
  end

  describe "create_split/1" do
    test "creates a split with default dimensions", %{pid: pid} do
      assert {:ok, split} = Manager.create_split(%{}, pid)
      assert split.dimensions == %{width: 80, height: 24}
      assert split.position == %{x: 0, y: 0}
      assert is_map(split.content)
      assert split.created_at
      assert is_nil(split.buffer_pid)
      assert is_nil(split.terminal_pid)
      assert is_nil(split.label)
    end

    test "creates a split with custom dimensions", %{pid: pid} do
      opts = %{
        dimensions: %{width: 100, height: 30},
        position: %{x: 10, y: 10}
      }

      assert {:ok, split} = Manager.create_split(opts, pid)
      assert split.dimensions == %{width: 100, height: 30}
      assert split.position == %{x: 10, y: 10}
    end

    test "creates a split with buffer binding", %{pid: pid} do
      fake_buffer = spawn(fn -> Process.sleep(:infinity) end)
      fake_terminal = spawn(fn -> Process.sleep(:infinity) end)

      opts = %{
        buffer_pid: fake_buffer,
        terminal_pid: fake_terminal,
        label: "Scout"
      }

      assert {:ok, split} = Manager.create_split(opts, pid)
      assert split.buffer_pid == fake_buffer
      assert split.terminal_pid == fake_terminal
      assert split.label == "Scout"
    end
  end

  describe "resize_split/2" do
    test "resizes an existing split", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)
      new_dimensions = %{width: 120, height: 40}

      assert {:ok, updated_split} =
               Manager.resize_split(split.id, new_dimensions, pid)

      assert updated_split.dimensions == new_dimensions
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} =
               Manager.resize_split(999, %{width: 100, height: 30}, pid)
    end
  end

  describe "navigate_to_split/1" do
    test "navigates to an existing split", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)
      assert {:ok, _} = Manager.navigate_to_split(split.id, pid)
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} = Manager.navigate_to_split(999, pid)
    end
  end

  describe "list_splits/0" do
    test "lists all splits", %{pid: pid} do
      {:ok, split1} = Manager.create_split(%{}, pid)
      {:ok, split2} = Manager.create_split(%{}, pid)
      splits = Manager.list_splits(pid)
      assert length(splits) == 2
      assert Enum.map(splits, & &1.id) |> Enum.sort() == [split1.id, split2.id]
    end

    test "returns empty list when no splits exist", %{pid: pid} do
      assert [] = Manager.list_splits(pid)
    end
  end

  describe "bind_buffer/4" do
    test "binds a buffer and terminal to a split", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)
      buffer = spawn(fn -> Process.sleep(:infinity) end)
      terminal = spawn(fn -> Process.sleep(:infinity) end)

      assert {:ok, updated} = Manager.bind_buffer(split.id, pid, buffer, terminal)
      assert updated.buffer_pid == buffer
      assert updated.terminal_pid == terminal
    end

    test "binds buffer only without terminal", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)
      buffer = spawn(fn -> Process.sleep(:infinity) end)

      assert {:ok, updated} = Manager.bind_buffer(split.id, pid, buffer)
      assert updated.buffer_pid == buffer
      assert is_nil(updated.terminal_pid)
    end

    test "returns error for non-existent split", %{pid: pid} do
      buffer = spawn(fn -> Process.sleep(:infinity) end)
      assert {:error, :not_found} = Manager.bind_buffer(999, pid, buffer)
    end
  end

  describe "unbind_buffer/2" do
    test "removes buffer binding from a split", %{pid: pid} do
      buffer = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, split} = Manager.create_split(%{buffer_pid: buffer}, pid)

      assert {:ok, updated} = Manager.unbind_buffer(split.id, pid)
      assert is_nil(updated.buffer_pid)
      assert is_nil(updated.terminal_pid)
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} = Manager.unbind_buffer(999, pid)
    end
  end

  describe "get_split_buffer/2" do
    test "returns buffer pid for bound split", %{pid: pid} do
      buffer = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, split} = Manager.create_split(%{buffer_pid: buffer}, pid)

      assert {:ok, ^buffer} = Manager.get_split_buffer(split.id, pid)
    end

    test "returns error when no buffer bound", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)
      assert {:error, :no_buffer} = Manager.get_split_buffer(split.id, pid)
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} = Manager.get_split_buffer(999, pid)
    end
  end

  describe "set_label/3" do
    test "sets a label on a split", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)

      assert {:ok, updated} = Manager.set_label(split.id, "Agent Alpha", pid)
      assert updated.label == "Agent Alpha"
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} = Manager.set_label(999, "nope", pid)
    end
  end

  describe "remove_split/2" do
    test "removes an existing split", %{pid: pid} do
      {:ok, split} = Manager.create_split(%{}, pid)

      assert :ok = Manager.remove_split(split.id, pid)
      assert [] = Manager.list_splits(pid)
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} = Manager.remove_split(999, pid)
    end
  end
end
