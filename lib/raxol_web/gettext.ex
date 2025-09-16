defmodule RaxolWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.
  """

  use Gettext.Backend, otp_app: :raxol

  @doc """
  Get the current locale.
  """
  def get_locale do
    Gettext.get_locale(__MODULE__)
  end

  @doc """
  Get available locales.
  """
  def available_locales do
    Gettext.known_locales(__MODULE__)
  end

  @doc """
  Check if locale is right-to-left.
  """
  def rtl?(locale) do
    locale in ["ar", "he", "fa", "ur"]
  end

  @doc """
  Translate a message.
  """
  def t(msgid, bindings \\ []) do
    Gettext.dgettext(__MODULE__, "default", msgid, bindings)
  end

  @doc """
  Translate a message with domain.
  """
  def t(domain, msgid, bindings) do
    Gettext.dgettext(__MODULE__, domain, msgid, bindings)
  end
end
