defmodule Raxol.Benchmark.Suites.InputLatency do
  @moduledoc """
  Benchmarks the event -> update -> view -> layout -> cells pipeline.

  Measures end-to-end latency from a simulated input event through the
  full TEA cycle to rendered cells.
  """

  alias Raxol.Benchmark.Apps
  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.Renderer, as: UIRenderer
  alias Raxol.UI.Theming.Theme

  @dimensions %{width: 120, height: 40}

  @doc "Returns Benchee job map for input latency."
  @spec jobs(keyword()) :: map()
  def jobs(opts \\ []) do
    theme = Theme.get(Theme.default_theme_id())
    apps = if opts[:quick], do: [Apps.SimpleText], else: Apps.all()

    Map.new(apps, fn mod ->
      model = mod.init(nil)
      name = mod |> Module.split() |> List.last()

      {"latency_#{name}",
       fn ->
         {updated_model, _commands} = mod.update(:tick, model)
         view = mod.view(updated_model)
         positioned = LayoutEngine.apply_layout(view, @dimensions)
         UIRenderer.render_to_cells(positioned, theme)
       end}
    end)
  end
end
