# Development Roadmap

**Version**: v2.0.1
**Updated**: 2025-12-05
**Status**: Published to Hex.pm - gathering user feedback

## Document Organization

This TODO is organized by priority:
1. **IMMEDIATE NEXT STEPS** - Post-release activities (user feedback, documentation)
2. **RECENTLY COMPLETED** - v2.0.1 publication complete (Dec 5, 2025)
3. **CRITICAL PRIORITIES** - Blocking issues (none currently)
4. **FUTURE ENHANCEMENTS** - Post-release features with implementation plans (v2.2+)
5. **TECHNICAL DEBT** - Minor issues to address when convenient
6. **KNOWN NON-ISSUES** - Reference documentation for expected behaviors
7. **FUTURE ROADMAP** - Long-term vision (Q2 2025+)

## Quick Links

- **Published Packages**: https://hex.pm/packages/raxol (and raxol_core, raxol_plugin, raxol_liveview)
- **Recent Work**: See "RECENTLY COMPLETED" for v2.0.1 publication details
- **Kitty Protocol Plan**: `docs/project/KITTY_PROTOCOL_PLAN.md`
- **Code Review**: `docs/project/CODE_REVIEW_GRAPHICS_INTEGRATION.md`
- **Session Summary**: `docs/project/SESSION_SUMMARY.md`

---

## IMMEDIATE NEXT STEPS

### Post-Release Activities (v2.0.1)
**Priority**: Medium
**Status**: v2.0.1 published successfully on Dec 5, 2025

**Current Activities**:
1. **User Feedback** - Monitor GitHub issues and Hex.pm feedback
2. **Documentation** - Point raxol.io domain to documentation site
3. **Examples** - Create demo applications showcasing graphics features
4. **Planning** - Prioritize v2.2 features based on user demand

**Installation** (for users):
```elixir
# Minimal - just buffer primitives
{:raxol_core, "~> 2.0"}

# With LiveView support
{:raxol_core, "~> 2.0"}
{:raxol_liveview, "~> 2.0"}

# Everything (meta-package)
{:raxol, "~> 2.0"}
```

**Next Steps** (no immediate priority):
- Gather user feedback on graphics features
- Consider Kitty Graphics Protocol implementation (see FUTURE ENHANCEMENTS)
- Address technical debt incrementally
- Plan v2.2 feature set based on community input

---

## RECENTLY COMPLETED (v2.0.1)

### Hex.pm Publication ✅
**Completed**: 2025-12-05
**Effort**: Documentation fixes and publishing workflow

**Summary**: Successfully published all four packages to Hex.pm with complete documentation.

**Published Packages**:
- `raxol` v2.0.1 - Meta-package with all features
- `raxol_core` v2.0.1 - Core buffer primitives
- `raxol_plugin` v2.0.1 - Plugin framework
- `raxol_liveview` v2.0.1 - Phoenix LiveView integration

**Accomplishments**:
- Fixed all ExDoc documentation warnings
- Created missing documentation files (cookbook/README.md)
- Fixed broken markdown links in documentation
- Published packages in correct dependency order
- Created and pushed git tag v2.0.1
- Zero compilation warnings
- All 4344 tests passing

**Links**:
- Package: https://hex.pm/packages/raxol
- Documentation: https://hexdocs.pm/raxol
- Repository: https://github.com/Hydepwns/raxol

### Plugin Visualization Integration ✅
**Completed**: 2025-12-05
**Effort**: 2 days (as estimated)

**Summary**: Full integration of Sixel graphics rendering in plugin visualization system.

**Implementation**:
- Created `create_sixel_cells_from_buffer/2` bridging plugin → terminal Sixel
- Integrated with `Raxol.Terminal.ANSI.SixelGraphics.process_sequence/2`
- Implemented pixel buffer → Cell grid conversion with RGB color mapping
- Comprehensive test suite: 8 tests, 100% passing
- Code quality improvements: DRY helpers, flattened cases, pattern matching
- Test code reduced by 45% through helper functions

**Quality Metrics**:
- Zero compilation warnings
- Zero test regressions
- Code quality score: 8.7/10 → 9.3/10 (+7%)
- Fully functional, idiomatic Elixir patterns

