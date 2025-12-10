[
  # ================================================================================
  # DIALYZER SUPPRESSIONS - Incremental Fix In Progress
  # Last updated: 2025-12-10
  # Starting errors: 1736, Current: 1153, Fixed: ~583
  # Fixed categories:
  #   - invalid_contract (~187 fixed, 9 remaining - complex struct types)
  #   - call errors (~106 fixed, 35 remaining)
  #   - contract_supertype (~190 fixed, 494 remaining)
  # Goal: Continue fixing errors by category
  # ================================================================================

  # ================================================================================
  # EXTERNAL DEPENDENCIES (Cannot fix - keep permanently)
  # ================================================================================
  ~r"^deps/",
  ~r"lib/termbox2_nif/",

  # ================================================================================
  # TEST CODE (Acceptable for tests - keep permanently)
  # ================================================================================
  ~r"^test/",

  # ================================================================================
  # DELIBERATE PATTERNS (Keep permanently)
  # ================================================================================

  # Animation/Physics mathematical operations use pattern matching for coverage
  ~r"lib/raxol/animation/.*:pattern_match_cov.*can never match.*covered by previous",

  # ================================================================================
  # KNOWN FALSE POSITIVES (Keep permanently)
  # ================================================================================

  # Private functions starting with underscore are reported as unused
  ~r":unused_fun.*Function _",

  # GenServer/Supervisor callbacks reported incorrectly
  ~r":callback_type_mismatch.*handle_",

  # ================================================================================
  # TO BE FIXED - Invalid Contracts (~9 remaining, was 196)
  # These are type specs that don't match function implementations
  # Remaining are complex struct type inference issues
  # ================================================================================
  ~r":invalid_contract",

  # ================================================================================
  # TO BE FIXED - Contract Supertypes (494 remaining, was 684)
  # Type specs that are too broad (any() when more specific type exists)
  # Fixed ~190 errors this session
  # ================================================================================
  # ~r":contract_supertype",  # DISABLED TO CONTINUE FIXING

  # ================================================================================
  # TO BE FIXED - Pattern Match Issues (99 total)
  # ================================================================================
  ~r":pattern_match",

  # ================================================================================
  # TO BE FIXED - No Return (187 total)
  # Functions reported as having no return path
  # ================================================================================
  ~r":no_return",

  # ================================================================================
  # TO BE FIXED - Callback Issues (85 total across types)
  # ================================================================================
  ~r":callback",

  # ================================================================================
  # TO BE FIXED - Call Errors (35 remaining, was 141)
  # Function calls that dialyzer thinks won't succeed
  # Fixed 106 call errors (141->35)
  # ================================================================================
  ~r":call",

  # ================================================================================
  # TO BE FIXED - Extra Range (102 total)
  # Specs with more return types than function actually returns
  # ================================================================================
  ~r":extra_range",

  # ================================================================================
  # TO BE FIXED - Other Categories
  # ================================================================================
  ~r":guard_fail",
  ~r":exact_eq",
  ~r":map_update",
  ~r":unused_fun",
  ~r":unmatched_return",
  ~r":call_without_opaque"
]
