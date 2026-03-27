defmodule Mix.Tasks.Raxol.Repl do
  @shortdoc "Launch an interactive Elixir REPL in the terminal"
  @moduledoc """
  Interactive Elixir REPL powered by Raxol's terminal UI.

      $ mix raxol.repl

  Evaluates Elixir expressions with persistent bindings, IO capture,
  and sandboxed execution. Variables defined in one expression are
  available in subsequent ones.

  ## Options

    * `--sandbox` - Safety level: `none`, `standard` (default), `strict`
    * `--timeout` - Eval timeout in milliseconds (default: 5000)
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [sandbox: :string, timeout: :integer],
        aliases: [s: :sandbox, t: :timeout]
      )

    Mix.Task.run("app.start")

    sandbox =
      case opts[:sandbox] do
        "none" -> :none
        "strict" -> :strict
        _ -> :standard
      end

    timeout = Keyword.get(opts, :timeout, 5_000)

    Application.put_env(:raxol, :repl_sandbox, sandbox)
    Application.put_env(:raxol, :repl_timeout, timeout)

    {:ok, pid} = Raxol.start_link(Raxol.Playground.Demos.ReplDemo, [])
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end
end
