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
  ~r"lifecycle\.ex:\d+:contract_supertype"
]
