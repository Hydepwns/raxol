defmodule Raxol.Benchmark.Suites.WidgetMemory do
  @moduledoc """
  Benchmarks per-widget and composite memory usage.

  Measures memory for individual widget renders and composite sets
  at various scales (10, 50, 100 widgets).
  """

  alias Raxol.Benchmark.Apps
  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.Renderer, as: UIRenderer
  alias Raxol.UI.Theming.Theme

  @dimensions %{width: 120, height: 40}

  @doc "Returns Benchee job map for widget memory."
  @spec jobs(keyword()) :: map()
  def jobs(opts \\ []) do
    theme = Theme.get(Theme.default_theme_id())

    base_jobs =
      Map.new(Apps.all(), fn mod ->
        model = mod.init(nil)
        name = mod |> Module.split() |> List.last()

        {"memory_#{name}",
         fn ->
           view = mod.view(model)
           positioned = LayoutEngine.apply_layout(view, @dimensions)
           UIRenderer.render_to_cells(positioned, theme)
         end}
      end)

    scale_jobs =
      if opts[:quick] do
        %{}
      else
        %{
          "memory_10_texts" => fn -> render_n_texts(10, theme) end,
          "memory_50_texts" => fn -> render_n_texts(50, theme) end,
          "memory_100_texts" => fn -> render_n_texts(100, theme) end
        }
      end

    Map.merge(base_jobs, scale_jobs)
  end

  defp render_n_texts(n, theme) do
    # Build a column of N text elements using the View DSL indirectly
    view = %{
      type: :column,
      children:
        Enum.map(1..n, fn i ->
          %{type: :text, content: "Text widget ##{i}", style: %{}}
        end),
      style: %{}
    }

    positioned = LayoutEngine.apply_layout(view, @dimensions)
    UIRenderer.render_to_cells(positioned, theme)
  end
end
