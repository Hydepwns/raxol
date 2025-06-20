defmodule Raxol.Cldr do
  @moduledoc """
  Cldr backend module for Raxol.
  """
  use Cldr,
    locales: ["en", "fr", "de", "ja", "es", "ar", "he", "fa", "ur"],
    default_locale: "en",
    gettext: RaxolWeb.Gettext,
    data_dir: "priv/cldr",
    providers: [Cldr.DateTime, Cldr.Number, Cldr.Currency, Cldr.Calendar],
    otp_app: :raxol
end
