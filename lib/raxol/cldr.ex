defmodule Raxol.Cldr do
  @moduledoc """
  Cldr backend module for Raxol with reduced locales for faster compilation.

  Originally supported 9 locales, reduced to essential locales for faster builds.
  To re-enable all locales, change locales config below.
  """

  # Minimal locale set for faster compilation in development
  locales =
    if Mix.env() == :prod do
      ["en", "fr", "de", "ja", "es", "ar", "he", "fa", "ur"]
    else
      ["en"]
    end

  # Use minimal CLDR configuration to avoid guard compilation issues
  use Cldr,
    locales: locales,
    default_locale: "en",
    providers: [Cldr.Number],
    generate_docs: false,
    suppress_warnings: true,
    force_locale_download: false,
    otp_app: :raxol

  @doc """
  Get the configured locales for this environment.
  """
  def configured_locales do
    if Mix.env() == :prod do
      ["en", "fr", "de", "ja", "es", "ar", "he", "fa", "ur"]
    else
      ["en"]
    end
  end

  @doc """
  Check if running in development mode with reduced locales.
  """
  def development_mode?,
    do: Mix.env() != :prod and length(configured_locales()) == 1
end
