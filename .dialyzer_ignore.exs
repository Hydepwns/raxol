[
  # ================================================================================
  # DIALYZER SUPPRESSIONS
  # ================================================================================
  #
  # This file contains patterns for dialyzer warnings that are intentionally
  # suppressed. Each section documents why the suppression exists.
  #
  # Total suppressed: ~104 warnings
  # Last updated: 2024-12
  #
  # ================================================================================

  # ------------------------------------------------------------------------------
  # EXTERNAL CODE (deps, NIF, tests)
  # ------------------------------------------------------------------------------
  # Dependencies are maintained externally and their type issues are not our concern.
  # The termbox2 NIF is C code with Elixir bindings that dialyzer can't analyze.
  # Test files often use mocks and fixtures with intentionally loose typing.
  ~r"^deps/",
  ~r"lib/termbox2_nif/",
  ~r"^test/",

  # ------------------------------------------------------------------------------
  # DEFENSIVE CATCH-ALL CLAUSES
  # ------------------------------------------------------------------------------
  # These are intentionally unreachable pattern matches that exist as defensive
  # programming - they handle unexpected cases that "should never happen" but
  # provide graceful degradation if they do. Dialyzer correctly identifies them
  # as unreachable based on the types, but we keep them for safety.
  #
  # animation/*.ex - Catch-all clauses in animation state machine
  # output.ex - Fallback for unexpected output types
  ~r"lib/raxol/animation/.*:pattern_match_cov.*can never match.*covered by previous",
  ~r"output\.ex:.*:pattern_match_cov.*can never match.*covered by previous",

  # ------------------------------------------------------------------------------
  # UI COMPONENT EVENT HANDLING API MISMATCH
  # ------------------------------------------------------------------------------
  # The component behaviour defines:
  #   @callback handle_event(event(), state(), context()) :: {state(), [command()]}
  #
  # But UI components implement a different API:
  #   def handle_event(state, event, context) :: {:update, state} | :passthrough
  #
  # This is an intentional architectural decision. The components use a more
  # ergonomic API with tagged return tuples, while the behaviour was designed
  # for a different command-based architecture. Fixing this would require either:
  # 1. Refactoring all component implementations (breaking change)
  # 2. Updating the behaviour contract (could break other implementations)
  #
  # Affected files: button.ex, checkbox.ex, multi_line_input.ex, text_area.ex,
  #                 table.ex, selector.ex
  ~r"ui/components/.*:callback_type_mismatch.*handle_event",
  ~r"ui/theming/.*:callback_type_mismatch.*handle_event",

  # ------------------------------------------------------------------------------
  # COMPILE-TIME CONDITIONAL CODE (termbox2_nif availability)
  # ------------------------------------------------------------------------------
  # The codebase supports multiple terminal backends:
  # - termbox2_nif: Native C NIF for Unix/macOS (high performance)
  # - IOTerminal: Pure Elixir fallback for Windows or when NIF unavailable
  #
  # At compile time, @termbox2_available is set based on whether the NIF loaded.
  # This creates dead code branches that dialyzer correctly identifies:
  # - When NIF is available: fallback branches are unreachable
  # - When NIF is unavailable: NIF branches are unreachable
  #
  # driver.ex - Backend selection based on NIF availability
  # terminal_utils.ex - Dimension detection via NIF or fallback
  # dcs_entry_state.ex - Parser state that checks terminal capabilities
  ~r"driver\.ex:.*pattern_match.*type (true|:ok|0|\{:ok,)",
  ~r"driver\.ex:.*pattern_match_cov.*can never match.*covered by previous",
  ~r"terminal_utils\.ex:.*pattern_match.*type (true|false)",
  ~r"terminal_utils\.ex:.*extra_range",
  ~r"dcs_entry_state\.ex:.*pattern_match.*type true",

  # ------------------------------------------------------------------------------
  # INTENTIONAL NO-RETURN FUNCTIONS (error handlers)
  # ------------------------------------------------------------------------------
  # These functions are designed to always raise exceptions. They serve as
  # error handlers that terminate execution with descriptive error messages.
  # Dialyzer correctly identifies they have no normal return path.
  #
  # view_utils.ex - handle_invalid_spacing_type/1, handle_invalid_margin_type/1
  #   Raise ArgumentError for invalid CSS-like spacing/margin values
  #
  # recovery_supervisor.ex - escalate_to_parent/3
  #   Raises when error recovery fails and must escalate to parent supervisor
  #
  # bench.memory_analysis.ex - handle_unknown_scenario/1
  #   Raises for unrecognized benchmark scenarios (programming error)
  ~r"view_utils\.ex:.*no_return.*handle_invalid_",
  ~r"recovery_supervisor\.ex:.*no_return.*escalate_to_parent",
  ~r"bench\.memory_analysis\.ex:.*no_return.*handle_unknown_scenario",

  # ------------------------------------------------------------------------------
  # CREDO MACRO EXPANSION (custom checks)
  # ------------------------------------------------------------------------------
  # Custom Credo checks use `use Credo.Check` which expands to inject internal
  # Credo functions that dialyzer cannot resolve. These are false positives -
  # the functions exist at runtime via the Credo dependency but are injected
  # by macro expansion in a way dialyzer cannot analyze.
  ~r"credo/.*:unknown_function.*Credo\."
]
