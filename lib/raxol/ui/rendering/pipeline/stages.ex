defmodule Raxol.UI.Rendering.Pipeline.Stages do
  @moduledoc """
  Core rendering pipeline stage execution.
  Manages the sequential execution of rendering stages:
  1. Layout - Calculate positions and sizes
  2. Composition - Build render tree
  3. Paint - Convert to draw commands
  4. Commit - Send to renderer
  """

  require Logger
  alias Raxol.UI.Rendering.{Layouter, Composer, Painter}

  @type diff_result :: term()
  @type tree :: map() | nil
  @type layout_data :: map() | nil
  @type composed_data :: map() | nil
  @type painted_data :: term()

  @doc """
  Executes all rendering stages in sequence.
  Returns {painted_output, composed_tree} for state storage.
  """
  @spec execute_render_stages(
          diff_result(),
          tree(),
          module(),
          composed_data(),
          painted_data()
        ) :: {painted_data(), composed_data()}
  def execute_render_stages(
        diff_result,
        new_tree_for_reference,
        _renderer_module,
        previous_composed_tree,
        previous_painted_output
      ) do
    process_render_stages(
      should_process_tree?(diff_result, new_tree_for_reference),
      diff_result,
      new_tree_for_reference,
      previous_composed_tree,
      previous_painted_output
    )
  end

  defp process_render_stages(
         false,
         _diff_result,
         _new_tree_for_reference,
         previous_composed_tree,
         previous_painted_output
       ) do
    Logger.debug(
      "Render Pipeline: No effective tree to process based on initial diff_result and new_tree_for_reference."
    )

    {previous_painted_output, previous_composed_tree}
  end

  defp process_render_stages(
         _should_process,
         diff_result,
         new_tree_for_reference,
         previous_composed_tree,
         previous_painted_output
       ) do
    layout_data = Layouter.layout_tree(diff_result, new_tree_for_reference)

    process_layout_stage(
      should_process_layout?(diff_result, layout_data),
      diff_result,
      layout_data,
      new_tree_for_reference,
      previous_composed_tree,
      previous_painted_output
    )
  end

  defp process_layout_stage(
         false,
         _diff_result,
         _layout_data,
         _new_tree_for_reference,
         previous_composed_tree,
         previous_painted_output
       ) do
    Logger.debug(
      "Render Pipeline: Layout stage resulted in nil, skipping compose, paint and commit."
    )

    {previous_painted_output, previous_composed_tree}
  end

  defp process_layout_stage(
         _should_process,
         _diff_result,
         layout_data,
         new_tree_for_reference,
         previous_composed_tree,
         previous_painted_output
       ) do
    composed_data =
      Composer.compose_render_tree(
        layout_data,
        new_tree_for_reference,
        previous_composed_tree
      )

    handle_composition_stage(
      composed_data,
      layout_data,
      previous_painted_output,
      previous_composed_tree,
      new_tree_for_reference
    )
  end

  @doc """
  Handles the composition and paint stages after successful layout.
  """
  @spec handle_composition_stage(
          composed_data(),
          layout_data(),
          painted_data(),
          composed_data(),
          tree()
        ) :: {painted_data(), composed_data()}
  def handle_composition_stage(
        composed_data,
        layout_data,
        previous_painted_output,
        previous_composed_tree,
        new_tree_for_reference
      ) do
    process_composition_stage(
      should_process_composition?(composed_data, layout_data),
      composed_data,
      new_tree_for_reference,
      previous_composed_tree,
      previous_painted_output
    )
  end

  defp process_composition_stage(
         false,
         composed_data,
         _new_tree_for_reference,
         _previous_composed_tree,
         previous_painted_output
       ) do
    Logger.debug(
      "Render Pipeline: Composition stage resulted in nil, skipping paint and commit."
    )

    {previous_painted_output, composed_data}
  end

  defp process_composition_stage(
         _should_process,
         composed_data,
         new_tree_for_reference,
         previous_composed_tree,
         previous_painted_output
       ) do
    painted_data =
      Painter.paint(
        composed_data,
        new_tree_for_reference,
        previous_composed_tree,
        previous_painted_output
      )

    {painted_data, composed_data}
  end

  # Stage validation functions

  @doc false
  def should_process_tree?(diff_result, new_tree_for_reference) do
    is_map(new_tree_for_reference) or
      diff_result == {:replace, nil} or
      (is_tuple(diff_result) and elem(diff_result, 0) == :replace)
  end

  @doc false
  def should_process_layout?(diff_result, layout_data) do
    is_map(layout_data) or
      (is_tuple(diff_result) and elem(diff_result, 0) == :replace and
         elem(diff_result, 1) == nil)
  end

  @doc false
  def should_process_composition?(composed_data, layout_data) do
    is_map(composed_data) or
      (is_map(layout_data) and map_size(layout_data) == 0) or
      layout_data == nil
  end
end
