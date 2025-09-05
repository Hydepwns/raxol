defmodule Raxol.Core.I18n.Server do
  @moduledoc """
  GenServer for managing internationalization state.

  This server maintains all i18n state in a supervised, fault-tolerant manner,
  replacing the Process dictionary usage with proper OTP patterns.

  ## Features
  - Translation management
  - Locale switching
  - RTL language support
  - Currency and datetime formatting
  - Integration with accessibility
  """

  use GenServer

  alias Cldr
  alias Raxol.Core.ErrorHandling

  defstruct [
    :config,
    :event_manager,
    :accessibility_module,
    :current_locale,
    :translations,
    :rtl_locales
  ]

  # Client API

  @doc """
  Starts the I18n server.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    config = Keyword.get(opts, :config, %{})
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Initialize the i18n framework with configuration.
  """
  def init_i18n(server \\ __MODULE__, config \\ []) do
    GenServer.call(server, {:init_i18n, config})
  end

  @doc """
  Get a translated string for the given key.
  """
  def translate(server \\ __MODULE__, key, bindings \\ %{}) do
    GenServer.call(server, {:translate, key, bindings})
  end

  @doc """
  Shorthand for translate/3.
  """
  def t(server \\ __MODULE__, key, bindings \\ %{}) do
    translate(server, key, bindings)
  end

  @doc """
  Set the current locale.
  """
  def set_locale(server \\ __MODULE__, locale) do
    GenServer.call(server, {:set_locale, locale})
  end

  @doc """
  Get the current locale.
  """
  def get_locale(server \\ __MODULE__) do
    GenServer.call(server, :get_locale)
  end

  @doc """
  Check if the current locale is right-to-left.
  """
  def rtl?(server \\ __MODULE__) do
    GenServer.call(server, :rtl?)
  end

  @doc """
  Format a currency amount according to the current locale.
  """
  def format_currency(server \\ __MODULE__, amount, currency_code) do
    GenServer.call(server, {:format_currency, amount, currency_code})
  end

  @doc """
  Format a datetime according to the current locale.
  """
  def format_datetime(server \\ __MODULE__, datetime) do
    GenServer.call(server, {:format_datetime, datetime})
  end

  @doc """
  Get all available locales.
  """
  def available_locales(server \\ __MODULE__) do
    GenServer.call(server, :available_locales)
  end

  @doc """
  Add or update translations for a locale.
  """
  def add_translations(server \\ __MODULE__, locale, translations) do
    GenServer.call(server, {:add_translations, locale, translations})
  end

  # Server Callbacks

  @impl GenServer
  def init(config) do
    config_map = if is_list(config), do: Enum.into(config, %{}), else: config

    state = %__MODULE__{
      config: config_map,
      event_manager:
        Map.get(config_map, :event_manager, Raxol.Core.Events.Manager),
      accessibility_module:
        Map.get(config_map, :accessibility_module, Raxol.Core.Accessibility),
      current_locale: Map.get(config_map, :default_locale, "en"),
      translations: %{},
      rtl_locales: Map.get(config_map, :rtl_locales, ["ar", "he", "fa", "ur"])
    }

    # Load default translations
    {:ok, load_translations(state, state.current_locale)}
  end

  @impl GenServer
  def handle_call({:init_i18n, config}, _from, state) do
    config_map = if is_list(config), do: Enum.into(config, %{}), else: config

    new_state = %{
      state
      | config: Map.merge(state.config, config_map),
        event_manager: Map.get(config_map, :event_manager, state.event_manager),
        accessibility_module:
          Map.get(config_map, :accessibility_module, state.accessibility_module),
        current_locale:
          Map.get(config_map, :default_locale, state.current_locale),
        rtl_locales: Map.get(config_map, :rtl_locales, state.rtl_locales)
    }

    new_state = load_translations(new_state, new_state.current_locale)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:translate, key, bindings}, _from, state) do
    locale = state.current_locale
    fallback_locale = Map.get(state.config, :fallback_locale, "en")

    template =
      get_in(state.translations, [locale, key]) ||
        get_in(state.translations, [fallback_locale, key]) ||
        key

    # Use EEx to evaluate the template with bindings
    translated =
      case ErrorHandling.safe_call(fn ->
             EEx.eval_string(template, bindings: bindings)
           end) do
        {:ok, result} -> result
        {:error, _} -> template
      end

    {:reply, translated, state}
  end

  @impl GenServer
  def handle_call({:set_locale, locale}, _from, state) do
    available_locales = Map.get(state.config, :available_locales, ["en"])
    handle_locale_change(Enum.member?(available_locales, locale), locale, state)
  end

  defp handle_locale_change(false, _locale, state) do
    {:reply, {:error, :locale_not_available}, state}
  end

  defp handle_locale_change(true, locale, state) do
    previous_locale = state.current_locale
    new_state = %{state | current_locale: locale}
    new_state = load_translations(new_state, locale)

    # Broadcast locale change event
    broadcast_locale_event(state.event_manager, previous_locale, locale, new_state)
    {:reply, :ok, new_state}
  end

  defp broadcast_locale_event(nil, _previous_locale, _locale, _state), do: :ok
  defp broadcast_locale_event(event_manager, previous_locale, locale, new_state) do
    event = {:locale_changed, previous_locale, locale}
    event_manager.broadcast(event)
    handle_locale_changed(event, new_state)
  end

  @impl GenServer
  def handle_call(:get_locale, _from, state) do
    {:reply, state.current_locale, state}
  end

  @impl GenServer
  def handle_call(:rtl?, _from, state) do
    is_rtl = Enum.member?(state.rtl_locales, state.current_locale)
    {:reply, is_rtl, state}
  end

  @impl GenServer
  def handle_call({:format_currency, amount, currency_code}, _from, state)
      when is_number(amount) and is_binary(currency_code) do
    formatted =
      case ErrorHandling.safe_call(fn ->
             case Cldr.Number.to_string(amount,
                    currency: currency_code,
                    backend: Raxol.Cldr,
                    locale: state.current_locale
                  ) do
               {:ok, formatted} -> formatted
               {:error, _} -> "#{currency_code} #{amount}"
             end
           end) do
        {:ok, result} -> result
        {:error, _} -> "#{currency_code} #{amount}"
      end

    {:reply, formatted, state}
  end

  @impl GenServer
  def handle_call({:format_datetime, datetime}, _from, state)
      when is_struct(datetime, DateTime) do
    formatted =
      case ErrorHandling.safe_call(fn ->
             case Cldr.DateTime.to_string(datetime,
                    backend: Raxol.Cldr,
                    locale: state.current_locale
                  ) do
               {:ok, formatted} -> formatted
               {:error, _} -> DateTime.to_string(datetime)
             end
           end) do
        {:ok, result} -> result
        {:error, _} -> DateTime.to_string(datetime)
      end

    {:reply, formatted, state}
  end

  @impl GenServer
  def handle_call(:available_locales, _from, state) do
    locales = Map.get(state.config, :available_locales, ["en"])
    {:reply, locales, state}
  end

  @impl GenServer
  def handle_call({:add_translations, locale, translations}, _from, state) do
    updated_translations =
      Map.update(
        state.translations,
        locale,
        translations,
        &Map.merge(&1, translations)
      )

    new_state = %{state | translations: updated_translations}
    {:reply, :ok, new_state}
  end

  # Private Functions

  defp load_translations(state, locale) do
    # Default translations - in production, load from files
    default_translations =
      case locale do
        "fr" ->
          %{
            "welcome_message" => "Bienvenue!",
            "hello_name" => "Bonjour, <%= @name %>!",
            "test_announcement" => "Ceci est une annonce de test",
            "loading" => "Chargement...",
            "error" => "Erreur",
            "success" => "Succès"
          }

        "es" ->
          %{
            "welcome_message" => "¡Bienvenido!",
            "hello_name" => "¡Hola, <%= @name %>!",
            "test_announcement" => "Este es un anuncio de prueba",
            "loading" => "Cargando...",
            "error" => "Error",
            "success" => "Éxito"
          }

        "ar" ->
          %{
            "welcome_message" => "مرحبا!",
            "hello_name" => "مرحبا، <%= @name %>!",
            "test_announcement" => "هذا إعلان اختبار",
            "loading" => "جار التحميل...",
            "error" => "خطأ",
            "success" => "نجاح"
          }

        _ ->
          %{
            "welcome_message" => "Welcome!",
            "hello_name" => "Hello, <%= @name %>!",
            "test_announcement" => "This is a test announcement",
            "loading" => "Loading...",
            "error" => "Error",
            "success" => "Success"
          }
      end

    updated_translations =
      Map.put(state.translations, locale, default_translations)

    %{state | translations: updated_translations}
  end

  defp handle_locale_changed({:locale_changed, old_locale, new_locale}, state) do
    old_rtl = Enum.member?(state.rtl_locales, old_locale)
    new_rtl = Enum.member?(state.rtl_locales, new_locale)

    handle_rtl_change(old_rtl != new_rtl, state.event_manager, new_rtl)
    update_accessibility_direction(state.accessibility_module, new_rtl)
    :ok
  end

  defp handle_rtl_change(false, _event_manager, _new_rtl), do: :ok
  defp handle_rtl_change(true, nil, _new_rtl), do: :ok
  defp handle_rtl_change(true, event_manager, new_rtl) do
    event_manager.broadcast({:rtl_changed, new_rtl})
  end

  defp update_accessibility_direction(nil, _new_rtl), do: :ok
  defp update_accessibility_direction(accessibility_module, new_rtl) do
    direction = get_direction(new_rtl)
    accessibility_module.set_option(:direction, direction)
  end

  defp get_direction(true), do: :rtl
  defp get_direction(false), do: :ltr
end
