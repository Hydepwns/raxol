defmodule Raxol.Agent.ContextStoreTest do
  use ExUnit.Case, async: false

  alias Raxol.Agent.ContextStore

  setup do
    ContextStore.init()

    on_exit(fn ->
      # Clean up test data
      for id <- ContextStore.list() do
        ContextStore.delete(id)
      end
    end)

    :ok
  end

  describe "save/2 and load/1" do
    test "saves and loads a context" do
      context = %{step: 3, findings: ["a.ex", "b.ex"]}
      :ok = ContextStore.save(:test_agent, context)

      assert {:ok, ^context} = ContextStore.load(:test_agent)
    end

    test "overwrites existing context" do
      ContextStore.save(:test_agent, %{v: 1})
      ContextStore.save(:test_agent, %{v: 2})

      assert {:ok, %{v: 2}} = ContextStore.load(:test_agent)
    end

    test "returns error for missing agent" do
      assert {:error, :not_found} = ContextStore.load(:nonexistent)
    end
  end

  describe "update/2" do
    test "transforms existing context" do
      ContextStore.save(:test_agent, %{count: 1})

      {:ok, updated} =
        ContextStore.update(:test_agent, fn ctx ->
          %{ctx | count: ctx.count + 1}
        end)

      assert updated.count == 2
      assert {:ok, %{count: 2}} = ContextStore.load(:test_agent)
    end

    test "returns error if agent not found" do
      assert {:error, :not_found} =
               ContextStore.update(:missing, fn ctx -> ctx end)
    end
  end

  describe "delete/1" do
    test "removes a context" do
      ContextStore.save(:test_agent, %{data: true})
      :ok = ContextStore.delete(:test_agent)

      assert {:error, :not_found} = ContextStore.load(:test_agent)
    end

    test "is idempotent" do
      :ok = ContextStore.delete(:nonexistent)
    end
  end

  describe "list/0" do
    test "returns all stored agent ids" do
      ContextStore.save(:agent_a, %{})
      ContextStore.save(:agent_b, %{})
      ContextStore.save(:agent_c, %{})

      ids = ContextStore.list()

      assert :agent_a in ids
      assert :agent_b in ids
      assert :agent_c in ids
    end
  end
end
