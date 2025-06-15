defmodule Raxol.Terminal.Split.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Split.Manager

  setup do
    {:ok, pid} = Manager.start_link()
    %{pid: pid}
  end

  describe "create_split/1" do
    test "creates a split with default dimensions", %{pid: pid} do
      assert {:ok, split} = Manager.create_split()
      assert split.dimensions == %{width: 80, height: 24}
      assert split.position == %{x: 0, y: 0}
      assert is_map(split.content)
      assert split.created_at
    end

    test "creates a split with custom dimensions", %{pid: pid} do
      opts = %{
        dimensions: %{width: 100, height: 30},
        position: %{x: 10, y: 10}
      }

      assert {:ok, split} = Manager.create_split(opts)
      assert split.dimensions == %{width: 100, height: 30}
      assert split.position == %{x: 10, y: 10}
    end
  end

  describe "resize_split/2" do
    test "resizes an existing split", %{pid: pid} do
      {:ok, split} = Manager.create_split()
      new_dimensions = %{width: 120, height: 40}

      assert {:ok, updated_split} =
               Manager.resize_split(split.id, new_dimensions)

      assert updated_split.dimensions == new_dimensions
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} =
               Manager.resize_split(999, %{width: 100, height: 30})
    end
  end

  describe "navigate_to_split/1" do
    test "navigates to an existing split", %{pid: pid} do
      {:ok, split} = Manager.create_split()
      assert {:ok, _} = Manager.navigate_to_split(split.id)
    end

    test "returns error for non-existent split", %{pid: pid} do
      assert {:error, :not_found} = Manager.navigate_to_split(999)
    end
  end

  describe "list_splits/0" do
    test "lists all splits", %{pid: pid} do
      {:ok, split1} = Manager.create_split()
      {:ok, split2} = Manager.create_split()
      splits = Manager.list_splits()
      assert length(splits) == 2
      assert Enum.map(splits, & &1.id) |> Enum.sort() == [split1.id, split2.id]
    end

    test "returns empty list when no splits exist", %{pid: pid} do
      assert [] = Manager.list_splits()
    end
  end
end
