defmodule RaxolWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.
  """

  use Gettext.Backend, otp_app: :raxol

  @doc """
  Gets the current locale.
  """
  def get_locale do
    Gettext.get_locale(__MODULE__)
  end

  @doc """
  Gets available locales.
  """
  def available_locales do
    Gettext.known_locales(__MODULE__)
  end

  @doc """
  Checks if the current locale is right-to-left.
  """
  def rtl? do
    locale = get_locale()
    rtl?(locale)
  end

  @doc """
  Checks if the given locale is right-to-left.
  """
  def rtl?(locale) when is_binary(locale) do
    rtl_locales = ["ar", "he", "fa", "ur"]
    locale in rtl_locales
  end

  def rtl?(_), do: false

  @doc """
  Gets a translated string for the given key.
  """
  def t(key, bindings \\ %{}) do
    Gettext.dgettext(__MODULE__, "default", key, bindings)
  end

  @doc """
  Gets a translated string for the given key with locale.
  """
  def t(key, bindings, opts) do
    locale = Keyword.get(opts, :locale, get_locale())
    default = Keyword.get(opts, :default, key)

    case Gettext.dgettext(__MODULE__, "default", key, bindings) do
      ^key -> default
      translated -> translated
    end
  end
end
