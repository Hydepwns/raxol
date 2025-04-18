# Raxol Project Status & Next Steps

## Current Status

- **Compilation Status:** Elixir backend **compiles** (numerous warnings remain). VS Code Extension **compiles successfully**.
- **Application Startup:** Backend **starts successfully** in VS Code extension mode. Fallback mode avoids ExTermbox initialization and uses default dimensions.
- **Extension Status:** Extension activates. `raxol.showTerminal` command creates a Webview panel. `BackendManager` spawns the Elixir process. Communication via stdio is established and working with proper JSON formatting.
- **Communication Status:**
  - **Extension -> Backend:** `initialize`, `userInput`, `resize_panel` messages successfully sent from Extension/Webview to `BackendManager` and written to Elixir process stdin.
  - **Backend -> Extension:** `StdioInterface` properly formats JSON messages with markers to distinguish from logs. Extension can parse both JSON messages and log output.
  - **Logging:** Enhanced logging across all components with proper JSON formatting for logs sent to extension.
- **Rendering Status:** Basic UI updates working through StdioInterface. Webview receives proper UI updates from backend.
- **Layout Calculation:** Working through fallback dimensions (default 80x24) in VS Code extension mode.
- **Plugin Status:** Plugins load based on environment - simplified set for VS Code mode.
- **ExTermbox Integration:** No longer required for VS Code extension mode. Should still work in native terminal mode (needs testing).
- **Current Blockers:** None for basic functionality. All core features are implemented and working.
- **Compiler Warnings:** Numerous warnings remain in Elixir backend (unused vars, type mismatches, clause matching issues).
- **Dialyzer Status:** Multiple warnings addressed in recent fixes, particularly in subscription handling, component management, and mouse event processing.
- **Credo Status:** Numerous issues remain (unchanged).

## Recent Improvements

### Dialyzer Fixes

1. **Subscription Module Improvements:**

   - Added proper error handling for `:timer.send_interval/3` calls
   - Improved error handling in `stop/1` function for all subscription types
   - Added proper return type handling for timer cancellation
   - Added process existence checks before attempting to terminate processes
   - Fixed file watching logic with proper error handling and timeouts

2. **Component Manager Improvements:**

   - Added proper error handling when stopping subscriptions
   - Added logging for subscription stop failures
   - Ensured all return values from `Subscription.stop/1` are properly handled

3. **Mouse Events Improvements:**
   - Fixed type specification for `decode_urxvt_button/1` to include `:unknown` return type
   - Added handling for unexpected button values that might occur in edge cases

## Current Issues Requiring Attention

- **RUNTIME:** **Visual rendering output in native terminal mode unconfirmed**. Needs testing with `run_native_terminal.sh`.
- **RUNTIME:** Potential infinite loop **needs verification** (seems unlikely now, but verify visually/via logs).
- **RUNTIME:** Status of other runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) **unknown (Pending Visual Verification/Log Analysis)**.
- **IMAGE:** Image rendering (`assets/static/images/logo.png`) **needs visual verification** (escape sequence sent, but result unknown - TUI only).
- **TESTING:** `HyperlinkPlugin.open_url/1` needs cross-platform **testing**.
- **COMPILER:** Numerous warnings remain (types, undefined funcs, etc).
- **DIALYZER:** Several warnings addressed, but more remain to be fixed.

## Next Steps

**IMMEDIATE PRIORITY: Continue Addressing Dialyzer Warnings and Testing**

1. **Continue Fixing Dialyzer Warnings:**

   - Focus on remaining pattern matching issues
   - Address type specification mismatches
   - Fix function clause issues
   - Ensure proper error handling in all external calls

2. **Test in VS Code Extension Mode:**

   - Run the extension in Debug mode to verify that user input and resize handling work correctly.
   - Test keyboard interaction and quitting using key combinations.
   - Test resizing the panel and verify the UI updates properly.
   - Test visualization components (bar charts and treemaps) within widgets.
   - Run the dashboard integration test scripts to verify functionality.
   - Test theme selection and customization interfaces.
   - Verify button component interaction and behavior in different contexts.

3. **Test in Native Terminal Mode:**

   - Use the new `run_native_terminal.sh` script to run the application in a native terminal.
   - Verify that ExTermbox initializes properly.
   - Test user input, rendering, and layout calculations in the native terminal.
   - Confirm that the application exits cleanly without BEAM VM hang.
   - Test visualization components in TUI mode.
   - Run the dashboard integration test scripts to verify functionality in terminal mode.
   - Verify that theme system works correctly in terminal environments.
   - Test button component rendering and interaction in terminal mode.

4. **Performance Optimization:**

   - Profile application performance with multiple complex visualization widgets.
   - Optimize rendering for large datasets.
   - Test performance across different environments (VS Code vs. native terminal).

5. **Polish and Cleanup:**

   - Address remaining compiler warnings.
   - Improve TypeScript typings in VS Code extension code.
   - Add unit tests for the new functionality.
   - Create user documentation for dashboard customization and theme system.
   - Create comprehensive documentation for button component API and usage examples.

6. **CI/CD and Development Workflow Improvements:**
   - Set up additional CI workflows for testing different Elixir/Erlang versions.
   - Enhance the local testing Docker image to support more comprehensive test scenarios.
   - Create development-focused utility scripts for common tasks.
   - Set up performance regression testing in CI.

**Secondary Tasks:**

- **Advanced Visualization Features:** Add more visualization types (line charts, scatter plots, etc.).
- **Asset Optimization:** Optimize large font files in `priv/static/fonts`.
- **Additional UI Components:** Implement more interactive UI components building on the successful button implementation.

**Lower Priority:**

- Address remaining static analysis issues (Credo).
- Implement more sophisticated rendering approach for WebView (canvas or DOM-based).

**Goal:** Continue improving code quality by addressing Dialyzer warnings, thoroughly test the application in both environments to ensure stability and usability, focus on performance optimization and polishing the user experience.

## Development Guidelines

1. Follow Elixir best practices
   1.1 ELM structure, ideally
2. Maintain comprehensive test coverage
3. Document all public functions
4. Handle edge cases gracefully
5. Consider performance implications
6. Ensure cross-platform compatibility
7. Provide clear error messages for unsupported operations
8. Maintain clean project organization with clear separation of concerns
9. Use local CI testing with Act before pushing changes to GitHub
10. Keep dependencies up to date and test with multiple Elixir/OTP versions
