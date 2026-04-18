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
  # These specs intentionally document the public interface more broadly than
  # dialyzer can prove from the implementation.

  # app_templates.ex: render/2 accepts String.t() but only has clauses for
  # specific template literals ("blank", "counter", etc). The catch-all raises.
  ~r"app_templates\.ex:\d+:contract_supertype",

  # helpers.ex: animate/2 returns map() but dialyzer infers
  # %{animation_hints: nonempty_list()}. The spec documents the general contract.
  ~r"helpers\.ex:\d+:contract_supertype",

  # demo_helpers.ex: history_prev/next use map() for models with required keys.
  # Elixir's type system can't express "map with at least these keys."
  ~r"demo_helpers\.ex:\d+:contract_supertype",

  # text_helper.ex: dialyzer narrows MultiLineInput.t() to %{lines: [binary()]}
  # through pattern match flow in delete_selection, losing the :value key that
  # delete_text_range needs via with_lines. False positive from flow narrowing.
  ~r"text_helper\.ex:\d+:\d+:call"
]
