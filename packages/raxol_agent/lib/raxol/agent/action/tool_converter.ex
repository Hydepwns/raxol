defmodule Raxol.Agent.Action.ToolConverter do
  @moduledoc """
  Converts Action modules to LLM tool definitions and dispatches tool calls.

  Use `to_tool_definitions/1` to generate the `tools` parameter for
  OpenAI/Anthropic API calls, then `dispatch_tool_call/3` to route
  the LLM's tool call response back to the matching Action module.
  """

  @doc """
  Convert action modules to tool definitions for LLM API calls.

  Returns a list of JSON Schema function tool definitions.
  """
  @spec to_tool_definitions([module()]) :: [map()]
  def to_tool_definitions(action_modules) when is_list(action_modules) do
    Enum.map(action_modules, fn module ->
      module.to_tool_definition()
    end)
  end

  @doc """
  Dispatch an LLM tool call to the matching action module.

  The `tool_call` map should have `"name"` and `"arguments"` keys
  (standard OpenAI/Anthropic function calling format). Arguments can
  be a string (JSON) or a pre-parsed map with string keys.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec dispatch_tool_call(map(), [module()], map()) ::
          {:ok, map()} | {:ok, map(), [Raxol.Core.Runtime.Command.t()]} | {:error, term()}
  def dispatch_tool_call(tool_call, action_modules, context \\ %{}) do
    name = Map.get(tool_call, "name") || Map.get(tool_call, :name)
    raw_args = Map.get(tool_call, "arguments") || Map.get(tool_call, :arguments, %{})

    with {:ok, module} <- find_action(name, action_modules),
         {:ok, params} <- parse_arguments(raw_args, module) do
      module.call(params, context)
    end
  end

  @doc """
  Build a tool result message for feeding back to the LLM.

  Encodes the result as a JSON string suitable for the `tool` role message.
  """
  @spec format_tool_result(String.t(), map()) :: map()
  def format_tool_result(tool_call_id, result) when is_map(result) do
    %{
      role: "tool",
      tool_call_id: tool_call_id,
      content: Jason.encode!(result)
    }
  end

  # -- Private ---------------------------------------------------------------

  defp find_action(name, action_modules) do
    case Enum.find(action_modules, fn mod -> mod.__action_meta__().name == name end) do
      nil -> {:error, {:unknown_tool, name}}
      module -> {:ok, module}
    end
  end

  defp parse_arguments(args, _action_module) when is_map(args) do
    {:ok, atomize_keys(args)}
  end

  defp parse_arguments(args, _action_module) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, map} when is_map(map) -> {:ok, atomize_keys(map)}
      {:ok, _} -> {:error, :arguments_not_object}
      {:error, _} = err -> err
    end
  end

  defp parse_arguments(_args, _action_module), do: {:ok, %{}}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {safe_to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp safe_to_existing_atom(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> str
  end
end
