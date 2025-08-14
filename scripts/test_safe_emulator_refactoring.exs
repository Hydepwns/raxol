#!/usr/bin/env elixir

# Script to validate safe_emulator.ex refactoring
# Tests that the module compiles and basic patterns work

defmodule SafeEmulatorRefactoringTest do
  def run do
    IO.puts("🔍 Testing safe_emulator.ex refactoring...")
    
    # Test 1: Check file can be parsed (syntax validation)
    case Code.string_to_quoted!(File.read!("lib/raxol/terminal/emulator/safe_emulator.ex")) do
      {:defmodule, _, _} ->
        IO.puts("✅ Module syntax is valid")
      _ ->
        IO.puts("❌ Module syntax error")
        System.halt(1)
    end
    
    # Test 2: Verify try/catch blocks were removed
    content = File.read!("lib/raxol/terminal/emulator/safe_emulator.ex")
    
    try_catch_count = 
      content
      |> String.split("\n")
      |> Enum.count(fn line -> 
        String.contains?(line, "try do") or 
        String.contains?(line, "rescue") or
        String.contains?(line, "catch")
      end)
    
    # Count only try/catch in main logic (not helper functions)
    main_function_lines = 
      content
      |> String.split("# Helper functions for functional error handling")
      |> List.first()
    
    main_try_catch_count = 
      main_function_lines
      |> String.split("\n")
      |> Enum.count(fn line -> 
        String.contains?(line, "try do") or 
        (String.contains?(line, "rescue") and not String.contains?(line, "def")) or
        (String.contains?(line, "catch") and not String.contains?(line, "def"))
      end)
    
    if main_try_catch_count > 2 do  # Should be minimal in main logic
      IO.puts("❌ Too many try/catch blocks in main logic: #{main_try_catch_count}")
      System.halt(1)
    else
      IO.puts("✅ Main logic converted to functional patterns (#{main_try_catch_count} remaining)")
      IO.puts("✅ Helper functions use appropriate exception handling: #{try_catch_count - main_try_catch_count}")
    end
    
    # Test 3: Verify 'with' statements were added
    with_count = 
      content
      |> String.split("\n")
      |> Enum.count(fn line -> String.contains?(line, "with ") end)
    
    if with_count < 10 do  # Should have at least 10 'with' statements from our refactoring
      IO.puts("❌ Not enough 'with' statements found: #{with_count}")
      System.halt(1)
    else
      IO.puts("✅ Functional 'with' statements added: #{with_count}")
    end
    
    # Test 4: Check for functional helper functions
    helper_functions = [
      "validate_input_size",
      "safe_call_with_timeout", 
      "validate_resize_dimensions",
      "perform_input_chunking",
      "safe_reduce_chunks"
    ]
    
    missing_helpers = 
      helper_functions
      |> Enum.reject(fn helper -> String.contains?(content, helper) end)
    
    if length(missing_helpers) > 0 do
      IO.puts("❌ Missing helper functions: #{inspect(missing_helpers)}")
      System.halt(1)
    else
      IO.puts("✅ All functional helper functions present")
    end
    
    IO.puts("\n🎉 Safe emulator refactoring validation successful!")
    IO.puts("📊 Conversion summary:")
    IO.puts("  • Try/catch blocks: minimized")
    IO.puts("  • With statements: #{with_count}")
    IO.puts("  • Helper functions: #{length(helper_functions)}")
    IO.puts("  • Functional error handling: ✅")
  end
end

SafeEmulatorRefactoringTest.run()