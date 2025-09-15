# Protocol Migration Plan

## Overview
This document outlines the migration from custom behaviours to Elixir protocols where applicable in the Raxol codebase.

## Current State Analysis

### Statistics
- **Total behaviour modules**: 54 behaviour files found
- **Total @behaviour implementations**: 264 files with 2263 occurrences
- **Already using protocols**: String.Chars protocol implemented for Color

### Key Candidates for Protocol Migration

## High Priority Migrations

### 1. Renderer Protocol
**Current**: `Raxol.Terminal.RendererBehaviour`
**Rationale**: Different data types need different rendering strategies
**Benefits**:
- Polymorphic rendering for various data structures
- Extensible by third-party plugins
- Better separation of concerns

```elixir
defprotocol Raxol.Protocols.Renderable do
  @doc "Renders the data structure to terminal output"
  def render(data, opts \\ [])

  @doc "Gets render metadata"
  def render_metadata(data)
end
```

### 2. Serialization Protocol
**Current**: Custom JSON encoding in multiple modules
**Rationale**: Different structs need custom serialization
**Benefits**:
- Unified serialization interface
- Support for multiple formats (JSON, TOML, etc.)

```elixir
defprotocol Raxol.Protocols.Serializable do
  @doc "Serializes data to the specified format"
  def serialize(data, format \\ :json)

  @doc "Deserializes data from the specified format"
  def deserialize(data, format \\ :json)
end
```

### 3. Buffer Operations Protocol
**Current**: Multiple buffer behaviour modules
**Rationale**: Different buffer types (screen, scrollback, overlay) need different operations
**Benefits**:
- Polymorphic buffer operations
- Cleaner buffer abstraction

```elixir
defprotocol Raxol.Protocols.BufferOperations do
  @doc "Writes data to the buffer"
  def write(buffer, position, data, style \\ nil)

  @doc "Reads data from the buffer"
  def read(buffer, position, length \\ 1)

  @doc "Clears the buffer or a region"
  def clear(buffer, region \\ :all)
end
```

## Medium Priority Migrations

### 4. Style Protocol
**Current**: `Raxol.Terminal.Emulator.StyleBehaviour`
**Rationale**: Different components have different styling needs
**Benefits**:
- Polymorphic styling
- Theme application across different types

```elixir
defprotocol Raxol.Protocols.Styleable do
  @doc "Applies style to the data"
  def apply_style(data, style)

  @doc "Gets the current style"
  def get_style(data)

  @doc "Merges styles"
  def merge_styles(data, new_style)
end
```

### 5. Event Handling Protocol
**Current**: Various event handler behaviours
**Rationale**: Different components handle events differently
**Benefits**:
- Unified event handling
- Better event propagation

```elixir
defprotocol Raxol.Protocols.EventHandler do
  @doc "Handles an event"
  def handle_event(handler, event, state)

  @doc "Determines if handler can handle event"
  def can_handle?(handler, event)
end
```

## Low Priority (Keep as Behaviours)

The following should remain as behaviours as they define contracts for modules/processes:

1. **Plugin System Behaviours** - Define plugin lifecycle and capabilities
2. **Process/GenServer Behaviours** - Core OTP patterns
3. **Command Handler Behaviours** - Command pattern implementation
4. **System Adapter Behaviours** - External system integration

## Migration Strategy

### Phase 1: Foundation (Week 1)
1. Create `lib/raxol/protocols/` directory structure
2. Implement Renderable protocol for existing types
3. Migrate Color module's String.Chars to new protocol structure
4. Add comprehensive tests for new protocols

### Phase 2: Core Protocols (Week 2)
1. Implement Serializable protocol
2. Migrate JSON encoding from various modules
3. Implement BufferOperations protocol
4. Update buffer implementations

### Phase 3: UI Protocols (Week 3)
1. Implement Styleable protocol
2. Migrate style operations
3. Implement EventHandler protocol
4. Update event handling code

### Phase 4: Cleanup (Week 4)
1. Remove deprecated behaviours
2. Update documentation
3. Performance testing
4. Migration guide for plugins

## Benefits Summary

1. **Better Polymorphism**: Protocols provide true polymorphism for data types
2. **Open Extension**: Third-party code can implement protocols for their types
3. **Performance**: Protocol dispatch is optimized by the BEAM
4. **Cleaner Code**: Less boilerplate than behaviour callbacks
5. **Type Safety**: Protocols provide compile-time guarantees

## Backwards Compatibility

- Keep behaviour modules during transition with deprecation warnings
- Provide adapter modules for existing plugins
- Version 2.0 can remove deprecated behaviours

## Success Metrics

- Reduction in code complexity (fewer modules)
- Improved performance in render pipeline
- Easier plugin development
- Better test coverage