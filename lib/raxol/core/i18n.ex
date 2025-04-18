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

  require Logger

  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.Accessibility

  @doc """
  Initialize the internationalization system.

  ## Options

  * `:default_locale` - The default locale to use (default: "en")
  * `:available_locales` - List of available locales (default: ["en"])
  * `:fallback_locale` - Fallback locale when translation is missing (default: "en")
  * `:translations_dir` - Directory containing translation files (default: "./priv/locales")

  ## Examples

      iex> I18n.init()
      :ok

      iex> I18n.init(default_locale: "fr", available_locales: ["en", "fr", "es"])
      :ok
  """
  def init(opts \\ []) do
    # Get configuration
    default_locale = Keyword.get(opts, :default_locale, "en")
    available_locales = Keyword.get(opts, :available_locales, ["en"])
    fallback_locale = Keyword.get(opts, :fallback_locale, "en")
    translations_dir = Keyword.get(opts, :translations_dir, "./priv/locales")

    # Store configuration
    config = %{
      default_locale: default_locale,
      available_locales: available_locales,
      fallback_locale: fallback_locale,
      translations_dir: translations_dir
    }

    Process.put(:i18n_config, config)

    # Set initial locale
    Process.put(:i18n_current_locale, default_locale)

    # Initialize translations cache
    Process.put(:i18n_translations, %{})

    # Initialize RTL locales
    rtl_locales = ["ar", "he", "fa", "ur"]
    Process.put(:i18n_rtl_locales, rtl_locales)

    # Load translations for default locale
    case load_translations(default_locale) do
      :ok ->
        # Register event handlers
        _ =
          EventManager.register_handler(
            :locale_changed,
            __MODULE__,
            :handle_locale_changed
          )

        :ok

      {:error, reason} ->
        Logger.warning(
          "Failed to load translations for default locale: #{inspect(reason)}"
        )

        :ok
    end
  end

  @doc """
  Get a translated string for the current locale.

  ## Parameters

  * `key` - The translation key
  * `bindings` - Map of variable bindings (default: %{})
  * `opts` - Additional options

  ## Options

  * `:locale` - Override the current locale
  * `:default` - Default text if translation is missing

  ## Examples

      iex> I18n.t("welcome_message")
      "Welcome to the application"

      iex> I18n.t("hello_name", %{name: "John"})
      "Hello, John!"

      iex> I18n.t("missing_key", %{}, default: "Missing translation")
      "Missing translation"
  """
  def t(key, bindings \\ %{}, opts \\ []) do
    # Get locale (from options or current)
    locale = Keyword.get(opts, :locale) || Process.get(:i18n_current_locale)

    # Get default text
    default = Keyword.get(opts, :default, key)

    # Get translations for locale
    translations = get_translations(locale)

    # Get translation or fallback
    translation =
      case Map.get(translations, key) do
        nil ->
          # Try fallback locale
          config = Process.get(:i18n_config)
          fallback_locale = Map.get(config, :fallback_locale)

          if fallback_locale && fallback_locale != locale do
            # Get translations for fallback locale
            fallback_translations = get_translations(fallback_locale)

            # Get translation from fallback or use default
            Map.get(fallback_translations, key, default)
          else
            # Use default
            default
          end

        translation ->
          translation
      end

    # Apply variable bindings
    apply_bindings(translation, bindings)
  end

  @doc """
  Check if the current locale is right-to-left (RTL).

  ## Options

  * `:locale` - Check a specific locale instead of the current one

  ## Examples

      iex> I18n.rtl?()
      false

      iex> I18n.rtl?(locale: "ar")
      true
  """
  def rtl?(opts \\ []) do
    # Get locale (from options or current)
    locale = Keyword.get(opts, :locale) || Process.get(:i18n_current_locale)

    # Get RTL locales
    rtl_locales = Process.get(:i18n_rtl_locales, [])

    # Check if current locale is RTL
    Enum.member?(rtl_locales, locale)
  end

  @doc """
  Set the current locale.

  ## Parameters

  * `locale` - The locale to set as current

  ## Examples

      iex> I18n.set_locale("fr")
      :ok

      iex> I18n.set_locale("invalid")
      {:error, :invalid_locale}
  """
  def set_locale(locale) do
    # Get config
    config = Process.get(:i18n_config)
    available_locales = Map.get(config, :available_locales, ["en"])

    # Check if locale is available
    if Enum.member?(available_locales, locale) do
      # Set current locale
      previous_locale = Process.get(:i18n_current_locale)
      Process.put(:i18n_current_locale, locale)

      # Load translations for new locale
      case load_translations(locale) do
        :ok ->
          # Broadcast event
          EventManager.broadcast({:locale_changed, previous_locale, locale})

        {:error, reason} ->
          Logger.warning(
            "Failed to load translations for locale #{locale}: #{inspect(reason)}"
          )
      end

      :ok
    else
      {:error, :invalid_locale}
    end
  end

  @doc """
  Get the current locale.

  ## Examples

      iex> I18n.get_locale()
      "en"
  """
  def get_locale do
    Process.get(:i18n_current_locale)
  end

  @doc """
  Get a list of available locales.

  ## Examples

      iex> I18n.available_locales()
      ["en", "fr", "es"]
  """
  def available_locales do
    config = Process.get(:i18n_config)
    Map.get(config, :available_locales, ["en"])
  end

  @doc """
  Format a screen reader announcement in the current locale.

  This integrates with the accessibility module to provide
  screen reader announcements in the user's preferred language.

  ## Parameters

  * `key` - The translation key for the announcement
  * `bindings` - Map of variable bindings (default: %{})
  * `opts` - Additional options

  ## Examples

      iex> I18n.announce("file_saved")
      :ok

      iex> I18n.announce("item_selected", %{item: "Document"})
      :ok
  """
  def announce(key, bindings \\ %{}, opts \\ []) do
    # Get translated message
    message = t(key, bindings, opts)

    # Make screen reader announcement
    _ = Accessibility.announce(message)
  end

  @doc """
  Register translations for a specific locale.

  ## Parameters

  * `locale` - The locale for these translations
  * `translations` - Map of translation keys to translated strings

  ## Examples

      iex> I18n.register_translations("fr", %{
      ...>   "welcome_message" => "Bienvenue dans l'application",
      ...>   "hello_name" => "Bonjour, {{name}}!"
      ...> })
      :ok
  """
  def register_translations(locale, translations) do
    # Get existing translations
    current_translations = get_translations(locale)

    # Merge with new translations
    updated_translations = Map.merge(current_translations, translations)

    # Store updated translations
    all_translations = Process.get(:i18n_translations, %{})

    updated_all_translations =
      Map.put(all_translations, locale, updated_translations)

    Process.put(:i18n_translations, updated_all_translations)

    :ok
  end

  @doc """
  Handle locale changed events.
  """
  def handle_locale_changed({:locale_changed, old_locale, new_locale}) do
    # This event handler can be used for additional actions when locale changes
    # For example, updating screen orientation for RTL languages

    # Check if RTL status changed
    old_rtl = Enum.member?(Process.get(:i18n_rtl_locales, []), old_locale)
    new_rtl = Enum.member?(Process.get(:i18n_rtl_locales, []), new_locale)

    if old_rtl != new_rtl do
      # RTL status changed, broadcast event
      EventManager.broadcast({:rtl_changed, new_rtl})
    end

    :ok
  end

  # Private functions

  defp get_translations(locale) do
    # Get all translations
    all_translations = Process.get(:i18n_translations, %{})

    # Get translations for this locale, or empty map if none
    Map.get(all_translations, locale, %{})
  end

  defp load_translations(locale) do
    # Get translations directory
    config = Process.get(:i18n_config)
    translations_dir = Map.get(config, :translations_dir)

    # Build file path
    file_path = Path.join(translations_dir, "#{locale}.json")

    # Check if file exists
    if File.exists?(file_path) do
      # Read and parse JSON
      case File.read(file_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, translations} ->
              # Register translations
              register_translations(locale, translations)
              :ok

            {:error, _} ->
              # Invalid JSON
              {:error, :invalid_json}
          end

        {:error, _} ->
          # Could not read file
          {:error, :file_read_error}
      end
    else
      # File doesn't exist - no translations available
      # This isn't necessarily an error, as we may have in-memory translations
      :ok
    end
  end

  defp apply_bindings(translation, bindings) do
    # Apply variable bindings to the translation string
    # Replace patterns like {{variable}} with the value from bindings
    Enum.reduce(bindings, translation, fn {key, value}, acc ->
      pattern = "{{#{key}}}"
      String.replace(acc, pattern, to_string(value))
    end)
  end
end
