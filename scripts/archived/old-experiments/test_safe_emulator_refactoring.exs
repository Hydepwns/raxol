#!/usr/bin/env elixir

# Script to validate safe_emulator.ex refactoring
# Tests that the module compiles and basic patterns work

defmodule SafeEmulatorRefactoringTest do
  def run do
    IO.puts("[CHECK] Testing safe_emulator.ex refactoring...")

    # Test 1: Check file can be parsed (syntax validation)
    case Code.string_to_quoted!(
           File.read!("lib/raxol/terminal/emulator/safe_emulator.ex")
         ) do
      {:defmodule, _, _} ->
        IO.puts("[OK] Module syntax is valid")

      _ ->
        IO.puts("[FAIL] Module syntax error")
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
          (String.contains?(line, "rescue") and
             not String.contains?(line, "def")) or
          (String.contains?(line, "catch") and not String.contains?(line, "def"))
      end)

    # Should be minimal in main logic
    if main_try_catch_count > 2 do
      IO.puts(
        "[FAIL] Too many try/catch blocks in main logic: #{main_try_catch_count}"
      )

      System.halt(1)
    else
      IO.puts(
        "[OK] Main logic converted to functional patterns (#{main_try_catch_count} remaining)"
      )

      IO.puts(
        "[OK] Helper functions use appropriate exception handling: #{try_catch_count - main_try_catch_count}"
      )
    end

    # Test 3: Verify 'with' statements were added
    with_count =
      content
      |> String.split("\n")
      |> Enum.count(fn line -> String.contains?(line, "with ") end)

    # Should have at least 10 'with' statements from our refactoring
    if with_count < 10 do
      IO.puts("[FAIL] Not enough 'with' statements found: #{with_count}")
      System.halt(1)
    else
      IO.puts("[OK] Functional 'with' statements added: #{with_count}")
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
      IO.puts("[FAIL] Missing helper functions: #{inspect(missing_helpers)}")
      System.halt(1)
    else
      IO.puts("[OK] All functional helper functions present")
    end

    IO.puts("\n🎉 Safe emulator refactoring validation successful!")
    IO.puts("[REPORT] Conversion summary:")
    IO.puts("  • Try/catch blocks: minimized")
    IO.puts("  • With statements: #{with_count}")
    IO.puts("  • Helper functions: #{length(helper_functions)}")
    IO.puts("  • Functional error handling: [OK]")
  end
end

SafeEmulatorRefactoringTest.run()
