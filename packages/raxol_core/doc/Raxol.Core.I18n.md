# `Raxol.Core.I18n`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/i18n.ex#L1)

Refactored internationalization module using GenServer for state management.

This module provides the same API as the original I18n module but delegates
all state management to a supervised GenServer, eliminating Process dictionary usage.

## Migration Guide

1. Add the I18n.I18nServer to your supervision tree:

    children = [
      {Raxol.Core.I18n.I18nServer, name: Raxol.Core.I18n.I18nServer, config: config}
    ]

2. Replace `Raxol.Core.I18n` with `Raxol.Core.I18n` in your code

3. All API calls remain the same

# `add_translations`

Add or update translations for a locale.

## Examples

    iex> I18n.add_translations("en", %{
    ...>   "new_key" => "New translation",
    ...>   "another_key" => "Another translation"
    ...> })
    :ok

# `available_locales`

Get all available locales.

# `cleanup`

Clean up i18n resources.

With GenServer, cleanup happens automatically when the server stops.

# `format_currency`

Format a currency amount according to the current locale.

## Examples

    iex> I18n.format_currency(1234.56, "USD")
    "$1,234.56"

    iex> I18n.set_locale("fr")
    iex> I18n.format_currency(1234.56, "EUR")
    "1 234,56 €"

# `format_datetime`

Format a datetime according to the current locale.

## Examples

    iex> dt = DateTime.utc_now()
    iex> I18n.format_datetime(dt)
    "December 12, 2025 at 3:45 PM"

# `get_locale`

Get the current locale.

## Examples

    iex> I18n.get_locale()
    "en"

# `handle_locale_changed`

Handle locale changed events.

This is now handled internally by the server.

# `init`

Initialize the i18n framework.

Now initializes the GenServer state instead of Process dictionary.

# `rtl?`

Check if the current locale is right-to-left.

## Examples

    iex> I18n.set_locale("ar")
    iex> I18n.rtl?()
    true

    iex> I18n.set_locale("en")
    iex> I18n.rtl?()
    false

# `set_locale`

Set the current locale.

## Examples

    iex> I18n.set_locale("fr")
    :ok

    iex> I18n.set_locale("invalid")
    {:error, :locale_not_available}

# `t`

Get a translated string for the given key.

## Examples

    iex> I18n.t("welcome_message")
    "Welcome!"

    iex> I18n.t("hello_name", %{name: "John"})
    "Hello, John!"

---

*Consult [api-reference.md](api-reference.md) for complete listing*
