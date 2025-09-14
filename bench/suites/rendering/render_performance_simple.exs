# Simple Render Performance Profiling (No GenServers)
Logger.configure(level: :error)

alias Raxol.UI.Rendering.TreeDiffer
alias Raxol.Terminal.Emulator
alias Raxol.Terminal.TerminalParser

IO.puts("Simple Render Performance Profiling")
IO.puts("=" <> String.duplicate("=", 50))

# Create test UI trees of different complexities
simple_tree = %{
  type: :view,
  children: [
    %{type: :label, attrs: %{text: "Hello World"}}
  ]
}

complex_tree = %{
  type: :view,
  children: [
    %{
      type: :view,
      children: 
        for i <- 1..50 do
          %{type: :label, attrs: %{text: "Row #{i} - Column A"}}
        end
    },
    %{
      type: :view,
      children:
        for i <- 1..50 do
          %{type: :label, attrs: %{text: "Row #{i} - Column B"}}
        end
    }
  ]
}

# Test 1: Tree diffing performance
IO.puts("\n1. Tree Diffing Performance:")

# No change diff
{time_no_change, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    TreeDiffer.diff_trees(simple_tree, simple_tree)
  end)
end)
IO.puts("  No change (1k iterations): #{Float.round(time_no_change/1_000, 2)} μs/op")

# Simple change diff  
modified_simple = %{simple_tree | children: [%{type: :label, attrs: %{text: "Hello Universe"}}]}
{time_simple_change, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    TreeDiffer.diff_trees(simple_tree, modified_simple)
  end)
end)
IO.puts("  Simple change (1k iterations): #{Float.round(time_simple_change/1_000, 2)} μs/op")

# Complex tree diff
modified_complex = put_in(complex_tree, [:children, Access.at(0), :children, Access.at(0), :attrs, :text], "Modified")
{time_complex_diff, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    TreeDiffer.diff_trees(complex_tree, modified_complex)
  end)
end)
IO.puts("  Complex diff (100 iterations): #{Float.round(time_complex_diff/100, 2)} μs/op")

# Test 2: Terminal parsing performance (baseline comparison)
IO.puts("\n2. Terminal Parser Performance (baseline):")

emulator = Emulator.new(80, 24)
plain_text = "Hello World"
{time_parser, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    TerminalParser.parse(emulator, plain_text)
  end)
end)
IO.puts("  Plain text parsing (10k iterations): #{Float.round(time_parser/10_000, 2)} μs/op")

# Test 3: Memory allocation patterns
IO.puts("\n3. Memory Allocation Patterns:")

{time_tree_creation, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    %{
      type: :view,
      children: [
        %{type: :label, attrs: %{text: "Dynamic #{:rand.uniform(1000)}"}}
      ]
    }
  end)
end)
IO.puts("  Tree creation (1k iterations): #{Float.round(time_tree_creation/1_000, 2)} μs/op")

# Test 4: Structural operations (potential bottlenecks)
IO.puts("\n4. Structural Operations:")

test_list = Enum.map(1..100, fn i -> "item_#{i}" end)
{time_list_update, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    List.update_at(test_list, 50, fn _ -> "updated" end)
  end)
end)
IO.puts("  List.update_at middle (1k iterations): #{Float.round(time_list_update/1_000, 2)} μs/op")

{time_enum_map, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    Enum.map(1..50, fn i -> "item_#{i}" end)
  end)
end)
IO.puts("  Enum.map 50 items (1k iterations): #{Float.round(time_enum_map/1_000, 2)} μs/op")

# Test 5: Pattern matching performance
IO.puts("\n5. Pattern Matching Performance:")

{time_match_simple, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    case simple_tree do
      %{type: :view, children: [%{type: :label}]} -> :matched
      _ -> :not_matched
    end
  end)
end)
IO.puts("  Simple pattern match (10k iterations): #{Float.round(time_match_simple/10_000, 2)} μs/op")

# Test 6: Deep tree traversal
IO.puts("\n6. Tree Traversal Performance:")

defmodule TreeTraversal do
  def count_nodes(%{children: children}) when is_list(children) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end
  
  def count_nodes(_node), do: 1
end

{time_traversal, node_count} = :timer.tc(fn ->
  Enum.map(1..100, fn _ ->
    TreeTraversal.count_nodes(complex_tree)
  end) |> hd()
end)
IO.puts("  Tree traversal (#{node_count} nodes, 100 iterations): #{Float.round(time_traversal/100, 2)} μs/op")

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Performance Analysis Complete")
IO.puts("Total nodes in complex tree: #{TreeTraversal.count_nodes(complex_tree)}")

# Calculate performance targets based on TODO.md goals
current_parser_perf = time_parser/10_000  # μs/op
target_render_time = 1000.0  # 1ms target from TODO.md

IO.puts("\nPerformance Targets Analysis:")
IO.puts("  Current parser: #{Float.round(current_parser_perf, 2)} μs/op (target: <3 μs/op)")
IO.puts("  Target render: <#{target_render_time} μs (1ms)")
IO.puts("  Current simple diff: #{Float.round(time_simple_change/1_000, 2)} μs/op")
IO.puts("  Current complex diff: #{Float.round(time_complex_diff/100, 2)} μs/op")