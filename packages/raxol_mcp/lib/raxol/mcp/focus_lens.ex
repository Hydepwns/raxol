defmodule Raxol.MCP.FocusLens do
  @moduledoc """
  Attention-aware tool filtering for MCP surfaces.

  Complex UIs can expose 100+ tools, but LLM tool selection degrades
  past ~20. FocusLens filters the full tool set to a manageable subset
  based on which widget has focus.

  ## Modes

    * `:all` -- return all tools (default for headless sessions)
    * `:focused` -- return tools for the focused widget + globals

  In `:focused` mode, a `discover_tools` meta-tool is always included
  so agents can search the full set by keyword.

  ## Usage

      all_tools = TreeWalker.derive_tools(view_tree, context)

      # Headless: show everything
      FocusLens.filter(all_tools, mode: :all)

      # Interactive: show focused + globals
      FocusLens.filter(all_tools, mode: :focused, focused_id: "search_input")
  """

  @default_max_tools 15

  @type tool_def :: Raxol.MCP.Registry.tool_def()

  @doc """
  Filters a list of tools based on focus state.

  ## Options

    * `:mode` - `:all` (default) or `:focused`
    * `:focused_id` - widget ID that currently has focus (for `:focused` mode)
    * `:max_tools` - maximum number of tools to return (default: 15)
    * `:registry` - Registry reference for `discover_tools` (optional)
  """
  @spec filter([tool_def()], keyword()) :: [tool_def()]
  def filter(tools, opts \\ []) do
    mode = Keyword.get(opts, :mode, :all)
    max_tools = Keyword.get(opts, :max_tools, @default_max_tools)

    case mode do
      :all ->
        Enum.take(tools, max_tools)

      :focused ->
        focused_id = Keyword.get(opts, :focused_id)
        registry = Keyword.get(opts, :registry)
        filter_focused(tools, focused_id, max_tools, registry)
    end
  end

  @doc """
  Returns the `discover_tools` meta-tool spec.

  This tool lets agents search the full tool set by keyword when
  FocusLens is hiding tools. Pass a registry reference so the tool
  can query all registered tools.
  """
  @spec discover_tools_spec(GenServer.server()) :: tool_def()
  def discover_tools_spec(registry) do
    %{
      name: "discover_tools",
      description:
        "Search all available tools in the current session by keyword. " <>
          "Use this when the tool you need is not in the current focused set.",
      inputSchema: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "Search term to match against tool names and descriptions"
          }
        },
        required: ["query"]
      },
      callback: fn args ->
        query = String.downcase(args["query"] || "")
        all_tools = Raxol.MCP.Registry.list_tools(registry)

        matches =
          all_tools
          |> Enum.filter(fn tool ->
            String.downcase(tool[:name] || "") =~ query or
              String.downcase(tool[:description] || "") =~ query
          end)
          |> Enum.map(fn tool ->
            %{name: tool[:name], description: tool[:description]}
          end)

        {:ok, [%{type: "text", text: inspect(matches)}]}
      end
    }
  end

  defp filter_focused(tools, nil, max_tools, _registry) do
    Enum.take(tools, max_tools)
  end

  defp filter_focused(tools, focused_id, max_tools, registry) do
    prefix = "#{focused_id}."

    focused_tools =
      Enum.filter(tools, fn tool ->
        String.starts_with?(tool.name, prefix)
      end)

    global_tools =
      Enum.filter(tools, fn tool ->
        not String.contains?(tool.name, ".")
      end)

    discover =
      if registry do
        [discover_tools_spec(registry)]
      else
        []
      end

    (focused_tools ++ discover ++ global_tools)
    |> Enum.uniq_by(& &1.name)
    |> Enum.take(max_tools)
  end
end
