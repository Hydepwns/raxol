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
  ~r"app_templates\.ex:\d+:contract_supertype",
  ~r"chart_utils\.ex:\d+:contract_supertype",
  ~r"lifecycle\.ex:\d+:contract_supertype"
]
