defmodule RaxolPayments.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol_payments,
      version: @version,
      elixir: "~> 1.17 or ~> 1.18 or ~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      description: description(),
      package: package(),
      docs: docs(),
      name: "Raxol Payments",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Compile-time only: Action macro, CommandHook behaviour, Command struct
      {:raxol_agent, path: "../raxol_agent", runtime: false},
      {:req, "~> 0.5"},
      {:ex_secp256k1, "~> 0.8"},
      {:ex_keccak, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.0"},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Autonomous payment capabilities for Raxol agents. x402/MPP auto-pay,
    wallet management, spending controls, and cross-chain settlement.
    """
  end

  defp package do
    [
      name: "raxol_payments",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/raxol_payments"
      },
      maintainers: ["Raxol Team"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end
end
