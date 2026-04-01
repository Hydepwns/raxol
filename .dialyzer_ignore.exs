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
  # PROTOCOL FALLBACK IMPLEMENTATIONS (core_protocols) -- 13 warnings
  # ------------------------------------------------------------------------------
  # @fallback_to_any protocol impls return only default/error values, but
  # protocol specs describe the full contract for concrete implementations.
  # Dialyzer correctly flags that Any impls never produce :ok/:error variants.
  ~r"core_protocols\.ex:\d+:extra_range",
  ~r"core_protocols\.ex:\d+:contract_supertype",

  # ------------------------------------------------------------------------------
  # BROAD PUBLIC API SPECS (contract_supertype)
  # ------------------------------------------------------------------------------
  # Dialyzer narrows return types beyond what the public API intends.
  ~r"app_templates\.ex:\d+:contract_supertype",
  ~r"chart_utils\.ex:\d+:contract_supertype",
  ~r"lifecycle\.ex:\d+:contract_supertype"
]
