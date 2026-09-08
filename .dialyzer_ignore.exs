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

  # palette.ex: every one of these public functions is an accessor returning a
  # literal table (color lists, name->slot maps, semantic-token maps).
  # Dialyzer infers the exact literal -- `unknown_atom_rgb/0` as
  # `{128, 128, 128}`, `ansi_16_codes/0` as a 16-key map with singleton
  # integer values -- so any spec written as documentation (`rgb()`,
  # `%{atom() => 0..15}`) is by construction a supertype. Specing the literals
  # instead would make the contract useless to a reader and would have to be
  # edited every time a color changed.
  #
  # Named one by one rather than as `palette\.ex:\d+:contract_supertype`. That
  # form suppressed EVERY contract_supertype in the file at any line, forever,
  # in the module this change designates the single source of colour truth --
  # so a genuinely wrong spec on a function added later would be masked from
  # the moment it was written, and the ratchet could never resurface it.
  ~r"theming/palette\.ex:\d+:contract_supertype Type specification for (ansi_16|ansi_16_codes|ansi_16_names|ansi_16_variants|near_black_surface_rgb|platform_palette|renderer_defaults|salience_darcula_seeds|semantic_default_families|semantic_defaults|unknown_atom_rgb) is a supertype",

  # text_helper.ex: dialyzer narrows MultiLineInput.t() to %{lines: [binary()]}
  # through pattern match flow in delete_selection, losing the :value key that
  # delete_text_range needs via with_lines. False positive from flow narrowing.
  ~r"text_helper\.ex:\d+:\d+:call"
]
