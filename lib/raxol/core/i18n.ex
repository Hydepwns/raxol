defmodule Raxol.Core.I18n do
  @moduledoc """
  Internationalization framework for Raxol terminal UI applications.

  This module provides comprehensive internationalization (i18n) support:
  - Translation of UI text to multiple languages
  - Right-to-left (RTL) language support
  - Integration with accessibility features
  - Language detection and selection
  - Translation fallbacks
  - Dynamic language switching

  The framework works seamlessly with the accessibility module to provide
  screen reader announcements in the user's preferred language.

  ## Usage

  ```elixir
  # Initialize with default locale
  I18n.init(default_locale: "en")

  # Get a translated string
  message = I18n.t("welcome_message")

  # Get a translated string with variables
  greeting = I18n.t("hello_name", %{name: "John"})

  # Switch to a different locale
  I18n.set_locale("fr")

  # Check if the current locale is RTL
  is_rtl = I18n.rtl?()
  ```
  """

  alias Cldr

  # Public API

  @doc """
  Initialize the i18n framework.
  """
  def init(config \\ []) do
    config_map = Enum.into(config, %{})
    Process.put(:i18n_config, config_map)

    Process.put(
      :i18n_event_manager,
      Map.get(config_map, :event_manager, Raxol.Core.Events.Manager)
    )

    Process.put(
      :i18n_accessibility_module,
      Map.get(config_map, :accessibility_module, Raxol.Core.Accessibility)
    )

    Process.put(:i18n_current_locale, Map.get(config_map, :default_locale))
    Process.put(:i18n_translations, %{})
    Process.put(:i18n_rtl_locales, Map.get(config_map, :rtl_locales, []))
    load_translations(Map.get(config_map, :default_locale))
    :ok
  end

  @doc """
  Get a translated string for the given key.
  """
  def t(key, bindings \\ %{}) do
    locale = get_locale()
    translations = Process.get(:i18n_translations)
    config = Process.get(:i18n_config)
    fallback_locale = Map.get(config, :fallback_locale)
    template = get_in(translations, [locale, key]) || get_in(translations, [fallback_locale, key]) || key
    EEx.eval_string(template, bindings: bindings)
  end

  @doc """
  Set the current locale.
  """
  def set_locale(locale) do
    config = Process.get(:i18n_config)
    available_locales = Map.get(config, :available_locales, ["en"])
    event_manager = Process.get(:i18n_event_manager)

    if Enum.member?(available_locales, locale) do
      previous_locale = Process.get(:i18n_current_locale)
      Process.put(:i18n_current_locale, locale)
      load_translations(locale)
      event = {:locale_changed, previous_locale, locale}
      event_manager.broadcast(event)
      handle_locale_changed(event)
      :ok
    else
      {:error, :locale_not_available}
    end
  end

  @doc """
  Get the current locale.
  """
  def get_locale do
    Process.get(:i18n_current_locale, "en")
  end

  @doc """
  Check if the current locale is right-to-left.
  """
  def rtl? do
    Enum.member?(Process.get(:i18n_rtl_locales, []), get_locale())
  end

  @doc """
  Handle locale changed events.
  """
  def handle_locale_changed({:locale_changed, old_locale, new_locale}) do
    old_rtl = Enum.member?(Process.get(:i18n_rtl_locales, []), old_locale)
    new_rtl = Enum.member?(Process.get(:i18n_rtl_locales, []), new_locale)
    event_manager = Process.get(:i18n_event_manager)
    accessibility = Process.get(:i18n_accessibility_module)

    if old_rtl != new_rtl do
      event_manager.broadcast({:rtl_changed, new_rtl})
    end

    direction = if new_rtl, do: :rtl, else: :ltr
    accessibility.set_option(:direction, direction)

    :ok
  end

  @doc """
  Format a currency amount according to the current locale.
  """
  def format_currency(amount, currency_code) when is_number(amount) and is_binary(currency_code) do
    locale = get_locale()
    case Cldr.Number.to_string(amount, currency: currency_code, backend: Raxol.Cldr, locale: locale) do
      {:ok, formatted} -> formatted
      {:error, {exception, _}} -> raise exception
    end
  end

  @doc """
  Format a datetime according to the current locale.
  """
  def format_datetime(datetime) when is_struct(datetime, DateTime) do
    locale = get_locale()
    case Cldr.DateTime.to_string(datetime, backend: Raxol.Cldr, locale: locale) do
      {:ok, formatted} -> formatted
      {:error, {exception, _}} -> raise exception
    end
  end

  # Private functions

  defp load_translations(locale) do
    # In a real application, this would load translations from a file
    # For now, we'll just use a map
    translations =
      case locale do
        "fr" ->
          %{
            "welcome_message" => "Bienvenue!",
            "hello_name" => "Bonjour, %{name}!",
            "test_announcement" => "Ceci est une annonce de test"
          }
        _ ->
          %{
            "welcome_message" => "Welcome!",
            "hello_name" => "Hello, %{name}!",
            "test_announcement" => "This is a test announcement"
          }
      end

    Process.put(:i18n_translations, Map.put(Process.get(:i18n_translations), locale, translations))
    :ok
  end

  @doc """
  Clean up i18n resources.
  """
  def cleanup do
    Process.delete(:i18n_config)
    Process.delete(:i18n_event_manager)
    Process.delete(:i18n_accessibility_module)
    Process.delete(:i18n_current_locale)
    Process.delete(:i18n_translations)
    Process.delete(:i18n_rtl_locales)
    :ok
  end
end
