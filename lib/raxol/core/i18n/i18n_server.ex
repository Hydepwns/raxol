defmodule Raxol.Core.I18n.I18nServer do
  @moduledoc """
  ETS-backed internationalization server.

  Uses ETS for fast concurrent reads (translations, locale lookups)
  with a minimal GenServer only for initialization and table ownership.
  """

  use GenServer

  @table :raxol_i18n
  @default_locale "en"

  # ============================================================================
  # Client API - Direct ETS Access (no GenServer call)
  # ============================================================================

  @doc "Translate a key with optional bindings."
  def t(_server, key, bindings \\ %{}) do
    state = get_state()
    get_translation(state, key, bindings)
  end

  @doc "Get the current locale."
  def get_locale(_server) do
    get_state().locale
  end

  @doc "Check if current locale is right-to-left."
  def rtl?(_server) do
    get_state().locale in ["ar", "he", "fa", "ur"]
  end

  @doc "Get available locales."
  def available_locales(_server) do
    get_state().translations |> Map.keys()
  end

  @doc "Format currency amount."
  def format_currency(_server, amount, currency_code) do
    format_currency_amount(amount, currency_code)
  end

  @doc "Format datetime."
  def format_datetime(_server, datetime) do
    state = get_state()
    format_datetime_value(datetime, state.timezone)
  end

  # ============================================================================
  # Client API - Writes (ETS updates, no GenServer needed)
  # ============================================================================

  @doc "Initialize the i18n system with configuration."
  def init_i18n(_server, config) do
    state = get_state()

    new_state = %{
      state
      | locale: Map.get(config, :default_locale, state.locale),
        fallback_locale: Map.get(config, :fallback_locale, state.fallback_locale),
        translations: Map.merge(state.translations, Map.get(config, :translations, %{})),
        currency: Map.get(config, :currency, state.currency),
        timezone: Map.get(config, :timezone, state.timezone)
    }

    put_state(new_state)
    :ok
  end

  @doc "Set the current locale."
  def set_locale(_server, locale) do
    update_state(fn state -> %{state | locale: locale} end)
    :ok
  end

  @doc "Add translations for a locale."
  def add_translations(_server, locale, translations) do
    update_state(fn state ->
      new_translations =
        state.translations
        |> Map.put_new(locale, %{})
        |> Map.update!(locale, &Map.merge(&1, translations))

      %{state | translations: new_translations}
    end)

    :ok
  end

  # ============================================================================
  # GenServer - Table ownership only
  # ============================================================================

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    config = Keyword.get(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @impl true
  def init(config) when is_map(config) do
    create_table()

    state = %{
      locale: Map.get(config, :default_locale, @default_locale),
      fallback_locale: Map.get(config, :fallback_locale, @default_locale),
      translations: Map.get(config, :translations, %{}),
      currency: Map.get(config, :currency, "USD"),
      timezone: Map.get(config, :timezone, "UTC")
    }

    put_state(state)
    {:ok, :no_state}
  end

  @impl true
  def init(_config), do: init(%{})

  # ============================================================================
  # Private
  # ============================================================================

  defp create_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  defp get_state do
    case :ets.lookup(@table, :state) do
      [{:state, state}] -> state
      [] -> %{locale: @default_locale, fallback_locale: @default_locale,
              translations: %{}, currency: "USD", timezone: "UTC"}
    end
  end

  defp put_state(state) do
    :ets.insert(@table, {:state, state})
  end

  defp update_state(fun) do
    put_state(fun.(get_state()))
  end

  defp get_translation(state, key, bindings) do
    case get_translation_for_locale(state.translations, state.locale, key) do
      nil ->
        case get_translation_for_locale(state.translations, state.fallback_locale, key) do
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
