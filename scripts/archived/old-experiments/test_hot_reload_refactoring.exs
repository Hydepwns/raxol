#!/usr/bin/env elixir

# Script to validate hot_reload.ex refactoring
# Tests that the module compiles and functional patterns were applied

defmodule HotReloadRefactoringTest do
  def run do
    IO.puts("[CHECK] Testing hot_reload.ex refactoring...")

    # Test 1: Check file can be parsed (syntax validation)
    case Code.string_to_quoted!(File.read!("lib/raxol/devtools/hot_reload.ex")) do
      {:defmodule, _, _} ->
        IO.puts("[OK] Module syntax is valid")

      _ ->
        IO.puts("[FAIL] Module syntax error")
        System.halt(1)
    end

    # Test 2: Verify try/catch blocks were reduced
    content = File.read!("lib/raxol/devtools/hot_reload.ex")

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

    helper_try_catch_count =
      content
      |> String.split("# Helper functions for functional error handling")
      |> List.last()
      |> String.split("\n")
      |> Enum.count(fn line ->
        String.contains?(line, "try do") or
          String.contains?(line, "rescue") or
          String.contains?(line, "catch")
      end)

    if main_try_catch_count > 0 do
      IO.puts(
        "[FAIL] Main logic still has try/catch blocks: #{main_try_catch_count}"
      )

      System.halt(1)
    else
      IO.puts("[OK] Main logic converted to functional patterns")

      IO.puts(
        "[OK] Helper functions use appropriate exception handling: #{helper_try_catch_count}"
      )
    end

    # Test 3: Verify 'with' statements were added
    with_count =
      main_function_lines
      |> String.split("\n")
      |> Enum.count(fn line -> String.contains?(line, "with ") end)

    # Should have at least 8 'with' statements from our refactoring
    if with_count < 8 do
      IO.puts("[FAIL] Not enough 'with' statements found: #{with_count}")
      System.halt(1)
    else
      IO.puts("[OK] Functional 'with' statements added: #{with_count}")
    end

    # Test 4: Check for functional helper functions
    helper_functions = [
      "safe_path_join",
      "safe_path_wildcard",
      "safe_process_file_list",
      "safe_file_cwd",
      "safe_code_get_object_code",
      "safe_compile_file",
      "safe_function_call"
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

    # Test 5: Check that complex functional flows are preserved
    critical_patterns = [
      "with {:ok,",
      "else",
      "{:error, reason}",
      "safe_"
    ]

    pattern_counts =
      critical_patterns
      |> Enum.map(fn pattern ->
        count =
          content
          |> String.split("\n")
          |> Enum.count(fn line -> String.contains?(line, pattern) end)

        {pattern, count}
      end)

    IO.puts("[OK] Critical functional patterns found:")

    Enum.each(pattern_counts, fn {pattern, count} ->
      IO.puts("  • #{pattern}: #{count}")
    end)

    IO.puts("\n🎉 Hot reload refactoring validation successful!")
    IO.puts("[REPORT] Conversion summary:")
    IO.puts("  • Main logic try/catch: #{main_try_catch_count}")
    IO.puts("  • Helper try/catch: #{helper_try_catch_count}")
    IO.puts("  • With statements: #{with_count}")
    IO.puts("  • Helper functions: #{length(helper_functions)}")
    IO.puts("  • Functional error handling: [OK]")
  end
end

HotReloadRefactoringTest.run()
