[
  # ================================================================================
  # PERMANENT SUPPRESSIONS
  # ================================================================================
  ~r"^deps/",
  ~r"lib/termbox2_nif/",
  ~r"^test/",
  ~r"lib/raxol/animation/.*:pattern_match_cov.*can never match.*covered by previous",
  ~r":unused_fun.*Function _",
  ~r":callback_type_mismatch.*handle_",

  # Compile-time conditional pattern_match errors
  ~r"driver\.ex:.*pattern_match.*type true",
  ~r"terminal_utils\.ex:.*pattern_match.*type (true|false)",
  ~r"event_system_integration\.ex:.*pattern_match.*type true",
  ~r"dcs_entry_state\.ex:.*pattern_match.*type true",
  ~r"cached_style_renderer\.ex:.*pattern_match.*type true",
  ~r"grid_container\.ex:.*pattern_match.*type true",
  ~r"display/table\.ex:.*pattern_match.*type true"
]
