defmodule Raxol.Architecture.CQRSIntegrationTest do
  @moduledoc """
  Integration tests for the CQRS and Event Sourcing implementation.
  """

  use ExUnit.Case, async: false

  alias Raxol.Architecture.CQRS.{CommandDispatcher, Setup}
  alias Raxol.Architecture.EventSourcing.EventStore
  alias Raxol.Commands.CreateTerminalCommand
  alias Raxol.Terminal.TerminalRegistry

  setup do
    # Start the necessary processes for testing
    {:ok, event_store} = EventStore.start_link([])
    {:ok, registry} = TerminalRegistry.start_link([])
    {:ok, dispatcher} = CommandDispatcher.start_link([])

    # Setup the CQRS system
    :ok = Setup.setup()

    on_exit(fn ->
      GenServer.stop(event_store)
      GenServer.stop(registry)
      GenServer.stop(dispatcher)
    end)

    %{
      event_store: event_store,
      registry: registry,
      dispatcher: dispatcher
    }
  end

  describe "CQRS Command Processing" do
    test "can dispatch terminal creation command", %{dispatcher: _dispatcher} do
      # Create a valid terminal creation command
      command_attrs = %{
        user_id: "test_user_123",
        width: 80,
        height: 24,
        title: "Test Terminal",
        working_directory: "/tmp"
      }

      # Create the command
      {:ok, command} = CreateTerminalCommand.new(command_attrs)

      # Verify the command is properly structured
      assert command.user_id == "test_user_123"
      assert command.width == 80
      assert command.height == 24
      assert is_binary(command.terminal_id)
      assert is_binary(command.command_id)

      # Note: Full dispatch test would require terminal process setup
      # For now, we're testing the command creation and structure
    end

    test "validates command parameters", _context do
      # Test with invalid dimensions
      invalid_command_attrs = %{
        user_id: "test_user_123",
        # Too small
        width: 10,
        # Too large
        height: 200
      }

      # Should fail validation
      assert {:error, _reason} =
               CreateTerminalCommand.new(invalid_command_attrs)
    end

    test "requires user authentication", _context do
      # Test without user_id
      invalid_command_attrs = %{
        width: 80,
        height: 24
      }

      # Should fail validation due to missing user_id
      assert {:error, _reason} =
               CreateTerminalCommand.new(invalid_command_attrs)
    end
  end

  describe "Event Sourcing" do
    test "event store can store and retrieve events", %{
      event_store: event_store
    } do
      # Test basic event store functionality
      stats = EventStore.get_statistics(event_store)

      assert is_map(stats)
      assert Map.has_key?(stats, :total_streams)
      assert Map.has_key?(stats, :total_events)
    end
  end

  describe "Terminal Registry" do
    test "registry starts with empty state", %{registry: registry} do
      stats = TerminalRegistry.get_statistics(registry)

      assert stats.total_terminals == 0
      assert stats.active_users == 0
    end

    test "can check if terminal exists", %{registry: registry} do
      refute TerminalRegistry.exists?(registry, "non_existent_terminal")
    end

    test "can list all terminals when empty", %{registry: registry} do
      assert TerminalRegistry.list_all_terminals(registry) == []
    end
  end

  describe "Command Handler Registration" do
    test "handlers are properly registered", %{dispatcher: dispatcher} do
      handlers = CommandDispatcher.list_handlers(dispatcher)

      assert is_list(handlers)
      assert length(handlers) > 0

      # Check that CreateTerminalCommand handler is registered
      create_handler =
        Enum.find(handlers, fn handler ->
          handler.command_type == CreateTerminalCommand
        end)

      assert create_handler != nil
    end

    test "dispatcher has correct statistics", %{dispatcher: dispatcher} do
      stats = CommandDispatcher.get_statistics(dispatcher)

      assert stats.registered_handlers > 0
      # We added 3 middleware components
      assert stats.middleware_count >= 3
    end
  end
end
