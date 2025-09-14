# Command Handler Consolidation Mapping

**Phase 4.1 Target**: Consolidate 22 terminal command handlers into 1 unified system

## Handler Analysis Summary

### Current Handler Files (22 total)
1. `buffer_handler.ex` - Buffer operations
2. `cursor_handler.ex` - Cursor movement (CUP, CUU, CUD, CUF, CUB, etc.)  
3. `device_handler.ex` - Device status reports (DSR, DA)
4. `erase_handler.ex` - Erase operations (ED, EL, ECH)
5. `dcs_handler.ex` - Device Control Strings
6. `mode_handler.ex` - Mode setting/resetting (SM, RM)
7. `osc_handler.ex` - Operating System Commands
8. `window_handler.ex` - Window operations
9. `csi_handler.ex` - Main CSI dispatcher
10. `csi_handler/apply_handler.ex` - CSI application
11. `csi_handler/basic_handler.ex` - Basic CSI commands
12. `csi_handler/charset_handler.ex` - Character set handling
13. `csi_handler/csi_handler_factory.ex` - CSI handler factory
14. `csi_handler/cursor_movement_handler.ex` - CSI cursor movements
15. `csi_handler/device_handler.ex` - CSI device commands
16. `csi_handler/device_status_handler.ex` - CSI device status
17. `csi_handler/mode_handler.ex` - CSI mode commands
18. `csi_handler/screen_commands_handler.ex` - CSI screen commands
19. `csi_handler/screen_handler.ex` - CSI screen operations
20. `csi_handler/sgr_handler.ex` - Select Graphic Rendition
21. `csi_handler/text_handler.ex` - CSI text operations
22. `unified_command_handler.ex` - Our new unified system (target)

## Migration Strategy

### Step 1: Function Inventory & Analysis

#### Core Command Types to Consolidate:

**Cursor Commands** (from cursor_handler.ex + csi_handler/cursor_movement_handler.ex):
- `handle_cursor_movement/3` → UnifiedCommandHandler
- `handle_cup/2` (CUP - Cursor Position)
- `handle_A/2` (CUU - Cursor Up)  
- `handle_B/2` (CUD - Cursor Down)
- `handle_C/2` (CUF - Cursor Forward)
- `handle_D/2` (CUB - Cursor Backward)
- `handle_E/2` (CNL - Cursor Next Line)
- `handle_F/2` (CPL - Cursor Previous Line)
- `handle_G/2` (CHA - Cursor Horizontal Absolute)
- `handle_H/2` (CUP - Cursor Position alias)

**Device Commands** (from device_handler.ex + csi_handler/device*.ex):
- `handle_n/2` (DSR - Device Status Report)
- `handle_c/3` (DA - Device Attributes)
- Response generation functions

**Erase Commands** (from erase_handler.ex):
- `handle_erase/4` - Generic erase handler
- Screen erase variants (ED)
- Line erase variants (EL)  
- Character erase (ECH)

**Mode Commands** (from mode_handler.ex + csi_handler/mode_handler.ex):
- `handle_h/2` (SM - Set Mode)
- `handle_l/2` (RM - Reset Mode)
- DEC private mode handling

**Text Commands** (from csi_handler/sgr_handler.ex + csi_handler/text_handler.ex):
- `handle_m/2` (SGR - Select Graphic Rendition)
- Text styling and formatting

**Screen Commands** (from csi_handler/screen*.ex):
- Scrolling operations
- Screen manipulation

### Step 2: UnifiedCommandHandler Enhancement Plan

#### Current UnifiedCommandHandler Coverage Analysis:
✅ Basic cursor commands (A, B, C, D, E, F, G, H, f)
✅ Basic erase commands (J, K, X)  
✅ Basic device commands (c, n)
✅ Basic mode commands (h, l)
✅ Basic text commands (m)
✅ Basic scrolling commands (S, T)
✅ Tab commands (g)
✅ OSC commands (0, 1, 2, 4, 10, 11)

#### Missing Implementations Needed:
- [ ] Buffer operations from buffer_handler.ex
- [ ] DCS commands from dcs_handler.ex  
- [ ] Window operations from window_handler.ex
- [ ] Advanced CSI commands from csi_handler/ subdirectory
- [ ] Character set handling
- [ ] Complete SGR implementation
- [ ] Advanced mode operations

### Step 3: Migration Implementation Order

#### Phase 1: Core Command Enhancement (Days 1-2)
1. **Enhance cursor commands**: Merge cursor_handler.ex functionality
2. **Enhance device commands**: Merge device_handler.ex functionality  
3. **Enhance erase commands**: Merge erase_handler.ex functionality
4. **Add missing CSI commands**: From csi_handler/ subdirectory

#### Phase 2: Advanced Command Integration (Days 3-4)
1. **Buffer operations**: Integrate buffer_handler.ex
2. **DCS commands**: Integrate dcs_handler.ex
3. **Window operations**: Integrate window_handler.ex
4. **Mode operations**: Complete mode_handler.ex integration

#### Phase 3: Factory & Dispatcher Integration (Day 5)
1. **CSI factory pattern**: Integrate csi_handler_factory.ex logic
2. **Main CSI handler**: Integrate csi_handler.ex dispatcher
3. **Command routing**: Ensure all routing works through unified system

#### Phase 4: Deprecation & Bridge Creation (Days 6-7)
1. **Create deprecation bridges**: Replace each handler with deprecation version
2. **Update internal references**: Find and update all handler usage
3. **Add migration warnings**: Clear deprecation messages with examples
4. **Ensure backward compatibility**: All existing code continues working

### Step 4: Reference Update Strategy

#### Handler Alias Usage Locations (46 total found):
Need to systematically find and update:
```bash
grep -r "alias.*Handler" /Users/droo/Documents/CODE/raxol/lib --include="*.ex"
```

#### Common Usage Patterns to Update:
- `alias Raxol.Terminal.Commands.CursorHandler`
- `CursorHandler.handle_cup(emulator, params)`  
- `DeviceHandler.handle_n(emulator, params)`
- Factory pattern usage in CSI dispatching

## Compatibility Matrix

### Guaranteed Backward Compatibility:
- [ ] All public function signatures preserved
- [ ] All return value formats maintained
- [ ] All error handling behavior preserved
- [ ] All test suite passes unchanged

### Performance Requirements:
- [ ] Command processing time ≤ current performance
- [ ] Memory usage ≤ current consumption
- [ ] No regression in terminal responsiveness

### Migration Validation:
- [ ] Full test suite execution (0 failures)
- [ ] Integration test coverage for all commands
- [ ] Performance benchmark comparison
- [ ] Manual testing of complex command sequences

## Implementation Notes

### Key Challenges:
1. **Complex CSI dispatching logic** - Need to preserve exact routing behavior
2. **State management consistency** - Ensure emulator state handled correctly
3. **Error handling parity** - Match existing error behavior exactly
4. **Performance maintenance** - Unified system must not be slower

### Success Metrics:
1. **Functional parity**: 100% of existing functionality preserved
2. **Performance parity**: No measurable regression  
3. **Code reduction**: ~90% reduction in handler files (21→1)
4. **Maintainability**: Single point of command processing
5. **Extensibility**: Easy to add new commands to unified system

This consolidation will eliminate ~21 handler files while maintaining complete backward compatibility through deprecation bridges.