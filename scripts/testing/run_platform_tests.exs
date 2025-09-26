#!/usr/bin/env elixir

# Platform Test Runner Script
# This script runs all platform-specific tests and generates a report

defmodule Raxol.PlatformTestRunner do
  @moduledoc """
  Runs platform-specific tests for Raxol to validate cross-platform compatibility.

  This script:
  1. Identifies the current platform
  2. Runs appropriate platform-specific tests
  3. Generates a comprehensive report
  4. Validates minimum compatibility requirements
  """

  alias Raxol.System.Platform

  def run do
    IO.puts("\n=== Raxol Cross-Platform Test Runner ===\n")
    platform = Platform.get_current_platform()
    IO.puts("Running tests for platform: #{platform}")

    # Set up results collection
    results = %{
      platform: platform,
      tests: [],
      start_time: DateTime.utc_now(),
      end_time: nil,
      success: true
    }

    # Run the platform detection tests
    results = run_test(results, "Platform Detection", fn ->
      IO.puts("Testing platform detection...")
      case Mix.shell().cmd("mix test test/platform/platform_detection_test.exs", [quiet: true]) do
        0 -> {:ok, "Platform correctly identified"}
        _ -> {:error, "Failed to detect platform correctly"}
      end
    end)

    # Run terminal compatibility tests
    results = run_test(results, "Terminal Compatibility", fn ->
      IO.puts("Testing terminal compatibility...")
      case Mix.shell().cmd("mix run test/platform/verify_terminal_compatibility.exs", [quiet: false]) do
        0 -> {:ok, "Terminal compatibility verified"}
        _ -> {:error, "Terminal compatibility issues detected"}
      end
    end)

    # Run component rendering tests
    results = run_test(results, "Component Rendering", fn ->
      IO.puts("Testing component rendering...")
      case Mix.shell().cmd("mix test test/platform/component_rendering_test.exs", [quiet: true]) do
        0 -> {:ok, "Components render correctly on this platform"}
        _ -> {:error, "Component rendering issues detected"}
      end
    end)

    # Run platform-specific feature tests
    results = run_platform_specific_tests(results, platform)

    # Complete the results
    results = Map.put(results, :end_time, DateTime.utc_now())

    # Generate and display report
    display_report(results)

    # Write report to file
    write_report_file(results)

    # Exit with appropriate code
    if results.success, do: :ok, else: exit({:shutdown, 1})
  end

  # Run tests specific to each platform
  defp run_platform_specific_tests(results, :windows) do
    # Windows-specific tests
    run_test(results, "Windows Console Support", fn ->
      IO.puts("Testing Windows console support...")
      true = Platform.get_current_platform() == :windows
      case Platform.supports_feature?(:unicode) do
        true -> {:ok, "Unicode support verified"}
        false -> {:warning, "Limited Unicode support - some characters may not display correctly"}
      end
    end)
  end

  defp run_platform_specific_tests(results, :macos) do
    # macOS-specific tests
    run_test(results, "macOS Terminal Support", fn ->
      IO.puts("Testing macOS terminal support...")
      true = Platform.get_current_platform() == :macos

      # Check Apple Silicon optimization if applicable
      platform_info = Platform.get_platform_info()
      if Map.get(platform_info, :apple_silicon, false) do
        {:ok, "Apple Silicon optimizations active"}
      else
        {:ok, "Running on Intel macOS"}
      end
    end)
  end

  defp run_platform_specific_tests(results, :linux) do
    # Linux-specific tests
    run_test(results, "Linux Terminal Support", fn ->
      IO.puts("Testing Linux terminal support...")
      true = Platform.get_current_platform() == :linux

      platform_info = Platform.get_platform_info()

      # Check Wayland vs X11
      wayland_msg = if Map.get(platform_info, :wayland, false),
        do: "Wayland detected",
        else: "X11 detected"

      {:ok, "Linux terminal validated: #{platform_info.distribution}, #{wayland_msg}"}
    end)
  end

  defp run_platform_specific_tests(results, _) do
    # Generic tests for unknown platforms
    run_test(results, "Basic Platform Support", fn ->
      IO.puts("Testing basic support for unknown platform...")
      {:warning, "Unknown platform - running minimal compatibility tests only"}
    end)
  end

  # Helper to run a test and collect results
  defp run_test(results, name, test_fn) do
    IO.puts("\n=== Running: #{name} ===")

    {status, message} = try do
      test_fn.()
    rescue
      e -> {:error, "Exception: #{inspect(e)}"}
    catch
      kind, value -> {:error, "#{kind}: #{inspect(value)}"}
    end

    # Record test result
    test_result = %{
      name: name,
      status: status,
      message: message,
      timestamp: DateTime.utc_now()
    }

    # Update overall success flag
    success = if status == :error, do: false, else: results.success

    # Print result
    case status do
      :ok -> IO.puts("[OK] PASS: #{message}")
      :warning -> IO.puts("[WARN] WARNING: #{message}")
      :error -> IO.puts("[FAIL] FAIL: #{message}")
    end

    # Return updated results
    %{results | tests: [test_result | results.tests], success: success}
  end

  # Display a summary report
  defp display_report(results) do
    duration = DateTime.diff(results.end_time, results.start_time, :second)

    IO.puts("\n\n=== Cross-Platform Test Report ===")
    IO.puts("Platform: #{results.platform}")
    IO.puts("Tests run: #{length(results.tests)}")
    IO.puts("Duration: #{duration} seconds")

    # Count by status
    status_counts = Enum.reduce(results.tests, %{ok: 0, warning: 0, error: 0}, fn test, acc ->
      Map.update(acc, test.status, 1, &(&1 + 1))
    end)

    IO.puts("Results:")
    IO.puts("  [OK] Passed: #{status_counts.ok}")
    IO.puts("  [WARN] Warnings: #{status_counts.warning}")
    IO.puts("  [FAIL] Failed: #{status_counts.error}")

    # Overall status
    if results.success do
      IO.puts("\n[OK] OVERALL: PASS - Platform compatibility verified")
    else
      IO.puts("\n[FAIL] OVERALL: FAIL - Platform compatibility issues detected")

      # List failures
      failures = Enum.filter(results.tests, fn test -> test.status == :error end)
      IO.puts("\nFailures:")
      Enum.each(failures, fn test ->
        IO.puts("  • #{test.name}: #{test.message}")
      end)
    end
  end

  # Write report to file
  defp write_report_file(results) do
    # Ensure test results directory exists
    File.mkdir_p!("_build/test/results")

    # Generate filename
    filename = "_build/test/results/platform_test_#{results.platform}_#{System.os_time(:second)}.log"

    # Format the report
    content = """
    RAXOL CROSS-PLATFORM TEST REPORT
    ================================

    Platform: #{results.platform}
    Start time: #{results.start_time}
    End time: #{results.end_time}
    Duration: #{DateTime.diff(results.end_time, results.start_time, :second)} seconds

    TEST RESULTS:
    ============
    #{Enum.map_join(Enum.reverse(results.tests), "\n", fn test ->
      status_icon = case test.status do
        :ok -> "[OK]"
        :warning -> "!"
        :error -> "[FAIL]"
      end
      "#{status_icon} #{test.name}: #{test.message}"
    end)}

    SUMMARY:
    ========
    #{if results.success, do: "PASS - Platform compatibility verified", else: "FAIL - Platform compatibility issues detected"}
    """

    # Write the file
    File.write!(filename, content)
    IO.puts("\nReport written to: #{filename}")
  end
end

# Run the tests
Raxol.PlatformTestRunner.run()
