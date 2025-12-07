defmodule Termbox2Nif.MixProject do
  use Mix.Project

  def project do
    base_config = [
      app: :termbox2_nif,
      version: "0.3.1",
      elixir: "~> 1.0",
      description: "Termbox2 NIF for Elixir (Unix platforms only)",
      package: package(),
      deps: deps()
    ]

    # Only compile NIF on Unix systems
    # Windows will use pure Elixir driver in Raxol.Terminal.Driver
    case :os.type() do
      {:unix, _} ->
        Keyword.merge(base_config, compile_nif_config())

      {:win32, _} ->
        Mix.shell().info("""
        [termbox2_nif] Skipping NIF compilation on Windows.
        Raxol will use pure Elixir terminal driver instead.
        """)

        base_config
    end
  end

  defp compile_nif_config do
    [
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_clean: ["clean"],
      make_cwd: "c_src",
      make_env: %{
        "ERL_EI_INCLUDE_DIR" => "#{:code.root_dir()}/usr/include",
        "ERL_EI_LIBDIR" => "#{:code.root_dir()}/usr/lib",
        "MIX_ENV" => "#{Mix.env()}"
      }
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    case :os.type() do
      {:unix, _} ->
        [{:elixir_make, "~> 0.7", runtime: false}]

      {:win32, _} ->
        # No elixir_make dependency on Windows
        []
    end
  end

  defp package do
    [
      name: :termbox2_nif,
      files: [
        "lib",
        "c_src",
        "mix.exs",
        "c_src/Makefile*",
        "README.md",
        "LICENSE"
      ],
      maintainers: ["hydepwns"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/hydepwns/termbox2_nif"}
    ]
  end
end