**Files**:
- `lib/raxol/plugins/visualization/image_renderer.ex`
- `test/raxol/plugins/visualization/image_renderer_test.exs`
- `docs/project/KITTY_PROTOCOL_PLAN.md` (400+ lines)
- `docs/project/CODE_REVIEW_GRAPHICS_INTEGRATION.md`
- `docs/project/SESSION_SUMMARY.md`

**Documentation**: See CHANGELOG.md for detailed changes.

### Test Type Warnings Fixed ✅
**Completed**: 2025-12-05
**Effort**: 15 minutes (as estimated)

**Summary**: Removed unreachable pattern matching clauses causing Dialyzer warnings.

**Fixes**:
- Removed unreachable `%Emulator{} = emu -> emu` patterns (lines 178, 350)
- DCS handlers return tuples `{:ok, emu}` or `{:error, reason, emu}`, not bare structs
- Pattern matching now correctly handles all return types

**Quality Metrics**:
- Zero compilation warnings in Raxol code
- All 10 DCS handler tests passing
- Clean build with `--warnings-as-errors`

**Files Modified**:
- `test/raxol/terminal/commands/dcs_handlers_test.exs`

---

## CRITICAL PRIORITIES

### CI/CD Pipeline Stabilization
**Priority**: High
**Status**: In Progress (Phase 1 Complete - Dec 6, 2025)
**Estimated Effort**: 3-5 days total

#### Phase 1: Immediate Fixes ✅ (Completed Dec 6, 2025)
**Completed Tasks**:
- Fixed `delta_updater_test.exs` JSON parsing (removed Elixir underscores from JSON strings)
- Added hex/rebar installation to all CI workflow jobs
- Added explicit `mix deps.compile` steps to ensure dependencies are built
- Added graceful fallbacks for missing benchmark files
- Added file existence checks before running benchmarks
- Fixed format and compile checks in Unified CI Pipeline

**Results**:
- ✅ Unified CI Pipeline: Format and compile checks now passing
- ✅ Performance Tracking: Running successfully with fallbacks
- ✅ Regression Testing: Compilation errors resolved
- ✅ Security Scanning: Continues to pass
- ⚠️ Nightly Build: Still failing - requires Phase 2 investigation

**Commits**:
- d84103ae: Core CI fixes for workflows and tests
- 0089fe35: Unified CI workflow hex/rebar installation

#### Phase 2: Nightly Build Investigation (Next Priority)
**Status**: Not Started
**Estimated Effort**: 2-3 days
**Goal**: Identify and fix root causes of nightly build test failures

**Current Failure Summary** (from Dec 6, 2025 runs):
- Test Matrix: 10/11 jobs failing across multiple Elixir/OTP/OS combinations
- Dialyzer: Failing with exit code 1
- Extended Integration Tests: Passing ✅
- Extended Scenarios: Passing ✅

**Affected Combinations**:
- Elixir 1.17.3, 1.18.3, 1.19.0
- OTP 27.2, 28.2
- Ubuntu Latest, macOS Latest
- Common pattern: Test suite failures, not compilation errors

**Investigation Plan**:

1. **Isolate Failure Patterns** (4-6 hours)
   - [ ] Download and analyze logs from failed nightly runs
   - [ ] Identify common failing tests across all matrix combinations
   - [ ] Check if failures are environment-specific (macOS vs Ubuntu)
   - [ ] Check if failures are version-specific (Elixir/OTP combinations)
   - [ ] Look for timing-related issues (race conditions, timeouts)

   **Commands**:
   ```bash
   # Get detailed logs for specific failing run
   gh run view 19981649364 --log-failed

   # Compare logs across different matrix combinations
   gh api repos/Hydepwns/raxol/actions/jobs/57309039453/logs  # Ubuntu 1.17.3/27.2
   gh api repos/Hydepwns/raxol/actions/jobs/57309039461/logs  # macOS 1.18.3/28.2

   # Extract test names from failures
   gh run view 19981649364 --log-failed | grep "test.*(" | sort | uniq -c
   ```

2. **Reproduce Locally** (2-4 hours)
   - [ ] Set up test environment matching CI matrix
   - [ ] Run failing tests locally with same Elixir/OTP versions
   - [ ] Use asdf to test multiple version combinations:
   ```bash
   # Test with different Elixir versions
   asdf local elixir 1.17.3
   asdf local erlang 27.2
   TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test

   asdf local elixir 1.19.0
   asdf local erlang 28.2
   TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test
   ```
   - [ ] Check for environment variable differences between local and CI
   - [ ] Verify all required services are running (postgres, redis if needed)

