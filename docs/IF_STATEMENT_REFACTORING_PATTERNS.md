# If Statement Refactoring Patterns - UPDATED

## Overview

This document outlines patterns for refactoring if statements. **CRITICAL**: The original helper function approach actually INCREASED complexity. This updated guide focuses on patterns that actually reduce if statement count.

## Current Status

**Current**: 3,950 if statements
**Target**: < 500 if statements (87% reduction needed)

## ❌ BAD Patterns (DO NOT USE)

These patterns actually INCREASE complexity and should be avoided:

### BAD: Helper Function Pattern
```elixir
# BEFORE: 1 if statement
def process(x) do
  if x > 0, do: :positive, else: :negative
end

# AFTER: 3 lines of code (worse!)
def process(x) do
  handle_sign(x > 0)
end

defp handle_sign(true), do: :positive
defp handle_sign(false), do: :negative
```
**Problem**: Creates more complexity, not less.

## ✅ GOOD Patterns (Actually Reduce If Statements)

### GOOD: Guards Instead of If in Function Body
```elixir
# BEFORE: 1 if statement
def process(x) do
  if x > 0, do: :positive, else: :negative
end

# AFTER: 0 if statements (better!)
def process(x) when x > 0, do: :positive
def process(x), do: :negative
```

### GOOD: Case/Cond for Multiple Conditions
```elixir
# BEFORE: 3 if statements
def severity(outcome) do
  if outcome == :denied do
    :high
  elsif outcome == :allowed do
    :low
  else
    :medium
  end
end

# AFTER: 0 if statements
def severity(outcome) do
  case outcome do
    :denied -> :high
    :allowed -> :low
    _ -> :medium
  end
end
```

### GOOD: Map/Keyword Lookups
```elixir
# BEFORE: if statements
severity = if outcome == :denied, do: :medium, else: :low

# AFTER: 0 if statements
@severity_map %{denied: :medium, allowed: :low}
severity = Map.get(@severity_map, outcome, :low)
```

### GOOD: With Statement for Pipeline Error Handling
```elixir
# BEFORE: Nested if statements
def process_data(data) do
  if valid?(data) do
    if authorized?(data) do
      if available?(data) do
        transform(data)
      else
        {:error, :unavailable}
      end
    else
      {:error, :unauthorized}
    end
  else
    {:error, :invalid}
  end
end

# AFTER: 0 if statements
def process_data(data) do
  with :ok <- valid?(data),
       :ok <- authorized?(data),
       :ok <- available?(data) do
    transform(data)
  else
    {:error, reason} -> {:error, reason}
  end
end
```

## Refactoring Strategy

### Pattern 1: Boolean Checks → Function Head Pattern Matching

**Before:**
```elixir
def start_drag(state, element_id, position, drag_config) do
  if drag_config.draggable do
    # do something
    {:ok, updated_state}
  else
    {:error, :not_draggable}
  end
end
```

**After:**
```elixir
def start_drag(state, element_id, position, drag_config) do
  do_start_drag(drag_config.draggable, state, element_id, position, drag_config)
end

defp do_start_drag(false, _state, _element_id, _position, _drag_config) do
  {:error, :not_draggable}
end

defp do_start_drag(_draggable, state, element_id, position, drag_config) do
  # do something
  {:ok, updated_state}
end
```

### Pattern 2: If/Else → Case Statement

**Before:**
```elixir
animation_name = if cancelled, do: :drag_cancel_feedback, else: :drag_drop_feedback
```

**After:**
```elixir
animation_name = get_animation_name(cancelled)

defp get_animation_name(true), do: :drag_cancel_feedback
defp get_animation_name(false), do: :drag_drop_feedback
```

### Pattern 3: Nil Checks → Pattern Matching

**Before:**
```elixir
def handle_animation(element) do
  if element do
    Framework.start_animation(:effect, element)
  end
end
```

**After:**
```elixir
def handle_animation(element) do
  start_animation_if_present(element)
end

defp start_animation_if_present(nil), do: :ok
defp start_animation_if_present(element) do
  Framework.start_animation(:effect, element)
end
```

### Pattern 4: State Checks → Guards

**Before:**
```elixir
def process(state) do
  if state.active do
    # process active state
  else
    state
  end
end
```

**After:**
```elixir
def process(%{active: false} = state), do: state
def process(%{active: true} = state) do
  # process active state
end
```

### Pattern 5: Complex Conditions → Multiple Function Heads

**Before:**
```elixir
def apply_constraint(position, start_position, constraints) do
  x = if Map.get(constraints, :horizontal, false) do
    start_position.x
  else
    position.x
  end
  
  y = if Map.get(constraints, :vertical, false) do
    start_position.y
  else
    position.y
  end
  
  %{x: x, y: y}
end
```

