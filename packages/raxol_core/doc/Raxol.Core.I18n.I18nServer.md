# `Raxol.Core.I18n.I18nServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/i18n/i18n_server.ex#L1)

ETS-backed internationalization server.

Uses ETS for fast concurrent reads (translations, locale lookups)
with a minimal GenServer only for initialization and table ownership.

# `add_translations`

Add translations for a locale.

# `available_locales`

Get available locales.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `format_currency`

Format currency amount.

# `format_datetime`

Format datetime.

# `get_locale`

Get the current locale.

# `init_i18n`

Initialize the i18n system with configuration.

# `rtl?`

Check if current locale is right-to-left.

# `set_locale`

Set the current locale.

# `start_link`

# `t`

Translate a key with optional bindings.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
