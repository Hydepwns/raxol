defmodule Raxol.Terminal.Commands.RegistryTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Commands.Registry

  setup do
    registry = Registry.new()
    {:ok, %{registry: registry}}
  end

  describe "new/1" do
    test "creates a new registry with default options", %{registry: registry} do
      assert registry.commands == %{}
      assert registry.history == []
      assert registry.max_history == 1000
      assert registry.metrics.registrations == 0
      assert registry.metrics.executions == 0
      assert registry.metrics.completions == 0
      assert registry.metrics.validations == 0
    end

    test ~c"creates registry with custom max history" do
      registry = Registry.new(max_history: 500)
      assert registry.max_history == 500
    end
  end

  describe "register_command/2" do
    test "registers a valid command", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command",
        handler: fn _args -> :ok end,
        aliases: ["t"],
        usage: "test [args]",
        completion: nil
      }

      assert {:ok, updated_registry} =
               Registry.register_command(registry, command)

      assert updated_registry.commands["test"] == command
      assert updated_registry.metrics.registrations == 1
    end

    test "rejects command with missing required fields", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command"
        # Missing handler and usage
      }

      assert {:error, :invalid_command} =
               Registry.register_command(registry, command)
    end

    test "rejects duplicate command name", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command",
        handler: fn _args -> :ok end,
        aliases: ["t"],
        usage: "test [args]",
        completion: nil
      }

      {:ok, registry} = Registry.register_command(registry, command)

      assert {:error, :command_exists} =
               Registry.register_command(registry, command)
    end
  end

  describe "execute_command/3" do
    test "executes a registered command", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command",
        handler: fn args -> {:ok, args} end,
        aliases: ["t"],
        usage: "test [args]",
        completion: nil
      }

      {:ok, registry} = Registry.register_command(registry, command)

      assert {:ok, updated_registry, {:ok, ["arg1"]}} =
               Registry.execute_command(registry, "test", ["arg1"])

      assert updated_registry.metrics.executions == 1
      assert hd(updated_registry.history) == "test"
    end

    test "rejects execution of non-existent command", %{registry: registry} do
      assert {:error, :command_not_found} =
               Registry.execute_command(registry, "nonexistent", [])
    end

    test "validates command arguments", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command",
        handler: fn args -> {:ok, args} end,
        aliases: ["t"],
        usage: "test [args]",
        completion: fn args ->
          if length(args) > 0, do: :ok, else: {:error, :missing_args}
        end
      }

      {:ok, registry} = Registry.register_command(registry, command)

      assert {:error, :missing_args} =
               Registry.execute_command(registry, "test", [])
    end
  end

  describe "get_completions/2" do
    test "returns matching command completions", %{registry: registry} do
      commands = [
        %{
          name: "test",
          description: "Test command",
          handler: fn _args -> :ok end,
          aliases: ["t"],
          usage: "test [args]",
          completion: nil
        },
        %{
          name: "test2",
          description: "Another test command",
          handler: fn _args -> :ok end,
          aliases: ["t2"],
          usage: "test2 [args]",
          completion: nil
        }
      ]

      registry =
        Enum.reduce(commands, registry, fn cmd, acc ->
          {:ok, acc} = Registry.register_command(acc, cmd)
          acc
        end)

      assert {:ok, updated_registry, ["t", "t2", "test", "test2"]} =
               Registry.get_completions(registry, "t")

      assert updated_registry.metrics.completions == 1
    end

    test "returns empty list for no matches", %{registry: registry} do
      assert {:ok, updated_registry, []} =
               Registry.get_completions(registry, "nonexistent")

      assert updated_registry.metrics.completions == 1
    end
  end

  describe "get_history/1" do
    test "returns command history", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command",
        handler: fn _args -> :ok end,
        aliases: ["t"],
        usage: "test [args]",
        completion: nil
      }

      {:ok, registry} = Registry.register_command(registry, command)
      {:ok, registry, _} = Registry.execute_command(registry, "test", [])
      assert Registry.get_history(registry) == ["test"]
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{registry: registry} do
      metrics = Registry.get_metrics(registry)
      assert metrics.registrations == 0
      assert metrics.executions == 0
      assert metrics.completions == 0
      assert metrics.validations == 0
    end
  end

  describe "clear_history/1" do
    test "clears command history", %{registry: registry} do
      command = %{
        name: "test",
        description: "Test command",
        handler: fn _args -> :ok end,
        aliases: ["t"],
        usage: "test [args]",
        completion: nil
      }

      {:ok, registry} = Registry.register_command(registry, command)
      {:ok, registry, _} = Registry.execute_command(registry, "test", [])
      updated_registry = Registry.clear_history(registry)
      assert updated_registry.history == []
    end
  end
end
