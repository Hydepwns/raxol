defmodule Raxol.Test.Visual do
  @moduledoc """
  Provides utilities for visual testing of Raxol components.

  This module handles:
  - Component rendering verification
  - Layout testing
  - Style validation
  - Terminal output comparison
  - Cross-terminal compatibility testing

  ## Example

      defmodule MyComponent.VisualTest do
        use ExUnit.Case
        use Raxol.Test.Visual

        test 'renders correctly' do
          component = setup_visual_component(MyComponent)

          assert_renders_as component, fn output ->
            assert output =~ "Expected Content"
            assert_layout_matches output, width: 10, height: 5
          end
        end
      end
  """

  alias Raxol.Test.TestHelper
  alias Raxol.Terminal.Buffer.Operations
  import Raxol.Guards

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.Visual
      import Raxol.Test.Visual.Matchers
    end
  end

  @doc """
  Sets up a component for visual testing.

  This function:
  1. Initializes the component
  2. Sets up the render context
  3. Configures the test terminal
  4. Prepares snapshot directories
  """
  def setup_visual_component(module, props \\ %{}) do
    {:ok, component} = Raxol.Test.Unit.setup_isolated_component(module, props)

    # Defensive check: ensure component is a map with :module and :state
    if !(map?(component) and Map.has_key?(component, :module) and
           Map.has_key?(component, :state)) do
      raise ArgumentError,
            "setup_visual_component/2 expected a map with :module and :state keys, got: #{inspect(component)}"
    end

    # Set up render context
    terminal = TestHelper.setup_test_terminal()
    theme = Raxol.UI.Theming.Theme.default_theme()
    initial_width = 80
    initial_height = 24

    render_context = %{
      terminal: terminal,
      viewport: %{width: initial_width, height: initial_height},
      max_width: initial_width,
      max_height: initial_height,
      theme: theme
    }

    Map.merge(component, %{render_context: render_context})
  end

  @doc """
  Captures the rendered output of a component using a direct rendering pipeline.
  Ensures that the component is rendered in a controlled environment suitable for visual testing.

  The `component_struct` argument is expected to be a Raxol component map, potentially
  containing a `:render_context` key with `:width`, `:height`, and `:theme` information.
  If `:render_context` or its keys are missing, defaults will be applied.

  Returns the terminal output as a string for comparison.
  """
  @spec capture_render(Raxol.Core.Types.Component.t() | map()) :: String.t()
  def capture_render(component_or_map_or_view, opts \\ []) do
    # IO.inspect("MARKER VISUAL_EX TOP CAPTURE_RENDER")

    # If a pre-rendered view_map is passed, use it directly
    {view_map, width, height, theme} =
      if map?(component_or_map_or_view) &&
           Map.has_key?(component_or_map_or_view, :type) do
        # This is likely a view_map already, extract details or use defaults
        extract_render_details_from_view_map(component_or_map_or_view, opts)
      else
        # This is a component struct or a map of props to build one
        extract_render_details(component_or_map_or_view)
      end

    # Ensure elements to layout is a list
    elements_to_layout = if list?(view_map), do: view_map, else: [view_map]

    # Log dimensions being used for layout
    # Raxol.Core.Runtime.Log.info("[VisualTest] Layout Dimensions: W=#{width}, H=#{height}")

    layout_elements =
      Raxol.Renderer.Layout.apply_layout(elements_to_layout, %{
        width: width,
        height: height
      })

    # IO.inspect(layout_elements, label: "CR_LAYOUT_ELEMENTS") # CR = Capture Render
    # IO.inspect(&Raxol.UI.Renderer.render_to_cells/2, label: "FUNCTION_REF_VISUAL_EX")
    raw_cells = Raxol.UI.Renderer.render_to_cells(layout_elements, theme)
    # IO.inspect(raw_cells, label: "CR_RAW_CELLS")

    # Ensure raw_cells is a list, even if it's empty or contains non-cell data (error case)
    cells_list = if list?(raw_cells), do: raw_cells, else: []

    # Populate the screen buffer with raw cells
    initial_buffer = Raxol.Terminal.ScreenBuffer.new(width, height)

    final_buffer =
      Enum.reduce(cells_list, initial_buffer, fn
        {x, y, char, fg, bg, attrs}, acc_buffer ->
          # Default to space if nil
          actual_char = if nil?(char), do: ~c" ", else: char

          # IO.inspect(unexpected_cell_data, label: "UNEXPECTED_RAW_CELL_DATA_IN_REDUCE") # This was an error, it should be the tuple {x,y,char...}
          Operations.write_char(acc_buffer, x, y, actual_char, %{
            foreground: fg,
            background: bg,
            attrs: attrs
          })

        # Handle non-tuple data
        _unexpected_cell_data, acc_buffer ->
          # IO.inspect(unexpected_cell_data, label: "UNEXPECTED_RAW_CELL_DATA_IN_REDUCE")
          # Ignore and return buffer
          acc_buffer
      end)

    # IO.inspect(final_buffer, label: "CAPTURE_RENDER_FINAL_BUFFER")

    # Render the buffer to a string
    renderer_instance = Raxol.Terminal.Renderer.new(final_buffer, theme)
    output_string = Raxol.Terminal.Renderer.render(renderer_instance)
    # IO.inspect(output_string, label: "CAPTURE_RENDER_OUTPUT_STRING")
    output_string
  end

  defp extract_render_details_from_view_map(view_map, _opts) do
    extract_render_details_from_view_map(view_map)
  end

  defp extract_render_details_from_view_map(view_map) do
    default_ctx = default_render_context()

    # Try to get dimensions and theme from the view_map's render_context, then view_map itself, then defaults
    render_context_from_view_map = Map.get(view_map, :render_context)

    width =
      get_in(render_context_from_view_map, [:max_width]) ||
        get_in(render_context_from_view_map, [:terminal, :width]) ||
        Map.get(view_map, :max_width) ||
        Map.get(view_map, :width) ||
        default_ctx.max_width

    height =
      get_in(render_context_from_view_map, [:max_height]) ||
        get_in(render_context_from_view_map, [:terminal, :height]) ||
        Map.get(view_map, :max_height) ||
        Map.get(view_map, :height) ||
        default_ctx.max_height

    theme =
      get_in(render_context_from_view_map, [:theme]) ||
        Map.get(view_map, :theme) ||
        default_ctx.theme

    {view_map, width, height, theme}
  end

  defp extract_render_details(component_or_map) when map?(component_or_map) do
    # IO.inspect("MARKER VISUAL_EX TOP EXTRACT_RENDER_DETAILS")
    # Extract or default the rendering context
    render_context_from_component = Map.get(component_or_map, :render_context)
    default_ctx = default_render_context()

    # Prioritize keys from component's render_context, then defaults
    width =
      get_in(render_context_from_component, [:max_width]) ||
        get_in(render_context_from_component, [:terminal, :width]) ||
        default_ctx.max_width

    height =
      get_in(render_context_from_component, [:max_height]) ||
        get_in(render_context_from_component, [:terminal, :height]) ||
        default_ctx.max_height

    theme = get_in(render_context_from_component, [:theme]) || default_ctx.theme

    base_context =
      default_ctx |> Map.merge(render_context_from_component || %{})

    current_context_for_render =
      base_context
      |> Map.put(:max_width, width)
      |> Map.put(:max_height, height)
      # Ensure theme is set before accessing terminal/viewport
      |> Map.put(:theme, theme)
      |> Map.update(:terminal, %{}, fn terminal_map ->
        terminal_map
        |> Map.put(:width, width)
        |> Map.put(:height, height)
      end)
      |> Map.update(:viewport, %{}, fn viewport_map ->
        viewport_map
        |> Map.put(:width, width)
        |> Map.put(:height, height)
      end)

    view_map = render_component(component_or_map, current_context_for_render)

    # Return the extracted details, not the fully rendered string.
    # The main capture_render function will handle layout, cell rendering, and string output.
    {view_map, width, height, theme}
  end

  @doc """
  Verifies that a component renders as expected.

  Takes a function that can make assertions about the rendered output.
  """
  def assert_renders_as(component, assertions)
      when function?(assertions, 1) do
    output = capture_render(component)
    assertions.(output)
  end

  @doc """
  Creates or updates a snapshot of the component's rendered output.

  Used for visual regression testing.
  """
  def snapshot_component(component, name, context) do
    output = capture_render(component)
    snapshot_path = Path.join([context.snapshots_dir, "#{name}.snap"])

    File.mkdir_p!(Path.dirname(snapshot_path))
    File.write!(snapshot_path, output)

    output
  end

  @doc """
  Compares a component's current render with its snapshot.

  Returns a detailed diff if there are differences.
  """
  def compare_with_snapshot(component, name, context) do
    current = capture_render(component)
    snapshot_path = Path.join([context.snapshots_dir, "#{name}.snap"])

    case File.read(snapshot_path) do
      {:ok, expected} ->
        if current == expected do
          :ok
        else
          {:diff, compute_visual_diff(expected, current)}
        end

      {:error, :enoent} ->
        {:error, :no_snapshot}
    end
  end

  @doc """
  Tests a component's rendering across different terminal sizes.

  Verifies responsive behavior and layout adaptability.
  """
  def test_responsive_rendering(component, sizes) when list?(sizes) do
    Enum.map(sizes, fn {width, height} ->
      # Create an updated render_context for this specific size
      updated_render_context =
        Map.merge(component.render_context, %{
          viewport: %{width: width, height: height},
          max_width: width,
          max_height: height
        })

      # Create a component instance with this specific render_context for capture_render
      component_for_size = %{component | render_context: updated_render_context}

      # Capture render at this size
      output = capture_render(component_for_size)

      # Return as a map for verification
      %{width: width, height: height, output: output}
    end)
  end

  @doc """
  Tests a component's rendering with different style themes.

  Verifies proper style application and theme switching.
  """
  def test_themed_rendering(component, themes) when map?(themes) do
    Enum.map(themes, fn {name, partial_theme_map} ->
      # Get the original full theme struct from the component's render_context
      original_full_theme_struct = get_in(component.render_context.theme)

      # Merge the partial_theme_map into the original_full_theme_struct
      # This ensures that :component_styles and other essential keys from the original struct are preserved.
      updated_theme_struct =
        Map.merge(original_full_theme_struct, partial_theme_map)

      # Create a new component state with this updated theme struct for rendering
      component_for_this_theme =
        put_in(component.render_context.theme, updated_theme_struct)

      # Capture themed render
      output = capture_render(component_for_this_theme)

      # Return theme and output for verification
      {name, output}
    end)
  end

  # @doc """
  # Verifies that a component's layout adapts correctly to its container.
  #
  # Tests proper sizing, positioning, and constraint handling.
  # """
  # def verify_layout_constraints(component, constraints) do
  #   # Get current layout
  #   layout = get_component_layout(component)
  #
  #   # Verify each constraint
  #   Enum.reduce_while(constraints, :ok, fn
  #     {:min_width, min}, :ok ->
  #       if layout.width >= min, do: {:cont, :ok}, else: {:halt, {:error, :min_width}}
  #     {:max_width, max}, :ok ->
  #       if layout.width <= max, do: {:cont, :ok}, else: {:halt, {:error, :max_width}}
  #     {:min_height, min}, :ok ->
  #       if layout.height >= min, do: {:cont, :ok}, else: {:halt, {:error, :min_height}}
  #     {:max_height, max}, :ok ->
  #       if layout.height <= max, do: {:cont, :ok}, else: {:halt, {:error, :max_height}}
  #     {key, value}, :ok ->
  #       if layout[key] == value, do: {:cont, :ok}, else: {:halt, {:error, key}}
  #   end)
  # end

  # Private Helpers

  @doc """
  Renders a component state within a controlled test environment.
  Accepts an optional context map.
  """
  def render_component(component_map, context \\ default_render_context()) do
    if !(map?(component_map) and Map.has_key?(component_map, :state)) do
      raise ArgumentError,
            "render_component/2 expected a map with :module and :state keys, got: #{inspect(component_map)}"
    end

    # Extract the actual state and module from the component map
    state = component_map.state
    module = component_map.module

    # Pass the *actual* state and the *provided* context to the component's render/2 function
    rendered_view = module.render(state, context)

    # Return the raw view structure
    rendered_view
  end

  defp default_render_context do
    %{
      terminal: %{output: [], width: 80, cursor: {0, 0}, height: 24},
      theme: Raxol.UI.Theming.Theme.default_theme(),
      viewport: %{width: 80, height: 24},
      max_width: 80,
      max_height: 24,
      errors: %{},
      focused_component: nil,
      # Match typical full context structure
      terminal_size: {80, 24}
    }
  end

  defp compute_visual_diff(_expected, _actual) do
    # Placeholder: Implement actual diffing logic (e.g., using Diffy)
    # Return a list of tagged tuples as expected by format_diff/1
    [{:eq, "No difference detected (placeholder)"}]
  end
end
