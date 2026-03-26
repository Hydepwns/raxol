defmodule Raxol.Core.StateManagerFunctionalTest do
  @moduledoc """
  Tests for the functional (pure map) strategy of Raxol.Core.StateManager
  and the ETSStrategy module directly.

  Functional tests require no GenServers or supervision trees.
  ETS tests use unique table names per test for full isolation.
  """
  use ExUnit.Case, async: true

  alias Raxol.Core.StateManager
  alias Raxol.Core.StateManager.ETSStrategy

  # ---------------------------------------------------------------------------
  # Functional strategy tests
  # ---------------------------------------------------------------------------

  describe "initialize/0" do
    test "returns {:ok, %{}}" do
      assert {:ok, %{}} = StateManager.initialize()
    end
  end

  describe "initialize/1" do
    test "returns default empty map when no initial_state given" do
      assert {:ok, %{}} = StateManager.initialize([])
    end

    test "returns the provided initial_state" do
      state = %{count: 0, name: "test"}
      assert {:ok, ^state} = StateManager.initialize(initial_state: state)
    end

    test "handles initial_state with nested data" do
      state = %{a: %{b: %{c: 1}}}
      assert {:ok, ^state} = StateManager.initialize(initial_state: state)
    end
  end

  describe "get/3 with map state" do
    test "returns value for existing key" do
      state = %{foo: "bar", count: 42}
      assert StateManager.get(state, :foo) == "bar"
      assert StateManager.get(state, :count) == 42
    end

    test "returns nil for missing key" do
      assert StateManager.get(%{}, :missing) == nil
    end

    test "accepts opts list without affecting result" do
      state = %{x: 1}
      assert StateManager.get(state, :x, []) == 1
    end

    test "returns default when key is missing and default is not a list" do
      state = %{a: 1}
      assert StateManager.get(state, :b, :default_val) == :default_val
      assert StateManager.get(state, :b, 0) == 0
      assert StateManager.get(state, :b, false) == false
    end
  end

  describe "get/4 with strategy: :functional" do
    test "returns value for existing key" do
      state = %{key: "value"}
      assert StateManager.get(state, :key, nil, strategy: :functional) == "value"
    end

    test "returns default for missing key" do
      state = %{a: 1}
      assert StateManager.get(state, :missing, :fallback, strategy: :functional) == :fallback
    end

    test "returns nil default when key missing and default is nil" do
      assert StateManager.get(%{}, :nope, nil, strategy: :functional) == nil
    end
  end

  describe "put/4 with strategy: :functional" do
    test "adds a new key to the map" do
      assert {:ok, %{a: 1}} = StateManager.put(%{}, :a, 1, strategy: :functional)
    end

    test "overwrites an existing key" do
      state = %{a: 1}
      assert {:ok, %{a: 2}} = StateManager.put(state, :a, 2, strategy: :functional)
    end

    test "preserves other keys" do
      state = %{a: 1, b: 2}
      assert {:ok, new} = StateManager.put(state, :c, 3, strategy: :functional)
      assert new == %{a: 1, b: 2, c: 3}
    end

    test "supports string keys" do
      assert {:ok, %{"key" => "val"}} =
               StateManager.put(%{}, "key", "val", strategy: :functional)
    end

    test "defaults to functional strategy" do
      assert {:ok, %{x: 99}} = StateManager.put(%{}, :x, 99)
    end
  end

  describe "update/4 with strategy: :functional" do
    test "updates existing key with function" do
      state = %{count: 5}

      assert {:ok, %{count: 6}} =
               StateManager.update(state, :count, &(&1 + 1), strategy: :functional)
    end

    test "uses nil as default when key is missing" do
      state = %{}

      assert {:ok, %{new_key: nil}} =
               StateManager.update(state, :new_key, fn val -> val end, strategy: :functional)
    end

    test "supports complex transformations" do
      state = %{items: [1, 2, 3]}

      assert {:ok, %{items: [0, 1, 2, 3]}} =
               StateManager.update(
                 state,
                 :items,
                 fn list -> [0 | list] end,
                 strategy: :functional
               )
    end

    test "defaults to functional strategy" do
      state = %{n: 10}
      assert {:ok, %{n: 20}} = StateManager.update(state, :n, &(&1 * 2))
    end
  end

  describe "delete/3 with strategy: :functional" do
    test "removes an existing key" do
      state = %{a: 1, b: 2}
      assert {:ok, %{b: 2}} = StateManager.delete(state, :a, strategy: :functional)
    end

    test "returns unchanged map when key does not exist" do
      state = %{a: 1}
      assert {:ok, %{a: 1}} = StateManager.delete(state, :missing, strategy: :functional)
    end

    test "can delete all keys one by one" do
      state = %{x: 1, y: 2}
      {:ok, state} = StateManager.delete(state, :x, strategy: :functional)
      {:ok, state} = StateManager.delete(state, :y, strategy: :functional)
      assert state == %{}
    end

    test "defaults to functional strategy" do
      assert {:ok, %{}} = StateManager.delete(%{a: 1}, :a)
    end
  end

  describe "clear/2 with strategy: :functional" do
    test "returns empty map regardless of input" do
      assert {:ok, %{}} = StateManager.clear(%{a: 1, b: 2}, strategy: :functional)
    end

    test "returns empty map from already empty state" do
      assert {:ok, %{}} = StateManager.clear(%{}, strategy: :functional)
    end

    test "defaults to functional strategy" do
      assert {:ok, %{}} = StateManager.clear(%{data: "gone"})
    end
  end

  describe "merge/3 with strategy: :functional" do
    test "merges two maps" do
      assert {:ok, %{a: 1, b: 2}} =
               StateManager.merge(%{a: 1}, %{b: 2}, strategy: :functional)
    end

    test "second map overwrites first on conflict" do
      assert {:ok, %{a: 2}} =
               StateManager.merge(%{a: 1}, %{a: 2}, strategy: :functional)
    end

    test "merging with empty map returns the other map" do
      assert {:ok, %{x: 1}} = StateManager.merge(%{x: 1}, %{}, strategy: :functional)
      assert {:ok, %{x: 1}} = StateManager.merge(%{}, %{x: 1}, strategy: :functional)
    end

    test "merging two empty maps returns empty map" do
      assert {:ok, %{}} = StateManager.merge(%{}, %{}, strategy: :functional)
    end

    test "defaults to functional strategy" do
      assert {:ok, %{a: 1, b: 2}} = StateManager.merge(%{a: 1}, %{b: 2})
    end
  end

  describe "validate/2" do
    test "returns :ok for maps" do
      assert :ok = StateManager.validate(%{})
      assert :ok = StateManager.validate(%{a: 1})
      assert :ok = StateManager.validate(%{"key" => "val"})
    end

    test "returns error for non-map values" do
      assert {:error, :invalid_state_type} = StateManager.validate(nil)
      assert {:error, :invalid_state_type} = StateManager.validate("string")
      assert {:error, :invalid_state_type} = StateManager.validate(42)
      assert {:error, :invalid_state_type} = StateManager.validate([1, 2])
      assert {:error, :invalid_state_type} = StateManager.validate(:atom)
      assert {:error, :invalid_state_type} = StateManager.validate({:tuple})
    end

    test "accepts opts without affecting validation" do
      assert :ok = StateManager.validate(%{}, some: :opt)
      assert {:error, :invalid_state_type} = StateManager.validate(nil, some: :opt)
    end
  end

  describe "transaction/2" do
    test "wraps successful function result in {:ok, result}" do
      assert {:ok, 42} = StateManager.transaction(fn -> 42 end)
      assert {:ok, "hello"} = StateManager.transaction(fn -> "hello" end)
      assert {:ok, nil} = StateManager.transaction(fn -> nil end)
    end

    test "catches raised exceptions and returns {:error, exception}" do
      assert {:error, %RuntimeError{message: "boom"}} =
               StateManager.transaction(fn -> raise "boom" end)
    end

    test "catches thrown values" do
      assert {:error, {:throw, :oops}} =
               StateManager.transaction(fn -> throw(:oops) end)
    end

    test "catches exits" do
      assert {:error, {:exit, :shutdown}} =
               StateManager.transaction(fn -> exit(:shutdown) end)
    end

    test "can compose functional state operations" do
      {:ok, result} =
        StateManager.transaction(fn ->
          {:ok, state} = StateManager.put(%{}, :a, 1, strategy: :functional)
          {:ok, state} = StateManager.put(state, :b, 2, strategy: :functional)
          state
        end)

      assert result == %{a: 1, b: 2}
    end
  end

  describe "delegate_to_domain/3" do
    test "returns error for unknown domain" do
      assert {:error, {:unknown_domain, :nonexistent}} =
               StateManager.delegate_to_domain(:nonexistent, :some_fn, [])
    end

    test "returns error for arbitrary atom domains" do
      assert {:error, {:unknown_domain, :foobar}} =
               StateManager.delegate_to_domain(:foobar, :get, [:key])
    end
  end

  describe "list_domains/0" do
    test "returns a list of atom keys" do
      domains = StateManager.list_domains()
      assert is_list(domains)
      assert Enum.all?(domains, &is_atom/1)
    end

    test "includes known domains" do
      domains = StateManager.list_domains()
      assert :terminal in domains
      assert :plugins in domains
      assert :animation in domains
      assert :core in domains
    end

    test "returns exactly four domains" do
      assert length(StateManager.list_domains()) == 4
    end
  end

  # ---------------------------------------------------------------------------
  # ETSStrategy direct tests
  # ---------------------------------------------------------------------------

  defp unique_table_opts do
    table = :"test_ets_#{System.unique_integer([:positive])}"
    [table_name: table]
  end

  defp setup_table(opts) do
    ETSStrategy.init_if_needed(opts)
    opts
  end

  defp safe_delete_table(table) do
    case :ets.info(table) do
      :undefined -> :ok
      _ -> :ets.delete(table)
    end
  end

  describe "ETSStrategy.init_if_needed/1" do
    test "creates a new named ETS table" do
      opts = unique_table_opts()
      table = Keyword.fetch!(opts, :table_name)

      on_exit(fn ->
        case :ets.info(table) do
          :undefined -> :ok
          _ -> :ets.delete(table)
        end
      end)

      assert :ets.info(table) == :undefined
      assert :ok = ETSStrategy.init_if_needed(opts)
      assert :ets.info(table) != :undefined
    end

    test "is idempotent when table already exists" do
      opts = unique_table_opts()
      table = Keyword.fetch!(opts, :table_name)

      on_exit(fn ->
        case :ets.info(table) do
          :undefined -> :ok
          _ -> :ets.delete(table)
        end
      end)

      assert :ok = ETSStrategy.init_if_needed(opts)
      assert :ok = ETSStrategy.init_if_needed(opts)
      assert :ets.info(table) != :undefined
    end
  end

  describe "ETSStrategy.get/3 and set/3" do
    test "set stores and get retrieves a value" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:name, "alice", opts)
      assert ETSStrategy.get(:name, nil, opts) == "alice"
    end

    test "get returns default when key is missing" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      assert ETSStrategy.get(:missing, :default, opts) == :default
      assert ETSStrategy.get(:missing, nil, opts) == nil
    end

    test "set overwrites previous value" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:key, "first", opts)
      :ok = ETSStrategy.set(:key, "second", opts)
      assert ETSStrategy.get(:key, nil, opts) == "second"
    end

    test "supports string keys" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set("str_key", 123, opts)
      assert ETSStrategy.get("str_key", nil, opts) == 123
    end

    test "supports complex values" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      value = %{nested: [1, %{deep: true}]}
      :ok = ETSStrategy.set(:complex, value, opts)
      assert ETSStrategy.get(:complex, nil, opts) == value
    end
  end

  describe "ETSStrategy.update/3" do
    test "updates existing value with function" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:counter, 0, opts)
      :ok = ETSStrategy.update(:counter, &(&1 + 1), opts)
      assert ETSStrategy.get(:counter, nil, opts) == 1
    end

    test "passes nil to function when key does not exist" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.update(:absent, fn nil -> "created" end, opts)
      assert ETSStrategy.get(:absent, nil, opts) == "created"
    end
  end

  describe "ETSStrategy.delete/2" do
    test "removes an existing key" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:doomed, "bye", opts)
      assert ETSStrategy.get(:doomed, nil, opts) == "bye"

      :ok = ETSStrategy.delete(:doomed, opts)
      assert ETSStrategy.get(:doomed, nil, opts) == nil
    end

    test "is a no-op when key does not exist" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.delete(:nonexistent, opts)
    end
  end

  describe "ETSStrategy.clear/1" do
    test "removes all objects from the table" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:a, 1, opts)
      :ok = ETSStrategy.set(:b, 2, opts)
      :ok = ETSStrategy.clear(opts)

      assert ETSStrategy.get(:a, nil, opts) == nil
      assert ETSStrategy.get(:b, nil, opts) == nil
    end
  end

  describe "ETSStrategy.get_all/1" do
    test "returns all entries as a map with :table and :version" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:x, 10, opts)
      :ok = ETSStrategy.set(:y, 20, opts)

      all = ETSStrategy.get_all(opts)
      assert all[:x] == 10
      assert all[:y] == 20
      assert all[:table] == table
      assert is_integer(all[:version])
    end

    test "excludes __version__ key from entries" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:data, "val", opts)
      all = ETSStrategy.get_all(opts)

      refute Map.has_key?(all, :__version__)
    end
  end

  describe "ETSStrategy nested operations" do
    test "set_nested and get_nested round-trip" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set_nested([:config, :ui, :theme], "dark", opts)
      assert ETSStrategy.get_nested([:config, :ui, :theme], opts) == "dark"
    end

    test "set_nested updates parent map" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set_nested([:settings, :color], "blue", opts)
      parent = ETSStrategy.get(:settings, nil, opts)
      assert is_map(parent)
      assert parent[:color] == "blue"
    end

    test "delete_nested removes tuple key and updates parent" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set_nested([:app, :feature], "on", opts)
      assert ETSStrategy.get_nested([:app, :feature], opts) == "on"

      :ok = ETSStrategy.delete_nested([:app, :feature], opts)
      assert ETSStrategy.get_nested([:app, :feature], opts) == nil
    end

    test "get_nested returns nil for non-existent paths" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      assert ETSStrategy.get_nested([:no, :such, :path], opts) == nil
    end
  end

  describe "ETSStrategy.get_version/1 and increment_version/1" do
    test "initial version is 0" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      assert ETSStrategy.get_version(opts) == 0
    end

    test "increment_version increases the counter" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      ETSStrategy.increment_version(opts)
      assert ETSStrategy.get_version(opts) == 1

      ETSStrategy.increment_version(opts)
      ETSStrategy.increment_version(opts)
      assert ETSStrategy.get_version(opts) == 3
    end

    test "set increments version automatically" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      v0 = ETSStrategy.get_version(opts)
      :ok = ETSStrategy.set(:key, "val", opts)
      assert ETSStrategy.get_version(opts) == v0 + 1
    end

    test "update increments version" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:n, 1, opts)
      v1 = ETSStrategy.get_version(opts)
      :ok = ETSStrategy.update(:n, &(&1 + 1), opts)
      assert ETSStrategy.get_version(opts) == v1 + 1
    end

    test "delete increments version" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.set(:key, "val", opts)
      v1 = ETSStrategy.get_version(opts)
      :ok = ETSStrategy.delete(:key, opts)
      assert ETSStrategy.get_version(opts) == v1 + 1
    end
  end

  describe "ETSStrategy.merge/3" do
    test "merges two maps into ETS" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.merge(%{a: 1}, %{b: 2}, opts)
      assert ETSStrategy.get(:a, nil, opts) == 1
      assert ETSStrategy.get(:b, nil, opts) == 2
    end

    test "second map wins on key conflict" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.merge(%{k: "old"}, %{k: "new"}, opts)
      assert ETSStrategy.get(:k, nil, opts) == "new"
    end

    test "merging with empty maps is a no-op" do
      opts = unique_table_opts() |> setup_table()
      table = Keyword.fetch!(opts, :table_name)
      on_exit(fn -> safe_delete_table(table) end)

      :ok = ETSStrategy.merge(%{}, %{}, opts)
      # Only version-related entries, no user data
      all = ETSStrategy.get_all(opts)
      user_keys = Map.drop(all, [:table, :version])
      assert map_size(user_keys) == 0
    end
  end
end