3. **Categorize Failures** (2-3 hours)
   - [ ] **Flaky Tests**: Identify tests that pass sometimes, fail others
   - [ ] **Environment-Specific**: Tests that fail only on macOS or Ubuntu
   - [ ] **Version-Specific**: Tests that fail on certain Elixir/OTP versions
   - [ ] **Timeout Issues**: Tests exceeding time limits
   - [ ] **Resource Issues**: Memory/CPU constraints in CI environment
   - [ ] **Mock/Stub Issues**: Mox expectations not being met

   **Analysis**:
   ```bash
   # Run tests multiple times to detect flaky tests
   for i in {1..10}; do
     echo "Run $i"
     TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --seed 0
   done

   # Check for timeout-related failures
   TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --trace
   ```

4. **Fix Root Causes** (4-8 hours)
   **Potential Fixes**:
   - [ ] Add proper setup/teardown for flaky tests
   - [ ] Increase timeouts for slow-running tests in CI
   - [ ] Add platform-specific test tags (@tag :skip_on_macos, @tag :skip_on_ubuntu)
   - [ ] Fix race conditions with proper process synchronization
   - [ ] Add retries for network-dependent tests
   - [ ] Update test fixtures for version compatibility
   - [ ] Fix Mox expectations for async tests

   **Example Fixes**:
   ```elixir
   # Add setup to ensure clean state
   setup do
     on_exit(fn ->
       # Clean up processes, ETS tables, etc.
     end)
   end

   # Add platform-specific skip
   @tag :skip_on_macos
   test "something that only works on Linux" do
     # ...
   end

   # Increase timeout for slow tests
   @tag timeout: 60_000
   test "slow integration test" do
     # ...
   end
   ```

5. **Dialyzer Failures** (2-3 hours)
   - [ ] Run dialyzer locally to reproduce issues:
   ```bash
   mix dialyzer --format github
   ```
   - [ ] Check for new type spec warnings
   - [ ] Fix type mismatches or add proper specs
   - [ ] Consider making Dialyzer non-blocking if issues are non-critical:
   ```yaml
   - name: Run Dialyzer
     run: mix dialyzer
     continue-on-error: true  # Add this if needed
   ```

6. **Update Workflow Configuration** (1-2 hours)
   - [ ] Add better error reporting in nightly.yml
   - [ ] Add test result summaries to GitHub Actions output
   - [ ] Consider reducing test matrix to critical combinations only:
   ```yaml
   # Current: 11 combinations (3 Elixir × 2 OTP × 2 OS - 1 excluded)
   # Proposed: 4-6 critical combinations
   matrix:
     include:
       - elixir: "1.17.3"
         otp: "27.2"
         os: ubuntu-latest
       - elixir: "1.19.0"
         otp: "28.2"
         os: ubuntu-latest
       - elixir: "1.19.0"
         otp: "28.2"
         os: macos-latest
   ```
   - [ ] Add test artifact uploads with better paths
   - [ ] Add summary step showing which tests failed

**Success Criteria**:
- [ ] Nightly build passes on all tested configurations
- [ ] OR: Failing tests are properly tagged/skipped with documented reasons
- [ ] Dialyzer runs without errors (or is marked continue-on-error with issue tracking)
- [ ] Test matrix reduced to maintainable size if needed
- [ ] All flaky tests identified and fixed or marked

**Files to Check**:
- `.github/workflows/nightly.yml`
- Test files showing consistent failures
- Dialyzer PLT files and type specs
- Test helper modules for proper setup/teardown

**Links**:
- Latest nightly run: https://github.com/Hydepwns/raxol/actions/runs/19981649364
- Workflow file: `.github/workflows/nightly.yml`

---

## FUTURE ENHANCEMENTS (v2.2+)

### Post-Release Improvements (Optional)

#### Documentation & Examples
- **Priority**: Medium
- **Effort**: 2-3 days
- **Tasks**:
  - Create demo application showcasing Sixel rendering capabilities
  - Add cookbook examples for plugin visualization usage
  - Performance benchmarks for image rendering
  - Video tutorials for graphics features
  - Point raxol.io domain to documentation site

