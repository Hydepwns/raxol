defmodule Mix.Tasks.Raxol.Debugger do
  @shortdoc "Launch the interactive time-travel debugger UI"
  @moduledoc """
  Interactive debugger for time-travel debugging Raxol TEA applications.

      $ mix raxol.debugger

  Connects to the default `Raxol.Debug.TimeTravel` process. Use `--import`
  to load an exported snapshot file for offline inspection.

  ## Options

    * `--import PATH` - Import snapshots from a .bin export file
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [import: :string],
        aliases: [i: :import]
      )

    Mix.Task.run("app.start")

    tt_ref =
      case opts[:import] do
        nil ->
          Raxol.Debug.TimeTravel

        path ->
          {:ok, pid} = Raxol.Debug.TimeTravel.start_link(name: nil)
          {:ok, _count} = Raxol.Debug.TimeTravel.import_file(pid, path)
          Mix.shell().info("Imported snapshots from #{path}")
          pid
      end

    Application.put_env(:raxol, :debugger_tt_ref, tt_ref)

    {:ok, pid} = Raxol.start_link(Raxol.Debug.DebuggerApp, [])
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    end
  end
end
