[
  # raxol_agent is a compile-time-only dep (runtime: false).
  # Dialyzer cannot see the BEAM files for these modules,
  # but they are available at compile time via the path dep.

  # Action behaviour and macro-injected functions
  {"lib/raxol/payments/actions/payments/get_balance.ex", :callback_info_missing},
  {"lib/raxol/payments/actions/payments/get_balance.ex", :unknown_function},
  {"lib/raxol/payments/actions/payments/get_quote.ex", :callback_info_missing},
  {"lib/raxol/payments/actions/payments/get_quote.ex", :unknown_function},
  {"lib/raxol/payments/actions/payments/list_history.ex", :callback_info_missing},
  {"lib/raxol/payments/actions/payments/list_history.ex", :unknown_function},
  {"lib/raxol/payments/actions/payments/spending_status.ex", :callback_info_missing},
  {"lib/raxol/payments/actions/payments/spending_status.ex", :unknown_function},
  {"lib/raxol/payments/actions/payments/transfer.ex", :callback_info_missing},
  {"lib/raxol/payments/actions/payments/transfer.ex", :unknown_function},

  # CommandHook behaviour from raxol_agent
  {"lib/raxol/payments/spending_hook.ex", :callback_info_missing}
]
