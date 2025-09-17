#!/usr/bin/env elixir

# Script to automatically convert Enum.map |> Enum.join to Enum.map_join

defmodule MapJoinFixer do
  def run(file_path) do
    content = File.read!(file_path)

    # Pattern 1: Multi-line with |> on new line
    fixed_content = Regex.replace(
      ~r/([\s]*)(.*?)Enum\.map\((.*?)\)\s*\n\s*\|>\s*Enum\.join\((.*?)\)/ms,
      content,
      fn full_match, indent, prefix, map_args, join_args ->
        "#{indent}#{prefix}Enum.map_join(#{map_args}, #{join_args})"
      end
    )

    # Pattern 2: Single line
    fixed_content = Regex.replace(
      ~r/(.*?)Enum\.map\((.*?)\)\s*\|>\s*Enum\.join\((.*?)\)/,
      fixed_content,
      fn full_match, prefix, map_args, join_args ->
        "#{prefix}Enum.map_join(#{map_args}, #{join_args})"
      end
    )

    # Pattern 3: With piping into Enum.map
    fixed_content = Regex.replace(
      ~r/(\|>\s*)Enum\.map\((.*?)\)\s*\n\s*\|>\s*Enum\.join\((.*?)\)/ms,
      fixed_content,
      fn full_match, pipe_prefix, map_args, join_args ->
        "#{pipe_prefix}Enum.map_join(#{join_args}, #{map_args})"
      end
    )

    # Pattern 4: Simpler multi-line detection
    fixed_content = Regex.replace(
      ~r/Enum\.map\((fn.*?end)\)\s*\n\s*\|>\s*Enum\.join\((.*?)\)/ms,
      fixed_content,
      fn full_match, map_fn, join_args ->
        "Enum.map_join(#{join_args}, #{map_fn})"
      end
    )

    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts("Fixed: #{file_path}")
      true
    else
      false
    end
  end

  def find_and_fix_all() do
    files = System.cmd("grep", [
      "-r",
      "-l",
      "--include=*.ex",
      "--include=*.exs",
      "Enum.map.*Enum.join",
      "lib/",
      "test/",
      "bench/",
      "examples/",
      "scripts/"
    ]) |> elem(0) |> String.split("\n", trim: true)

    fixed_count = files
    |> Enum.map(&run/1)
    |> Enum.count(& &1)

    IO.puts("\nTotal files fixed: #{fixed_count}")
  end
end

MapJoinFixer.find_and_fix_all()