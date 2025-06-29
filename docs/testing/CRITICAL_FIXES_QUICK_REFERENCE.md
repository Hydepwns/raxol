# Critical Fixes Quick Reference

## 🚨 Immediate Fixes Needed

### 1. Fix Raxol.Terminal.Cursor.Style Behaviour (2 issues)

**File**: `lib/raxol/terminal/cursor/style.ex`

**Problem**: Module defines itself as behaviour but missing callbacks for `blink/1` and `get_style/1`

**Fix**: Add these callbacks to the behaviour definition (around line 30):

```elixir
@callback blink(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
            Raxol.Terminal.Cursor.Manager.t()
@callback get_style(cursor :: Raxol.Terminal.Cursor.Manager.t()) :: atom()
```

### 2. Fix ScreenBuffer @impl Annotations (63 issues)

**File**: `lib/raxol/terminal/screen_buffer.ex`

**Problem**: Missing `@impl Raxol.Terminal.ScreenBufferBehaviour` annotations

**Fix**: Add `@impl Raxol.Terminal.ScreenBufferBehaviour` before each of these functions:

```elixir
@impl Raxol.Terminal.ScreenBufferBehaviour
def apply_single_shift(buffer, shift) do
  # existing implementation
end

@impl Raxol.Terminal.ScreenBufferBehaviour
def attribute_set?(buffer, attribute) do
  # existing implementation
end

# ... continue for all 35 functions listed in the main plan
```

### 3. Fix Duplicate Function Definitions (5 issues)

**File**: `lib/raxol/terminal/buffer/char_editor.ex`

**Problem**: Multiple definitions of same function with same arity

**Fix**: Group function clauses together or remove duplicates:

```elixir
# Instead of:
def insert_chars(buffer, row, col, chars) do
  # implementation 1
end

def some_other_function() do
  # other code
end

def insert_chars(buffer, row, col, chars) do
  # implementation 2
end

# Do this:
def insert_chars(buffer, row, col, chars) do
  # implementation 1
end

def insert_chars(buffer, row, col, chars) do
  # implementation 2
end

def some_other_function() do
  # other code
end
```

### 4. Fix GenServer Behaviour Conflicts (9 issues)

**File**: `lib/raxol/terminal/graphics/unified_graphics.ex`

**Problem**: `the behaviour GenServer has been declared twice`

**Fix**: Remove duplicate `use GenServer` or `@behaviour GenServer` declarations

```elixir
# Keep only one of these:
use GenServer
# OR
@behaviour GenServer
# But not both
```

### 5. Fix Underscored Variable Usage (3 issues)

**Problem**: Variables with leading underscore are being used

**Fix**: Remove underscore if variable is actually used:

```elixir
# Instead of:
def some_function(_args) do
  _args  # This causes warning
end

# Do this:
def some_function(args) do
  args
end
```

## 🔧 Quick Commands for Testing

```bash
# Check current state
mix compile 2>&1 | grep -c "warning:"

# Test specific fixes
mix compile 2>&1 | grep "Raxol.Terminal.Cursor.Style"

# Run tests after fixes
mix test --max-failures=0
```

## 📋 Priority Order

1. **Fix Cursor.Style behaviour** (2 warnings)
2. **Add ScreenBuffer @impl annotations** (63 warnings)
3. **Fix duplicate function definitions** (5 warnings)
4. **Fix GenServer conflicts** (9 warnings)
5. **Fix underscored variables** (3 warnings)

**Total**: 82 critical warnings that can be fixed quickly

## 🎯 Expected Impact

After these fixes:

- **Total warnings**: 576 → ~494 (-82)
- **Behaviour issues**: 63 → 0 (-63)
- **Duplicate definitions**: 5 → 0 (-5)
- **Behaviour conflicts**: 9 → 0 (-9)

This represents a **14% reduction** in compilation warnings with relatively low-risk changes.
