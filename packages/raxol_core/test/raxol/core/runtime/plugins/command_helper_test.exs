defmodule Raxol.Core.Runtime.Plugins.CommandHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.CommandHelper
  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  defmodule TestCommandPlugin do
    def get_commands do
      [{:test_cmd, :handle_command, 2}]
    end

    def handle_command(args, _state) do
      {:ok, %{result: args}, args}
    end
  end

  defmodule MultiCommandPlugin do
    def get_commands do
      [
        {:greet, :do_greet, 2},
        {:farewell, :do_farewell, 2}
      ]
    end

    def do_greet(_args, _state), do: {:ok, %{}, "hello"}
    def do_farewell(_args, _state), do: {:ok, %{}, "bye"}
  end

  defmodule NoCommandPlugin do
    def hello, do: :world
  end

  defmodule BadTuplePlugin do
    def get_commands do
      [{:valid, :handle_command, 2}, {:bad_one, "not_atom", -1}, "not_a_tuple"]
    end

    def handle_command(_args, _state), do: {:ok, %{}, nil}
  end

  describe "validate_command_args/1" do
    test "accepts list of strings" do
      assert :ok = CommandHelper.validate_command_args(["hello", "world"])
    end

    test "accepts list of numbers" do
      assert :ok = CommandHelper.validate_command_args([1, 2.5, 3])
    end

    test "accepts mixed strings and numbers" do
      assert :ok = CommandHelper.validate_command_args(["arg", 42])
    end

    test "accepts empty list" do
      assert :ok = CommandHelper.validate_command_args([])
    end

    test "rejects nil" do
      assert {:error, :invalid_args} = CommandHelper.validate_command_args(nil)
    end

    test "rejects non-list" do
      assert {:error, :invalid_args} =
               CommandHelper.validate_command_args("string")
    end

    test "rejects list with maps" do
      assert {:error, :invalid_args} =
               CommandHelper.validate_command_args([%{}])
    end

    test "rejects list with atoms" do
      assert {:error, :invalid_args} =
               CommandHelper.validate_command_args([:atom])
    end

    test "rejects list with tuples" do
      assert {:error, :invalid_args} =
               CommandHelper.validate_command_args([{:a, :b}])
    end
  end

  describe "find_plugin_id_by_module/2" do
    test "finds plugin id by matching module" do
      plugins = %{
        "plugin_a" => ModuleA,
        "plugin_b" => ModuleB,
        "plugin_c" => ModuleC
      }

      assert "plugin_b" =
               CommandHelper.find_plugin_id_by_module(plugins, ModuleB)
    end

    test "returns nil when module not found" do
      plugins = %{"plugin_a" => ModuleA}
      assert nil == CommandHelper.find_plugin_id_by_module(plugins, ModuleZ)
    end

    test "returns nil for empty plugins map" do
      assert nil == CommandHelper.find_plugin_id_by_module(%{}, ModuleA)
    end
  end

  describe "find_plugin_for_command/4" do
    test "finds existing command in table" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestCommandPlugin,
          "test_cmd",
          TestCommandPlugin,
          :handle_command,
          2
        )

      result =
        CommandHelper.find_plugin_for_command(
          table,
          "test_cmd",
          TestCommandPlugin,
          2
        )

      assert {:ok, {TestCommandPlugin, :handle_command, 2}} = result
    end

    test "returns :not_found for missing command" do
      table = %{}

      result =
        CommandHelper.find_plugin_for_command(table, "missing", nil, 2)

      assert :not_found = result
    end

    test "handles atom command names by converting to string" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestCommandPlugin,
          "test_cmd",
          TestCommandPlugin,
          :handle_command,
          2
        )

      result =
        CommandHelper.find_plugin_for_command(
          table,
          :test_cmd,
          TestCommandPlugin,
          2
        )

      assert {:ok, {TestCommandPlugin, :handle_command, 2}} = result
    end

    test "trims and downcases command name" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestCommandPlugin,
          "test_cmd",
          TestCommandPlugin,
          :handle_command,
          2
        )

      result =
        CommandHelper.find_plugin_for_command(
          table,
          "  TEST_CMD  ",
          TestCommandPlugin,
          2
        )

      assert {:ok, {TestCommandPlugin, :handle_command, 2}} = result
    end
  end

  describe "register_plugin_commands/3" do
    test "registers commands from plugin with get_commands/0" do
      table = %{}

      result =
        CommandHelper.register_plugin_commands(TestCommandPlugin, %{}, table)

      assert is_map(result)
      assert Map.has_key?(result, TestCommandPlugin)
      commands = Map.get(result, TestCommandPlugin)
      assert length(commands) == 1
    end

    test "registers multiple commands" do
      table = %{}

      result =
        CommandHelper.register_plugin_commands(MultiCommandPlugin, %{}, table)

      assert is_map(result)
      commands = Map.get(result, MultiCommandPlugin)
      assert length(commands) == 2
    end

    test "returns unchanged table for plugin without get_commands/0" do
      table = %{existing: :data}

      result =
        CommandHelper.register_plugin_commands(NoCommandPlugin, %{}, table)

      assert result == table
    end

    test "skips invalid command tuples" do
      table = %{}

      result =
        CommandHelper.register_plugin_commands(BadTuplePlugin, %{}, table)

      assert is_map(result)
      # Only the valid command should be registered
      commands = Map.get(result, BadTuplePlugin, [])
      valid_names = Enum.map(commands, fn {name, _, _} -> name end)
      assert "valid" in valid_names
      refute "bad_one" in valid_names
    end
  end

  describe "unregister_plugin_commands/2" do
    test "removes module's commands from table" do
      table = %{}

      table =
        CommandHelper.register_plugin_commands(TestCommandPlugin, %{}, table)

      assert Map.has_key?(table, TestCommandPlugin)

      result =
        CommandHelper.unregister_plugin_commands(table, TestCommandPlugin)

      refute Map.has_key?(result, TestCommandPlugin)
    end

    test "handles missing module gracefully" do
      table = %{SomeOther => []}

      result =
        CommandHelper.unregister_plugin_commands(table, TestCommandPlugin)

      assert is_map(result)
    end

    test "handles empty table" do
      result = CommandHelper.unregister_plugin_commands(%{}, TestCommandPlugin)
      assert result == %{}
    end
  end

  describe "handle_command/5" do
    test "returns error for missing command" do
      state = %{
        plugins: %{},
        plugin_states: %{}
      }

      result =
        CommandHelper.handle_command(%{}, "nonexistent", nil, ["arg"], state)

      assert {:error, :not_found} = result
    end

    test "returns error for invalid args" do
      table = %{}

      table =
        CommandRegistry.register_command(
          table,
          TestCommandPlugin,
          "test_cmd",
          TestCommandPlugin,
          :handle_command,
          2
        )

      state = %{
        plugins: %{"test" => TestCommandPlugin},
        plugin_states: %{"test" => %{}}
      }

      result =
        CommandHelper.handle_command(
          table,
          "test_cmd",
          nil,
          nil,
          state
        )

      assert {:error, :invalid_args, _} = result
    end
  end
end
