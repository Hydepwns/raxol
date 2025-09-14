# Render Pipeline Performance Profiling
Logger.configure(level: :error)

alias Raxol.UI.Rendering.Pipeline
alias Raxol.UI.Rendering.Renderer
alias Raxol.Terminal.Emulator
alias Raxol.Terminal.TerminalParser

# Start supervision tree components needed for rendering
{:ok, _} = Raxol.Core.Runtime.Supervisor.start_link([])

IO.puts("Render Pipeline Performance Profiling")
IO.puts("=" <> String.duplicate("=", 50))

# Create test UI trees of different complexities
simple_tree = %{
  type: :view,
  children: [
    %{type: :label, attrs: %{text: "Hello World"}}
  ]
}

medium_tree = %{
  type: :view,
  children: 
    for i <- 1..10 do
      %{type: :label, attrs: %{text: "Item #{i}"}}
    end
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
    Pipeline.diff_trees(simple_tree, simple_tree)
  end)
end)
IO.puts("  No change (1k iterations): #{Float.round(time_no_change/1_000, 2)} μs/op")

# Simple change diff  
modified_simple = %{simple_tree | children: [%{type: :label, attrs: %{text: "Hello Universe"}}]}
{time_simple_change, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    Pipeline.diff_trees(simple_tree, modified_simple)
  end)
end)
IO.puts("  Simple change (1k iterations): #{Float.round(time_simple_change/1_000, 2)} μs/op")

# Complex tree diff
modified_complex = put_in(complex_tree, [:children, Access.at(0), :children, Access.at(0), :attrs, :text], "Modified")
{time_complex_diff, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Pipeline.diff_trees(complex_tree, modified_complex)
  end)
end)
IO.puts("  Complex diff (100 iterations): #{Float.round(time_complex_diff/100, 2)} μs/op")

# Test 2: Pipeline update performance 
IO.puts("\n2. Pipeline Update Performance:")

{time_pipeline_simple, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    Pipeline.update_tree(simple_tree)
  end)
end)
IO.puts("  Simple tree update (1k iterations): #{Float.round(time_pipeline_simple/1_000, 2)} μs/op")

{time_pipeline_complex, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Pipeline.update_tree(complex_tree)
  end)
end)
IO.puts("  Complex tree update (100 iterations): #{Float.round(time_pipeline_complex/100, 2)} μs/op")

# Test 3: Terminal parsing performance (for comparison)
IO.puts("\n3. Terminal Parser Performance (baseline):")

emulator = Emulator.new(80, 24)
plain_text = "Hello World"
{time_parser, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    TerminalParser.parse(emulator, plain_text)
  end)
end)
IO.puts("  Plain text parsing (10k iterations): #{Float.round(time_parser/10_000, 2)} μs/op")

# Test 4: Memory allocation patterns
IO.puts("\n4. Memory Allocation Patterns:")

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

# Test 5: Structural operations
IO.puts("\n5. Structural Operations:")

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

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Performance Analysis Complete")