**After:**
```elixir
def apply_constraint(position, start_position, constraints) do
  x = get_constrained_x(position, start_position, constraints)
  y = get_constrained_y(position, start_position, constraints)
  %{x: x, y: y}
end

defp get_constrained_x(_position, start_position, %{horizontal: true}), do: start_position.x
defp get_constrained_x(position, _start_position, _constraints), do: position.x

defp get_constrained_y(_position, start_position, %{vertical: true}), do: start_position.y
defp get_constrained_y(position, _start_position, _constraints), do: position.y
```

### Pattern 6: Nested If → Flat Pattern Matching

**Before:**
```elixir
def handle_drop(state) do
  if state.valid_drop_target do
    result = state.valid_drop_target.on_drop.(state.drag_data)
    if state.dragging_element do
      animate_success(state.dragging_element)
    end
    {:ok, result}
  else
    if state.dragging_element do
      animate_failure(state.dragging_element)
    end
    {:error, :invalid_target}
  end
end
```

**After:**
```elixir
def handle_drop(state) do
  perform_drop(state.valid_drop_target, state.dragging_element, state.drag_data)
end

defp perform_drop(nil, dragging_element, _drag_data) do
  animate_if_present(dragging_element, :failure)
  {:error, :invalid_target}
end

defp perform_drop(valid_target, dragging_element, drag_data) do
  result = valid_target.on_drop.(drag_data)
  animate_if_present(dragging_element, :success)
  {:ok, result}
end

defp animate_if_present(nil, _type), do: :ok
defp animate_if_present(element, :success), do: animate_success(element)
defp animate_if_present(element, :failure), do: animate_failure(element)
```

## Benefits

### Code Quality
- **Readability**: Pattern matching makes intent clearer
- **Maintainability**: Each case is isolated in its own function
- **Testability**: Each function head can be tested independently
- **Type Safety**: Pattern matching catches more errors at compile time

### Performance
- **Compile-time Optimization**: Pattern matching is optimized by BEAM
- **Reduced Branching**: Less runtime decision making
- **Better Cache Locality**: Related code is grouped together
- **Tail Call Optimization**: Pattern matched functions can be tail-recursive

## Migration Strategy

### Phase 1: Simple Boolean Checks (Quick Wins)
- `if condition, do: x, else: y` → pattern matching
- `if condition do...end` → guard clauses
- Inline if statements → helper functions

### Phase 2: Nil Checks
- `if value do...end` → pattern match on nil
- `if is_nil(value)` → pattern match on nil
- `if value != nil` → guard clauses

### Phase 3: State Checks
- `if state.field` → pattern match on map keys
- `if state.active` → multiple function heads
- Complex state checks → guard combinations

### Phase 4: Complex Conditionals
- Nested if statements → flat pattern matching
- If/else if chains → multiple function heads
- Boolean combinations → complex guards

## Example Migration: drag_drop.ex

**Results:**
- Before: 17 if statements
- After: 3 if statements
- Reduction: 82%

**Remaining Work:**
The 3 remaining if statements in drag_drop.ex can be further refactored:
1. Line 216: `if state.active` → pattern match on state
2. Line 241: `if valid_drop_target != state.valid_drop_target` → guard clause
3. Line 539: `if updated_state.valid_drop_target` → pattern matching

## Anti-Patterns to Avoid

### ❌ Don't Create Too Many Small Functions
Balance between removing if statements and maintaining readability.

### ❌ Don't Force Pattern Matching Where If Is Clearer
Some simple boolean checks are clearer as if statements.

### ❌ Don't Duplicate Logic
Extract common patterns into shared functions.

## Tools and Scripts

### Count If Statements
```bash
# Count total if statements in codebase
grep -r "^\s*if " lib --include="*.ex" | wc -l

# Find files with most if statements
for file in lib/**/*.ex; do 
  count=$(grep -c "^\s*if " "$file" 2>/dev/null || echo 0)
  if [ "$count" -gt 10 ]; then 
    echo "$count $file"
  fi
done | sort -rn | head -10
```

### Verify Refactoring
```bash
# Run tests after refactoring
mix test

# Check for compilation warnings
mix compile --warnings-as-errors

# Run credo for code quality
mix credo --strict
```

## Conclusion

Refactoring if statements to pattern matching is a key part of the functional programming transformation. The patterns outlined here provide a systematic approach to achieving the target of < 500 if statements (87% reduction from the original 3,925).

The drag_drop.ex example shows that 80%+ reduction is achievable while improving code quality and maintainability.