# Bug Analysis and Investigation Prompts

## Initial Bug Triage

When encountering a bug report, start with these questions:

### 1. Understand the Problem
```markdown
- What is the expected behavior?
- What is the actual behavior?
- When did this start happening?
- How frequently does it occur?
- What is the impact/severity?
```

### 2. Reproduction Steps
```markdown
1. Environment setup required
2. Exact steps to reproduce
3. Success rate of reproduction
4. Minimal reproduction case
5. Any workarounds discovered
```

## Investigation Workflow

### Step 1: Gather Information
```bash
# Check recent commits that might be related
git log --oneline -20 lib/raxol/affected/module.ex

# Search for related error messages
grep -r "error message" lib/ test/

# Find similar issues in tests
mix test --only related_module

# Check for recent changes
git diff HEAD~5 lib/raxol/affected/
```

### Step 2: Locate the Problem
```elixir
# Add debug logging
require Logger

def problematic_function(args) do
  Logger.debug("Input: #{inspect(args)}")
  
  result = process(args)
  Logger.debug("Result: #{inspect(result)}")
  
  result
end

# Or use IEx.pry for interactive debugging
def problematic_function(args) do
  require IEx
  IEx.pry()  # Execution stops here
  process(args)
end
```

### Step 3: Isolate the Issue
```elixir
# Create minimal test case
defmodule BugTest do
  use ExUnit.Case
  
  test "reproduces the bug" do
    # Minimal setup
    state = create_minimal_state()
    
    # Action that triggers bug
    result = Module.function_that_fails(state, trigger_input)
    
    # This should fail, demonstrating the bug
    assert result == expected_value
  end
end
```

## Common Bug Categories in Raxol

### 1. Terminal Emulation Bugs

#### Symptoms
- Incorrect cursor position
- Corrupted display
- Missing characters
- Wrong colors/attributes

#### Investigation
```elixir
# Enable ANSI sequence logging
defmodule Debug.ANSILogger do
  def log_sequences(input) do
    input
    |> String.split(~r/(\e\[[^m]*m)/, include_captures: true)
    |> Enum.map(&inspect/1)
    |> Enum.join("\n")
    |> IO.puts()
  end
end

# Check buffer state
buffer = Terminal.get_buffer(pid)
IO.inspect(buffer, limit: :infinity)

# Verify cursor position
{row, col} = Terminal.get_cursor(pid)
assert row >= 0 and row < height
assert col >= 0 and col < width
```

### 2. Concurrency Bugs

#### Symptoms
- Race conditions
- Deadlocks
- Inconsistent state
- Process crashes

#### Investigation
```elixir
# Check process state
:sys.get_state(process_name)

# Monitor process messages
:sys.trace(process_name, true)

# Check for message queue buildup
Process.info(pid, :message_queue_len)

# Analyze supervision tree
Supervisor.which_children(MySupervisor)
|> Enum.map(fn {id, pid, type, modules} ->
  {id, Process.alive?(pid), Process.info(pid, :message_queue_len)}
end)
```

### 3. Memory Leaks

#### Symptoms
- Growing memory usage
- Slow performance over time
- OOM crashes

#### Investigation
```elixir
# Check process memory
processes = for pid <- Process.list() do
  case Process.info(pid, [:memory, :registered_name]) do
    nil -> nil
    info -> {info[:registered_name] || pid, info[:memory]}
  end
end
|> Enum.reject(&is_nil/1)
|> Enum.sort_by(fn {_, mem} -> -mem end)
|> Enum.take(10)

# Check ETS tables
:ets.all()
|> Enum.map(fn table ->
  info = :ets.info(table)
  {info[:name], info[:size], info[:memory]}
end)
|> Enum.sort_by(fn {_, _, mem} -> -mem end)

# Monitor specific process
:erlang.process_flag(:save_calls, 50)
:erlang.process_info(pid, :current_stacktrace)
```

### 4. Performance Bugs

#### Symptoms
- Slow operations
- High CPU usage
- Timeouts
- Unresponsive UI

#### Investigation
```elixir
# Profile function execution
:timer.tc(fn ->
  Module.slow_function(args)
end)
|> elem(0)
|> Kernel./(1_000_000)
|> IO.puts("Execution time: #{&1} seconds")

# Use Benchee for detailed analysis
Benchee.run(%{
  "current" => fn -> current_implementation(data) end,
  "optimized" => fn -> optimized_implementation(data) end
})

# Check for N+1 queries or operations
:fprof.start()
:fprof.trace([:start, {:procs, self()}])
Module.function_to_profile()
:fprof.trace(:stop)
:fprof.profile()
:fprof.analyse(dest: 'profile.txt')
```

