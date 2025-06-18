defmodule JSON.MixProject do
  use Mix.Project

  def project do
    [
      app: :json,
      version: "1.4.2",
      elixir: "~> 1.0",
      description:
        "Raxol's fork of the JSON parser and generator in pure Elixir",
      package: package(),
      deps: []
    ]
  end

  def application do
    [applications: []]
  end

  defp package do
    [
      maintainers: ["hydepwns"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/hydepwns/elixir-json"}
    ]
  end
end
