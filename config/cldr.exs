use Mix.Config

# Configure the CLDR backend
config :raxol, Raxol.Cldr,
  locales: ["en", "fr", "de", "ja", "es", "ar", "he", "fa", "ur"],
  default_locale: "en",
  gettext: RaxolWeb.Gettext,
  precompile_number_formats: ["¤¤#,##0.00"],
  data_dir: "priv/cldr",
  otp_app: :raxol
