defmodule Termbox2Nif.MixProject do
  use Mix.Project

  def project do
    [
      app: :termbox2_nif,
      version: "0.3.1",
      elixir: "~> 1.0",
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_clean: ["clean"],
      make_cwd: "c_src",
      make_env: %{
        "ERL_EI_INCLUDE_DIR" => "#{:code.root_dir()}/usr/include",
        "ERL_EI_LIBDIR" => "#{:code.root_dir()}/usr/lib",
        "MIX_ENV" => "#{Mix.env()}"
      },
      description: "Termbox2 NIF for Elixir",
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.7", runtime: false}
    ]
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
