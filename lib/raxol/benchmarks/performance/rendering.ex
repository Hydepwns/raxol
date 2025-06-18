defmodule Raxol.Benchmarks.Performance.Rendering do
  @moduledoc '''
  Rendering performance benchmark functions for Raxol.
  '''

  @doc '''
  Benchmarks rendering performance for various component types and complexities.

  Tests rendering performance for:
  - Simple components (text, buttons)
  - Medium complexity (tables, lists)
  - Complex components (dashboards, multi-panel layouts)
  '''
  def benchmark_rendering do
    IO.puts("Benchmarking rendering performance...")

    # Prepare test components
    simple_component = generate_test_component(:simple)
    medium_component = generate_test_component(:medium)
    complex_component = generate_test_component(:complex)

    # Measure rendering time for each complexity
    simple_render_time = measure_render_time(simple_component, 1000)
    medium_render_time = measure_render_time(medium_component, 100)
    complex_render_time = measure_render_time(complex_component, 10)

    # Measure full screen render time
    full_screen_time = measure_full_screen_render(100)

    # Calculate average render time per component
    results = %{
      simple_component_time_μs: simple_render_time,
      medium_component_time_μs: medium_render_time,
      complex_component_time_μs: complex_render_time,
      full_screen_render_time_ms: full_screen_time,
      components_per_frame: calculate_components_per_frame(simple_render_time),
      renders_per_second: calculate_renders_per_second(full_screen_time)
    }

    IO.puts("✓ Rendering benchmarks complete")
    results
  end

  # Helper functions moved from Raxol.Benchmarks.Performance

  # Making public for use by other benchmarks
  def generate_test_component(:simple) do
    # Return a simple text or button component
    %{type: :simple, content: "Simple test component"}
  end

  def generate_test_component(:medium) do
    # Return a medium complexity component like a form or table
    items = for i <- 1..10, do: %{id: i, name: "Item #{i}"}
    %{type: :medium, items: items, has_border: true}
  end

  def generate_test_component(:complex) do
    # Return a complex component like a dashboard
    panels =
      for i <- 1..5 do
        sub_items =
          for j <- 1..10, do: %{id: j, value: j * i, label: "Value #{j}"}

        %{
          id: i,
          title: "Panel #{i}",
          items: sub_items,
          has_charts: true,
          has_tables: true
        }
      end

    %{type: :complex, panels: panels, layout: :grid}
  end

  # Making public for use by other benchmarks
  def measure_render_time(component, iterations) do
    {time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          # Simulate rendering by converting component to string representation
          render_component(component)
        end
      end)

    # Return average microseconds per render
    time / iterations
  end

  # Making public for use by other benchmarks
  def render_component(component) do
    # Simulate the work of rendering a component to a string
    case component do
      %{type: :simple, content: content} ->
        content
        |> to_string()
        |> String.pad_trailing(20)
        |> String.pad_leading(24)

      %{type: :medium, items: items} ->
        header = "| ID  | Name       |\n|-----|------------|\n"

        rows =
          Enum.map_join(items, "\n", fn %{id: id, name: name} ->
            "| #{String.pad_trailing(to_string(id), 4)} | #{String.pad_trailing(name, 10)} |"
          end)

        header <> rows

      %{type: :complex, panels: panels} ->
        Enum.map_join(panels, "\n\n", fn panel ->
          title = "=== #{panel.title} ===\n"
          table = "Table with #{length(panel.items)} items"
          chart = "Chart visualization"
          title <> table <> "\n" <> chart
        end)
    end
  end

  # Making public for use by other benchmarks
  def measure_full_screen_render(iterations) do
    # Simulate rendering a full screen (80x24 terminal)
    width = 80
    height = 24

    {time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          # Create a screen buffer and fill it with content
          buffer =
            for y <- 1..height do
              for x <- 1..width do
                "#{rem(x * y, 10)}"
              end
              |> Enum.join("")
            end
            |> Enum.join("\n")

          # Force evaluation
          _ = byte_size(buffer)
        end
      end)

    # Return average milliseconds per full screen render
    time / iterations / 1000
  end

  # Making public for use by other benchmarks
  def calculate_components_per_frame(simple_component_time_μs) do
    # Calculate how many simple components can render in 16.67ms (60 FPS)
    frame_budget_μs = 16667
    trunc(frame_budget_μs / simple_component_time_μs)
  end

  # Making public for use by other benchmarks
  def calculate_renders_per_second(full_screen_time_ms) do
    # Calculate full screens per second
    trunc(1000 / full_screen_time_ms)
  end
end
