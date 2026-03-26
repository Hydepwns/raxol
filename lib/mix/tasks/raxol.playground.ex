defmodule Mix.Tasks.Raxol.Playground do
  @shortdoc "Launch the Raxol component playground"
  @moduledoc """
  Interactive terminal playground for browsing Raxol widgets.

      $ mix raxol.playground

  Browse components with j/k, select with Enter, Tab to switch between
  the sidebar and the live demo. Press c to view code snippets,
  / to search, q to quit.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, pid} = Raxol.start_link(Raxol.Playground.App, [])
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end
end
