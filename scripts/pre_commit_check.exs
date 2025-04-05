#!/usr/bin/env elixir

# This script runs all pre-commit checks for the Raxol project.
# It ensures that all checks pass before allowing a commit.

defmodule PreCommitCheck do
  @moduledoc """
  Pre-commit check script for the Raxol project.
  This script runs all pre-commit checks and ensures they pass.
  """

  @doc """
  Main function to run all pre-commit checks.
  """
  def run do
    IO.puts("Running pre-commit checks for Raxol project...")
    
    # Run all checks
    check_type_safety()
    check_documentation_consistency()
    check_code_style()
    check_broken_links()
    check_test_coverage()
    check_performance()
    check_accessibility()
    check_e2e()
    
    IO.puts("All pre-commit checks passed!")
    System.halt(0)
  end
  
  @doc """
  Check type safety.
  """
  def check_type_safety do
    IO.puts("Checking type safety...")
    
    # Run the check_type_safety.exs script
    System.cmd("mix", ["run", "scripts/check_type_safety.exs"])
  end
  
  @doc """
  Check documentation consistency.
  """
  def check_documentation_consistency do
    IO.puts("Checking documentation consistency...")
    
    # Run the check_documentation.exs script
    System.cmd("mix", ["run", "scripts/check_documentation.exs"])
  end
  
  @doc """
  Check code style.
  """
  def check_code_style do
    IO.puts("Checking code style...")
    
    # Run the check_style.exs script
    System.cmd("mix", ["run", "scripts/check_style.exs"])
  end
  
  @doc """
  Check for broken links in documentation.
  """
  def check_broken_links do
    IO.puts("Checking for broken links in documentation...")
    
    # Run the check_links.exs script
    System.cmd("mix", ["run", "scripts/check_links.exs"])
  end
  
  @doc """
  Check test coverage.
  """
  def check_test_coverage do
    IO.puts("Checking test coverage...")
    
    # Run the check_coverage.exs script
    System.cmd("mix", ["run", "scripts/check_coverage.exs"])
  end
  
  @doc """
  Check performance.
  """
  def check_performance do
    IO.puts("Checking performance...")
    
    # Run the performance validation script
    System.cmd("mix", ["run", "scripts/validate_performance.exs"])
  end
  
  @doc """
  Check accessibility.
  """
  def check_accessibility do
    IO.puts("Checking accessibility...")
    
    # Run the accessibility validation script
    System.cmd("mix", ["run", "scripts/validate_accessibility.exs"])
  end
  
  @doc """
  Check end-to-end tests.
  """
  def check_e2e do
    IO.puts("Checking end-to-end tests...")
    
    # Run the end-to-end validation script
    System.cmd("mix", ["run", "scripts/validate_e2e.exs"])
  end
end

# Run the pre-commit checks
PreCommitCheck.run() 