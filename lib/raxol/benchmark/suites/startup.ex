defmodule Raxol.Benchmark.Suites.Startup do
  @moduledoc """
  Benchmarks Lifecycle startup time from start_link to initialized state.

  Uses `environment: :agent` to skip terminal driver and focus on
  framework initialization overhead.
  """

  alias Raxol.Benchmark.Apps

  @doc "Returns Benchee job map for startup timing."
  @spec jobs(keyword()) :: map()
  def jobs(opts \\ []) do
    apps = if opts[:quick], do: [Apps.Empty, Apps.SimpleText], else: Apps.all()

    Map.new(apps, fn mod ->
      name = mod |> Module.split() |> List.last()

      {"startup_#{name}",
       fn ->
         unique_name =
           :"startup_bench_#{name}_#{System.unique_integer([:positive])}"

         {:ok, pid} =
           Raxol.Core.Runtime.Lifecycle.start_link(mod,
             environment: :agent,
             name: unique_name
           )

         Process.unlink(pid)
         GenServer.cast(pid, :shutdown)
         :ok
       end}
    end)
  end
end
