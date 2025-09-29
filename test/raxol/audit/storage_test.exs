defmodule Raxol.Audit.StorageTest do
  use ExUnit.Case, async: false
  alias Raxol.Audit.Storage

  @test_storage_path "test/audit_storage_test"

  setup do
    # Clean up test directory if it exists
    File.rm_rf!(@test_storage_path)

    config = %{
      storage_path: @test_storage_path,
      compress_logs: false,
      max_file_size: 10_000,
      rotation_period: :daily,
      keep_files: 7
    }

    {:ok, _pid} = Storage.start_link(name: Storage, config: config)

    on_exit(fn ->
      case Process.whereis(Storage) do
        pid when is_pid(pid) ->
          try do
            GenServer.stop(Storage, :normal, 1000)
          catch
            :exit, _ -> :ok
          end
        nil -> :ok
      end

      File.rm_rf!(@test_storage_path)
    end)

    :ok
  end

  describe "store_batch/2" do
    test "stores events successfully" do
      events = create_test_events(5)
      assert :ok = Storage.store_batch(events)
    end

    test "stores events with all fields intact" do
      event = %{
        event_id: "test123",
        timestamp: System.system_time(:millisecond),
        event_type: :authentication,
        user_id: "user123",
        outcome: :success,
        metadata: %{extra: "data"}
      }

      assert :ok = Storage.store_batch([event])

      {:ok, results} = Storage.query(%{event_type: :authentication})
      assert length(results) == 1
      stored_event = hd(results)
      assert stored_event.event_id == "test123"
      assert stored_event.user_id == "user123"
    end
  end

  describe "query/3" do
    setup do
      # Store some test events
      events = [
        %{
          event_id: "evt1",
          timestamp: System.system_time(:millisecond),
          event_type: :authentication,
          user_id: "alice",
          severity: :low,
          outcome: :success
        },
        %{
          event_id: "evt2",
          timestamp: System.system_time(:millisecond),
          event_type: :authorization,
          user_id: "bob",
          severity: :medium,
          outcome: :denied
        },
        %{
          event_id: "evt3",
          timestamp: System.system_time(:millisecond),
          event_type: :data_access,
          user_id: "alice",
          severity: :high,
          resource_type: "document",
          resource_id: "doc123"
        }
      ]

      Storage.store_batch(events)
      :ok
    end

    test "queries by user_id" do
      {:ok, results} = Storage.query(%{user_id: "alice"})
      assert length(results) == 2
      assert Enum.all?(results, &(&1.user_id == "alice"))
    end

    test "queries by event_type" do
      {:ok, results} = Storage.query(%{event_type: :authentication})
      assert length(results) == 1
      assert hd(results).event_type == :authentication
    end

    test "queries by severity" do
      {:ok, results} = Storage.query(%{severity: :high})
      assert length(results) == 1
      assert hd(results).severity == :high
    end

    test "queries by resource" do
      {:ok, results} =
        Storage.query(%{
          resource_type: "document",
          resource_id: "doc123"
        })

      assert length(results) == 1
      assert hd(results).resource_id == "doc123"
    end

    test "queries with pagination" do
      # Add more events
      events = create_test_events(20)
      Storage.store_batch(events)

      {:ok, page1} = Storage.query(%{}, limit: 5, offset: 0)
      {:ok, page2} = Storage.query(%{}, limit: 5, offset: 5)

      assert length(page1) == 5
      assert length(page2) == 5
      assert hd(page1).event_id != hd(page2).event_id
    end

    test "queries with sorting" do
      {:ok, asc_results} =
        Storage.query(%{}, sort_by: :timestamp, sort_order: :asc)

      {:ok, desc_results} =
        Storage.query(%{}, sort_by: :timestamp, sort_order: :desc)

      assert hd(asc_results).timestamp <= List.last(asc_results).timestamp
      assert hd(desc_results).timestamp >= List.last(desc_results).timestamp
    end

    test "queries with text search" do
      event_with_text = %{
        event_id: "search_test",
        timestamp: System.system_time(:millisecond),
        description: "User performed suspicious activity",
        command: "rm -rf important_files",
        event_type: :security
      }

      Storage.store_batch([event_with_text])

      {:ok, results} = Storage.query(%{text_search: "suspicious"})
      assert Enum.any?(results, &(&1.event_id == "search_test"))

      {:ok, results} = Storage.query(%{text_search: "important"})
      assert Enum.any?(results, &(&1.event_id == "search_test"))
    end
  end

  describe "get_events_in_range/3" do
    test "gets events within time range" do
      now = System.system_time(:millisecond)

      events = [
        %{event_id: "old", timestamp: now - 60_000},
        %{event_id: "recent", timestamp: now - 10_000},
        %{event_id: "current", timestamp: now}
      ]

      Storage.store_batch(events)

      {:ok, results} = Storage.get_events_in_range(now - 30_000, now + 1000)

      event_ids = Enum.map(results, & &1.event_id)
      assert "recent" in event_ids
      assert "current" in event_ids
      refute "old" in event_ids
    end
  end

  describe "delete_before/2" do
    test "deletes old events" do
      now = System.system_time(:millisecond)

      events = [
        %{event_id: "very_old", timestamp: now - 100_000},
        %{event_id: "old", timestamp: now - 60_000},
        %{event_id: "recent", timestamp: now - 10_000}
      ]

      Storage.store_batch(events)

      {:ok, deleted_count} = Storage.delete_before(now - 30_000)
      assert deleted_count == 2

      {:ok, remaining} = Storage.query(%{})
      assert length(remaining) == 1
      assert hd(remaining).event_id == "recent"
    end
  end

  describe "create_index/2" do
    test "creates index for faster queries" do
      assert :ok = Storage.create_index(:session_id)

      # Store events with session_id
      events =
        for i <- 1..10 do
          %{
            event_id: "evt#{i}",
            timestamp: System.system_time(:millisecond),
            session_id: "session_#{rem(i, 3)}"
          }
        end

      Storage.store_batch(events)

      # Query should use index
      {:ok, results} = Storage.query(%{session_id: "session_1"})
      assert length(results) > 0
      assert Enum.all?(results, &(&1.session_id == "session_1"))
    end
  end

  describe "get_statistics/1" do
    test "returns storage statistics" do
      events = create_test_events(10)
      Storage.store_batch(events)

      {:ok, stats} = Storage.get_statistics()

      assert stats.total_events == 10
      assert stats.storage_size_bytes > 0
      assert is_list(stats.indexed_fields)
      assert stats.file_count >= 1
      assert stats.compression_enabled == false
    end

    test "tracks oldest and newest events" do
      old_event = %{
        event_id: "old",
        timestamp: 1000
      }

      new_event = %{
        event_id: "new",
        timestamp: 2000
      }

      Storage.store_batch([old_event, new_event])

      {:ok, stats} = Storage.get_statistics()

      assert stats.oldest_event.event_id == "old"
      assert stats.newest_event.event_id == "new"
    end
  end

  describe "file rotation" do
    test "rotates files when triggered" do
      # Store some events
      events = create_test_events(5)
      Storage.store_batch(events)

      # Trigger rotation
      send(Process.whereis(Storage), :rotate_file)
      Process.sleep(100)

      # Check that files were rotated
      files = File.ls!(@test_storage_path)
      assert length(files) >= 1
    end
  end

  describe "compression" do
    test "compresses archived files when enabled" do
      # Restart with compression enabled
      GenServer.stop(Storage)

      config = %{
        storage_path: @test_storage_path,
        compress_logs: true
      }

      {:ok, _pid} = Storage.start_link(name: Storage, config: config)

      # Store events and trigger rotation
      events = create_test_events(10)
      Storage.store_batch(events)

      send(Process.whereis(Storage), :rotate_file)
      # Give compression time to complete
      Process.sleep(500)

      files = File.ls!(@test_storage_path)
      assert Enum.any?(files, &String.ends_with?(&1, ".gz"))
    end
  end

  describe "indexing" do
    test "updates indexes when storing events" do
      events = [
        %{event_id: "e1", timestamp: 1000, user_id: "alice", severity: :high},
        %{event_id: "e2", timestamp: 2000, user_id: "bob", severity: :low},
        %{event_id: "e3", timestamp: 3000, user_id: "alice", severity: :low}
      ]

      Storage.store_batch(events)

      # User index should work
      {:ok, alice_events} = Storage.query(%{user_id: "alice"})
      assert length(alice_events) == 2

      # Severity index should work
      {:ok, low_events} = Storage.query(%{severity: :low})
      assert length(low_events) == 2
    end

    test "rebuilds index for existing data" do
      # Store events without custom field
      events =
        for i <- 1..5 do
          %{
            event_id: "evt#{i}",
            timestamp: System.system_time(:millisecond),
            custom_field: "value_#{rem(i, 2)}"
          }
        end

      Storage.store_batch(events)

      # Create index after data exists
      Storage.create_index(:custom_field)

      # Should be able to query by custom field
      {:ok, results} = Storage.query(%{custom_field: "value_0"})
      assert length(results) > 0
    end
  end

  describe "text search" do
    test "finds events by text content" do
      events = [
        %{
          event_id: "e1",
          timestamp: 1000,
          description: "User login successful from home network"
        },
        %{
          event_id: "e2",
          timestamp: 2000,
          command: "sudo apt-get update",
          description: "System update initiated"
        },
        %{
          event_id: "e3",
          timestamp: 3000,
          error_message: "Permission denied for sensitive operation"
        }
      ]

      Storage.store_batch(events)

      {:ok, results} = Storage.query(%{text_search: "update"})
      assert length(results) == 1
      assert hd(results).event_id == "e2"

      {:ok, results} = Storage.query(%{text_search: "sensitive"})
      assert length(results) == 1
      assert hd(results).event_id == "e3"

      {:ok, results} = Storage.query(%{text_search: "user"})
      assert length(results) == 1
    end

    test "searches with multiple terms" do
      event = %{
        event_id: "multi",
        timestamp: 1000,
        description: "Critical security alert detected"
      }

      Storage.store_batch([event])

      {:ok, results} = Storage.query(%{text_search: "critical security"})
      assert length(results) == 1

      {:ok, results} = Storage.query(%{text_search: "security alert"})
      assert length(results) == 1

      {:ok, results} = Storage.query(%{text_search: "nonexistent term"})
      assert Enum.empty?(results)
    end
  end

  # Helper functions

  defp create_test_events(count) do
    for i <- 1..count do
      %{
        event_id: "evt_#{i}",
        timestamp: System.system_time(:millisecond) + i,
        event_type:
          Enum.random([:authentication, :authorization, :data_access]),
        user_id: "user_#{rem(i, 3)}",
        severity: Enum.random([:low, :medium, :high])
      }
    end
  end
end
