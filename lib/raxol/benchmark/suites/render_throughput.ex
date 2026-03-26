defmodule Raxol.Benchmark.Suites.RenderThroughput do
  @moduledoc """
  Benchmarks the view -> layout -> cells render pipeline at 5 complexity levels.

  Measures pure function call throughput (no GenServer overhead) to isolate
  the actual rendering cost.
  """

  alias Raxol.Benchmark.Apps
  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.Renderer, as: UIRenderer
  alias Raxol.UI.Theming.Theme

  @dimensions %{width: 120, height: 40}

  @doc "Returns Benchee job map for render throughput."
  @spec jobs(keyword()) :: map()
  def jobs(opts \\ []) do
    theme = Theme.get(Theme.default_theme_id())
    apps = if opts[:quick], do: [Apps.Empty, Apps.SimpleText], else: Apps.all()

    Map.new(apps, fn mod ->
      model = mod.init(nil)
      name = mod |> Module.split() |> List.last()

      {"render_#{name}",
       fn ->
         view = mod.view(model)
         positioned = LayoutEngine.apply_layout(view, @dimensions)
         UIRenderer.render_to_cells(positioned, theme)
       end}
    end)
  end
end
