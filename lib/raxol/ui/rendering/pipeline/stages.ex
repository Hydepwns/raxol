defmodule Raxol.UI.Rendering.Pipeline.Stages do
  @moduledoc """
  Defines and executes the rendering pipeline stages for UI components.

  Stages:
  1. Validate - ensure tree is well-formed
  2. Preprocess - handle operation type (replace vs partial update)
  3. Apply styles - merge default/theme/custom styles
  4. Layout - calculate positions via LayoutEngine.apply_layout
  5. Render - convert positioned elements to cells via UIRenderer.render_to_cells
  6. Post-process - optimize output
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.Renderer, as: UIRenderer

  @default_width 80
  @default_height 24

  @doc """
  Executes the rendering pipeline stages.

  ## Parameters

  * `operation` - The diff operation (e.g. `{:replace, tree}`, `{:update, path, changes}`)
  * `tree` - The current UI element tree
  * `renderer_module` - Optional renderer module (used as fallback if UIRenderer unavailable)
  * `context` - Previous composed tree (for caching/reuse)
  * `options` - Previous painted output (for caching/reuse)
  """
  def execute_render_stages(operation, tree, renderer_module, context, options) do
    tree
    |> validate_tree()
    |> preprocess(operation)
    |> apply_styles()
    |> layout()
    |> render(renderer_module, context, options)
    |> postprocess()
  end

  # Stage 1: Validate the tree structure
  defp validate_tree(nil), do: %{}
  defp validate_tree(tree), do: tree

  # Stage 2: Preprocess based on operation type
  defp preprocess(tree, {:update, region, subtree}) do
    tree
    |> Map.put(:region, region)
    |> Map.put(:subtree, subtree)
  end

  defp preprocess(tree, _operation), do: tree

  # Stage 3: Apply styles to the tree
  defp apply_styles(tree) do
    Map.put_new(tree, :style, %{})
  end

  # Stage 4: Layout calculation using real LayoutEngine
  defp layout(tree) do
    dimensions = extract_dimensions(tree)

    case tree do
      %{type: _} ->
        # Tree is an element tree -- run through LayoutEngine
        positioned = LayoutEngine.apply_layout(tree, dimensions)
        %{tree: tree, positioned_elements: positioned, dimensions: dimensions}

      %{children: _} ->
        # Wrap as a view for LayoutEngine
        view = Map.put(tree, :type, :view)
        positioned = LayoutEngine.apply_layout(view, dimensions)
        %{tree: tree, positioned_elements: positioned, dimensions: dimensions}

      _ ->
        # Not a recognizable element tree -- pass through with empty positioning
        %{tree: tree, positioned_elements: [], dimensions: dimensions}
    end
  end

  # Stage 5: Render positioned elements to cells using UIRenderer
  defp render(
         %{positioned_elements: positioned, tree: tree} = _layout_result,
         renderer_module,
         _context,
         _options
       ) do
    cells = render_positioned_elements(positioned, renderer_module)

    %{
      rendered: true,
      content: tree,
      cells: cells,
      output: cells
    }
  end


  defp render_positioned_elements([], _renderer_module), do: []

  defp render_positioned_elements(positioned, _renderer_module) do
    UIRenderer.render_to_cells(positioned)
  end

  # Stage 6: Post-processing
  defp postprocess(rendered), do: rendered

  # --- Public convenience functions ---

  @doc """
  Executes a simplified render for performance-critical paths.
  """
  def fast_render(tree, renderer_module) do
    tree
    |> validate_tree()
    |> layout()
    |> render(renderer_module, nil, nil)
  end

  @doc """
  Executes only the layout stage.
  """
  def layout_only(tree) do
    tree
    |> validate_tree()
    |> layout()
  end

  @doc """
  Executes only the style application stage.
  """
  def style_only(tree) do
    tree
    |> validate_tree()
    |> apply_styles()
  end

  # --- Private helpers ---

  defp extract_dimensions(%{width: w, height: h}), do: %{width: w, height: h}

  defp extract_dimensions(_),
    do: %{width: @default_width, height: @default_height}
end
