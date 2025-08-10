defmodule Raxol.Svelte.Reactive do
  @moduledoc """
  Svelte-style reactive declarations for Raxol.

  Provides reactive statement syntax similar to Svelte's `$:`,
  automatically re-executing code when dependencies change using reactive_stmt().

  ## Example

      defmodule Calculator do
        use Raxol.Svelte.Component
        
        state :x, 0
        state :y, 0
        
        # These automatically re-run when x or y change
        reactive_block do
          reactive_stmt(sum = @x + @y)
          reactive_stmt(product = @x * @y)
          reactive_stmt(description = "Sum: \#{sum}, Product: \#{product}")
          reactive_stmt(IO.puts("Calculation updated: \#{description}"))
        end
        
        def render do
          ~S'''
          <Box>
            <Text>X: {@x}, Y: {@y}</Text>
            <Text>Sum: {sum}</Text>
            <Text>Product: {product}</Text>
            <Text>{description}</Text>
          </Box>
          '''
        end
      end
  """

  @doc """
  Define a reactive block that automatically re-executes when dependencies change.
  Uses reactive_stmt() calls similar to Svelte's `$:` syntax.
  """
  defmacro reactive_block(do: block) do
    statements = extract_reactive_statements(block)

    quote do
      @reactive_statements unquote(statements)

      # Generate a function that executes all reactive statements
      def execute_reactive_statements(state) do
        unquote(transform_reactive_block(block))
      end
    end
  end

  @doc """
  Single reactive statement.
  """
  defmacro reactive_statement(statement) do
    deps = extract_dependencies_from_statement(statement)
    transformed = transform_reactive_statement(statement)

    quote do
      @reactive_statements Map.put(
                             @reactive_statements || %{},
                             make_ref(),
                             %{
                               deps: unquote(deps),
                               execute: fn state -> unquote(transformed) end
                             }
                           )
    end
  end

  @doc """
  Reactive assignment with automatic dependency tracking.

  This simulates Svelte's $: syntax. Use ~R sigil for nicer syntax:

      reactive_block do
        ~R"sum = @x + @y"
        ~R"product = @x * @y"
      end
  """
  defmacro reactive_stmt(statement) do
    case statement do
      {:=, _, [var, expression]} ->
        create_reactive_assignment(var, expression)

      expression ->
        create_reactive_expression(expression)
    end
  end

  # Private helper functions

  defp extract_reactive_statements({:__block__, _, statements}) do
    Enum.map(statements, &extract_single_statement/1)
  end

  defp extract_reactive_statements(single_statement) do
    [extract_single_statement(single_statement)]
  end

  defp extract_single_statement({:reactive_stmt, _, [statement]}) do
    deps = extract_dependencies_from_statement(statement)

    %{
      statement: statement,
      deps: deps,
      id: make_ref()
    }
  end

  defp extract_single_statement(statement) do
    # Non-reactive statement
    %{
      statement: statement,
      deps: [],
      id: make_ref()
    }
  end

  defp extract_dependencies_from_statement(ast) do
    {_, deps} =
      Macro.prewalk(ast, [], fn
        {:@, _, [{var, _, _}]} = node, acc ->
          {node, [var | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(deps)
  end

  defp transform_reactive_block({:__block__, meta, statements}) do
    transformed_statements =
      Enum.map(statements, &transform_reactive_statement/1)

    {:__block__, meta, transformed_statements}
  end

  defp transform_reactive_block(single_statement) do
    transform_reactive_statement(single_statement)
  end

  defp transform_reactive_statement({:reactive_stmt, _, [statement]}) do
    transform_statement_body(statement)
  end

  defp transform_reactive_statement(statement) do
    statement
  end

  defp transform_statement_body({:=, meta, [var, expression]}) do
    transformed_expr = transform_expression(expression)

    quote do
      var!(unquote(var)) = unquote(transformed_expr)
      # Store in component state for template access
      GenServer.call(
        self(),
        {:set_reactive_var, unquote(Atom.to_string(var)), var!(unquote(var))}
      )
    end
  end

  defp transform_statement_body(expression) do
    transform_expression(expression)
  end

  defp transform_expression(ast) do
    Macro.prewalk(ast, fn
      {:@, _, [{var, _, _}]} ->
        quote do
          get_in(state, [:state, unquote(var)]) ||
            get_in(state, [:reactive, unquote(var)]) ||
            get_reactive_var(unquote(var))
        end

      node ->
        node
    end)
  end

  defp create_reactive_assignment(var, expression) do
    deps = extract_dependencies_from_statement(expression)

    var_name =
      case var do
        {name, _, _} when is_atom(name) -> name
        name when is_atom(name) -> name
      end

    quote do
      @reactive_vars Map.put(@reactive_vars || %{}, unquote(var_name), %{
                       deps: unquote(deps),
                       compute: fn state ->
                         unquote(transform_expression(expression))
                       end
                     })
    end
  end

  defp create_reactive_expression(expression) do
    deps = extract_dependencies_from_statement(expression)

    quote do
      @reactive_expressions (@reactive_expressions || []) ++
                              [
                                %{
                                  deps: unquote(deps),
                                  execute: fn state ->
                                    unquote(transform_expression(expression))
                                  end
                                }
                              ]
    end
  end

  @doc """
  Mixin for components using reactive declarations.
  """
  defmacro __using__(_opts) do
    quote do
      import Raxol.Svelte.Reactive

      @reactive_statements %{}
      @reactive_vars %{}
      @reactive_expressions []
      @reactive_var_cache %{}

      # Add reactive variable support to GenServer
      @impl GenServer
      def handle_call({:set_reactive_var, name, value}, _from, state) do
        cache = Map.put(state[:reactive_var_cache] || %{}, name, value)
        state = Map.put(state, :reactive_var_cache, cache)
        {:reply, :ok, state}
      end

      @impl GenServer
      def handle_call({:get_reactive_var, name}, _from, state) do
        value = get_in(state, [:reactive_var_cache, name])
        {:reply, value, state}
      end

      def get_reactive_var(name) do
        GenServer.call(self(), {:get_reactive_var, name})
      end

      # Execute reactive statements when state changes
      defp execute_all_reactive_statements(state) do
        # Execute reactive expressions
        Enum.each(@reactive_expressions, fn %{execute: execute} ->
          execute.(state)
        end)

        # Update reactive variables
        Enum.reduce(@reactive_vars, state, fn {name, %{compute: compute}},
                                              acc ->
          value = compute.(acc)
          put_in(acc, [:reactive, name], value)
        end)
      end

      # Override state update to trigger reactive statements
      defp update_state_with_reactive(state) do
        new_state = execute_all_reactive_statements(state)

        # Check if we have the reactive execution function
        if function_exported?(__MODULE__, :execute_reactive_statements, 1) do
          execute_reactive_statements(new_state)
        end

        new_state
      end

      # Hook into state changes
      def handle_call({:set_state, name, value}, _from, state) do
        new_state = put_in(state, [:state, name], value)
        new_state = update_state_with_reactive(new_state)

        # Mark as dirty and schedule render
        send(self(), :render)

        {:reply, :ok, %{new_state | dirty: true}}
      end

      def handle_call({:update_state, name, fun}, _from, state) do
        current = get_in(state, [:state, name])
        new_value = fun.(current)

        new_state = put_in(state, [:state, name], new_value)
        new_state = update_state_with_reactive(new_state)

        # Mark as dirty and schedule render
        send(self(), :render)

        {:reply, new_value, %{new_state | dirty: true}}
      end

      defoverridable handle_call: 3
    end
  end
end
