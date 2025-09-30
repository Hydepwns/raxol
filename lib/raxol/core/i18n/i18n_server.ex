defmodule Raxol.Core.I18n.I18nServer do
  @moduledoc """
  GenServer-based internationalization server.

  Provides state management for i18n functionality without using
  the Process dictionary, making it more robust and testable.
  """

  use GenServer
  require Logger

  @default_locale "en"
  @default_config %{
    default_locale: @default_locale,
    fallback_locale: @default_locale,
    translations: %{},
    currency: "USD",
    timezone: "UTC"
  }

  defstruct [
    :locale,
    :fallback_locale,
    :translations,
    :currency,
    :timezone,
    :config
  ]

  # Client API

  @doc """
  Starts the I18n server.
  """
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    config = Keyword.get(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Initialize the i18n system with configuration.
  """
  def init_i18n(server, config) do
    GenServer.call(server, {:init_i18n, config})
  end

  @doc """
  Translate a key with optional bindings.
  """
  def t(server, key, bindings \\ %{}) do
    GenServer.call(server, {:translate, key, bindings})
  end

  @doc """
  Set the current locale.
  """
  def set_locale(server, locale) do
    GenServer.call(server, {:set_locale, locale})
  end

  @doc """
  Get the current locale.
  """
  def get_locale(server) do
    GenServer.call(server, :get_locale)
  end

  @doc """
  Check if current locale is right-to-left.
  """
  def rtl?(server) do
    GenServer.call(server, :rtl?)
  end

  @doc """
  Format currency amount.
  """
  def format_currency(server, amount, currency_code) do
    GenServer.call(server, {:format_currency, amount, currency_code})
  end

  @doc """
  Format datetime.
  """
  def format_datetime(server, datetime) do
    GenServer.call(server, {:format_datetime, datetime})
  end

  @doc """
  Get available locales.
  """
  def available_locales(server) do
    GenServer.call(server, :available_locales)
  end

  @doc """
  Add translations for a locale.
  """
  def add_translations(server, locale, translations) do
    GenServer.call(server, {:add_translations, locale, translations})
  end

  # Server callbacks

  @impl true
  def init(config) when is_map(config) do
    state = %__MODULE__{
      locale: Map.get(config, :default_locale, @default_locale),
      fallback_locale: Map.get(config, :fallback_locale, @default_locale),
      translations: Map.get(config, :translations, %{}),
      currency: Map.get(config, :currency, "USD"),
      timezone: Map.get(config, :timezone, "UTC"),
      config: Map.merge(@default_config, config)
    }

    {:ok, state}
  end

  @impl true
  def init(_config) do
    init(%{})
  end

  @impl true
  def handle_call({:init_i18n, config}, _from, state) do
    new_state = %{
      state
      | locale: Map.get(config, :default_locale, state.locale),
        fallback_locale:
          Map.get(config, :fallback_locale, state.fallback_locale),
        translations:
          Map.merge(state.translations, Map.get(config, :translations, %{})),
        currency: Map.get(config, :currency, state.currency),
        timezone: Map.get(config, :timezone, state.timezone),
        config: Map.merge(state.config, config)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:translate, key, bindings}, _from, state) do
    translation = get_translation(state, key, bindings)
    {:reply, translation, state}
  end

  @impl true
  def handle_call({:set_locale, locale}, _from, state) do
    new_state = %{state | locale: locale}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_locale, _from, state) do
    {:reply, state.locale, state}
  end

  @impl true
  def handle_call(:rtl?, _from, state) do
    rtl_locales = ["ar", "he", "fa", "ur"]
    is_rtl = state.locale in rtl_locales
    {:reply, is_rtl, state}
  end

  @impl true
  def handle_call({:format_currency, amount, currency_code}, _from, state) do
    formatted = format_currency_amount(amount, currency_code)
    {:reply, formatted, state}
  end

  @impl true
  def handle_call({:format_datetime, datetime}, _from, state) do
    formatted = format_datetime_value(datetime, state.timezone)
    {:reply, formatted, state}
  end

  @impl true
  def handle_call(:available_locales, _from, state) do
    locales = Map.keys(state.translations)
    {:reply, locales, state}
  end

  @impl true
  def handle_call({:add_translations, locale, translations}, _from, state) do
    new_translations =
      state.translations
      |> Map.put_new(locale, %{})
      |> Map.update!(locale, &Map.merge(&1, translations))

    new_state = %{state | translations: new_translations}
    {:reply, :ok, new_state}
  end

  # Private functions

  defp get_translation(state, key, bindings) do
    case get_translation_for_locale(state.translations, state.locale, key) do
      nil ->
        case get_translation_for_locale(
               state.translations,
               state.fallback_locale,
               key
             ) do
          nil -> key
          translation -> interpolate(translation, bindings)
        end

      translation ->
        interpolate(translation, bindings)
    end
  end

  defp get_translation_for_locale(translations, locale, key) do
    translations
    |> Map.get(locale, %{})
    |> Map.get(key)
  end

  defp interpolate(template, bindings) when is_map(bindings) do
    Enum.reduce(bindings, template, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp interpolate(template, _bindings), do: template

  defp format_currency_amount(amount, currency_code) do
    formatted_amount = :erlang.float_to_binary(amount / 100.0, decimals: 2)

    case currency_code do
      "USD" -> "$#{formatted_amount}"
      "EUR" -> "EUR #{formatted_amount}"
      "GBP" -> "GBP #{formatted_amount}"
      _ -> "#{currency_code} #{formatted_amount}"
    end
  end

  defp format_datetime_value(%DateTime{} = datetime, _timezone) do
    DateTime.to_string(datetime)
  end

  defp format_datetime_value(datetime, _timezone) when is_binary(datetime) do
    datetime
  end

  defp format_datetime_value(datetime, _timezone) do
    to_string(datetime)
  end
end
