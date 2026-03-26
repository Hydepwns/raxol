[
  # ================================================================================
  # DIALYZER SUPPRESSIONS
  # ================================================================================
  #
  # Only truly unfixable warnings are suppressed here. Each is documented.
  #
  # Total suppressed: ~40 warnings
  # Last updated: 2026-03
  #
  # ================================================================================

  # ------------------------------------------------------------------------------
  # EXTERNAL CODE (vendored NIF dependency) -- 5 warnings
  # ------------------------------------------------------------------------------
  # The termbox2 NIF vendors elixir_make source. We cannot modify this code.
  ~r"lib/termbox2_nif/",

  # ------------------------------------------------------------------------------
  # COMPILE-TIME CONDITIONAL CODE (termbox2_nif availability) -- 12 warnings
  # ------------------------------------------------------------------------------
  # The codebase supports multiple terminal backends:
  # - termbox2_nif: Native C NIF for Unix/macOS
  # - IOTerminal: Pure Elixir fallback for Windows
  #
  # At compile time, @termbox2_available creates dead code branches that
  # dialyzer correctly flags but cannot be removed without breaking
  # cross-platform support.
  #
  # driver.ex - Backend selection (7 warnings)
  # terminal_utils.ex - Dimension detection (4 warnings)
  # dcs_entry_state.ex - Parser state capabilities (1 warning)
  ~r"driver\.ex:.*pattern_match",
  ~r"driver\.ex:.*unused_fun",
  ~r"terminal_utils\.ex:.*pattern_match",
  ~r"terminal_utils\.ex:.*extra_range",
  ~r"dcs_entry_state\.ex:.*pattern_match",

  # ------------------------------------------------------------------------------
  # CREDO MACRO EXPANSION -- 1 warning
  # ------------------------------------------------------------------------------
  # `use Credo.Check` injects functions that dialyzer cannot resolve.
  ~r"credo/.*:unknown_function.*Credo\.",

  # ------------------------------------------------------------------------------
  # DIALYZER FALSE POSITIVE (consistency_checker) -- 1 warning
  # ------------------------------------------------------------------------------
  # Dialyzer incorrectly infers that File.read always returns {:error, ...}
  # for paths produced by find_elixir_files. The {:ok, _} branch is valid.
  ~r"consistency_checker\.ex:\d+:\d+:pattern_match The pattern can never match",

  # ------------------------------------------------------------------------------
  # EXUNIT MACRO ARTIFACT (test_utils) -- 1 warning
  # ------------------------------------------------------------------------------
  # ExUnit.CaseTemplate macro expansion generates an unreachable false/true
  # branch. Cannot be fixed without removing the macro.
  ~r"test_utils\.ex:\d+:pattern_match",

  # ------------------------------------------------------------------------------
  # PROTOCOL FALLBACK IMPLEMENTATIONS (core_protocols) -- 13 warnings
  # ------------------------------------------------------------------------------
  # @fallback_to_any protocol impls return only default/error values, but
  # protocol specs describe the full contract for concrete implementations.
  # Dialyzer correctly flags that Any impls never produce :ok/:error variants.
  ~r"core_protocols\.ex:\d+:extra_range",
  ~r"core_protocols\.ex:\d+:contract_supertype",

  # ------------------------------------------------------------------------------
  # BROAD PUBLIC API SPECS (contract_supertype) -- 5 warnings
  # ------------------------------------------------------------------------------
  # Dialyzer narrows return types beyond what the public API intends.
  # e.g., t() vs exact struct literal, String.t() vs binary(), broad params
  # vs specific matched patterns. Specs are intentionally broader.
  ~r"app_templates\.ex:\d+:contract_supertype",
  ~r"sixel_graphics\.ex:\d+:contract_supertype",
  ~r"chart_utils\.ex:\d+:contract_supertype"
]