## Bug Fix Verification

### 1. Write Regression Test
```elixir
defmodule RegressionTest do
  use ExUnit.Case
  
  @tag :regression
  test "bug #123 - cursor position after line wrap" do
    # Setup that previously caused the bug
    terminal = create_terminal(width: 10)
    
    # Action that triggered the bug
    Terminal.write(terminal, "1234567890ABC")
    
    # Verify the fix
    assert Terminal.get_cursor(terminal) == {1, 3}
    assert Terminal.get_line(terminal, 0) == "1234567890"
    assert Terminal.get_line(terminal, 1) == "ABC"
  end
end
```

### 2. Verify No Side Effects
```bash
# Run full test suite
mix test

# Run specific subsystem tests
mix test test/raxol/terminal/

# Check performance impact
mix run bench/relevant_benchmark.exs

# Verify no memory leaks
mix test --include memory_intensive
```

### 3. Document the Fix
```elixir
defmodule Module do
  @doc """
  Process input handling cursor wrap correctly.
  
  ## Bug Fix
  
  Fixed in commit abc123: Cursor now properly wraps to next line
  when writing past the right margin. Previously, cursor position
  could become negative or exceed buffer bounds.
  
  See: https://github.com/org/raxol/issues/123
  """
  def fixed_function(input) do
    # Implementation with fix
  end
end
```

## Root Cause Analysis Template

```markdown
## Bug Report: [Title]

### Summary
Brief description of the bug and its impact.

### Root Cause
The bug was caused by [specific technical reason].

### Timeline
- When introduced: [commit/date]
- When discovered: [date]
- When fixed: [commit/date]

### Technical Details
```elixir
# Code that caused the bug
def buggy_function(input) do
  # Problem: didn't handle edge case
  process(input)
end

# Fixed version
def fixed_function(input) do
  # Solution: handle edge case
  if edge_case?(input) do
    handle_edge_case(input)
  else
    process(input)
  end
end
```

### Testing
- Regression test added: `test/module_test.exs:123`
- Coverage before: X%
- Coverage after: Y%

### Prevention
To prevent similar bugs:
1. Add validation for [condition]
2. Improve test coverage for [area]
3. Add static analysis rule for [pattern]

### Lessons Learned
- [Key takeaway 1]
- [Key takeaway 2]
```

## Debugging Tools and Techniques

### Interactive Debugging
```elixir
# Start IEx session with project
iex -S mix

# Recompile and reload module
r Module.Name

# Start observer for visual debugging
:observer.start()

# Trace function calls
:dbg.tracer()
:dbg.p(:all, :c)
:dbg.tpl(Module, :function, [])
```

### Memory Debugging
```elixir
# Get memory snapshot
:erlang.memory()

# Check binary memory (common leak source)
:erlang.memory(:binary)

# Find large binaries
:recon.bin_leak(10)
```

### Process Debugging
```elixir
# Get process info
Process.info(pid)

# Check registered processes
Process.registered()
|> Enum.map(&{&1, Process.whereis(&1)})
|> Enum.map(fn {name, pid} -> 
  {name, Process.info(pid, :message_queue_len)}
end)
```

## Bug Report Template

```markdown
## Bug Description
Clear, concise description of the bug.

## Environment
- Raxol version: 
- Elixir version: 
- Erlang/OTP version: 
- Operating System: 

## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior
What should happen.

## Actual Behavior
What actually happens.

## Error Messages/Logs
```
Paste any relevant error messages or logs
```

## Additional Context
Any other relevant information.

## Possible Solution
If you have ideas on how to fix.
```

## Prevention Strategies

### 1. Add Guards
```elixir
defguard is_valid_position(x, y, width, height) 
  when is_integer(x) and is_integer(y) and 
       x >= 0 and x < width and 
       y >= 0 and y < height
```

### 2. Use Types and Specs
```elixir
@spec process_input(String.t(), pos_integer()) :: 
  {:ok, term()} | {:error, atom()}
```

### 3. Defensive Programming
```elixir
def safe_divide(a, b) when b != 0, do: {:ok, a / b}
def safe_divide(_, 0), do: {:error, :division_by_zero}
```

### 4. Property Testing
```elixir
property "buffer operations maintain invariants" do
  check all ops <- list_of(buffer_operation()) do
    buffer = apply_operations(new_buffer(), ops)
    assert valid_buffer?(buffer)
  end
end
```