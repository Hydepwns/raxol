# Code Review Guidelines for AI Assistants

## Review Approach

When reviewing code in the Raxol codebase, follow this systematic approach:

### 1. Initial Assessment
- Understand the purpose and context of the changes
- Check if the code aligns with existing patterns
- Verify test coverage for new functionality
- Assess performance implications

### 2. Detailed Review Process

#### Code Quality Checklist
```markdown
- [ ] Follows Elixir conventions and idioms
- [ ] Uses pattern matching effectively
- [ ] Proper error handling with tagged tuples
- [ ] Functions are small and focused
- [ ] Module structure is logical
- [ ] No code duplication
- [ ] Clear variable and function names
```

#### Architecture Checklist
```markdown
- [ ] Follows supervision tree patterns
- [ ] Proper process isolation
- [ ] No bottlenecks introduced
- [ ] Scales with concurrent usage
- [ ] Maintains fault tolerance
```

#### Testing Checklist
```markdown
- [ ] Unit tests for new functions
- [ ] Integration tests for interactions
- [ ] Property tests where applicable
- [ ] Test coverage above 98%
- [ ] Tests are deterministic
- [ ] Mock external dependencies
```

## Common Issues to Check

### 1. GenServer Anti-patterns
```elixir
# ❌ Bad: Blocking in init
def init(opts) do
  data = fetch_initial_data()  # Blocks supervisor
  {:ok, data}
end

# ✅ Good: Use continue for async init
def init(opts) do
  {:ok, opts, {:continue, :load_data}}
end

def handle_continue(:load_data, opts) do
  data = fetch_initial_data()
  {:noreply, data}
end
```

### 2. Error Handling
```elixir
# ❌ Bad: Swallowing errors
def process(data) do
  try do
    do_process(data)
  rescue
    _ -> nil
  end
end

# ✅ Good: Proper error propagation
def process(data) do
  case do_process(data) do
    {:ok, result} -> {:ok, result}
    {:error, reason} = error -> 
      Logger.error("Processing failed: #{inspect(reason)}")
      error
  end
end
```

### 3. Memory Leaks
```elixir
# ❌ Bad: Unbounded growth
def handle_cast({:add, item}, state) do
  {:noreply, [item | state]}  # List grows forever
end

# ✅ Good: Bounded collections
def handle_cast({:add, item}, state) do
  new_items = [item | state.items] |> Enum.take(1000)
  {:noreply, %{state | items: new_items}}
end
```

### 4. Process Communication
```elixir
# ❌ Bad: Synchronous calls in loops
for item <- items do
  GenServer.call(server, {:process, item})
end

# ✅ Good: Batch operations or async processing
GenServer.call(server, {:process_batch, items})
# Or use Task.async_stream for parallel processing
```

## Review Comment Templates

### Suggesting Improvements
```markdown
**Suggestion**: Consider using pattern matching here to simplify the logic:

\```elixir
# Current
def handle(data) do
  if data.type == :foo do
    process_foo(data)
  else
    process_other(data)
  end
end

# Suggested
def handle(%{type: :foo} = data), do: process_foo(data)
def handle(data), do: process_other(data)
\```

This makes the code more idiomatic and easier to extend.
```

### Performance Concerns
```markdown
**Performance**: This operation has O(n²) complexity. Consider using a more efficient approach:

\```elixir
# Current: O(n²)
for x <- list1, y <- list2, x == y, do: {x, y}

# Better: O(n log n)
set = MapSet.new(list1)
for y <- list2, MapSet.member?(set, y), do: {y, y}
\```

This reduces complexity from quadratic to linearithmic.
```

### Security Issues
```markdown
**Security**: Avoid converting user input to atoms as it can exhaust the atom table:

\```elixir
# Vulnerable
String.to_atom(user_input)

# Safe
String.to_existing_atom(user_input)
# Or use strings/maps instead of atoms
\```
```

### Test Coverage
```markdown
**Testing**: This function lacks test coverage. Please add tests covering:
- Happy path with valid input
- Error handling for invalid input
- Edge cases (empty, nil, boundary values)

Example test structure:
\```elixir
describe "function_name/1" do
  test "processes valid input" do
    assert function_name("valid") == {:ok, "result"}
  end
  
  test "handles invalid input" do
    assert function_name(nil) == {:error, :invalid_input}
  end
end
\```
```

## Review Priority Levels

### 🔴 Critical (Must Fix)
- Security vulnerabilities
- Data corruption risks
- Memory leaks
- Race conditions
- Breaking changes without migration

### 🟡 Important (Should Fix)
- Performance issues
- Missing error handling
- Lack of tests
- Code duplication
- Unclear naming

### 🟢 Minor (Consider)
- Style inconsistencies
- Missing documentation
- Optimization opportunities
- Refactoring suggestions

## Automated Checks to Run

Before manual review, ensure these automated checks pass:

```bash
# Format check
mix format --check-formatted

# Compilation with warnings as errors
mix compile --warnings-as-errors

# Static analysis
mix credo --strict

# Type checking
mix dialyzer

# Security audit
mix sobelow

# Test coverage
mix test --cover
```

## Review Workflow

### 1. Pre-Review Checks
```bash
# Fetch latest changes
git fetch origin
git checkout feature-branch

# Run automated checks
mix format --check-formatted && \
mix compile --warnings-as-errors && \
mix test
```

### 2. Code Review
- Review commit by commit for context
- Check against the checklists above
- Verify changes match the PR description
- Test the changes locally

### 3. Testing Changes
```bash
# Run full test suite
mix test

# Run specific tests for changed modules
mix test test/path/to/changed_module_test.exs

# Check performance if relevant
mix run bench/relevant_benchmark.exs
```

### 4. Feedback Structure
```markdown
## Review Summary

### ✅ Positive
- Clean implementation of [feature]
- Good test coverage
- Follows existing patterns

### 🔧 Required Changes
1. Fix memory leak in BufferManager (see inline comment)
2. Add error handling for network failures

### 💡 Suggestions
- Consider extracting common logic to a helper module
- Could optimize the sorting algorithm for large datasets

### Questions
- What's the expected behavior when [edge case]?
- Have you considered using [alternative approach]?
```

## Special Considerations for Raxol

### Terminal Emulation Code
- Verify ANSI sequence handling
- Check buffer boundary conditions
- Ensure cursor position validation
- Test with various terminal sizes

### Component System
- Verify lifecycle methods
- Check event propagation
- Validate prop types
- Test re-rendering behavior

### Plugin System
- Ensure proper isolation
- Verify dependency resolution
- Check hot-reload compatibility
- Test error recovery

### Performance Critical Paths
- Buffer operations
- ANSI parsing
- Rendering pipeline
- Event dispatch

## Review Metrics

Track these metrics to improve code quality:
- Defect density (bugs per line of code)
- Review coverage (% of code reviewed)
- Time to review
- Review effectiveness (bugs caught in review vs production)

## Continuous Improvement

After each review:
1. Update patterns documentation with new findings
2. Add new anti-patterns discovered
3. Create automated checks for repeated issues
4. Share learnings with the team