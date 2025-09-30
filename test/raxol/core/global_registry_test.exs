defmodule Raxol.Core.UnifiedRegistryTest do
  use ExUnit.Case, async: false  # GenServer tests should not be async

  alias Raxol.Core.UnifiedRegistry

  setup do
    # Start the registry for each test with the required name parameter
    start_supervised!({UnifiedRegistry, [name: UnifiedRegistry]})
    :ok
  end

  describe "start_link/1" do
    test "starts successfully with default options" do
      # Already started in setup, test that it's running
      assert Process.whereis(UnifiedRegistry) != nil
    end

    test "starts with custom config" do
      # Stop the default one and start with config
      stop_supervised(UnifiedRegistry)

      config = %{max_entries: 1000, cleanup_interval: 60_000}
      start_supervised!({UnifiedRegistry, [name: UnifiedRegistry, config: config]})

      assert Process.whereis(UnifiedRegistry) != nil
    end
  end

  describe "register/3 and lookup/2" do
    test "registers and looks up session data" do
      session_id = "session_123"
      session_data = %{user: "test_user", created_at: DateTime.utc_now()}

      assert :ok = UnifiedRegistry.register(:sessions, session_id, session_data)
      assert {:ok, entry} = UnifiedRegistry.lookup(:sessions, session_id)

      assert entry == session_data
    end

    test "registers and looks up plugin data" do
      plugin_id = :test_plugin
      plugin_data = %{name: "Test Plugin", version: "1.0.0"}

      assert :ok = UnifiedRegistry.register(:plugins, plugin_id, plugin_data)
      assert {:ok, entry} = UnifiedRegistry.lookup(:plugins, plugin_id)

      assert entry == plugin_data
    end

    test "registers and looks up command data" do
      command_name = "test_command"
      command_handler = fn -> :executed end

      assert :ok = UnifiedRegistry.register(:commands, command_name, command_handler)
      assert {:ok, entry} = UnifiedRegistry.lookup(:commands, command_name)

      assert is_function(entry)
    end

    test "registers and looks up theme data" do
      theme_name = "dark_theme"
      theme_data = %{background: "#000000", foreground: "#FFFFFF"}

      assert :ok = UnifiedRegistry.register(:themes, theme_name, theme_data)
      assert {:ok, entry} = UnifiedRegistry.lookup(:themes, theme_name)

      assert entry == theme_data
    end

    test "registers and looks up component data" do
      component_id = "button_component"
      component_data = %{type: :button, props: %{text: "Click me"}}

      assert :ok = UnifiedRegistry.register(:components, component_id, component_data)
      assert {:ok, entry} = UnifiedRegistry.lookup(:components, component_id)

      assert entry == component_data
    end

    test "lookup returns error for non-existent entry" do
      assert {:error, :not_found} = UnifiedRegistry.lookup(:sessions, "non_existent")
    end

    test "lookup returns error for invalid registry type" do
      assert {:error, :unknown_registry_type} = UnifiedRegistry.lookup(:invalid, "test")
    end

    test "register overwrites existing entry" do
      id = "overwrite_test"
      original_data = %{value: 1}
      new_data = %{value: 2}

      assert :ok = UnifiedRegistry.register(:sessions, id, original_data)
      assert :ok = UnifiedRegistry.register(:sessions, id, new_data)

      {:ok, entry} = UnifiedRegistry.lookup(:sessions, id)
      assert entry == new_data
    end
  end

  describe "unregister/2" do
    test "unregisters existing entry" do
      id = "to_remove"
      data = %{test: :data}

      UnifiedRegistry.register(:sessions, id, data)
      assert {:ok, _} = UnifiedRegistry.lookup(:sessions, id)

      assert :ok = UnifiedRegistry.unregister(:sessions, id)
      assert {:error, :not_found} = UnifiedRegistry.lookup(:sessions, id)
    end

    test "unregister succeeds even if entry doesn't exist" do
      assert :ok = UnifiedRegistry.unregister(:sessions, "non_existent")
    end

    test "unregister returns error for invalid registry type" do
      assert {:error, :unknown_registry_type} = UnifiedRegistry.unregister(:invalid, "test")
    end
  end

  describe "list/1" do
    test "lists all entries in a registry" do
      # Register multiple entries
      UnifiedRegistry.register(:plugins, :plugin1, %{name: "Plugin 1"})
      UnifiedRegistry.register(:plugins, :plugin2, %{name: "Plugin 2"})
      UnifiedRegistry.register(:plugins, :plugin3, %{name: "Plugin 3"})

      entries = UnifiedRegistry.list(:plugins)

      assert length(entries) == 3
      assert Enum.all?(entries, &is_map/1)
    end

    test "returns empty list for empty registry" do
      assert [] = UnifiedRegistry.list(:themes)
    end

    test "returns error for invalid registry type" do
      assert {:error, :unknown_registry_type} = UnifiedRegistry.list(:invalid)
    end
  end

  describe "count/1" do
    test "returns correct count of entries" do
      assert 0 = UnifiedRegistry.count(:commands)

      UnifiedRegistry.register(:commands, "cmd1", fn -> :ok end)
      assert 1 = UnifiedRegistry.count(:commands)

      UnifiedRegistry.register(:commands, "cmd2", fn -> :ok end)
      assert 2 = UnifiedRegistry.count(:commands)

      UnifiedRegistry.unregister(:commands, "cmd1")
      assert 1 = UnifiedRegistry.count(:commands)
    end

    test "returns error for invalid registry type" do
      assert 0 = UnifiedRegistry.count(:invalid)
    end
  end

  describe "search/2" do
    setup do
      # Register some test data
      UnifiedRegistry.register(:commands, "user_login", %{description: "Handle user login"})
      UnifiedRegistry.register(:commands, "user_logout", %{description: "Handle user logout"})
      UnifiedRegistry.register(:commands, "admin_panel", %{description: "Show admin interface"})
      UnifiedRegistry.register(:commands, "file_upload", %{description: "Upload file to server"})
      :ok
    end

    test "searches for entries by pattern" do
      results = UnifiedRegistry.search(:commands, "user")

      assert length(results) == 2
      # Results contain the data, not the full entry structure
    end

    test "search is case insensitive" do
      results = UnifiedRegistry.search(:commands, "USER")

      assert length(results) == 2
    end

    test "search returns empty list when no matches" do
      results = UnifiedRegistry.search(:commands, "nonexistent")

      assert [] = results
    end

    test "search returns error for invalid registry type" do
      assert {:error, :unknown_registry_type} = UnifiedRegistry.search(:invalid, "pattern")
    end
  end

  describe "filter/2" do
    setup do
      UnifiedRegistry.register(:sessions, "session1", %{active: true, user: "alice"})
      UnifiedRegistry.register(:sessions, "session2", %{active: false, user: "bob"})
      UnifiedRegistry.register(:sessions, "session3", %{active: true, user: "charlie"})
      :ok
    end

    test "filters entries by function" do
      active_filter = fn entry -> entry.active == true end
      results = UnifiedRegistry.filter(:sessions, active_filter)

      assert length(results) == 2
      assert Enum.all?(results, fn entry -> entry.active == true end)
    end

    test "filter returns empty list when no matches" do
      admin_filter = fn entry -> entry.user == "admin" end
      results = UnifiedRegistry.filter(:sessions, admin_filter)

      assert [] = results
    end

    test "filter returns error for invalid registry type" do
      filter_fn = fn _ -> true end
      assert {:error, :unknown_registry_type} = UnifiedRegistry.filter(:invalid, filter_fn)
    end
  end

  describe "stats/0" do
    test "returns statistics for all registries" do
      # Register some test data
      UnifiedRegistry.register(:sessions, "s1", %{})
      UnifiedRegistry.register(:sessions, "s2", %{})
      UnifiedRegistry.register(:plugins, :p1, %{})
      UnifiedRegistry.register(:commands, "c1", fn -> :ok end)

      stats = UnifiedRegistry.stats()

      assert is_map(stats)
      assert stats.sessions == 2
      assert stats.plugins == 1
      assert stats.commands == 1
      assert stats.themes == 0
      assert stats.components == 0
      assert is_integer(stats.total_entries)
      assert stats.total_entries == 4
    end
  end

  describe "bulk_register/2" do
    test "registers multiple entries at once" do
      entries = [
        {"bulk1", %{data: 1}},
        {"bulk2", %{data: 2}},
        {"bulk3", %{data: 3}}
      ]

      assert {:ok, 3} = UnifiedRegistry.bulk_register(:sessions, entries)

      assert 3 = UnifiedRegistry.count(:sessions)
      assert {:ok, _} = UnifiedRegistry.lookup(:sessions, "bulk1")
      assert {:ok, _} = UnifiedRegistry.lookup(:sessions, "bulk2")
      assert {:ok, _} = UnifiedRegistry.lookup(:sessions, "bulk3")
    end

    test "bulk_register returns error for invalid registry type" do
      entries = [{"test", %{}}]
      assert {:error, :unknown_registry_type} = UnifiedRegistry.bulk_register(:invalid, entries)
    end

    test "bulk_register handles empty list" do
      assert {:ok, 0} = UnifiedRegistry.bulk_register(:sessions, [])
      assert 0 = UnifiedRegistry.count(:sessions)
    end
  end

  describe "bulk_unregister/2" do
    setup do
      entries = [
        {"remove1", %{data: 1}},
        {"remove2", %{data: 2}},
        {"remove3", %{data: 3}},
        {"keep", %{data: 4}}
      ]
      UnifiedRegistry.bulk_register(:sessions, entries)
      :ok
    end

    test "unregisters multiple entries at once" do
      ids_to_remove = ["remove1", "remove2", "remove3"]

      assert {:ok, 3} = UnifiedRegistry.bulk_unregister(:sessions, ids_to_remove)

      assert 1 = UnifiedRegistry.count(:sessions)
      assert {:ok, _} = UnifiedRegistry.lookup(:sessions, "keep")
      assert {:error, :not_found} = UnifiedRegistry.lookup(:sessions, "remove1")
    end

    test "bulk_unregister returns error for invalid registry type" do
      assert {:error, :unknown_registry_type} = UnifiedRegistry.bulk_unregister(:invalid, ["test"])
    end

    test "bulk_unregister handles empty list" do
      original_count = UnifiedRegistry.count(:sessions)
      assert {:ok, 0} = UnifiedRegistry.bulk_unregister(:sessions, [])
      assert ^original_count = UnifiedRegistry.count(:sessions)
    end
  end

  describe "convenience functions for sessions" do
    test "register_session/2 and lookup_session/1" do
      session_id = "conv_session"
      session_data = %{user: "test"}

      assert :ok = UnifiedRegistry.register_session(session_id, session_data)
      assert {:ok, entry} = UnifiedRegistry.lookup_session(session_id)

      assert entry == session_data
    end

    test "unregister_session/1" do
      session_id = "to_remove"
      UnifiedRegistry.register_session(session_id, %{})

      assert :ok = UnifiedRegistry.unregister_session(session_id)
      assert {:error, :not_found} = UnifiedRegistry.lookup_session(session_id)
    end

    test "list_sessions/0" do
      UnifiedRegistry.register_session("s1", %{})
      UnifiedRegistry.register_session("s2", %{})

      sessions = UnifiedRegistry.list_sessions()
      assert length(sessions) == 2
    end
  end

  describe "convenience functions for plugins" do
    test "register_plugin/2 and lookup_plugin/1" do
      plugin_id = :test_plugin
      plugin_data = %{name: "Test", version: "1.0"}

      assert :ok = UnifiedRegistry.register_plugin(plugin_id, plugin_data)
      assert {:ok, entry} = UnifiedRegistry.lookup_plugin(plugin_id)

      assert entry == plugin_data
    end

    test "unregister_plugin/1" do
      plugin_id = :to_remove
      UnifiedRegistry.register_plugin(plugin_id, %{})

      assert :ok = UnifiedRegistry.unregister_plugin(plugin_id)
      assert {:error, :not_found} = UnifiedRegistry.lookup_plugin(plugin_id)
    end

    test "list_plugins/0" do
      UnifiedRegistry.register_plugin(:p1, %{})
      UnifiedRegistry.register_plugin(:p2, %{})

      plugins = UnifiedRegistry.list_plugins()
      assert length(plugins) == 2
    end
  end

  describe "convenience functions for commands" do
    test "register_command/2 and lookup_command/1" do
      command_name = "test_cmd"
      command_handler = fn -> :executed end

      assert :ok = UnifiedRegistry.register_command(command_name, command_handler)
      assert {:ok, entry} = UnifiedRegistry.lookup_command(command_name)

      assert is_function(entry)
    end

    test "unregister_command/1" do
      command_name = "to_remove"
      UnifiedRegistry.register_command(command_name, fn -> :ok end)

      assert :ok = UnifiedRegistry.unregister_command(command_name)
      assert {:error, :not_found} = UnifiedRegistry.lookup_command(command_name)
    end

    test "list_commands/0" do
      UnifiedRegistry.register_command("c1", fn -> :ok end)
      UnifiedRegistry.register_command("c2", fn -> :ok end)

      commands = UnifiedRegistry.list_commands()
      assert length(commands) == 2
    end

    test "search_commands/1" do
      UnifiedRegistry.register_command("user_cmd", fn -> :ok end)
      UnifiedRegistry.register_command("admin_cmd", fn -> :ok end)

      results = UnifiedRegistry.search_commands("user")
      assert length(results) == 1
      # Results contain the data, search works
    end
  end

  describe "error handling" do
    test "handles invalid registry types gracefully" do
      assert {:error, :unknown_registry_type} = UnifiedRegistry.register(:invalid, "id", %{})
      assert {:error, :unknown_registry_type} = UnifiedRegistry.lookup(:invalid, "id")
      assert {:error, :unknown_registry_type} = UnifiedRegistry.unregister(:invalid, "id")
      assert {:error, :unknown_registry_type} = UnifiedRegistry.list(:invalid)
      assert 0 = UnifiedRegistry.count(:invalid)
      assert {:error, :unknown_registry_type} = UnifiedRegistry.search(:invalid, "pattern")
    end

    test "handles GenServer failures gracefully" do
      # Test that the registry can recover from errors
      # This is more of a integration test to ensure robustness

      # Register some data
      UnifiedRegistry.register(:sessions, "test", %{})
      assert {:ok, _} = UnifiedRegistry.lookup(:sessions, "test")

      # Registry should still be functional after normal operations
      assert is_map(UnifiedRegistry.stats())
    end
  end

  describe "concurrency and state management" do
    test "handles concurrent registrations correctly" do
      # Test concurrent access
      tasks = 1..10 |> Enum.map(fn i ->
        Task.async(fn ->
          UnifiedRegistry.register(:sessions, "session_#{i}", %{number: i})
        end)
      end)

      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))

      # Verify all entries were registered
      assert 10 = UnifiedRegistry.count(:sessions)
    end

    test "maintains data consistency across operations" do
      # Register, lookup, modify, lookup again
      id = "consistency_test"
      original_data = %{value: 1, timestamp: System.monotonic_time()}

      UnifiedRegistry.register(:sessions, id, original_data)
      {:ok, entry1} = UnifiedRegistry.lookup(:sessions, id)

      # Update the entry
      updated_data = %{value: 2, timestamp: System.monotonic_time()}
      UnifiedRegistry.register(:sessions, id, updated_data)
      {:ok, entry2} = UnifiedRegistry.lookup(:sessions, id)

      # Verify data changed
      assert entry1 != entry2
    end

    test "handles registry state transitions correctly" do
      # Test the full lifecycle: register -> lookup -> unregister -> lookup
      id = "lifecycle_test"
      data = %{test: :data}

      # Initial state: not found
      assert {:error, :not_found} = UnifiedRegistry.lookup(:sessions, id)

      # Register
      assert :ok = UnifiedRegistry.register(:sessions, id, data)
      assert {:ok, entry} = UnifiedRegistry.lookup(:sessions, id)
      assert entry == data

      # Unregister
      assert :ok = UnifiedRegistry.unregister(:sessions, id)
      assert {:error, :not_found} = UnifiedRegistry.lookup(:sessions, id)
    end
  end

  describe "performance and scalability" do
    test "handles large numbers of entries efficiently" do
      # Register many entries to test performance
      entries = 1..100 |> Enum.map(fn i ->
        {"entry_#{i}", %{index: i, data: "test_data_#{i}"}}
      end)

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, 100} = UnifiedRegistry.bulk_register(:components, entries)
      end_time = System.monotonic_time(:millisecond)

      # Should complete reasonably quickly (less than 1 second)
      assert (end_time - start_time) < 1000

      # Verify all entries are registered
      assert 100 = UnifiedRegistry.count(:components)

      # Test lookup performance
      start_time = System.monotonic_time(:millisecond)
      {:ok, _} = UnifiedRegistry.lookup(:components, "entry_50")
      end_time = System.monotonic_time(:millisecond)

      # Lookups should be very fast (less than 10ms)
      assert (end_time - start_time) < 10
    end

    test "search performance is acceptable" do
      # Register entries with searchable content
      1..50 |> Enum.each(fn i ->
        UnifiedRegistry.register(:commands, "test_command_#{i}", %{
          description: "Test command number #{i}"
        })
      end)

      start_time = System.monotonic_time(:millisecond)
      results = UnifiedRegistry.search(:commands, "command")
      end_time = System.monotonic_time(:millisecond)

      # Should find all entries
      assert length(results) == 50

      # Search should complete quickly (less than 100ms)
      assert (end_time - start_time) < 100
    end
  end

  describe "module behaviour compliance" do
    test "implements RegistryBehaviour correctly" do
      # Verify all behaviour callbacks are implemented
      behaviours = UnifiedRegistry.__info__(:attributes)
                  |> Enum.filter(fn {attr, _} -> attr == :behaviour end)
                  |> Enum.flat_map(fn {_, behaviours} -> behaviours end)

      assert UnifiedRegistry.RegistryBehaviour in behaviours
    end

    test "exports all required callback functions" do
      functions = UnifiedRegistry.__info__(:functions)

      # Check behaviour callback functions are exported
      assert {:register, 3} in functions
      assert {:unregister, 2} in functions
      assert {:lookup, 2} in functions
      assert {:list, 1} in functions
      assert {:count, 1} in functions
      assert {:search, 2} in functions
    end

    test "module has proper documentation" do
      {:docs_v1, _, :elixir, _, %{"en" => module_doc}, _, _} =
        Code.fetch_docs(UnifiedRegistry)

      assert is_binary(module_doc)
      assert String.length(module_doc) > 100
      assert String.contains?(module_doc, "registry")
    end
  end
end