#### Property-Based Tests
- **Priority**: Low
- **Effort**: 1-2 days
- **Tasks**:
  - Add property-based tests for graphics modules
  - Test grid dimension invariants
  - Test color conversion edge cases
  - Test Sixel parser with random valid sequences

### Graphics System Enhancements

#### 1. Kitty Graphics Protocol
- **Priority**: Medium (based on user demand)
- **Effort**: 14 days (1-2 weeks)
- **Status**: Planned - detailed implementation plan ready
- **Plan Document**: `docs/project/KITTY_PROTOCOL_PLAN.md`
- **Rationale**: Modern protocol superior to Sixel in several ways:
  - Native animation support (unlike Sixel)
  - Better compression (zlib, PNG)
  - More efficient for large images
  - Pixel-perfect placement with z-indexing
  - Base64 transmission for compatibility
- **Implementation Phases**:
  1. Parser (3 days) - Control data parsing, base64 decoding, chunking
  2. Graphics State (3 days) - Image store, placement management, z-index
  3. DCS Integration (1 day) - Route Kitty sequences to graphics handler
  4. Compression (1 day) - zlib/PNG decompression support
  5. Animation (2 days) - Frame sequencing, playback scheduling
  6. Plugin Integration (2 days) - Update `create_kitty_cells` function
  7. Testing (2 days) - Comprehensive test suite
- **Architecture**: Mirrors proven Sixel pattern (KittyParser, KittyGraphics, KittyAnimation)
- **Decision Point**: Gather user feedback post-v2.0.1 release before implementing

#### 2. Sixel Animation Support
- **Priority**: Low
- **Effort**: 3-5 days
- **Status**: Not in DEC Sixel spec (extension would be custom)
- **Note**: Original Sixel protocol supports static images only (by design)
- **Implementation Plan**:
  1. Add frame sequencing to `SixelGraphics` state
  2. Implement frame timing and delay parameters
  3. Add frame buffer management with double buffering
  4. Create animation playback scheduler
  5. Handle frame transitions and cleanup
- **Alternative**: Use Kitty protocol which has native animation support
- **Considerations**: Custom extension may not be compatible with other Sixel implementations

### Distributed Systems

#### Distributed Session Management
- **Location**: `lib/raxol/core/session/distributed_session_registry.ex:899, 912`
- **Functions**: Session rebalancing and migration stubs
- **Status**: Infrastructure for future distributed deployment
- **Rationale**: Future feature, not needed for current release

#### Distributed Test Infrastructure
- ~10 distributed session registry tests skipped
- Requires multi-node Erlang setup
- See `test/raxol/core/session/distributed_session_registry_test.exs`
- Defer until distributed features are prioritized

### Code Quality

#### Credo Warnings
- Various code quality suggestions
- Non-blocking, address incrementally
- Can be tackled during maintenance windows

---

## TECHNICAL DEBT

### Dependency Warnings (Jason)
- **Priority**: Very Low
- **Source**: Jason dependency (deprecated charlist syntax)
- **Impact**: None on Raxol code
- **Status**: Will be fixed in future Jason releases
- **Note**: These warnings are from dependencies, not Raxol code

### Minor Test Variable Warnings
- **Priority**: Very Low
- **Impact**: None (tests pass, cosmetic only)
- **Examples**: Unused variables in test setups
- **Fix**: Can be addressed incrementally during maintenance

---

## KNOWN NON-ISSUES (For Reference Only)

### RuntimeTest - Skipped by Design
- **Location**: `test/raxol/runtime_test.exs`
- **Status**: 6 tests tagged `@tag skip: "Requires messaging infrastructure not yet implemented"`
- **Lines**: 220, 274, 308, 364, 408, 442
- **Rationale**: Intentional, not a bug

### Termbox2LoadingTest - NIF Loading
- **Status**: Expected failure when `SKIP_TERMBOX2_TESTS=true`
- **Rationale**: By design, no action required

---

## FUTURE ROADMAP

### Platform Expansion (Q2 2025)
- WASM production support
- PWA capabilities
- Mobile terminal support
- Cloud session management

### Long-term Vision
- AI-powered command completion
- IDE integrations
- Natural language interfaces
- Collaborative terminal sessions

---

## Development Commands

```bash
# Testing
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker

# Quality
mix raxol.check
mix format
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile --warnings-as-errors
```
