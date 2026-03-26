defmodule Raxol.Benchmark.Apps do
  @moduledoc """
  Fixture TEA applications for benchmarking render throughput, input latency,
  and memory usage. Each app has known complexity and pure implementations
  (no subscriptions, no side effects).
  """

  defmodule Empty do
    @moduledoc "Minimal TEA app: empty model, empty view."
    use Raxol.Core.Runtime.Application

    @impl true
    def init(_), do: %{}

    @impl true
    def update(_msg, model), do: {model, []}

    @impl true
    def view(_model), do: text("")
  end

  defmodule SimpleText do
    @moduledoc "10 lines of text in a column."
    use Raxol.Core.Runtime.Application

    @impl true
    def init(_) do
      %{lines: Enum.map(1..10, &"Line #{&1}: The quick brown fox")}
    end

    @impl true
    def update(:tick, model), do: {model, []}
    def update(_msg, model), do: {model, []}

    @impl true
    def view(model) do
      column do
        Enum.map(model.lines, fn line ->
          text(line)
        end)
      end
    end
  end

  defmodule Table100 do
    @moduledoc "100-row, 5-column table."
    use Raxol.Core.Runtime.Application

    @impl true
    def init(_) do
      rows =
        Enum.map(1..100, fn i ->
          %{
            id: i,
            name: "Item #{i}",
            status: Enum.random(["active", "pending", "done"]),
            count: :rand.uniform(1000),
            score: Float.round(:rand.uniform() * 100, 1)
          }
        end)

      %{rows: rows}
    end

    @impl true
    def update(:tick, model), do: {model, []}
    def update(_msg, model), do: {model, []}

    @impl true
    def view(model) do
      column do
        [
          text("ID  | Name       | Status  | Count | Score", style: [:bold])
          | Enum.map(model.rows, fn r ->
              line =
                String.pad_trailing("#{r.id}", 4) <>
                  "| " <>
                  String.pad_trailing(r.name, 11) <>
                  "| " <>
                  String.pad_trailing(r.status, 8) <>
                  "| " <>
                  String.pad_trailing("#{r.count}", 6) <>
                  "| #{r.score}"

              text(line)
            end)
        ]
      end
    end
  end

  defmodule NestedLayout do
    @moduledoc "Nested row > column > box > text, depth 3."
    use Raxol.Core.Runtime.Application

    @impl true
    def init(_), do: %{depth: 3}

    @impl true
    def update(_msg, model), do: {model, []}

    @impl true
    def view(model) do
      row do
        Enum.map(1..3, fn i ->
          column do
            Enum.map(1..3, fn j ->
              box style: %{border: :single, padding: 1} do
                column do
                  Enum.map(1..model.depth, fn k ->
                    text("Cell [#{i},#{j},#{k}]")
                  end)
                end
              end
            end)
          end
        end)
      end
    end
  end

  defmodule Dashboard do
    @moduledoc "Mixed 3-panel dashboard with text, table rows, and progress indicators."
    use Raxol.Core.Runtime.Application

    @impl true
    def init(_) do
      %{
        title: "System Dashboard",
        stats: %{cpu: 42.5, memory: 67.8, uptime: "3d 14h"},
        log_lines: Enum.map(1..15, &"[INFO] Event #{&1} processed"),
        tasks:
          Enum.map(1..8, fn i ->
            %{name: "Task #{i}", progress: :rand.uniform(100)}
          end)
      }
    end

    @impl true
    def update(:tick, model), do: {model, []}
    def update(_msg, model), do: {model, []}

    @impl true
    def view(model) do
      column style: %{gap: 0} do
        [
          text(model.title, style: [:bold]),
          row style: %{gap: 1} do
            [
              box style: %{border: :single, padding: 1} do
                column do
                  [
                    text("CPU: #{model.stats.cpu}%"),
                    text("MEM: #{model.stats.memory}%"),
                    text("UP:  #{model.stats.uptime}")
                  ]
                end
              end,
              box style: %{border: :single, padding: 1} do
                column do
                  Enum.map(model.log_lines, fn line ->
                    text(line)
                  end)
                end
              end,
              box style: %{border: :single, padding: 1} do
                column do
                  Enum.map(model.tasks, fn task ->
                    bar = String.duplicate("#", div(task.progress, 5))

                    text(
                      "#{String.pad_trailing(task.name, 8)} [#{String.pad_trailing(bar, 20)}] #{task.progress}%"
                    )
                  end)
                end
              end
            ]
          end
        ]
      end
    end
  end

  @doc "Returns all benchmark app modules."
  @spec all :: nonempty_list(
          Empty | SimpleText | Table100 | NestedLayout | Dashboard
        )
  def all do
    [Empty, SimpleText, Table100, NestedLayout, Dashboard]
  end

  @doc "Returns a map of app name to module for benchmarking."
  @spec as_map :: %{String.t() => module()}
  def as_map do
    Map.new(all(), fn mod ->
      name = mod |> Module.split() |> List.last() |> Macro.underscore()
      {name, mod}
    end)
  end
end
