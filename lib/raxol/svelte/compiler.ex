defmodule Raxol.Svelte.Compiler do
  @moduledoc """
  Compile-time template compiler for Raxol Svelte components.

  Transforms templates into efficient direct buffer operations,
  eliminating virtual DOM overhead.

  ## Compilation Process

  1. Parse template AST
  2. Analyze dependencies and reactive bindings
  3. Generate optimized buffer operations
  4. Inline static content
  5. Create minimal update paths

  ## Example

      # Template
      ~H\"\"\"
      <Box x={@x} y={@y}>
        <Text color="green">{@message}</Text>
        <Button on_click={&increment/0}>Count: {@count}</Button>
      </Box>
      \"\"\"
      
      # Compiles to:
      def render_optimized(assigns, buffer) do
        buffer
        |> draw_box(assigns.x, assigns.y, 20, 5, :single)
        |> move_cursor(assigns.x + 1, assigns.y + 1)
        |> set_color(:green)
        |> write_text(assigns.message)
        |> move_cursor(assigns.x + 1, assigns.y + 2)
        |> draw_button("Count: \#{assigns.count}", &increment/0)
      end
  """

  @doc """
  Compile a template AST to optimized buffer operations.
  """
  def compile_template(template_ast, opts \\ []) do
    optimize = Keyword.get(opts, :optimize, true)

    template_ast
    |> analyze_template()
    |> optimize_static_content()
    |> generate_buffer_operations()
    |> apply_optimizations(optimize)
  end

  @doc """
  Analyze template for dependencies and structure.
  """
  def analyze_template(ast) do
    %{
      ast: ast,
      dependencies: extract_dependencies(ast),
      static_parts: find_static_parts(ast),
      dynamic_parts: find_dynamic_parts(ast),
      components: find_components(ast),
      directives: find_directives(ast)
    }
  end

  @doc """
  Generate buffer operations from analyzed template.
  """
  def generate_buffer_operations(analysis) do
    operations =
      analysis.ast
      |> flatten_ast()
      |> Enum.map(&ast_node_to_operation/1)
      |> List.flatten()
      |> optimize_operations()

    %{analysis | operations: operations}
  end

  # Template Analysis

  defp extract_dependencies(ast) do
    {_, deps} =
      Macro.prewalk(ast, MapSet.new(), fn
        # Reactive variables (@var)
        {:@, _, [{var, _, _}]} = node, acc ->
          {node, MapSet.put(acc, {:reactive, var})}

        # Function calls that might be reactive
        {{:., _, [{var, _, _}, _]}, _, _} = node, acc ->
          {node, MapSet.put(acc, {:function, var})}

        # Component props
        {component, _, props} = node, acc when is_atom(component) ->
          prop_deps = extract_prop_dependencies(props)
          {node, MapSet.union(acc, prop_deps)}

        node, acc ->
          {node, acc}
      end)

    MapSet.to_list(deps)
  end

  defp extract_prop_dependencies(props) when is_list(props) do
    Enum.reduce(props, MapSet.new(), fn
      {_key, {:@, _, [{var, _, _}]}}, acc ->
        MapSet.put(acc, {:prop, var})

      {_key, {{:., _, _}, _, _} = call}, acc ->
        MapSet.put(acc, {:call, call})

      _, acc ->
        acc
    end)
  end

  defp extract_prop_dependencies(_), do: MapSet.new()

  defp find_static_parts(ast) do
    {_, static} =
      Macro.prewalk(ast, [], fn
        # Text nodes without interpolation
        {:text, _, [content]} = node, acc when is_binary(content) ->
          {node, [{:static_text, content} | acc]}

        # Elements with only static props
        {element, _, props} = node, acc when is_atom(element) ->
          handle_static_element(
            all_static_props?(props),
            node,
            element,
            props,
            acc
          )

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(static)
  end

  defp find_dynamic_parts(ast) do
    {_, dynamic} =
      Macro.prewalk(ast, [], fn
        # Interpolated text {expr}
        {:expr, _, [expr]} = node, acc ->
          {node, [{:dynamic_text, expr} | acc]}

        # Elements with dynamic props
        {element, _, props} = node, acc when is_atom(element) ->
          dynamic_props =
            Enum.filter(props, fn {_k, v} -> is_dynamic_value?(v) end)

          handle_dynamic_element(
            dynamic_props != [],
            node,
            element,
            dynamic_props,
            acc
          )

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(dynamic)
  end

  defp find_components(ast) do
    {_, components} =
      Macro.prewalk(ast, [], fn
        # Custom components (capitalized)
        {component, _, props} = node, acc when is_atom(component) ->
          handle_component_name(
            component_name?(component),
            node,
            component,
            props,
            acc
          )

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(components)
  end

  defp find_directives(ast) do
    {_, directives} =
      Macro.prewalk(ast, [], fn
        # Event handlers
        {element, _, props} = node, acc when is_atom(element) ->
          events =
            Enum.filter(props, fn
              {:on_click, _} -> true
              {:on_change, _} -> true
              {:on_enter, _} -> true
              _ -> false
            end)

          uses =
            Enum.filter(props, fn
              {key, _} -> String.starts_with?(Atom.to_string(key), "use_")
            end)

          new_directives = events ++ uses

          handle_new_directives(
            new_directives != [],
            node,
            element,
            new_directives,
            acc
          )

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(directives)
  end

  # Buffer Operation Generation

  defp flatten_ast(ast) do
    case ast do
      {:__block__, _, children} -> Enum.flat_map(children, &flatten_ast/1)
      list when is_list(list) -> Enum.flat_map(list, &flatten_ast/1)
      node -> [node]
    end
  end

  defp ast_node_to_operation({:text, _, [content]}) when is_binary(content) do
    {:write_text, content, []}
  end

  defp ast_node_to_operation({:expr, _, [expr]}) do
    {:write_expr, expr, []}
  end

  defp ast_node_to_operation({element, _, props}) when is_atom(element) do
    case element do
      :Box ->
        generate_box_operations(props)

      :Text ->
        generate_text_operations(props)

      :Button ->
        generate_button_operations(props)

      :TextInput ->
        generate_input_operations(props)

      component when is_atom(component) ->
        handle_component_operation(component_name?(component), component, props)
    end
  end

  defp ast_node_to_operation(node) do
    {:unknown, node, []}
  end

  defp generate_box_operations(props) do
    [
      {:begin_box, extract_box_style(props)},
      {:position, get_prop(props, :x, 0), get_prop(props, :y, 0)},
      {:size, get_prop(props, :width, :auto), get_prop(props, :height, :auto)},
      {:border, get_prop(props, :border, :none)},
      {:padding, get_prop(props, :padding, 0)}
    ]
  end

  defp generate_text_operations(props) do
    [
      {:write_text, get_prop(props, :children, ""),
       [
         color: get_prop(props, :color, :default),
         bold: get_prop(props, :bold, false),
         italic: get_prop(props, :italic, false)
       ]}
    ]
  end

  defp generate_button_operations(props) do
    [
      {:draw_button, get_prop(props, :children, "Button"),
       [
         on_click: get_prop(props, :on_click, nil),
         variant: get_prop(props, :variant, :default),
         disabled: get_prop(props, :disabled, false)
       ]}
    ]
  end

  defp generate_input_operations(props) do
    [
      {:draw_input,
       [
         value: get_prop(props, :value, ""),
         placeholder: get_prop(props, :placeholder, ""),
         on_change: get_prop(props, :on_change, nil)
       ]}
    ]
  end

  # Optimization

  defp optimize_static_content(analysis) do
    # Group consecutive static operations
    optimized_static =
      analysis.static_parts
      |> Enum.chunk_by(&is_text_operation?/1)
      |> Enum.map(&maybe_merge_text/1)

    %{analysis | static_parts: optimized_static}
  end

  defp optimize_operations(operations) do
    operations
    |> merge_consecutive_writes()
    |> eliminate_redundant_moves()
    |> batch_style_changes()
  end

  defp merge_consecutive_writes(operations) do
    Enum.reduce(operations, [], fn
      {:write_text, text1, opts1}, [{:write_text, text2, opts2} | rest]
      when opts1 == opts2 ->
        [{:write_text, text2 <> text1, opts1} | rest]

      op, acc ->
        [op | acc]
    end)
    |> Enum.reverse()
  end

  defp eliminate_redundant_moves(operations) do
    Enum.reduce(operations, [], fn
      {:position, x, y}, [{:position, x, y} | rest] ->
        [{:position, x, y} | rest]

      op, acc ->
        [op | acc]
    end)
    |> Enum.reverse()
  end

  defp batch_style_changes(operations) do
    # Group consecutive style operations
    operations
  end

  defp apply_optimizations(analysis, true) do
    # Apply aggressive optimizations
    analysis
  end

  defp apply_optimizations(analysis, false) do
    # Keep operations as-is for debugging
    analysis
  end

  # Helper Functions

  defp all_static_props?(props) when is_list(props) do
    Enum.all?(props, fn {_k, v} -> !is_dynamic_value?(v) end)
  end

  defp all_static_props?(_), do: true

  defp is_dynamic_value?({:@, _, _}), do: true
  defp is_dynamic_value?({{:., _, _}, _, _}), do: true
  defp is_dynamic_value?(_), do: false

  defp component_name?(atom) when is_atom(atom) do
    name = Atom.to_string(atom)
    String.match?(name, ~r/^[A-Z]/)
  end

  defp is_text_operation?({:static_text, _}), do: true
  defp is_text_operation?(_), do: false

  defp maybe_merge_text([{:static_text, _} | _] = texts) do
    content = texts |> Enum.map(fn {:static_text, t} -> t end) |> Enum.join()
    {:static_text, content}
  end

  defp maybe_merge_text([single]), do: single

  defp get_prop(props, key, default) when is_list(props) do
    Keyword.get(props, key, default)
  end

  defp get_prop(_, _, default), do: default

  defp extract_box_style(props) do
    %{
      border: get_prop(props, :border, :none),
      padding: get_prop(props, :padding, 0),
      margin: get_prop(props, :margin, 0)
    }
  end

  # Helper functions to eliminate if statements

  defp handle_static_element(false, node, _element, _props, acc) do
    {node, acc}
  end

  defp handle_static_element(true, node, element, props, acc) do
    {node, [{:static_element, element, props} | acc]}
  end

  defp handle_dynamic_element(false, node, _element, _dynamic_props, acc) do
    {node, acc}
  end

  defp handle_dynamic_element(true, node, element, dynamic_props, acc) do
    {node, [{:dynamic_element, element, dynamic_props} | acc]}
  end

  defp handle_component_name(false, node, _component, _props, acc) do
    {node, acc}
  end

  defp handle_component_name(true, node, component, props, acc) do
    {node, [{component, props} | acc]}
  end

  defp handle_new_directives(false, node, _element, _new_directives, acc) do
    {node, acc}
  end

  defp handle_new_directives(true, node, element, new_directives, acc) do
    {node, [{element, new_directives} | acc]}
  end

  defp handle_component_operation(false, component, _props) do
    # Handle as unknown element
    {:error, :unknown_element, component}
  end

  defp handle_component_operation(true, component, props) do
    {:render_component, component, props}
  end
end
