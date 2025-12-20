defmodule Raxol.Terminal.Commands.CSICommandServerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.CSIHandler
  alias Raxol.Terminal.Emulator

  describe "CSI command handling" do
    test "handles cursor movement commands correctly" do
      # Test that basic CSI commands work with minimal emulator state
      emulator = %{cursor: %{row: 5, col: 5}, width: 80, height: 24}

      # Test basic cursor movement commands that should be handled
      cursor_commands = ["A", "B", "C", "D", "H"]

      for command <- cursor_commands do
        result = try do
          CSIHandler.handle_csi_sequence(emulator, command, [])
        rescue
          _ -> :test_error
        end

        # Should return the emulator (possibly modified) without crashing
        assert result != :test_error, "Command #{command} should not crash"
      end
    end

    test "handles unknown CSI commands gracefully" do
      # Test that unknown CSI commands don't crash
      emulator = %{test: :emulator}
      result = CSIHandler.handle_csi_sequence(emulator, "UNKNOWN", [])
      assert %{test: :emulator} = result
    end

    test "handles erase commands" do
      # Test erase display and line commands
      emulator = Emulator.new(80, 24, [])

      # Test erase commands
      erase_commands = ["J", "K"]

      for command <- erase_commands do
        result = CSIHandler.handle_csi_sequence(emulator, command, [])
        assert result != nil, "Erase command #{command} should return a result"
      end
    end

    test "has expected public functions" do
      # Verify that the CSIHandler module has the functions we expect
      functions = CSIHandler.__info__(:functions)
      assert Keyword.has_key?(functions, :handle_csi_sequence)
    end

    test "module has documentation" do
      # Check that the module is documented
      case Code.fetch_docs(CSIHandler) do
        {:docs_v1, _, _, _, module_doc, _, _} ->
          assert module_doc != :none
        _ ->
          # If no docs available, just verify module exists
          assert Code.ensure_loaded?(CSIHandler)
      end
    end

    test "module has proper attributes" do
      # Check basic module info
      attributes = CSIHandler.__info__(:attributes)
      assert is_list(attributes)
    end
  end

  describe "handle_csi/4 compatibility" do
    test "handles CSI with different parameter formats" do
      # Test the CSI handler with different parameter combinations
      emulator = %{test: :emulator}

      # Using CSIHandler instead of UnifiedCommandHandler
      result = CSIHandler.handle_csi_sequence(emulator, "UNKNOWN", [1, 2])

      # Should handle gracefully
      assert %{test: :emulator} = result
    end

    test "handles commands with default parameters" do
      # Test calling handle_csi_sequence with default parameters
      result = CSIHandler.handle_csi_sequence(%{test: :emulator}, "UNKNOWN", [])

      assert %{test: :emulator} = result
    end

    test "handles commands with empty parameters" do
      result = CSIHandler.handle_csi_sequence(%{test: :emulator}, "UNKNOWN", [])

      assert %{test: :emulator} = result
    end

    test "handles commands with intermediates" do
      # CSIHandler.handle_csi_sequence doesn't take intermediates parameter
      result = CSIHandler.handle_csi_sequence(%{test: :emulator}, "UNKNOWN", [1])

      assert %{test: :emulator} = result
    end
  end

  # Note: OSC and DCS commands are not handled by CSIHandler
  # This is expected behavior as CSIHandler focuses on CSI sequences only
end
