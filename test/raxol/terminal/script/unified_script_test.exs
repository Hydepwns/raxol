defmodule Raxol.Terminal.Script.UnifiedScriptTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Script.UnifiedScript

  setup do
    {:ok, _pid} = UnifiedScript.start_link(
      script_paths: ["test/fixtures/scripts"],
      auto_load: false
    )
    :ok
  end

  describe "basic operations" do
    test "loads and unloads scripts" do
      # Load script
      source = """
      def hello do
        IO.puts("Hello, World!")
      end
      """

      assert {:ok, script_id} = UnifiedScript.load_script(
        source,
        :elixir,
        name: "Hello Script",
        version: "1.0.0"
      )

      # Get script state
      assert {:ok, script_state} = UnifiedScript.get_script_state(script_id)
      assert script_state.name == "Hello Script"
      assert script_state.type == :elixir
      assert script_state.source == source

      # Unload script
      assert :ok = UnifiedScript.unload_script(script_id)
      assert {:error, :script_not_found} = UnifiedScript.get_script_state(script_id)
    end

    test "handles script configuration" do
      # Load script with config
      source = """
      def hello do
        IO.puts("Hello, World!")
      end
      """

      config = %{
        timeout: 5000,
        retries: 3,
        debug: true
      }

      assert {:ok, script_id} = UnifiedScript.load_script(
        source,
        :elixir,
        name: "Hello Script",
        version: "1.0.0",
        config: config
      )

      # Update config
      new_config = %{
        timeout: 10000,
        retries: 5,
        debug: false
      }

      assert :ok = UnifiedScript.update_script_config(script_id, new_config)

      # Verify config update
      assert {:ok, script_state} = UnifiedScript.get_script_state(script_id)
      assert script_state.config == new_config
    end
  end

  describe "script execution" do
    test "executes scripts with arguments" do
      # Load script
      source = """
      def hello(name) do
        "Hello, \#{name}!"
      end
      """

      assert {:ok, script_id} = UnifiedScript.load_script(
        source,
        :elixir,
        name: "Hello Script"
      )

      # Execute script with argument
      assert {:ok, result} = UnifiedScript.execute_script(script_id, ["World"])
      assert result == "Hello, World!"

      # Get script output
      assert {:ok, output} = UnifiedScript.get_script_output(script_id)
      assert output == "Hello, World!"
    end

    test "handles script states" do
      # Load script
      source = """
      def long_running do
        Process.sleep(1000)
        "Done"
      end
      """

      assert {:ok, script_id} = UnifiedScript.load_script(
        source,
        :elixir,
        name: "Long Running Script"
      )

      # Execute script
      assert {:ok, _} = UnifiedScript.execute_script(script_id)

      # Pause script
      assert :ok = UnifiedScript.pause_script(script_id)
      assert {:ok, script_state} = UnifiedScript.get_script_state(script_id)
      assert script_state.status == :paused

      # Resume script
      assert :ok = UnifiedScript.resume_script(script_id)
      assert {:ok, script_state} = UnifiedScript.get_script_state(script_id)
      assert script_state.status == :running

      # Stop script
      assert :ok = UnifiedScript.stop_script(script_id)
      assert {:ok, script_state} = UnifiedScript.get_script_state(script_id)
      assert script_state.status == :idle
    end
  end

  describe "script management" do
    test "lists scripts with filters" do
      # Load different scripts
      assert {:ok, elixir_id} = UnifiedScript.load_script(
        "def hello do end",
        :elixir,
        name: "Elixir Script"
      )

      assert {:ok, lua_id} = UnifiedScript.load_script(
        "function hello() end",
        :lua,
        name: "Lua Script"
      )

      # Get all scripts
      assert {:ok, all_scripts} = UnifiedScript.get_scripts()
      assert map_size(all_scripts) == 2

      # Filter by type
      assert {:ok, elixir_scripts} = UnifiedScript.get_scripts(type: :elixir)
      assert map_size(elixir_scripts) == 1

      # Filter by status
      assert {:ok, idle_scripts} = UnifiedScript.get_scripts(status: :idle)
      assert map_size(idle_scripts) == 2
    end

    test "exports and imports scripts" do
      # Load script
      source = """
      def hello do
        IO.puts("Hello, World!")
      end
      """

      assert {:ok, script_id} = UnifiedScript.load_script(
        source,
        :elixir,
        name: "Hello Script"
      )

      # Export script
      export_path = "test/fixtures/scripts/exported.ex"
      assert :ok = UnifiedScript.export_script(script_id, export_path)

      # Import script
      assert {:ok, imported_id} = UnifiedScript.import_script(export_path)

      # Verify imported script
      assert {:ok, original_state} = UnifiedScript.get_script_state(script_id)
      assert {:ok, imported_state} = UnifiedScript.get_script_state(imported_id)
      assert imported_state.source == original_state.source
      assert imported_state.type == original_state.type

      # Clean up
      File.rm!(export_path)
    end
  end

  describe "error handling" do
    test "handles invalid script types" do
      assert {:error, :invalid_script_type} = UnifiedScript.load_script(
        "def hello do end",
        :invalid_type,
        name: "Invalid Script"
      )
    end

    test "handles invalid script sources" do
      assert {:error, :invalid_script_source} = UnifiedScript.load_script(
        "",
        :elixir,
        name: "Empty Script"
      )
    end

    test "handles invalid configurations" do
      assert {:ok, script_id} = UnifiedScript.load_script(
        "def hello do end",
        :elixir,
        name: "Hello Script"
      )

      assert {:error, :invalid_script_config} = UnifiedScript.update_script_config(
        script_id,
        "invalid_config"
      )
    end

    test "handles non-existent scripts" do
      assert {:error, :script_not_found} = UnifiedScript.get_script_state("non_existent")
      assert {:error, :script_not_found} = UnifiedScript.unload_script("non_existent")
      assert {:error, :script_not_found} = UnifiedScript.update_script_config("non_existent", %{})
    end

    test "handles invalid script states" do
      # Load script
      assert {:ok, script_id} = UnifiedScript.load_script(
        "def hello do end",
        :elixir,
        name: "Hello Script"
      )

      # Try to pause idle script
      assert {:error, :invalid_script_state} = UnifiedScript.pause_script(script_id)

      # Try to resume idle script
      assert {:error, :invalid_script_state} = UnifiedScript.resume_script(script_id)

      # Try to stop idle script
      assert {:error, :invalid_script_state} = UnifiedScript.stop_script(script_id)
    end
  end

  describe "script types" do
    test "handles different script types" do
      # Elixir script
      elixir_source = """
      def hello do
        "Hello from Elixir"
      end
      """

      assert {:ok, elixir_id} = UnifiedScript.load_script(
        elixir_source,
        :elixir,
        name: "Elixir Script"
      )

      # Lua script
      lua_source = """
      function hello()
        return "Hello from Lua"
      end
      """

      assert {:ok, lua_id} = UnifiedScript.load_script(
        lua_source,
        :lua,
        name: "Lua Script"
      )

      # Python script
      python_source = """
      def hello():
          return "Hello from Python"
      """

      assert {:ok, python_id} = UnifiedScript.load_script(
        python_source,
        :python,
        name: "Python Script"
      )

      # JavaScript script
      js_source = """
      function hello() {
        return "Hello from JavaScript";
      }
      """

      assert {:ok, js_id} = UnifiedScript.load_script(
        js_source,
        :javascript,
        name: "JavaScript Script"
      )

      # Verify script states
      assert {:ok, elixir_state} = UnifiedScript.get_script_state(elixir_id)
      assert {:ok, lua_state} = UnifiedScript.get_script_state(lua_id)
      assert {:ok, python_state} = UnifiedScript.get_script_state(python_id)
      assert {:ok, js_state} = UnifiedScript.get_script_state(js_id)

      assert elixir_state.type == :elixir
      assert lua_state.type == :lua
      assert python_state.type == :python
      assert js_state.type == :javascript
    end
  end
end
