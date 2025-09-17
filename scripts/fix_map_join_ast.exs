#!/usr/bin/env elixir

defmodule MapJoinFixer do
  def fix_file(path) do
    case File.read(path) do
      {:ok, content} ->
        lines = String.split(content, "\n")
        fixed_lines = fix_lines(lines, [])

        fixed_content = Enum.join(fixed_lines, "\n")

        if fixed_content != content do
          File.write!(path, fixed_content)
          IO.puts("Fixed: #{path}")
          true
        else
          false
        end

      {:error, _} ->
        false
    end
  end

  defp fix_lines([], acc), do: Enum.reverse(acc)

  defp fix_lines([line | rest], acc) do
    cond do
      # Pattern: |> Enum.map(fn -> ...) |> Enum.join(sep)
      String.contains?(line, "|> Enum.map(fn") and
      length(rest) > 0 and
      check_for_join_ahead(rest) ->
        {fixed_lines, remaining} = fix_multiline_map_join(line, rest)
        fix_lines(remaining, Enum.reverse(fixed_lines) ++ acc)

      # Pattern: Enum.map(...) |> Enum.join on next line
      String.contains?(line, "Enum.map(") and
      not String.contains?(line, "Enum.map_join") and
      length(rest) > 0 and
      check_next_line_join(rest) ->
        {fixed_lines, remaining} = fix_enum_map_with_join(line, rest)
        fix_lines(remaining, Enum.reverse(fixed_lines) ++ acc)

      true ->
        fix_lines(rest, [line | acc])
    end
  end

  defp check_for_join_ahead(lines) do
    # Look ahead up to 10 lines for |> Enum.join
    lines
    |> Enum.take(10)
    |> Enum.any?(&String.contains?(&1, "|> Enum.join"))
  end

  defp check_next_line_join([next | _]) do
    String.match?(next, ~r/^\s*\|>\s*Enum\.join/)
  end
  defp check_next_line_join(_), do: false

  defp fix_multiline_map_join(first_line, rest) do
    # Collect lines until we find |> Enum.join
    {map_lines, after_map} = collect_until_join([first_line | rest], [])

    case after_map do
      [join_line | remaining] when String.contains?(join_line, "|> Enum.join") ->
        # Extract the join argument
        join_arg = extract_join_arg(join_line)

        # Rewrite the first line to use map_join
        fixed_first = String.replace(first_line, "|> Enum.map(fn", "|> Enum.map_join(#{join_arg}, fn")
        fixed_first = String.replace(fixed_first, "Enum.map(fn", "Enum.map_join(#{join_arg}, fn")

        # Remove the join line
        fixed_lines = [fixed_first | Enum.drop(map_lines, 1)]
        {fixed_lines, remaining}

      _ ->
        # Couldn't find matching join, return as-is
        {[first_line], rest}
    end
  end

  defp fix_enum_map_with_join(map_line, [join_line | rest]) do
    if String.match?(join_line, ~r/^\s*\|>\s*Enum\.join/) do
      # Extract join argument
      join_arg = extract_join_arg(join_line)

      # Replace Enum.map with Enum.map_join
      fixed_line = map_line
      |> String.replace(~r/Enum\.map\(/, "Enum.map_join(#{join_arg}, ")

      {[fixed_line], rest}
    else
      {[map_line], [join_line | rest]}
    end
  end

  defp collect_until_join([], acc), do: {Enum.reverse(acc), []}
  defp collect_until_join([line | rest] = all, acc) do
    if String.contains?(line, "|> Enum.join") do
      {Enum.reverse(acc), all}
    else
      collect_until_join(rest, [line | acc])
    end
  end

  defp extract_join_arg(join_line) do
    case Regex.run(~r/Enum\.join\((.*?)\)/, join_line) do
      [_, arg] -> arg
      _ -> "\"\""
    end
  end

  def run() do
    paths = [
      "lib/",
      "test/",
      "bench/",
      "examples/"
    ]

    files = paths
    |> Enum.flat_map(fn path ->
      Path.wildcard("#{path}**/*.{ex,exs}")
    end)
    |> Enum.filter(fn file ->
      content = File.read!(file)
      String.contains?(content, "Enum.map") and String.contains?(content, "Enum.join")
    end)

    IO.puts("Found #{length(files)} files to check...")

    fixed_count = files
    |> Enum.map(&fix_file/1)
    |> Enum.count(& &1)

    IO.puts("\nTotal files fixed: #{fixed_count}")
  end
end

MapJoinFixer.run()