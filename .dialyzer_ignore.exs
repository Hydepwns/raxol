[
  # ================================================================================
  # DIALYZER SUPPRESSIONS
  # ================================================================================
  #
  # Only truly unfixable warnings are suppressed here. Each is documented.
  #
  # Last updated: 2026-04
  #
  # ================================================================================

  # ------------------------------------------------------------------------------
  # BROAD PUBLIC API SPECS (contract_supertype)
  # ------------------------------------------------------------------------------
  # Dialyzer narrows return types beyond what the public API intends.
  # app_templates.ex: render/2 accepts known template names; catch-all raises
  # lifecycle.ex: handle_error spec documents all possible error recovery actions
  # chart_utils.ex: format_axis_label spec is trivially correct (number -> String.t())
  ~r"app_templates\.ex:\d+:contract_supertype",
  ~r"chart_utils\.ex:\d+:contract_supertype",
  ~r"lifecycle\.ex:\d+:contract_supertype",

  # ------------------------------------------------------------------------------
  # INTENTIONALLY BROAD SPECS (contract_supertype)
  # ------------------------------------------------------------------------------
  # These specs use broader types than dialyzer infers for API clarity.
  # file_system.ex: dir_node returns node_entry() type alias (broader than literal)
  # demo_helpers.ex: history_prev/next accept any map with required keys
  # evaluator.ex: capture_io wraps arbitrary funs (broader than specific eval types)
  # vfs_helpers.ex: print_error/format_error accept any atom error reason
  ~r"file_system\.ex:\d+:contract_supertype",
  ~r"demo_helpers\.ex:\d+:contract_supertype",
  ~r"evaluator\.ex:\d+:contract_supertype",
  ~r"vfs_helpers\.ex:\d+:contract_supertype",

  # ------------------------------------------------------------------------------
  # DIALYZER FLOW NARROWING (false positive)
  # ------------------------------------------------------------------------------
  # text_helper.ex: delete_text_range called from delete_selection which takes
  # MultiLineInput.t() -- dialyzer loses the :value key through pattern match flow
  ~r"text_helper\.ex:\d+:\d+:call"
]
