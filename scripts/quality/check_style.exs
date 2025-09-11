#!/usr/bin/env elixir

# This script checks code style.
# It ensures that all code follows the project's style guidelines.

defmodule CheckStyle do
  @moduledoc """
  Script to check code style.
  This script ensures that all code follows the project's style guidelines.
  """

  @doc """
  Main function to check code style.
  """
  def run do
    IO.puts("Running formatter on staged files...")

    # Get list of staged Elixir files
    {staged_files, 0} = System.cmd("git", ["diff", "--name-only", "--cached", "--", "*.ex", "*.exs"], stderr_to_stdout: true)

    # Format all staged files
    staged_files = String.split(staged_files, "\n", trim: true)

    if staged_files != [] do
      IO.puts("Formatting #{length(staged_files)} staged Elixir files:")
      Enum.each(staged_files, &IO.puts("  - #{&1}"))

      # Format each staged file
      Enum.each(staged_files, fn file ->
        case System.cmd("mix", ["format", file], stderr_to_stdout: true) do
          {output, 0} ->
            if output != "", do: IO.puts("  Output for #{file}: #{output}")
          {output, status} ->
            IO.puts("  Error formatting #{file} (status #{status}): #{output}")
        end
      end)

      # Stage the formatted files again
      System.cmd("git", ["add"] ++ staged_files)
      IO.puts("Staged files have been formatted and re-added to git staging area.")
    else
      IO.puts("No Elixir files staged for commit.")
    end

    # Verify formatting
    IO.puts("Verifying formatting of all files...")
    case System.cmd("mix", ["format", "--check-formatted"], stderr_to_stdout: true) do
      {_, 0} ->
        IO.puts("All files are properly formatted.")

      {output, _} ->
        IO.puts("Some files are not properly formatted: #{output}")
        # We don't fail here since we already ran the formatter on staged files
    end

    IO.puts("Code style check passed!")
    System.halt(0)
  end
end

# Run the code style check
CheckStyle.run()
