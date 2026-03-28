defmodule Raxol.Core.Runtime.Plugins.CommandRegistryTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  defmodule TestHandler do
    def handle_command(args, _context), do: {:ok, args}
    def handle_other(args, _context), do: {:ok, :other, args}
  end

  defmodule PluginWithValidCommands do
    def commands do
      [
        %{
          name: "greet",
          handler: fn _args, _ctx -> {:ok, "hello"} end,
          metadata: %{description: "Greets user", usage: "greet [name]"}
        },
        %{
          name: "bye",
          handler: fn _args, _ctx -> {:ok, "goodbye"} end,
          metadata: %{description: "Says goodbye"}
        }
      ]
    end
  end

  defmodule PluginWithBadHandler do
    def commands do
      [
        %{
          name: "bad",
          handler: :not_a_function,
          metadata: %{description: "Bad handler"}
        }
      ]
    end
  end

  describe "new/0" do
    test "returns the table name atom" do
      assert :command_registry_table = CommandRegistry.new()
    end
  end

  describe "register_command/6" do
    test "registers a command in a map-based table" do
      table = %{}

      result =
        CommandRegistry.register_command(
          table,
          TestHandler,
          "test_cmd",
          TestHandler,
          :handle_command,
          2
        )

      assert is_map(result)
      assert Map.has_key?(result, TestHandler)
      commands = Map.get(result, TestHandler)
      assert length(commands) == 1
      [{name, {mod, fun, arity}, _meta}] = commands
      assert name == "test_cmd"
      assert mod == TestHandler
      assert fun == :handle_command
      assert arity == 2
    end

    test "appends commands to existing namespace" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestHandler,
          "cmd1",
          TestHandler,
          :handle_command,
          2
        )

      table =
        CommandRegistry.register_command(
          table,
          TestHandler,
          "cmd2",
          TestHandler,
          :handle_other,
          2
        )

      commands = Map.get(table, TestHandler)
      assert length(commands) == 2
    end

    test "returns error when table is not a map" do
      result =
        CommandRegistry.register_command(
          :not_a_map,
          TestHandler,
          "cmd",
          TestHandler,
          :handle_command,
          2
        )

      assert {:error, :invalid_table} = result
    end
  end

  describe "unregister_command/3" do
    test "removes a command from namespace and returns updated table" do
      table =
        CommandRegistry.register_command(
          %{},
          TestHandler,
          "removable",
          TestHandler,
          :handle_command,
          2
        )

      result =
        CommandRegistry.unregister_command(table, TestHandler, "removable")

      assert is_map(result)
      assert Map.get(result, TestHandler) == []
    end

    test "returns table unchanged for non-existent command" do
      table = %{TestHandler => []}
      result = CommandRegistry.unregister_command(table, TestHandler, "ghost")
      assert result == table
    end

    test "returns input unchanged for non-map table" do
      assert :not_map =
               CommandRegistry.unregister_command(:not_map, TestHandler, "cmd")
    end
  end

  describe "lookup_command/3" do
    test "finds a registered command" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestHandler,
          "findme",
          TestHandler,
          :handle_command,
          2
        )

      assert {:ok, {TestHandler, handler, 2}} =
               CommandRegistry.lookup_command(table, TestHandler, "findme")

      assert is_function(handler, 2)
    end

    test "returns error for missing command" do
      table = %{TestHandler => []}

      assert {:error, :not_found} =
               CommandRegistry.lookup_command(table, TestHandler, "nope")
    end

    test "returns error for non-map table" do
      assert {:error, :invalid_table} =
               CommandRegistry.lookup_command(:bad, TestHandler, "cmd")
    end

    test "returns error for missing namespace" do
      table = %{}

      assert {:error, :not_found} =
               CommandRegistry.lookup_command(table, TestHandler, "cmd")
    end
  end

  describe "unregister_commands_by_module/2" do
    test "removes all commands for a module" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestHandler,
          "cmd1",
          TestHandler,
          :handle_command,
          2
        )

      table =
        CommandRegistry.register_command(
          table,
          TestHandler,
          "cmd2",
          TestHandler,
          :handle_other,
          2
        )

      result = CommandRegistry.unregister_commands_by_module(table, TestHandler)
      assert is_map(result)
      refute Map.has_key?(result, TestHandler)
    end

    test "returns input for non-map table" do
      assert :atom =
               CommandRegistry.unregister_commands_by_module(:atom, TestHandler)
    end

    test "handles missing module gracefully" do
      table = %{}
      result = CommandRegistry.unregister_commands_by_module(table, TestHandler)
      assert result == %{}
    end
  end

  describe "find_command/2" do
    test "finds command across all namespaces" do
      table = %{
        TestHandler => [
          {"greet", {TestHandler, :handle_command, 2}, %{description: "hi"}}
        ]
      }

      assert {:ok, {{TestHandler, :handle_command, 2}, %{description: "hi"}}} =
               CommandRegistry.find_command("greet", table)
    end

    test "returns error for missing command" do
      table = %{
        TestHandler => [{"other", {TestHandler, :handle_command, 2}, %{}}]
      }

      assert {:error, :not_found} =
               CommandRegistry.find_command("missing", table)
    end

    test "returns error for empty table" do
      assert {:error, :not_found} = CommandRegistry.find_command("cmd", %{})
    end
  end

  describe "execute_command/3" do
    test "executes a found command handler" do
      handler = fn _args, _ctx -> {:ok, :executed} end

      table = %{
        TestHandler => [{"run", handler, %{}}]
      }

      result = CommandRegistry.execute_command("run", ["arg1"], table)
      assert {:ok, :executed} = result
    end

    test "returns error for missing command" do
      assert {:error, :not_found} =
               CommandRegistry.execute_command("missing", [], %{})
    end

    test "handles handler crash" do
      Process.flag(:trap_exit, true)
      handler = fn _args, _ctx -> raise "kaboom" end

      table = %{
        TestHandler => [{"crash", handler, %{}}]
      }

      result = CommandRegistry.execute_command("crash", [], table)
      assert {:error, {:execution_failed, _}} = result
    end

    test "respects timeout from metadata" do
      handler = fn _args, _ctx ->
        Process.sleep(2000)
        {:ok, :done}
      end

      table = %{
        TestHandler => [{"slow", handler, %{timeout: 50}}]
      }

      result = CommandRegistry.execute_command("slow", [], table)
      assert {:error, :command_timeout} = result
    end

    test "uses default 5000ms timeout" do
      handler = fn _args, _ctx -> {:ok, :fast} end

      table = %{
        TestHandler => [{"fast", handler, %{}}]
      }

      result = CommandRegistry.execute_command("fast", [], table)
      assert {:ok, :fast} = result
    end
  end

  describe "register_plugin_commands/3" do
    test "registers valid plugin commands" do
      existing_table = %{}

      result =
        CommandRegistry.register_plugin_commands(
          PluginWithValidCommands,
          %{},
          existing_table
        )

      assert {:ok, updated_table} = result
      assert Map.has_key?(updated_table, PluginWithValidCommands)
    end

    test "detects command conflicts" do
      existing_table = %{
        SomeOther => [{"greet", {SomeOther, :handle, 2}, %{}}]
      }

      result =
        CommandRegistry.register_plugin_commands(
          PluginWithValidCommands,
          %{},
          existing_table
        )

      assert {:error, {:command_exists, "greet"}} = result
    end
  end

  describe "valid_metadata_fields? (via register_plugin_commands)" do
    test "accepts valid metadata fields" do
      defmodule ValidMetaPlugin do
        def commands do
          [
            %{
              name: "meta_cmd",
              handler: &__MODULE__.do_meta/2,
              metadata: %{
                description: "A command",
                usage: "meta_cmd [args]",
                aliases: ["mc", "m"],
                timeout: 3000
              }
            }
          ]
        end

        def do_meta(_args, _ctx), do: :ok
      end

      result =
        CommandRegistry.register_plugin_commands(ValidMetaPlugin, %{}, %{})

      assert {:ok, _} = result
    end

    test "rejects invalid metadata fields" do
      defmodule BadMetaPlugin do
        def commands do
          [
            %{
              name: "bad_meta",
              handler: &__MODULE__.noop/2,
              metadata: %{unknown_field: true}
            }
          ]
        end

        def noop(_, _), do: :ok
      end

      result =
        CommandRegistry.register_plugin_commands(BadMetaPlugin, %{}, %{})

      assert {:error, :invalid_metadata_fields} = result
    end

    test "rejects non-binary description" do
      defmodule BadDescPlugin do
        def commands do
          [
            %{
              name: "bad_desc",
              handler: &__MODULE__.noop/2,
              metadata: %{description: 123}
            }
          ]
        end

        def noop(_, _), do: :ok
      end

      result =
        CommandRegistry.register_plugin_commands(BadDescPlugin, %{}, %{})

      assert {:error, :invalid_metadata_fields} = result
    end

    test "rejects non-list aliases" do
      defmodule BadAliasPlugin do
        def commands do
          [
            %{
              name: "bad_alias",
              handler: &__MODULE__.noop/2,
              metadata: %{aliases: "not_a_list"}
            }
          ]
        end

        def noop(_, _), do: :ok
      end

      result =
        CommandRegistry.register_plugin_commands(BadAliasPlugin, %{}, %{})

      assert {:error, :invalid_metadata_fields} = result
    end

    test "rejects negative timeout" do
      defmodule BadTimeoutPlugin do
        def commands do
          [
            %{
              name: "bad_timeout",
              handler: &__MODULE__.noop/2,
              metadata: %{timeout: -1}
            }
          ]
        end

        def noop(_, _), do: :ok
      end

      result =
        CommandRegistry.register_plugin_commands(BadTimeoutPlugin, %{}, %{})

      assert {:error, :invalid_metadata_fields} = result
    end
  end
end
