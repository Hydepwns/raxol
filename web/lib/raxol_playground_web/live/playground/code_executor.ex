defmodule RaxolPlaygroundWeb.Playground.CodeExecutor do
  @moduledoc """
  Handles compilation and execution of playground code examples.
  Provides sandboxed code execution with proper cleanup.
  """

  @doc """
  Executes component code and returns formatted output with timing information.
  """
  def execute(code, component) do
    start_time = System.monotonic_time(:microsecond)

    case compile_and_execute(code, component) do
      {:ok, output} ->
        elapsed = (System.monotonic_time(:microsecond) - start_time) / 1000.0

        result = """
        +===========================================================+
        |              Component Rendered Successfully              |
        +===========================================================+
        |                                                           |
        #{output}
        |                                                           |
        |   Render time: #{Float.round(elapsed, 2)}ms                                      |
        +===========================================================+
        """

        {:ok, result}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  rescue
    error ->
      {:error, "Unexpected error: #{Exception.message(error)}"}
  end

  defp compile_and_execute(code, component) do
    base_name = :"PlaygroundComponent#{:erlang.unique_integer([:positive])}"
    module_name = Module.concat([base_name])

    full_code = """
    defmodule #{inspect(module_name)} do
      #{code}
    end
    """

    try do
      case Code.compile_string(full_code) do
        [{compiled_module, _bytecode}] when compiled_module == module_name ->
          result = render_component(module_name, component)
          cleanup_module(module_name)
          result

        [{compiled_module, _bytecode}] ->
          result = render_component(compiled_module, component)
          cleanup_module(compiled_module)
          result

        [] ->
          {:error, "Failed to compile module"}

        _other ->
          {:error, "Unexpected compilation result"}
      end
    rescue
      e in CompileError ->
        {:error, {:compile_error, e.description}}

      e ->
        {:error, {:exception, Exception.message(e)}}
    end
  end

  defp cleanup_module(module_name) do
    if Code.ensure_loaded?(module_name) do
      :code.delete(module_name)
      :code.purge(module_name)
    end
  end

  defp render_component(module, component) do
    cond do
      function_exported?(module, :render, 1) ->
        render_template_component(module, component)

      function_exported?(module, :render, 2) ->
        render_buffer_component(component)

      function_exported?(module, :render, 4) ->
        render_raw_component(component)

      true ->
        {:error, "No valid render function found"}
    end
  end

  defp render_template_component(module, component) do
    assigns = %{
      component: component.name,
      framework: component.framework
    }

    case module.render(assigns) do
      {:safe, iodata} ->
        html = IO.iodata_to_binary(iodata)

        output = """
        |   Component: #{String.pad_trailing(component.name, 43)} |
        |   Framework: #{String.pad_trailing(component.framework, 43)} |
        |                                                           |
        |   Template Output (simplified):                          |
        |   #{String.pad_trailing(extract_text(html), 53)} |
        """

        {:ok, output}

      other ->
        {:ok, "|   Output: #{inspect(other) |> String.slice(0, 50)}"}
    end
  rescue
    e ->
      {:error, "Render failed: #{Exception.message(e)}"}
  end

  defp render_buffer_component(component) do
    output = """
    |   Component: #{String.pad_trailing(component.name, 43)} |
    |   Framework: Raw (buffer)                                 |
    |                                                           |
    |   Note: Buffer rendering requires terminal context       |
    """

    {:ok, output}
  end

  defp render_raw_component(component) do
    output = """
    |   Component: #{String.pad_trailing(component.name, 43)} |
    |   Framework: Raw                                          |
    |                                                           |
    |   Note: Raw rendering requires terminal buffer           |
    """

    {:ok, output}
  end

  defp extract_text(html) do
    html
    |> String.replace(~r/<[^>]+>/, "")
    |> String.trim()
    |> String.slice(0, 50)
  end

  defp format_error({:compile_error, description}) do
    """
    Compilation Error:

    #{description}

    Check your syntax and make sure all modules are properly defined.
    """
  end

  defp format_error({:exception, message}) do
    """
    Runtime Error:

    #{message}
    """
  end

  defp format_error(other) do
    """
    Error:

    #{inspect(other)}
    """
  end
end
